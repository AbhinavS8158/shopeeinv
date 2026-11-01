import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../core/database/app_database.dart';
import '../core/database/sync_service.dart';
import '../core/models/invoice.dart';
import '../core/models/stock_log.dart';
import 'cart_provider.dart';

class BillingProvider extends ChangeNotifier {
  List<Invoice> _invoices = [];
  bool _isLoading = false;

  List<Invoice> get invoices => _invoices;
  bool get isLoading => _isLoading;

  Future<void> loadInvoices(String shopId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await AppDatabase.instance.database;
      final result = await db.query(
        'invoices',
        where: 'shopId = ?',
        whereArgs: [shopId],
        orderBy: 'invoiceDate DESC',
      );
      _invoices = result.map((m) => Invoice.fromMap(m)).toList();
    } catch (e) {
      debugPrint('Error loading invoices: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String> getNextInvoiceNumber(String shopId, String prefix) async {
    final db = await AppDatabase.instance.database;
    final todayStr = DateFormat('yyyyMMdd').format(DateTime.now());
    final countResult = await db.rawQuery(
      "SELECT COUNT(*) FROM invoices WHERE shopId = ? AND invoiceNumber LIKE ?",
      [shopId, '$prefix$todayStr-%'],
    );
    final count = (countResult.first.values.first as int? ?? 0) + 1;
    return '$prefix$todayStr-${count.toString().padLeft(4, '0')}';
  }

  Future<Invoice?> createInvoice({
    required String shopId,
    required String invoiceNumber,
    required String customerId,
    required String customerName,
    required String customerPhone,
    required String customerGstin,
    required List<CartItem> cartItems,
    required double subtotal,
    required double discountAmount,
    required double taxableAmount,
    required double cgstAmount,
    required double sgstAmount,
    required double totalTax,
    required double roundOff,
    required double grandTotal,
    required double paidAmount,
    required String paymentMode, // 'cash', 'upi', 'card', 'credit'
    String notes = '',
  }) async {
    try {
      final db = await AppDatabase.instance.database;
      final invoiceId = const Uuid().v4();
      final dueAmount = (grandTotal - paidAmount) > 0 ? (grandTotal - paidAmount) : 0.0;
      final paymentStatus = dueAmount == 0
          ? 'paid'
          : (paidAmount > 0 ? 'partial' : 'unpaid');

      final items = cartItems.map((c) => c.toInvoiceItem()).toList();

      final invoice = Invoice(
        id: invoiceId,
        shopId: shopId,
        invoiceNumber: invoiceNumber,
        invoiceDate: DateTime.now(),
        customerId: customerId,
        customerName: customerName,
        customerPhone: customerPhone,
        customerGstin: customerGstin,
        items: items,
        subtotal: subtotal,
        discountAmount: discountAmount,
        taxableAmount: taxableAmount,
        cgstAmount: cgstAmount,
        sgstAmount: sgstAmount,
        totalTax: totalTax,
        roundOff: roundOff,
        grandTotal: grandTotal,
        paidAmount: paidAmount,
        dueAmount: dueAmount,
        paymentMode: paymentMode,
        paymentStatus: paymentStatus,
        notes: notes,
      );

      // Save Invoice
      await db.insert('invoices', invoice.toMap());

      // Deduct stock & create stock log for each product
      for (final cartItem in cartItems) {
        final prodResult = await db.query(
          'products',
          where: 'id = ?',
          whereArgs: [cartItem.product.id],
        );

        if (prodResult.isNotEmpty) {
          final oldQty = (prodResult.first['stockQuantity'] as num?)?.toDouble() ?? 0.0;
          final newQty = oldQty - cartItem.quantity;

          await db.update(
            'products',
            {
              'stockQuantity': newQty,
              'updatedAt': DateTime.now().toIso8601String(),
              'isSynced': 0,
            },
            where: 'id = ?',
            whereArgs: [cartItem.product.id],
          );

          // Stock Log
          final log = StockLog(
            id: const Uuid().v4(),
            shopId: shopId,
            productId: cartItem.product.id,
            productName: cartItem.product.name,
            changeType: 'sale',
            quantityChange: -cartItem.quantity,
            previousQuantity: oldQty,
            newQuantity: newQty,
            reason: 'Sale Bill #$invoiceNumber',
            referenceId: invoiceId,
          );
          await db.insert('stock_logs', log.toMap());
        }
      }

      // If due amount exists and customer is chosen, update customer's credit balance
      if (dueAmount > 0 && customerId.isNotEmpty) {
        final custResult = await db.query('customers', where: 'id = ?', whereArgs: [customerId]);
        if (custResult.isNotEmpty) {
          final currentCredit = (custResult.first['creditBalance'] as num?)?.toDouble() ?? 0.0;
          await db.update(
            'customers',
            {
              'creditBalance': currentCredit + dueAmount,
              'updatedAt': DateTime.now().toIso8601String(),
              'isSynced': 0,
            },
            where: 'id = ?',
            whereArgs: [customerId],
          );
        }
      }

      await loadInvoices(shopId);
      SyncService.instance.updatePendingCount();
      SyncService.instance.syncAll();
      return invoice;
    } catch (e) {
      debugPrint('Error creating invoice: $e');
      return null;
    }
  }

  // Get sales collected within a specific time window (e.g. cash session)
  double getSalesSince(DateTime since) {
    return _invoices
        .where((inv) => inv.invoiceDate.isAfter(since) || inv.invoiceDate.isAtSameMomentAs(since))
        .fold(0.0, (sum, inv) => sum + inv.paidAmount);
  }

  // Get cash sales specifically since session started
  double getCashSalesSince(DateTime since) {
    return _invoices
        .where((inv) =>
            (inv.invoiceDate.isAfter(since) || inv.invoiceDate.isAtSameMomentAs(since)) &&
            inv.paymentMode.toLowerCase() == 'cash')
        .fold(0.0, (sum, inv) => sum + inv.paidAmount);
  }

  // Get UPI sales specifically since session started
  double getUpiSalesSince(DateTime since) {
    return _invoices
        .where((inv) =>
            (inv.invoiceDate.isAfter(since) || inv.invoiceDate.isAtSameMomentAs(since)) &&
            inv.paymentMode.toLowerCase() == 'upi')
        .fold(0.0, (sum, inv) => sum + inv.paidAmount);
  }

  // Total sales for today
  double get todayCollectedAmount {
    final now = DateTime.now();
    return _invoices
        .where((inv) =>
            inv.invoiceDate.year == now.year &&
            inv.invoiceDate.month == now.month &&
            inv.invoiceDate.day == now.day)
        .fold(0.0, (sum, inv) => sum + inv.paidAmount);
  }

  // Dashboard Stats
  double get todaySalesAmount {
    final now = DateTime.now();
    return _invoices
        .where((inv) =>
            inv.invoiceDate.year == now.year &&
            inv.invoiceDate.month == now.month &&
            inv.invoiceDate.day == now.day)
        .fold(0.0, (sum, inv) => sum + inv.grandTotal);
  }

  int get todaySalesCount {
    final now = DateTime.now();
    return _invoices
        .where((inv) =>
            inv.invoiceDate.year == now.year &&
            inv.invoiceDate.month == now.month &&
            inv.invoiceDate.day == now.day)
        .length;
  }

  double get monthlySalesAmount {
    final now = DateTime.now();
    return _invoices
        .where((inv) =>
            inv.invoiceDate.year == now.year &&
            inv.invoiceDate.month == now.month)
        .fold(0.0, (sum, inv) => sum + inv.grandTotal);
  }

  List<Invoice> get recentInvoices {
    return _invoices.take(5).toList();
  }
}

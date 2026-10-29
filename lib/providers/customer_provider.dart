import 'package:flutter/material.dart';
import '../core/database/app_database.dart';
import '../core/database/sync_service.dart';
import '../core/models/customer.dart';

class CustomerProvider extends ChangeNotifier {
  List<Customer> _customers = [];
  bool _isLoading = false;

  List<Customer> get customers => _customers;
  bool get isLoading => _isLoading;

  Future<void> loadCustomers(String shopId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await AppDatabase.instance.database;
      final result = await db.query(
        'customers',
        where: 'shopId = ?',
        whereArgs: [shopId],
        orderBy: 'name ASC',
      );
      _customers = result.map((m) => Customer.fromMap(m)).toList();
    } catch (e) {
      debugPrint('Error loading customers: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Customer?> saveCustomer(Customer customer) async {
    try {
      final db = await AppDatabase.instance.database;
      final isExisting = _customers.any((c) => c.id == customer.id);

      if (!isExisting) {
        await db.insert('customers', customer.copyWith(isSynced: false).toMap());
      } else {
        await db.update(
          'customers',
          customer.copyWith(updatedAt: DateTime.now(), isSynced: false).toMap(),
          where: 'id = ?',
          whereArgs: [customer.id],
        );
      }

      await loadCustomers(customer.shopId);
      SyncService.instance.updatePendingCount();
      SyncService.instance.syncAll();
      return customer;
    } catch (e) {
      debugPrint('Error saving customer: $e');
      return null;
    }
  }

  Future<void> updateCreditBalance(String customerId, double changeAmount, String shopId) async {
    try {
      final db = await AppDatabase.instance.database;
      final c = _customers.firstWhere((x) => x.id == customerId);
      final newBalance = c.creditBalance + changeAmount;
      await db.update(
        'customers',
        {
          'creditBalance': newBalance,
          'updatedAt': DateTime.now().toIso8601String(),
          'isSynced': 0,
        },
        where: 'id = ?',
        whereArgs: [customerId],
      );
      await loadCustomers(shopId);
      SyncService.instance.updatePendingCount();
      SyncService.instance.syncAll();
    } catch (e) {
      debugPrint('Error updating credit balance: $e');
    }
  }
}

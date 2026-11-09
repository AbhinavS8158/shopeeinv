import 'dart:convert';

class InvoiceItem {
  final String productId;
  final String productName;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double discountAmount;
  final double gstRate; // e.g. 18
  final double taxAmount;
  final double totalAmount;
  final bool isWeightBased;
  final double? weightInGrams;
  final double? pricePerKg;
  final String productSellingType; // 'weight' or 'unit'

  InvoiceItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    this.unit = 'Pcs',
    required this.unitPrice,
    this.discountAmount = 0.0,
    this.gstRate = 0.0,
    required this.taxAmount,
    required this.totalAmount,
    this.isWeightBased = false,
    this.weightInGrams,
    this.pricePerKg,
    this.productSellingType = 'unit',
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'unit': unit,
      'unitPrice': unitPrice,
      'discountAmount': discountAmount,
      'gstRate': gstRate,
      'taxAmount': taxAmount,
      'totalAmount': totalAmount,
      'isWeightBased': isWeightBased ? 1 : 0,
      'weightInGrams': weightInGrams,
      'pricePerKg': pricePerKg,
      'productSellingType': productSellingType,
    };
  }

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: map['unit'] ?? 'Pcs',
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (map['discountAmount'] as num?)?.toDouble() ?? 0.0,
      gstRate: (map['gstRate'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (map['taxAmount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      isWeightBased: (map['isWeightBased'] == 1 || map['isWeightBased'] == true),
      weightInGrams: (map['weightInGrams'] as num?)?.toDouble(),
      pricePerKg: (map['pricePerKg'] as num?)?.toDouble(),
      productSellingType: map['productSellingType'] ??
          ((map['isWeightBased'] == 1 || map['isWeightBased'] == true) ? 'weight' : 'unit'),
    );
  }
}

class Invoice {
  final String id;
  final String shopId;
  final String invoiceNumber;
  final DateTime invoiceDate;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String customerGstin;
  final List<InvoiceItem> items;
  final double subtotal;
  final double discountAmount;
  final double taxableAmount;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double totalTax;
  final double roundOff;
  final double grandTotal;
  final double paidAmount;
  final double dueAmount;
  final String paymentMode; // 'cash', 'upi', 'card', 'credit'
  final String paymentStatus; // 'paid', 'partial', 'unpaid'
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;

  Invoice({
    required this.id,
    required this.shopId,
    required this.invoiceNumber,
    DateTime? invoiceDate,
    this.customerId = '',
    this.customerName = 'Walk-in Customer',
    this.customerPhone = '',
    this.customerGstin = '',
    required this.items,
    required this.subtotal,
    this.discountAmount = 0.0,
    required this.taxableAmount,
    this.cgstAmount = 0.0,
    this.sgstAmount = 0.0,
    this.igstAmount = 0.0,
    required this.totalTax,
    this.roundOff = 0.0,
    required this.grandTotal,
    required this.paidAmount,
    this.dueAmount = 0.0,
    this.paymentMode = 'cash',
    this.paymentStatus = 'paid',
    this.notes = '',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isSynced = false,
  })  : invoiceDate = invoiceDate ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shopId': shopId,
      'invoiceNumber': invoiceNumber,
      'invoiceDate': invoiceDate.toIso8601String(),
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerGstin': customerGstin,
      'itemsJson': jsonEncode(items.map((i) => i.toMap()).toList()),
      'subtotal': subtotal,
      'discountAmount': discountAmount,
      'taxableAmount': taxableAmount,
      'cgstAmount': cgstAmount,
      'sgstAmount': sgstAmount,
      'igstAmount': igstAmount,
      'totalTax': totalTax,
      'roundOff': roundOff,
      'grandTotal': grandTotal,
      'paidAmount': paidAmount,
      'dueAmount': dueAmount,
      'paymentMode': paymentMode,
      'paymentStatus': paymentStatus,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isSynced': isSynced ? 1 : 0,
    };
  }

  factory Invoice.fromMap(Map<String, dynamic> map) {
    List<InvoiceItem> parsedItems = [];
    if (map['itemsJson'] != null) {
      try {
        final decoded = jsonDecode(map['itemsJson']);
        if (decoded is List) {
          parsedItems = decoded.map((e) => InvoiceItem.fromMap(Map<String, dynamic>.from(e))).toList();
        }
      } catch (_) {}
    } else if (map['items'] != null && map['items'] is List) {
      parsedItems = (map['items'] as List).map((e) => InvoiceItem.fromMap(Map<String, dynamic>.from(e))).toList();
    }

    return Invoice(
      id: map['id'] ?? '',
      shopId: map['shopId'] ?? '',
      invoiceNumber: map['invoiceNumber'] ?? '',
      invoiceDate: map['invoiceDate'] != null ? DateTime.parse(map['invoiceDate']) : DateTime.now(),
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? 'Walk-in Customer',
      customerPhone: map['customerPhone'] ?? '',
      customerGstin: map['customerGstin'] ?? '',
      items: parsedItems,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (map['discountAmount'] as num?)?.toDouble() ?? 0.0,
      taxableAmount: (map['taxableAmount'] as num?)?.toDouble() ?? 0.0,
      cgstAmount: (map['cgstAmount'] as num?)?.toDouble() ?? 0.0,
      sgstAmount: (map['sgstAmount'] as num?)?.toDouble() ?? 0.0,
      igstAmount: (map['igstAmount'] as num?)?.toDouble() ?? 0.0,
      totalTax: (map['totalTax'] as num?)?.toDouble() ?? 0.0,
      roundOff: (map['roundOff'] as num?)?.toDouble() ?? 0.0,
      grandTotal: (map['grandTotal'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (map['paidAmount'] as num?)?.toDouble() ?? 0.0,
      dueAmount: (map['dueAmount'] as num?)?.toDouble() ?? 0.0,
      paymentMode: map['paymentMode'] ?? 'cash',
      paymentStatus: map['paymentStatus'] ?? 'paid',
      notes: map['notes'] ?? '',
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : DateTime.now(),
      isSynced: (map['isSynced'] == 1 || map['isSynced'] == true),
    );
  }
}

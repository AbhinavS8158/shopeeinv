class Product {
  final String id;
  final String shopId;
  final String name;
  final String sku;
  final String barcode;
  final String category;
  final double purchasePrice;
  final double sellingPrice;
  final double mrp;
  final double gstRate; // e.g. 0, 5, 12, 18, 28
  final double stockQuantity;
  final double minStockAlert;
  final String unit; // 'Pcs', 'Kg', 'Gm', 'Ltr', 'Box', 'Meter'
  final String hsnCode;
  final String supplierName;
  final DateTime? expiryDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;
  final bool isDeleted;

  Product({
    required this.id,
    required this.shopId,
    required this.name,
    this.sku = '',
    this.barcode = '',
    this.category = 'General',
    this.purchasePrice = 0.0,
    required this.sellingPrice,
    double? mrp,
    this.gstRate = 0.0,
    this.stockQuantity = 0.0,
    this.minStockAlert = 5.0,
    this.unit = 'Pcs',
    this.hsnCode = '',
    this.supplierName = '',
    this.expiryDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isSynced = false,
    this.isDeleted = false,
  })  : mrp = mrp ?? sellingPrice,
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isLowStock => stockQuantity <= minStockAlert;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shopId': shopId,
      'name': name,
      'sku': sku,
      'barcode': barcode,
      'category': category,
      'purchasePrice': purchasePrice,
      'sellingPrice': sellingPrice,
      'mrp': mrp,
      'gstRate': gstRate,
      'stockQuantity': stockQuantity,
      'minStockAlert': minStockAlert,
      'unit': unit,
      'hsnCode': hsnCode,
      'supplierName': supplierName,
      'expiryDate': expiryDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isSynced': isSynced ? 1 : 0,
      'isDeleted': isDeleted ? 1 : 0,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] ?? '',
      shopId: map['shopId'] ?? '',
      name: map['name'] ?? '',
      sku: map['sku'] ?? '',
      barcode: map['barcode'] ?? '',
      category: map['category'] ?? 'General',
      purchasePrice: (map['purchasePrice'] as num?)?.toDouble() ?? 0.0,
      sellingPrice: (map['sellingPrice'] as num?)?.toDouble() ?? 0.0,
      mrp: (map['mrp'] as num?)?.toDouble() ?? ((map['sellingPrice'] as num?)?.toDouble() ?? 0.0),
      gstRate: (map['gstRate'] as num?)?.toDouble() ?? 0.0,
      stockQuantity: (map['stockQuantity'] as num?)?.toDouble() ?? 0.0,
      minStockAlert: (map['minStockAlert'] as num?)?.toDouble() ?? 5.0,
      unit: map['unit'] ?? 'Pcs',
      hsnCode: map['hsnCode'] ?? '',
      supplierName: map['supplierName'] ?? '',
      expiryDate: map['expiryDate'] != null ? DateTime.tryParse(map['expiryDate']) : null,
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : DateTime.now(),
      isSynced: (map['isSynced'] == 1 || map['isSynced'] == true),
      isDeleted: (map['isDeleted'] == 1 || map['isDeleted'] == true),
    );
  }

  Product copyWith({
    String? id,
    String? shopId,
    String? name,
    String? sku,
    String? barcode,
    String? category,
    double? purchasePrice,
    double? sellingPrice,
    double? mrp,
    double? gstRate,
    double? stockQuantity,
    double? minStockAlert,
    String? unit,
    String? hsnCode,
    String? supplierName,
    DateTime? expiryDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
    bool? isDeleted,
  }) {
    return Product(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      category: category ?? this.category,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      mrp: mrp ?? this.mrp,
      gstRate: gstRate ?? this.gstRate,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      minStockAlert: minStockAlert ?? this.minStockAlert,
      unit: unit ?? this.unit,
      hsnCode: hsnCode ?? this.hsnCode,
      supplierName: supplierName ?? this.supplierName,
      expiryDate: expiryDate ?? this.expiryDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}

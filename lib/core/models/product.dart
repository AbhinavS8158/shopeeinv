import 'dart:convert';

class QuantityTier {
  final double minQty;
  final double? maxQty; // null means unbounded (e.g. 10+)
  final double unitPrice;

  QuantityTier({
    required this.minQty,
    this.maxQty,
    required this.unitPrice,
  });

  Map<String, dynamic> toMap() => {
    'minQty': minQty,
    'maxQty': maxQty,
    'unitPrice': unitPrice,
  };

  factory QuantityTier.fromMap(Map<String, dynamic> map) => QuantityTier(
    minQty: (map['minQty'] as num?)?.toDouble() ?? 1.0,
    maxQty: (map['maxQty'] as num?)?.toDouble(),
    unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0.0,
  );
}

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
  final bool isTaxIncluded; // true = Tax Included, false = Tax Excluded
  final String imageBase64;
  final double stockQuantity;
  final double minStockAlert;
  final String unit; // 'Pcs', 'Kg', 'Gm', 'Ltr', 'Box', 'Meter'
  final String hsnCode;
  final String supplierName;
  final DateTime? expiryDate;
  final String discountType; // 'none', 'percentage', 'fixed'
  final double discountValue; // e.g. 10% or 50 Rs
  final double maxDiscountPercent; // max allowable discount limit (default 100%)
  final String tierPricingJson; // JSON list of QuantityTier
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
    this.isTaxIncluded = false,
    this.imageBase64 = '',
    this.stockQuantity = 0.0,
    this.minStockAlert = 5.0,
    this.unit = 'Pcs',
    this.hsnCode = '',
    this.supplierName = '',
    this.expiryDate,
    this.discountType = 'none',
    this.discountValue = 0.0,
    this.maxDiscountPercent = 100.0,
    this.tierPricingJson = '',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isSynced = false,
    this.isDeleted = false,
  })  : mrp = mrp ?? sellingPrice,
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isLowStock => stockQuantity <= minStockAlert;

  List<QuantityTier> get quantityTiers {
    if (tierPricingJson.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(tierPricingJson);
      if (decoded is List) {
        final list = decoded.map((m) => QuantityTier.fromMap(m as Map<String, dynamic>)).toList();
        list.sort((a, b) => a.minQty.compareTo(b.minQty));
        return list;
      }
    } catch (_) {}
    return [];
  }

  double getUnitPriceForQty(double qty) {
    final tiers = quantityTiers;
    if (tiers.isEmpty) return sellingPrice;

    QuantityTier? matchedTier;
    for (final tier in tiers) {
      if (qty >= tier.minQty && (tier.maxQty == null || qty <= tier.maxQty!)) {
        matchedTier = tier;
      }
    }
    return matchedTier?.unitPrice ?? sellingPrice;
  }

  double calculateDefaultDiscount(double baseUnitPrice, double qty) {
    if (discountType == 'percentage' && discountValue > 0) {
      return (baseUnitPrice * qty) * (discountValue / 100.0);
    } else if (discountType == 'fixed' && discountValue > 0) {
      return discountValue * qty;
    }
    return 0.0;
  }

  bool get isWeightBased {
    final u = unit.toLowerCase().trim();
    if (u == 'kg' || u == 'gm' || u == 'g' || u == 'gram' || u == 'grams') return true;
    final cat = category.toLowerCase().trim();
    if (cat.contains('veg') ||
        cat.contains('rice') ||
        cat.contains('grain') ||
        cat.contains('fruit') ||
        cat.contains('spice') ||
        cat.contains('grocery') ||
        cat.contains('flour') ||
        cat.contains('dal') ||
        cat.contains('meat') ||
        cat.contains('fish')) {
      return true;
    }
    final n = name.toLowerCase().trim();
    if (n.contains('rice') ||
        n.contains('grain') ||
        n.contains('onion') ||
        n.contains('potato') ||
        n.contains('tomato') ||
        n.contains('dal') ||
        n.contains('sugar') ||
        n.contains('wheat') ||
        n.contains('atta') ||
        n.contains('chilli') ||
        n.contains('oil') ||
        n.contains('powder')) {
      return true;
    }
    return false;
  }

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
      'isTaxIncluded': isTaxIncluded ? 1 : 0,
      'imageBase64': imageBase64,
      'stockQuantity': stockQuantity,
      'minStockAlert': minStockAlert,
      'unit': unit,
      'hsnCode': hsnCode,
      'supplierName': supplierName,
      'expiryDate': expiryDate?.toIso8601String(),
      'discountType': discountType,
      'discountValue': discountValue,
      'maxDiscountPercent': maxDiscountPercent,
      'tierPricingJson': tierPricingJson,
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
      isTaxIncluded: (map['isTaxIncluded'] == 1 || map['isTaxIncluded'] == true),
      imageBase64: map['imageBase64'] ?? '',
      stockQuantity: (map['stockQuantity'] as num?)?.toDouble() ?? 0.0,
      minStockAlert: (map['minStockAlert'] as num?)?.toDouble() ?? 5.0,
      unit: map['unit'] ?? 'Pcs',
      hsnCode: map['hsnCode'] ?? '',
      supplierName: map['supplierName'] ?? '',
      expiryDate: map['expiryDate'] != null ? DateTime.tryParse(map['expiryDate']) : null,
      discountType: map['discountType'] ?? 'none',
      discountValue: (map['discountValue'] as num?)?.toDouble() ?? 0.0,
      maxDiscountPercent: (map['maxDiscountPercent'] as num?)?.toDouble() ?? 100.0,
      tierPricingJson: map['tierPricingJson'] ?? '',
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
    bool? isTaxIncluded,
    String? imageBase64,
    double? stockQuantity,
    double? minStockAlert,
    String? unit,
    String? hsnCode,
    String? supplierName,
    DateTime? expiryDate,
    String? discountType,
    double? discountValue,
    double? maxDiscountPercent,
    String? tierPricingJson,
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
      isTaxIncluded: isTaxIncluded ?? this.isTaxIncluded,
      imageBase64: imageBase64 ?? this.imageBase64,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      minStockAlert: minStockAlert ?? this.minStockAlert,
      unit: unit ?? this.unit,
      hsnCode: hsnCode ?? this.hsnCode,
      supplierName: supplierName ?? this.supplierName,
      expiryDate: expiryDate ?? this.expiryDate,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      maxDiscountPercent: maxDiscountPercent ?? this.maxDiscountPercent,
      tierPricingJson: tierPricingJson ?? this.tierPricingJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}

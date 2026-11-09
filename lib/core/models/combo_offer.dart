import 'dart:convert';

class ComboItem {
  final String productId;
  final String productName;
  final double quantity;

  ComboItem({
    required this.productId,
    required this.productName,
    required this.quantity,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
    };
  }

  factory ComboItem.fromMap(Map<String, dynamic> map) {
    return ComboItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

class ComboOffer {
  final String id;
  final String shopId;
  final String title;
  final String description;
  final String offerType; // 'fixed_price', 'percentage_discount', 'buy_x_get_y'
  final double comboPrice; // for fixed_price (e.g. 2000.0)
  final double discountPercentage; // for percentage_discount (e.g. 20.0)
  final List<ComboItem> items;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  ComboOffer({
    required this.id,
    required this.shopId,
    required this.title,
    this.description = '',
    required this.offerType,
    this.comboPrice = 0.0,
    this.discountPercentage = 0.0,
    required this.items,
    this.startDate,
    this.endDate,
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isValidNow {
    if (!isActive) return false;
    final now = DateTime.now();
    if (startDate != null && now.isBefore(startDate!)) return false;
    if (endDate != null && now.isAfter(endDate!)) return false;
    return true;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shopId': shopId,
      'title': title,
      'description': description,
      'offerType': offerType,
      'comboPrice': comboPrice,
      'discountPercentage': discountPercentage,
      'itemsJson': jsonEncode(items.map((i) => i.toMap()).toList()),
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isSynced': 0,
    };
  }

  factory ComboOffer.fromMap(Map<String, dynamic> map) {
    List<ComboItem> itemList = [];
    if (map['itemsJson'] != null && map['itemsJson'].toString().isNotEmpty) {
      try {
        final decoded = jsonDecode(map['itemsJson']);
        if (decoded is List) {
          itemList = decoded.map((m) => ComboItem.fromMap(m as Map<String, dynamic>)).toList();
        }
      } catch (_) {}
    }

    return ComboOffer(
      id: map['id'] ?? '',
      shopId: map['shopId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      offerType: map['offerType'] ?? 'fixed_price',
      comboPrice: (map['comboPrice'] as num?)?.toDouble() ?? 0.0,
      discountPercentage: (map['discountPercentage'] as num?)?.toDouble() ?? 0.0,
      items: itemList,
      startDate: map['startDate'] != null ? DateTime.tryParse(map['startDate']) : null,
      endDate: map['endDate'] != null ? DateTime.tryParse(map['endDate']) : null,
      isActive: (map['isActive'] == 1 || map['isActive'] == true),
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : DateTime.now(),
    );
  }

  ComboOffer copyWith({
    String? id,
    String? shopId,
    String? title,
    String? description,
    String? offerType,
    double? comboPrice,
    double? discountPercentage,
    List<ComboItem>? items,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ComboOffer(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      title: title ?? this.title,
      description: description ?? this.description,
      offerType: offerType ?? this.offerType,
      comboPrice: comboPrice ?? this.comboPrice,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      items: items ?? this.items,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

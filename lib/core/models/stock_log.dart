class StockLog {
  final String id;
  final String shopId;
  final String productId;
  final String productName;
  final String changeType; // 'sale', 'purchase', 'adjustment', 'return'
  final double quantityChange;
  final double previousQuantity;
  final double newQuantity;
  final String reason;
  final String referenceId; // invoiceId or purchaseId
  final DateTime createdAt;
  final bool isSynced;

  StockLog({
    required this.id,
    required this.shopId,
    required this.productId,
    required this.productName,
    required this.changeType,
    required this.quantityChange,
    required this.previousQuantity,
    required this.newQuantity,
    this.reason = '',
    this.referenceId = '',
    DateTime? createdAt,
    this.isSynced = false,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shopId': shopId,
      'productId': productId,
      'productName': productName,
      'changeType': changeType,
      'quantityChange': quantityChange,
      'previousQuantity': previousQuantity,
      'newQuantity': newQuantity,
      'reason': reason,
      'referenceId': referenceId,
      'createdAt': createdAt.toIso8601String(),
      'isSynced': isSynced ? 1 : 0,
    };
  }

  factory StockLog.fromMap(Map<String, dynamic> map) {
    return StockLog(
      id: map['id'] ?? '',
      shopId: map['shopId'] ?? '',
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      changeType: map['changeType'] ?? 'adjustment',
      quantityChange: (map['quantityChange'] as num?)?.toDouble() ?? 0.0,
      previousQuantity: (map['previousQuantity'] as num?)?.toDouble() ?? 0.0,
      newQuantity: (map['newQuantity'] as num?)?.toDouble() ?? 0.0,
      reason: map['reason'] ?? '',
      referenceId: map['referenceId'] ?? '',
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
      isSynced: (map['isSynced'] == 1 || map['isSynced'] == true),
    );
  }
}

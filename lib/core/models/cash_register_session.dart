class CashRegisterSession {
  final String id;
  final String shopId;
  final String date; // YYYY-MM-DD
  final double openingAmount;
  final DateTime openedAt;
  final double? closingAmount;
  final DateTime? closedAt;
  final String status; // 'open', 'closed'
  final String notes;
  final bool isSynced;

  CashRegisterSession({
    required this.id,
    required this.shopId,
    required this.date,
    required this.openingAmount,
    DateTime? openedAt,
    this.closingAmount,
    this.closedAt,
    this.status = 'open',
    this.notes = '',
    this.isSynced = false,
  }) : openedAt = openedAt ?? DateTime.now();

  bool get isOpen => status == 'open';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shopId': shopId,
      'date': date,
      'openingAmount': openingAmount,
      'openedAt': openedAt.toIso8601String(),
      'closingAmount': closingAmount,
      'closedAt': closedAt?.toIso8601String(),
      'status': status,
      'notes': notes,
      'isSynced': isSynced ? 1 : 0,
    };
  }

  factory CashRegisterSession.fromMap(Map<String, dynamic> map) {
    return CashRegisterSession(
      id: map['id'] ?? '',
      shopId: map['shopId'] ?? '',
      date: map['date'] ?? '',
      openingAmount: (map['openingAmount'] as num?)?.toDouble() ?? 0.0,
      openedAt: map['openedAt'] != null ? DateTime.parse(map['openedAt']) : DateTime.now(),
      closingAmount: (map['closingAmount'] as num?)?.toDouble(),
      closedAt: map['closedAt'] != null ? DateTime.parse(map['closedAt']) : null,
      status: map['status'] ?? 'open',
      notes: map['notes'] ?? '',
      isSynced: (map['isSynced'] == 1 || map['isSynced'] == true),
    );
  }

  CashRegisterSession copyWith({
    String? id,
    String? shopId,
    String? date,
    double? openingAmount,
    DateTime? openedAt,
    double? closingAmount,
    DateTime? closedAt,
    String? status,
    String? notes,
    bool? isSynced,
  }) {
    return CashRegisterSession(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      date: date ?? this.date,
      openingAmount: openingAmount ?? this.openingAmount,
      openedAt: openedAt ?? this.openedAt,
      closingAmount: closingAmount ?? this.closingAmount,
      closedAt: closedAt ?? this.closedAt,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}

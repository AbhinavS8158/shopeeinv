class Customer {
  final String id;
  final String shopId;
  final String name;
  final String phone;
  final String email;
  final String address;
  final String gstin;
  final double creditBalance; // Udhar / unpaid balance
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;

  Customer({
    required this.id,
    required this.shopId,
    required this.name,
    this.phone = '',
    this.email = '',
    this.address = '',
    this.gstin = '',
    this.creditBalance = 0.0,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isSynced = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shopId': shopId,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'gstin': gstin,
      'creditBalance': creditBalance,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isSynced': isSynced ? 1 : 0,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] ?? '',
      shopId: map['shopId'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      address: map['address'] ?? '',
      gstin: map['gstin'] ?? '',
      creditBalance: (map['creditBalance'] as num?)?.toDouble() ?? 0.0,
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : DateTime.now(),
      isSynced: (map['isSynced'] == 1 || map['isSynced'] == true),
    );
  }

  Customer copyWith({
    String? id,
    String? shopId,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? gstin,
    double? creditBalance,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
  }) {
    return Customer(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      gstin: gstin ?? this.gstin,
      creditBalance: creditBalance ?? this.creditBalance,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Customer && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class CustomerModel {
  final String id;
  final String customerCode;
  final String name;
  final String shopName;
  final String email;
  final String phone;
  final String address;
  final String status; // 'Active', 'Inactive', 'Blocked'
  final DateTime createdAt;
  final DateTime? lastLogin;
  final String notes;

  CustomerModel({
    required this.id,
    required this.customerCode,
    required this.name,
    required this.shopName,
    required this.email,
    required this.phone,
    required this.address,
    this.status = 'Active',
    required this.createdAt,
    this.lastLogin,
    this.notes = '',
  });

  CustomerModel copyWith({
    String? id,
    String? customerCode,
    String? name,
    String? shopName,
    String? email,
    String? phone,
    String? address,
    String? status,
    DateTime? createdAt,
    DateTime? lastLogin,
    String? notes,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      customerCode: customerCode ?? this.customerCode,
      name: name ?? this.name,
      shopName: shopName ?? this.shopName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerCode': customerCode,
      'name': name,
      'shopName': shopName,
      'email': email,
      'phone': phone,
      'address': address,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'lastLogin': lastLogin?.toIso8601String(),
      'notes': notes,
    };
  }

  factory CustomerModel.fromMap(Map<String, dynamic> map, String docId) {
    return CustomerModel(
      id: docId,
      customerCode: map['customerCode'] ?? 'CUST-0000',
      name: map['name'] ?? '',
      shopName: map['shopName'] ?? map['companyName'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      status: map['status'] ?? 'Active',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      lastLogin: map['lastLogin'] != null
          ? DateTime.tryParse(map['lastLogin'])
          : null,
      notes: map['notes'] ?? '',
    );
  }
}

class AuthUser {
  final String id;
  final String customerCode;
  final String name;
  final String email;
  final String phone;
  final String? shopName;
  final String status; // 'Active', 'Blocked', 'Suspended'
  final DateTime createdAt;
  final DateTime? lastLogin;
  final String? token;

  AuthUser({
    required this.id,
    required this.customerCode,
    required this.name,
    required this.email,
    required this.phone,
    this.shopName,
    this.status = 'Active',
    required this.createdAt,
    this.lastLogin,
    this.token,
  });

  bool get isActive => status.toLowerCase() == 'active';
  bool get isBlocked => status.toLowerCase() == 'blocked' || status.toLowerCase() == 'suspended';

  AuthUser copyWith({
    String? id,
    String? customerCode,
    String? name,
    String? email,
    String? phone,
    String? shopName,
    String? status,
    DateTime? createdAt,
    DateTime? lastLogin,
    String? token,
  }) {
    return AuthUser(
      id: id ?? this.id,
      customerCode: customerCode ?? this.customerCode,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      shopName: shopName ?? this.shopName,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      token: token ?? this.token,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerCode': customerCode,
      'name': name,
      'email': email.trim().toLowerCase(),
      'phone': phone.trim(),
      'shopName': shopName ?? '',
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'lastLogin': lastLogin?.toIso8601String(),
      'token': token,
    };
  }

  factory AuthUser.fromMap(Map<String, dynamic> map, [String? docId]) {
    return AuthUser(
      id: docId ?? map['id'] ?? '',
      customerCode: map['customerCode'] ?? 'CUST-0000',
      name: map['name'] ?? '',
      email: (map['email'] ?? '').toString().trim().toLowerCase(),
      phone: map['phone'] ?? '',
      shopName: map['shopName'] ?? map['companyName'],
      status: map['status'] ?? 'Active',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      lastLogin: map['lastLogin'] != null
          ? DateTime.tryParse(map['lastLogin'].toString())
          : null,
      token: map['token'],
    );
  }
}

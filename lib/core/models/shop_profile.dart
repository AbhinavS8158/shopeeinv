class ShopProfile {
  final String id;
  final String ownerId;
  final String shopName;
  final String ownerName;
  final String phone;
  final String email;
  final String gstin;
  final String address;
  final String city;
  final String state;
  final String pincode;
  final String upiId;
  final String? logoBase64;
  final String invoicePrefix;
  final String defaultInvoiceType; // 'thermal_58', 'thermal_80', 'a4'
  final String termsAndConditions;
  final bool isTaxInclusive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;

  ShopProfile({
    required this.id,
    required this.ownerId,
    required this.shopName,
    required this.ownerName,
    required this.phone,
    this.email = '',
    this.gstin = '',
    required this.address,
    this.city = '',
    this.state = 'Kerala',
    this.pincode = '',
    this.upiId = '',
    this.logoBase64,
    this.invoicePrefix = 'INV-',
    this.defaultInvoiceType = 'a4',
    this.termsAndConditions = 'Goods once sold cannot be taken back without original bill. Thank you for shopping with us!',
    this.isTaxInclusive = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isSynced = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'shopName': shopName,
      'ownerName': ownerName,
      'phone': phone,
      'email': email,
      'gstin': gstin,
      'address': address,
      'city': city,
      'state': state,
      'pincode': pincode,
      'upiId': upiId,
      'logoBase64': logoBase64,
      'invoicePrefix': invoicePrefix,
      'defaultInvoiceType': defaultInvoiceType,
      'termsAndConditions': termsAndConditions,
      'isTaxInclusive': isTaxInclusive ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isSynced': isSynced ? 1 : 0,
    };
  }

  factory ShopProfile.fromMap(Map<String, dynamic> map) {
    return ShopProfile(
      id: map['id'] ?? '',
      ownerId: map['ownerId'] ?? '',
      shopName: map['shopName'] ?? '',
      ownerName: map['ownerName'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      gstin: map['gstin'] ?? '',
      address: map['address'] ?? '',
      city: map['city'] ?? '',
      state: map['state'] ?? 'Kerala',
      pincode: map['pincode'] ?? '',
      upiId: map['upiId'] ?? '',
      logoBase64: map['logoBase64'],
      invoicePrefix: map['invoicePrefix'] ?? 'INV-',
      defaultInvoiceType: map['defaultInvoiceType'] ?? 'a4',
      termsAndConditions: map['termsAndConditions'] ?? '',
      isTaxInclusive: (map['isTaxInclusive'] == 1 || map['isTaxInclusive'] == true),
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : DateTime.now(),
      isSynced: (map['isSynced'] == 1 || map['isSynced'] == true),
    );
  }

  ShopProfile copyWith({
    String? id,
    String? ownerId,
    String? shopName,
    String? ownerName,
    String? phone,
    String? email,
    String? gstin,
    String? address,
    String? city,
    String? state,
    String? pincode,
    String? upiId,
    String? logoBase64,
    String? invoicePrefix,
    String? defaultInvoiceType,
    String? termsAndConditions,
    bool? isTaxInclusive,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
  }) {
    return ShopProfile(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      shopName: shopName ?? this.shopName,
      ownerName: ownerName ?? this.ownerName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      gstin: gstin ?? this.gstin,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      upiId: upiId ?? this.upiId,
      logoBase64: logoBase64 ?? this.logoBase64,
      invoicePrefix: invoicePrefix ?? this.invoicePrefix,
      defaultInvoiceType: defaultInvoiceType ?? this.defaultInvoiceType,
      termsAndConditions: termsAndConditions ?? this.termsAndConditions,
      isTaxInclusive: isTaxInclusive ?? this.isTaxInclusive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}

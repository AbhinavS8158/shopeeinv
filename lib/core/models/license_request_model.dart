class LicenseRequestModel {
  final String id;
  final String customerId;
  final String customerName;
  final String email;
  final String phone;
  final String shopId;
  final String shopName;
  final String businessType;
  final String address;
  final String gstin;
  final String status; // 'Pending', 'Approved', 'Rejected'
  final DateTime requestedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? rejectionReason;
  final String? adminNotes;
  final String? licenseKey;
  final String? licenseId;
  final int maxDevices;
  final String licenseType;
  final String validityType;

  LicenseRequestModel({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.email,
    required this.phone,
    required this.shopId,
    required this.shopName,
    this.businessType = 'Retail Store',
    required this.address,
    this.gstin = '',
    this.status = 'Pending',
    required this.requestedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.rejectionReason,
    this.adminNotes,
    this.licenseKey,
    this.licenseId,
    this.maxDevices = 2,
    this.licenseType = 'Standard',
    this.validityType = '1_year',
  });

  bool get isPending => status.toLowerCase() == 'pending';
  bool get isApproved => status.toLowerCase() == 'approved';
  bool get isRejected => status.toLowerCase() == 'rejected';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerId': customerId,
      'customerName': customerName,
      'email': email,
      'phone': phone,
      'shopId': shopId,
      'shopName': shopName,
      'businessType': businessType,
      'address': address,
      'gstin': gstin,
      'status': status,
      'requestedAt': requestedAt.toIso8601String(),
      'reviewedAt': reviewedAt?.toIso8601String(),
      'reviewedBy': reviewedBy,
      'rejectionReason': rejectionReason,
      'adminNotes': adminNotes,
      'licenseKey': licenseKey,
      'licenseId': licenseId,
      'maxDevices': maxDevices,
      'licenseType': licenseType,
      'validityType': validityType,
    };
  }

  factory LicenseRequestModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    return LicenseRequestModel(
      id: docId ?? map['id'] ?? '',
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      shopId: map['shopId'] ?? '',
      shopName: map['shopName'] ?? '',
      businessType: map['businessType'] ?? 'Retail Store',
      address: map['address'] ?? '',
      gstin: map['gstin'] ?? '',
      status: map['status'] ?? 'Pending',
      requestedAt: map['requestedAt'] != null
          ? DateTime.tryParse(map['requestedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      reviewedAt: map['reviewedAt'] != null
          ? DateTime.tryParse(map['reviewedAt'].toString())
          : null,
      reviewedBy: map['reviewedBy'],
      rejectionReason: map['rejectionReason'],
      adminNotes: map['adminNotes'],
      licenseKey: map['licenseKey'],
      licenseId: map['licenseId'],
      maxDevices: map['maxDevices'] is int
          ? map['maxDevices']
          : int.tryParse(map['maxDevices']?.toString() ?? '2') ?? 2,
      licenseType: map['licenseType'] ?? 'Standard',
      validityType: map['validityType'] ?? '1_year',
    );
  }
}

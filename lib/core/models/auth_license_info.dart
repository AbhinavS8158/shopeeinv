class AuthLicenseInfo {
  final String id;
  final String licenseKey;
  final String customerId;
  final String customerName;
  final String licenseType;
  final String status; // 'Active', 'Expired', 'Suspended', 'Revoked'
  final int maxDevices;
  final DateTime issuedAt;
  final DateTime? expiresAt;
  final int activeDevicesCount;

  AuthLicenseInfo({
    required this.id,
    required this.licenseKey,
    required this.customerId,
    required this.customerName,
    this.licenseType = 'Standard',
    this.status = 'Active',
    this.maxDevices = 2,
    required this.issuedAt,
    this.expiresAt,
    this.activeDevicesCount = 0,
  });

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  bool get isValid => status.toLowerCase() == 'active' && !isExpired;

  String get effectiveStatus {
    if (status.toLowerCase() == 'active' && isExpired) return 'Expired';
    return status;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'licenseKey': licenseKey,
      'customerId': customerId,
      'customerName': customerName,
      'licenseType': licenseType,
      'status': status,
      'maxDevices': maxDevices,
      'issuedAt': issuedAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'activeDevicesCount': activeDevicesCount,
    };
  }

  factory AuthLicenseInfo.fromMap(Map<String, dynamic> map, [String? docId]) {
    return AuthLicenseInfo(
      id: docId ?? map['id'] ?? '',
      licenseKey: map['licenseKey'] ?? '',
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      licenseType: map['licenseType'] ?? 'Standard',
      status: map['status'] ?? 'Active',
      maxDevices: map['maxDevices'] is int
          ? map['maxDevices']
          : int.tryParse(map['maxDevices']?.toString() ?? '2') ?? 2,
      issuedAt: map['issuedAt'] != null
          ? DateTime.tryParse(map['issuedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      expiresAt: map['expiresAt'] != null
          ? DateTime.tryParse(map['expiresAt'].toString())
          : null,
      activeDevicesCount: map['activeDevicesCount'] is int
          ? map['activeDevicesCount']
          : int.tryParse(map['activeDevicesCount']?.toString() ?? '0') ?? 0,
    );
  }
}

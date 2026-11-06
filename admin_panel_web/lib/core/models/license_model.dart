class LicenseModel {
  final String id;
  final String licenseKey;
  final String customerId;
  final String customerName;
  final String licenseType; // 'Trial', 'Standard', 'Premium', 'Enterprise'
  final String status; // 'Active', 'Expired', 'Suspended', 'Revoked'
  final int maxDevices;
  final String validityType; // '30_days', '3_months', '6_months', '1_year', 'lifetime', 'custom'
  final DateTime issuedAt;
  final DateTime? activatedAt;
  final DateTime? expiresAt;
  final String issuedBy;
  final String notes;

  LicenseModel({
    required this.id,
    required this.licenseKey,
    required this.customerId,
    required this.customerName,
    this.licenseType = 'Standard',
    this.status = 'Active',
    this.maxDevices = 2,
    this.validityType = '1_year',
    required this.issuedAt,
    this.activatedAt,
    this.expiresAt,
    this.issuedBy = 'Super Admin',
    this.notes = '',
  });

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  String get effectiveStatus {
    if (status == 'Active' && isExpired) return 'Expired';
    return status;
  }

  LicenseModel copyWith({
    String? id,
    String? licenseKey,
    String? customerId,
    String? customerName,
    String? licenseType,
    String? status,
    int? maxDevices,
    String? validityType,
    DateTime? issuedAt,
    DateTime? activatedAt,
    DateTime? expiresAt,
    String? issuedBy,
    String? notes,
  }) {
    return LicenseModel(
      id: id ?? this.id,
      licenseKey: licenseKey ?? this.licenseKey,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      licenseType: licenseType ?? this.licenseType,
      status: status ?? this.status,
      maxDevices: maxDevices ?? this.maxDevices,
      validityType: validityType ?? this.validityType,
      issuedAt: issuedAt ?? this.issuedAt,
      activatedAt: activatedAt ?? this.activatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      issuedBy: issuedBy ?? this.issuedBy,
      notes: notes ?? this.notes,
    );
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
      'validityType': validityType,
      'issuedAt': issuedAt.toIso8601String(),
      'activatedAt': activatedAt?.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'issuedBy': issuedBy,
      'notes': notes,
    };
  }

  factory LicenseModel.fromMap(Map<String, dynamic> map, String docId) {
    return LicenseModel(
      id: docId,
      licenseKey: map['licenseKey'] ?? '',
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      licenseType: map['licenseType'] ?? 'Standard',
      status: map['status'] ?? 'Active',
      maxDevices: map['maxDevices'] is int ? map['maxDevices'] : int.tryParse(map['maxDevices']?.toString() ?? '2') ?? 2,
      validityType: map['validityType'] ?? '1_year',
      issuedAt: map['issuedAt'] != null
          ? DateTime.tryParse(map['issuedAt']) ?? DateTime.now()
          : DateTime.now(),
      activatedAt: map['activatedAt'] != null
          ? DateTime.tryParse(map['activatedAt'])
          : null,
      expiresAt: map['expiresAt'] != null
          ? DateTime.tryParse(map['expiresAt'])
          : null,
      issuedBy: map['issuedBy'] ?? 'Admin',
      notes: map['notes'] ?? '',
    );
  }
}

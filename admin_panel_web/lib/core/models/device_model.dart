class DeviceModel {
  final String id;
  final String deviceId;
  final String deviceName;
  final String deviceType; // 'Desktop', 'Laptop', 'Mobile', 'Tablet'
  final String operatingSystem;
  final String appVersion;
  final String status; // 'Active', 'Blocked', 'Revoked'
  final DateTime firstConnectedAt;
  final DateTime lastActiveAt;
  final String licenseId;
  final String customerId;
  final String ipAddress;

  DeviceModel({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    this.deviceType = 'Desktop',
    required this.operatingSystem,
    this.appVersion = '1.0.0+1',
    this.status = 'Active',
    required this.firstConnectedAt,
    required this.lastActiveAt,
    required this.licenseId,
    required this.customerId,
    this.ipAddress = '127.0.0.1',
  });

  DeviceModel copyWith({
    String? id,
    String? deviceId,
    String? deviceName,
    String? deviceType,
    String? operatingSystem,
    String? appVersion,
    String? status,
    DateTime? firstConnectedAt,
    DateTime? lastActiveAt,
    String? licenseId,
    String? customerId,
    String? ipAddress,
  }) {
    return DeviceModel(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      deviceType: deviceType ?? this.deviceType,
      operatingSystem: operatingSystem ?? this.operatingSystem,
      appVersion: appVersion ?? this.appVersion,
      status: status ?? this.status,
      firstConnectedAt: firstConnectedAt ?? this.firstConnectedAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      licenseId: licenseId ?? this.licenseId,
      customerId: customerId ?? this.customerId,
      ipAddress: ipAddress ?? this.ipAddress,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'deviceType': deviceType,
      'operatingSystem': operatingSystem,
      'appVersion': appVersion,
      'status': status,
      'firstConnectedAt': firstConnectedAt.toIso8601String(),
      'lastActiveAt': lastActiveAt.toIso8601String(),
      'licenseId': licenseId,
      'customerId': customerId,
      'ipAddress': ipAddress,
    };
  }

  factory DeviceModel.fromMap(Map<String, dynamic> map, String docId) {
    return DeviceModel(
      id: docId,
      deviceId: map['deviceId'] ?? '',
      deviceName: map['deviceName'] ?? 'Unknown Device',
      deviceType: map['deviceType'] ?? 'Desktop',
      operatingSystem: map['operatingSystem'] ?? 'Unknown OS',
      appVersion: map['appVersion'] ?? '1.0.0',
      status: map['status'] ?? 'Active',
      firstConnectedAt: map['firstConnectedAt'] != null
          ? DateTime.tryParse(map['firstConnectedAt']) ?? DateTime.now()
          : DateTime.now(),
      lastActiveAt: map['lastActiveAt'] != null
          ? DateTime.tryParse(map['lastActiveAt']) ?? DateTime.now()
          : DateTime.now(),
      licenseId: map['licenseId'] ?? '',
      customerId: map['customerId'] ?? '',
      ipAddress: map['ipAddress'] ?? '127.0.0.1',
    );
  }
}

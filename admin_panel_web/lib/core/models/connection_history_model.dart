class ConnectionHistoryModel {
  final String id;
  final String customerId;
  final String customerName;
  final String licenseKey;
  final String deviceId;
  final String deviceName;
  final String deviceType;
  final String operatingSystem;
  final String action; // 'CONNECTED', 'RECONNECTED', 'BLOCKED_DEVICE_LIMIT', 'BLOCKED_BLACKLISTED', etc.
  final String status; // 'SUCCESS', 'DENIED'
  final String details;
  final String ipAddress;
  final DateTime timestamp;

  ConnectionHistoryModel({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.licenseKey,
    required this.deviceId,
    required this.deviceName,
    required this.deviceType,
    required this.operatingSystem,
    required this.action,
    required this.status,
    required this.details,
    this.ipAddress = '127.0.0.1',
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerId': customerId,
      'customerName': customerName,
      'licenseKey': licenseKey,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'deviceType': deviceType,
      'operatingSystem': operatingSystem,
      'action': action,
      'status': status,
      'details': details,
      'ipAddress': ipAddress,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ConnectionHistoryModel.fromMap(Map<String, dynamic> map, String docId) {
    return ConnectionHistoryModel(
      id: docId,
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      licenseKey: map['licenseKey'] ?? '',
      deviceId: map['deviceId'] ?? '',
      deviceName: map['deviceName'] ?? 'Unknown Device',
      deviceType: map['deviceType'] ?? 'Desktop',
      operatingSystem: map['operatingSystem'] ?? 'Unknown OS',
      action: map['action'] ?? '',
      status: map['status'] ?? 'SUCCESS',
      details: map['details'] ?? '',
      ipAddress: map['ipAddress'] ?? '127.0.0.1',
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

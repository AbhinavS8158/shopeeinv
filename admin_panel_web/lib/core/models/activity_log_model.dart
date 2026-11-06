class ActivityLogModel {
  final String id;
  final String adminName;
  final String action; // 'ISSUE_LICENSE', 'EXTEND_LICENSE', 'CHANGE_LIMIT', 'BLOCK_DEVICE', etc.
  final String targetType; // 'LICENSE', 'CUSTOMER', 'DEVICE', 'SYSTEM'
  final String targetId;
  final String details;
  final String ipAddress;
  final DateTime createdAt;

  ActivityLogModel({
    required this.id,
    required this.adminName,
    required this.action,
    required this.targetType,
    required this.targetId,
    required this.details,
    this.ipAddress = '127.0.0.1',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'adminName': adminName,
      'action': action,
      'targetType': targetType,
      'targetId': targetId,
      'details': details,
      'ipAddress': ipAddress,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ActivityLogModel.fromMap(Map<String, dynamic> map, String docId) {
    return ActivityLogModel(
      id: docId,
      adminName: map['adminName'] ?? 'Admin',
      action: map['action'] ?? '',
      targetType: map['targetType'] ?? '',
      targetId: map['targetId'] ?? '',
      details: map['details'] ?? '',
      ipAddress: map['ipAddress'] ?? '127.0.0.1',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

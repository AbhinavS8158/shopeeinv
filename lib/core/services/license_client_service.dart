import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LicenseCheckResult {
  final bool isAllowed;
  final String status;
  final String? errorMessage;
  final int maxDevices;
  final int activeDevices;

  LicenseCheckResult({
    required this.isAllowed,
    required this.status,
    this.errorMessage,
    this.maxDevices = 0,
    this.activeDevices = 0,
  });
}

class LicenseClientService {
  static const String _prefKey = 'shopeeinv_client_license_key';
  static const String _prefDevId = 'shopeeinv_client_device_id';

  /// Returns cached local device ID or generates a persistent one
  static Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? devId = prefs.getString(_prefDevId);
    if (devId == null || devId.isEmpty) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final platformStr = kIsWeb ? 'web' : Platform.operatingSystem;
      devId = 'dev_${platformStr}_$now';
      await prefs.setString(_prefDevId, devId);
    }
    return devId;
  }

  /// Saves the active license key in local storage
  static Future<void> saveLicenseKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, key.trim().toUpperCase());
  }

  /// Gets the currently saved license key
  static Future<String?> getSavedLicenseKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKey);
  }

  /// Verifies a license key against Firebase Cloud Firestore (shopeeinv-8da75)
  static Future<LicenseCheckResult> verifyAndRegisterTerminal({
    required String licenseKey,
    String? customDeviceName,
  }) async {
    final trimmedKey = licenseKey.trim().toUpperCase();
    final deviceId = await getOrCreateDeviceId();
    final deviceName = customDeviceName ?? (kIsWeb ? 'Web Terminal' : Platform.localHostname);
    final os = kIsWeb ? 'Web Browser' : Platform.operatingSystemVersion;
    final deviceType = kIsWeb
        ? 'Web'
        : (Platform.isAndroid || Platform.isIOS ? 'Mobile' : 'Desktop');

    try {
      final db = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: '(default)',
      );

      // 1. Fetch license document
      final licQuery = await db
          .collection('licenses')
          .where('licenseKey', isEqualTo: trimmedKey)
          .limit(1)
          .get();

      if (licQuery.docs.isEmpty) {
        return LicenseCheckResult(
          isAllowed: false,
          status: 'NOT_FOUND',
          errorMessage: 'Invalid license key. Please check your key or contact the administrator.',
        );
      }

      final licDoc = licQuery.docs.first;
      final licData = licDoc.data();
      final licenseStatus = licData['status'] ?? 'Active';
      final maxDevices = licData['maxDevices'] is int ? licData['maxDevices'] as int : int.tryParse(licData['maxDevices']?.toString() ?? '2') ?? 2;
      final customerId = licData['customerId'] ?? '';
      final customerName = licData['customerName'] ?? '';
      final expiresAtStr = licData['expiresAt'];

      // Check Expiration
      if (expiresAtStr != null) {
        final expiresAt = DateTime.tryParse(expiresAtStr);
        if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
          return LicenseCheckResult(
            isAllowed: false,
            status: 'EXPIRED',
            errorMessage: 'Your ShopeeInv license expired on ${expiresAtStr.length >= 10 ? expiresAtStr.substring(0, 10) : expiresAtStr}. Please renew your license.',
          );
        }
      }

      // Check Suspension / Revocation
      if (licenseStatus == 'Suspended' || licenseStatus == 'Revoked') {
        return LicenseCheckResult(
          isAllowed: false,
          status: licenseStatus.toUpperCase(),
          errorMessage: 'Your license is currently $licenseStatus. Please contact the administrator.',
        );
      }

      // 2. Fetch Customer Status
      if (customerId.isNotEmpty) {
        final custDoc = await db.collection('customers').doc(customerId).get();
        if (custDoc.exists && custDoc.data()?['status'] == 'Blocked') {
          return LicenseCheckResult(
            isAllowed: false,
            status: 'CUSTOMER_BLOCKED',
            errorMessage: 'Your shop account has been suspended by the administrator.',
          );
        }
      }

      // 3. Query Bound Hardware Devices
      final devicesQuery = await db
          .collection('devices')
          .where('customerId', isEqualTo: customerId)
          .get();

      final activeDevices = devicesQuery.docs.where((d) => d.data()['status'] == 'Active').toList();
      final existingDevDoc = devicesQuery.docs.where((d) => d.data()['deviceId'] == deviceId).firstOrNull;

      // 4. Handle Existing Device
      if (existingDevDoc != null) {
        final devData = existingDevDoc.data();
        if (devData['status'] == 'Blocked') {
          return LicenseCheckResult(
            isAllowed: false,
            status: 'DEVICE_BLOCKED',
            errorMessage: 'This specific device has been blocked by the administrator.',
          );
        }

        // Reconnect: update last active timestamp
        await existingDevDoc.reference.update({
          'lastActiveAt': DateTime.now().toIso8601String(),
          'deviceName': deviceName,
          'operatingSystem': os,
        });

        await saveLicenseKey(trimmedKey);

        return LicenseCheckResult(
          isAllowed: true,
          status: 'ACTIVE',
          maxDevices: maxDevices,
          activeDevices: activeDevices.length,
        );
      }

      // 5. Handle New Device: Check Available Device Slots
      if (activeDevices.length >= maxDevices) {
        final blockMsg =
            'Device Limit Reached! Your license allows only $maxDevices connected device${maxDevices > 1 ? "s" : ""}. '
            'Please remove an existing device or contact the administrator.';

        // Log blocked attempt to connection_history
        final histId = 'hist_${DateTime.now().millisecondsSinceEpoch}';
        await db.collection('connection_history').doc(histId).set({
          'id': histId,
          'customerId': customerId,
          'customerName': customerName,
          'licenseKey': trimmedKey,
          'deviceId': deviceId,
          'deviceName': deviceName,
          'deviceType': deviceType,
          'operatingSystem': os,
          'action': 'BLOCKED_DEVICE_LIMIT',
          'status': 'DENIED',
          'details': '${activeDevices.length}/$maxDevices slots occupied. Blocked new device connection.',
          'ipAddress': 'Client IP',
          'timestamp': DateTime.now().toIso8601String(),
        });

        return LicenseCheckResult(
          isAllowed: false,
          status: 'DEVICE_LIMIT_REACHED',
          errorMessage: blockMsg,
          maxDevices: maxDevices,
          activeDevices: activeDevices.length,
        );
      }

      // 6. Slots Available: Register New Terminal in Firestore
      final newDevId = 'dev_${DateTime.now().millisecondsSinceEpoch}';
      await db.collection('devices').doc(newDevId).set({
        'id': newDevId,
        'deviceId': deviceId,
        'deviceName': deviceName,
        'deviceType': deviceType,
        'operatingSystem': os,
        'appVersion': '1.0.0+1',
        'status': 'Active',
        'firstConnectedAt': DateTime.now().toIso8601String(),
        'lastActiveAt': DateTime.now().toIso8601String(),
        'licenseId': licDoc.id,
        'customerId': customerId,
        'ipAddress': 'Client IP',
      });

      // Log successful connection in connection_history
      final histId = 'hist_${DateTime.now().millisecondsSinceEpoch}';
      await db.collection('connection_history').doc(histId).set({
        'id': histId,
        'customerId': customerId,
        'customerName': customerName,
        'licenseKey': trimmedKey,
        'deviceId': deviceId,
        'deviceName': deviceName,
        'deviceType': deviceType,
        'operatingSystem': os,
        'action': 'CONNECTED',
        'status': 'SUCCESS',
        'details': 'New terminal registered (${activeDevices.length + 1}/$maxDevices slots used)',
        'ipAddress': 'Client IP',
        'timestamp': DateTime.now().toIso8601String(),
      });

      await saveLicenseKey(trimmedKey);

      return LicenseCheckResult(
        isAllowed: true,
        status: 'ACTIVE',
        maxDevices: maxDevices,
        activeDevices: activeDevices.length + 1,
      );
    } catch (e) {
      debugPrint('Firestore License verification error: $e');
      return LicenseCheckResult(
        isAllowed: false,
        status: 'ERROR',
        errorMessage: 'Unable to connect to license server: $e',
      );
    }
  }
}

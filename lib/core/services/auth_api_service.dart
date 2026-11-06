import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/api_response.dart';
import '../models/auth_user.dart';
import '../models/auth_license_info.dart';
import 'license_client_service.dart';

class AuthApiService {
  static const String _prefTokenKey = 'shopeeinv_auth_token';
  static const String _prefUserKey = 'shopeeinv_auth_user_data';
  static const String _prefLicenseKey = 'shopeeinv_auth_license_data';
  static const String _prefRememberMe = 'shopeeinv_auth_remember_me';

  static FirebaseFirestore? get _firestore {
    if (Firebase.apps.isNotEmpty) {
      return FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: '(default)',
      );
    }
    return null;
  }

  /// Hashes a password string with SHA-256 and constant salt
  static String hashPassword(String password) {
    const salt = 'shopeeinv_secure_salt_2026';
    final bytes = utf8.encode(password + salt);
    return sha256.convert(bytes).toString();
  }

  /// Generates a human-friendly unique license key (e.g. SHP-ABCD-1234-EF56)
  static String _generateLicenseKey() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    String segment() => String.fromCharCodes(
      Iterable.generate(4, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
    return 'SHP-${segment()}-${segment()}-${segment()}';
  }

  // =========================================================================
  // 1. POST /api/auth/register
  // =========================================================================
  static Future<ApiResponse<Map<String, dynamic>>> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPhone = phone.trim();
    final cleanName = name.trim();

    // 1. Field validation
    if (cleanName.isEmpty) {
      return ApiResponse.error(message: 'Full Name is required', errorCode: 'MISSING_NAME');
    }
    if (cleanEmail.isEmpty || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(cleanEmail)) {
      return ApiResponse.error(message: 'Please provide a valid email address', errorCode: 'INVALID_EMAIL');
    }
    if (cleanPhone.isEmpty || cleanPhone.replaceAll(RegExp(r'\D'), '').length < 8) {
      return ApiResponse.error(message: 'Please provide a valid phone number', errorCode: 'INVALID_PHONE');
    }
    if (password.length < 6) {
      return ApiResponse.error(message: 'Password must be at least 6 characters long', errorCode: 'WEAK_PASSWORD');
    }

    try {
      final db = _firestore;
      if (db == null) {
        return ApiResponse.error(
          message: 'Cloud service is currently unavailable. Please check your internet connection.',
          errorCode: 'FIREBASE_UNAVAILABLE',
        );
      }

      // 2. Prevent duplicate registration
      final existingCust = await db
          .collection('customers')
          .where('email', isEqualTo: cleanEmail)
          .limit(1)
          .get();

      if (existingCust.docs.isNotEmpty) {
        return ApiResponse.error(
          message: 'An account with this email address already exists. Please sign in instead.',
          errorCode: 'DUPLICATE_EMAIL',
          statusCode: 409,
        );
      }

      final now = DateTime.now();
      final customerId = 'cust_${now.millisecondsSinceEpoch}';
      final customerCode = 'CUST-${1000 + Random().nextInt(9000)}';
      final passwordHash = hashPassword(password);

      // 3. Create customer document in Firestore
      final customerData = {
        'id': customerId,
        'customerCode': customerCode,
        'name': cleanName,
        'shopName': '',
        'email': cleanEmail,
        'phone': cleanPhone,
        'passwordHash': passwordHash,
        'address': '',
        'status': 'Active',
        'createdAt': now.toIso8601String(),
        'lastLogin': null,
        'notes': 'Self-registered via ShopeeInv Mobile App',
      };
      await db.collection('customers').doc(customerId).set(customerData);

      // 4. Auto-generate active Standard License for the user (1-year validity, 2 devices)
      final licenseId = 'lic_${now.millisecondsSinceEpoch}';
      final licenseKey = _generateLicenseKey();
      final expiresAt = now.add(const Duration(days: 365));

      final licenseData = {
        'id': licenseId,
        'licenseKey': licenseKey,
        'customerId': customerId,
        'customerName': cleanName,
        'licenseType': 'Standard',
        'status': 'Active',
        'maxDevices': 2,
        'validityType': '1_year',
        'issuedAt': now.toIso8601String(),
        'activatedAt': now.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'issuedBy': 'Mobile App Registration',
        'notes': 'Default 2-device standard mobile license',
      };
      await db.collection('licenses').doc(licenseId).set(licenseData);

      // 5. Log activity
      final logId = 'log_${now.millisecondsSinceEpoch}';
      await db.collection('activity_logs').doc(logId).set({
        'id': logId,
        'action': 'USER_REGISTERED',
        'targetType': 'CUSTOMER',
        'targetId': customerId,
        'details': 'New user registered: $cleanName ($cleanEmail). License $licenseKey assigned.',
        'createdAt': now.toIso8601String(),
        'performedBy': cleanEmail,
      });

      final user = AuthUser.fromMap(customerData, customerId);
      final license = AuthLicenseInfo.fromMap(licenseData, licenseId);

      return ApiResponse.success(
        statusCode: 201,
        message: 'Account created successfully! Please sign in with your email and password.',
        data: {
          'user': user.toMap(),
          'license': license.toMap(),
        },
      );
    } catch (e) {
      debugPrint('Registration error: $e');
      return ApiResponse.error(
        message: 'Failed to create account: ${e.toString()}',
        errorCode: 'REGISTRATION_FAILED',
      );
    }
  }

  // =========================================================================
  // 2. POST /api/auth/login
  // =========================================================================
  static Future<ApiResponse<Map<String, dynamic>>> login({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    // 1. Validate inputs (Email & Password only)
    if (cleanEmail.isEmpty) {
      return ApiResponse.error(message: 'Email address is required', errorCode: 'MISSING_EMAIL');
    }
    if (password.isEmpty) {
      return ApiResponse.error(message: 'Password is required', errorCode: 'MISSING_PASSWORD');
    }

    try {
      final db = _firestore;
      if (db == null) {
        return ApiResponse.error(
          message: 'Cloud service is currently unavailable. Please verify internet connection.',
          errorCode: 'FIREBASE_UNAVAILABLE',
        );
      }

      // 2. Query user by email
      final custQuery = await db
          .collection('customers')
          .where('email', isEqualTo: cleanEmail)
          .limit(1)
          .get();

      if (custQuery.docs.isEmpty) {
        return ApiResponse.error(
          message: 'No account found with this email address. Please register.',
          errorCode: 'USER_NOT_FOUND',
          statusCode: 404,
        );
      }

      final custDoc = custQuery.docs.first;
      final custData = custDoc.data();
      final customerId = custDoc.id;

      // 3. Verify password
      final storedHash = custData['passwordHash'];
      final enteredHash = hashPassword(password);
      if (storedHash != null && storedHash != enteredHash) {
        return ApiResponse.error(
          message: 'Incorrect password. Please verify and try again.',
          errorCode: 'INVALID_CREDENTIALS',
          statusCode: 401,
        );
      }

      // 4. Verify customer status (Blocked / Suspended)
      final status = (custData['status'] ?? 'Active').toString();
      if (status.toLowerCase() == 'blocked' || status.toLowerCase() == 'suspended') {
        return ApiResponse.error(
          message: 'Your account has been suspended or blocked by the administrator.',
          errorCode: 'ACCOUNT_BLOCKED',
          statusCode: 403,
        );
      }

      // 5. Query user's license
      final licQuery = await db
          .collection('licenses')
          .where('customerId', isEqualTo: customerId)
          .get();

      if (licQuery.docs.isEmpty) {
        return ApiResponse.error(
          message: 'No active license found for this account. Please contact the administrator.',
          errorCode: 'NO_LICENSE',
          statusCode: 403,
        );
      }

      // Pick the most relevant license (prefer active non-expired)
      final activeLicenseDoc = licQuery.docs.firstWhere(
        (doc) {
          final d = doc.data();
          final st = d['status'] ?? 'Active';
          final exp = d['expiresAt'] != null ? DateTime.tryParse(d['expiresAt'].toString()) : null;
          return st == 'Active' && (exp == null || exp.isAfter(DateTime.now()));
        },
        orElse: () => licQuery.docs.first,
      );

      final licData = activeLicenseDoc.data();
      final license = AuthLicenseInfo.fromMap(licData, activeLicenseDoc.id);

      // Check license status & expiry
      if (license.status.toLowerCase() == 'suspended' || license.status.toLowerCase() == 'revoked') {
        return ApiResponse.error(
          message: 'Your license (${license.licenseKey}) is currently ${license.status}. Access denied.',
          errorCode: 'LICENSE_SUSPENDED',
          statusCode: 403,
        );
      }

      if (license.isExpired) {
        return ApiResponse.error(
          message: 'Your ShopeeInv license (${license.licenseKey}) has expired. Please renew your license to continue.',
          errorCode: 'LICENSE_EXPIRED',
          statusCode: 403,
        );
      }

      // 6. Hardware Identity & Device Connection Limit Check
      final deviceCheck = await registerDevice(
        customerId: customerId,
        customerName: custData['name'] ?? 'User',
        license: license,
      );

      if (!deviceCheck.success) {
        return ApiResponse.error(
          message: deviceCheck.message,
          errorCode: deviceCheck.errorCode,
          statusCode: deviceCheck.statusCode,
        );
      }

      // 7. Update lastLogin
      final now = DateTime.now();
      await custDoc.reference.update({'lastLogin': now.toIso8601String()});

      // 8. Generate Session Token
      final token = 'jwt_${customerId}_${now.millisecondsSinceEpoch}';
      final updatedUser = AuthUser.fromMap({
        ...custData,
        'lastLogin': now.toIso8601String(),
        'token': token,
      }, customerId);

      // 9. Save Session locally if rememberMe is enabled
      await saveSession(
        user: updatedUser,
        license: license,
        token: token,
        rememberMe: rememberMe,
      );

      return ApiResponse.success(
        statusCode: 200,
        message: 'Welcome back, ${updatedUser.name}!',
        data: {
          'token': token,
          'user': updatedUser.toMap(),
          'license': license.toMap(),
        },
      );
    } catch (e) {
      debugPrint('Login error: $e');
      return ApiResponse.error(
        message: 'Sign In failed: ${e.toString()}',
        errorCode: 'LOGIN_FAILED',
      );
    }
  }

  // =========================================================================
  // 7. POST /api/devices/register
  // =========================================================================
  static Future<ApiResponse<Map<String, dynamic>>> registerDevice({
    required String customerId,
    required String customerName,
    required AuthLicenseInfo license,
  }) async {
    try {
      final db = _firestore;
      if (db == null) {
        return ApiResponse.error(message: 'Firebase unavailable', errorCode: 'FIREBASE_UNAVAILABLE');
      }

      final deviceId = await LicenseClientService.getOrCreateDeviceId();
      final deviceName = kIsWeb ? 'Web Terminal' : Platform.localHostname;
      final os = kIsWeb ? 'Web Browser' : Platform.operatingSystemVersion;
      final deviceType = kIsWeb ? 'Web' : (Platform.isAndroid || Platform.isIOS ? 'Mobile' : 'Desktop');
      final now = DateTime.now();

      // Query existing devices for this customer
      final devicesQuery = await db
          .collection('devices')
          .where('customerId', isEqualTo: customerId)
          .get();

      final existingDevDoc = devicesQuery.docs.where((d) => d.data()['deviceId'] == deviceId).firstOrNull;
      final activeDevices = devicesQuery.docs.where((d) => d.data()['status'] == 'Active').toList();

      // If device already registered
      if (existingDevDoc != null) {
        final devData = existingDevDoc.data();
        if (devData['status'] == 'Blocked') {
          return ApiResponse.error(
            message: 'This specific device has been blocked by the administrator.',
            errorCode: 'DEVICE_BLOCKED',
            statusCode: 403,
          );
        }

        // Reconnection: update lastActiveAt
        await existingDevDoc.reference.update({
          'lastActiveAt': now.toIso8601String(),
          'deviceName': deviceName,
          'operatingSystem': os,
        });

        return ApiResponse.success(
          message: 'Device recognized and reconnected.',
          data: {'deviceId': deviceId, 'isNew': false},
        );
      }

      // If new device: check device limit slots
      if (activeDevices.length >= license.maxDevices) {
        final blockMsg =
            'Device Limit Reached! Your license allows only ${license.maxDevices} connected device${license.maxDevices > 1 ? "s" : ""}. '
            'Please remove an existing device or contact the administrator.';

        // Log limit breach to connection_history
        final histId = 'hist_${now.millisecondsSinceEpoch}';
        await db.collection('connection_history').doc(histId).set({
          'id': histId,
          'customerId': customerId,
          'customerName': customerName,
          'licenseKey': license.licenseKey,
          'deviceId': deviceId,
          'deviceName': deviceName,
          'deviceType': deviceType,
          'operatingSystem': os,
          'action': 'BLOCKED_DEVICE_LIMIT',
          'status': 'DENIED',
          'details': '${activeDevices.length}/${license.maxDevices} device slots occupied. Blocked connection.',
          'ipAddress': 'Client IP',
          'timestamp': now.toIso8601String(),
        });

        return ApiResponse.error(
          message: blockMsg,
          errorCode: 'DEVICE_LIMIT_EXCEEDED',
          statusCode: 429,
        );
      }

      // Slots available: register new hardware terminal
      final newDevDocId = 'dev_${now.millisecondsSinceEpoch}';
      await db.collection('devices').doc(newDevDocId).set({
        'id': newDevDocId,
        'deviceId': deviceId,
        'deviceName': deviceName,
        'deviceType': deviceType,
        'operatingSystem': os,
        'appVersion': '1.0.0+1',
        'status': 'Active',
        'firstConnectedAt': now.toIso8601String(),
        'lastActiveAt': now.toIso8601String(),
        'licenseId': license.id,
        'customerId': customerId,
        'ipAddress': 'Client IP',
      });

      // Log successful connection
      final histId = 'hist_${now.millisecondsSinceEpoch}';
      await db.collection('connection_history').doc(histId).set({
        'id': histId,
        'customerId': customerId,
        'customerName': customerName,
        'licenseKey': license.licenseKey,
        'deviceId': deviceId,
        'deviceName': deviceName,
        'deviceType': deviceType,
        'operatingSystem': os,
        'action': 'CONNECTED',
        'status': 'SUCCESS',
        'details': 'New terminal registered (${activeDevices.length + 1}/${license.maxDevices} slots used)',
        'ipAddress': 'Client IP',
        'timestamp': now.toIso8601String(),
      });

      return ApiResponse.success(
        statusCode: 201,
        message: 'Device successfully registered.',
        data: {'deviceId': deviceId, 'isNew': true},
      );
    } catch (e) {
      debugPrint('Device registration error: $e');
      return ApiResponse.error(
        message: 'Device validation error: ${e.toString()}',
        errorCode: 'DEVICE_ERROR',
      );
    }
  }

  // =========================================================================
  // 3. POST /api/auth/forgot-password
  // =========================================================================
  static Future<ApiResponse<String>> forgotPassword(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(cleanEmail)) {
      return ApiResponse.error(message: 'Please enter a valid email address', errorCode: 'INVALID_EMAIL');
    }

    try {
      final db = _firestore;
      if (db == null) {
        return ApiResponse.error(message: 'Cloud database unavailable', errorCode: 'FIREBASE_UNAVAILABLE');
      }

      final query = await db
          .collection('customers')
          .where('email', isEqualTo: cleanEmail)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return ApiResponse.error(
          message: 'No account registered with this email address.',
          errorCode: 'USER_NOT_FOUND',
          statusCode: 404,
        );
      }

      final custDoc = query.docs.first;
      final tempCode = (100000 + Random().nextInt(900000)).toString();

      await custDoc.reference.update({
        'resetCode': tempCode,
        'resetCodeGeneratedAt': DateTime.now().toIso8601String(),
      });

      return ApiResponse.success(
        message: 'Password reset request received! A verification code has been dispatched for $cleanEmail. (Code: $tempCode)',
        data: tempCode,
      );
    } catch (e) {
      debugPrint('Forgot password error: $e');
      return ApiResponse.error(
        message: 'Unable to process password reset: ${e.toString()}',
        errorCode: 'RESET_FAILED',
      );
    }
  }

  // =========================================================================
  // 4. POST /api/auth/reset-password
  // =========================================================================
  static Future<ApiResponse<bool>> resetPassword({
    required String email,
    required String resetCode,
    required String newPassword,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (newPassword.length < 6) {
      return ApiResponse.error(message: 'New password must be at least 6 characters', errorCode: 'WEAK_PASSWORD');
    }

    try {
      final db = _firestore;
      if (db == null) return ApiResponse.error(message: 'Database unavailable');

      final query = await db
          .collection('customers')
          .where('email', isEqualTo: cleanEmail)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return ApiResponse.error(message: 'Account not found', statusCode: 404);
      }

      final custDoc = query.docs.first;
      final data = custDoc.data();

      if (data['resetCode'] != resetCode.trim()) {
        return ApiResponse.error(message: 'Invalid or expired verification code.', errorCode: 'INVALID_CODE');
      }

      await custDoc.reference.update({
        'passwordHash': hashPassword(newPassword),
        'resetCode': FieldValue.delete(),
        'resetCodeGeneratedAt': FieldValue.delete(),
      });

      return ApiResponse.success(message: 'Password has been updated! You can now sign in with your new password.', data: true);
    } catch (e) {
      return ApiResponse.error(message: 'Password reset error: $e');
    }
  }

  // =========================================================================
  // 5. GET /api/auth/profile
  // =========================================================================
  static Future<ApiResponse<AuthUser>> getProfile() async {
    final user = await getSavedUser();
    if (user == null) {
      return ApiResponse.error(message: 'Not logged in', statusCode: 401, errorCode: 'UNAUTHORIZED');
    }
    return ApiResponse.success(message: 'Profile loaded', data: user);
  }

  // =========================================================================
  // 6. POST /api/auth/logout
  // =========================================================================
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefTokenKey);
    await prefs.remove(_prefUserKey);
    await prefs.remove(_prefLicenseKey);
  }

  // =========================================================================
  // Local Session Persistence Helper Methods
  // =========================================================================
  static Future<void> saveSession({
    required AuthUser user,
    required AuthLicenseInfo license,
    required String token,
    required bool rememberMe,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefRememberMe, rememberMe);
    if (rememberMe) {
      await prefs.setString(_prefTokenKey, token);
      await prefs.setString(_prefUserKey, jsonEncode(user.toMap()));
      await prefs.setString(_prefLicenseKey, jsonEncode(license.toMap()));
    }
  }

  static Future<AuthUser?> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_prefUserKey);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        return AuthUser.fromMap(map);
      } catch (e) {
        debugPrint('Error parsing saved user: $e');
      }
    }
    return null;
  }

  static Future<AuthLicenseInfo?> getSavedLicense() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_prefLicenseKey);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        return AuthLicenseInfo.fromMap(map);
      } catch (e) {
        debugPrint('Error parsing saved license: $e');
      }
    }
    return null;
  }

  static Future<String?> getSavedToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefTokenKey);
  }
}

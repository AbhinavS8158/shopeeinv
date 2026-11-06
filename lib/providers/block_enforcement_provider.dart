import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../core/services/license_client_service.dart';

class BlockEnforcementProvider extends ChangeNotifier {
  bool _isBlocked = false;
  String _blockMessage = 'Your account has been blocked . please contact Admin team';
  String? _blockReason;
  String? _blockedShopName;
  String? _blockedUserEmail;
  String? _blockedLicenseKey;
  DateTime? _blockedAt;
  bool _isChecking = false;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _customerSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _licenseSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _deviceSub;

  String? _currentCustomerId;

  bool get isBlocked => _isBlocked;
  String get blockMessage => _blockMessage;
  String? get blockReason => _blockReason;
  String? get blockedShopName => _blockedShopName;
  String? get blockedUserEmail => _blockedUserEmail;
  String? get blockedLicenseKey => _blockedLicenseKey;
  DateTime? get blockedAt => _blockedAt;
  bool get isChecking => _isChecking;

  FirebaseFirestore? get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  /// Start real-time monitoring for a customer ID
  void startMonitoring(String customerId, {String? shopName, String? email}) {
    if (_currentCustomerId == customerId && (_customerSub != null || _licenseSub != null)) {
      return;
    }

    stopMonitoring();
    _currentCustomerId = customerId;
    _blockedShopName = shopName;
    _blockedUserEmail = email;

    final db = _firestore;
    if (db == null) return;

    // 1. Listen to customer document (status changes to 'Blocked' or 'Suspended')
    _customerSub = db.collection('customers').doc(customerId).snapshots().listen((snap) {
      if (!snap.exists) return;
      final data = snap.data();
      if (data == null) return;

      final status = (data['status'] ?? 'Active').toString().toLowerCase();
      if (status == 'blocked' || status == 'suspended') {
        _setBlocked(
          message: 'Your account has been blocked . please contact Admin team',
          reason: 'Customer account suspended by administrator',
          shopName: data['shopName'] ?? _blockedShopName,
          email: data['email'] ?? _blockedUserEmail,
        );
      } else if (_isBlocked && _blockReason?.contains('Customer') == true) {
        // Check if all other aspects (license/device) are also clean
        checkFullStatus(customerId);
      }
    }, onError: (e) {
      debugPrint('BlockEnforcement customerSub error: $e');
    });

    // 2. Listen to license collection for this customer (status: 'Suspended' / 'Revoked' / 'Blocked')
    _licenseSub = db.collection('licenses').where('customerId', isEqualTo: customerId).snapshots().listen((snap) {
      if (snap.docs.isEmpty) return;

      bool hasActiveLicense = false;
      bool hasSuspendedLicense = false;
      String? suspendedKey;

      for (final doc in snap.docs) {
        final d = doc.data();
        final st = (d['status'] ?? 'Active').toString().toLowerCase();
        final exp = d['expiresAt'] != null ? DateTime.tryParse(d['expiresAt'].toString()) : null;
        final notExpired = exp == null || exp.isAfter(DateTime.now());

        if (st == 'active' && notExpired) {
          hasActiveLicense = true;
        } else if (st == 'suspended' || st == 'revoked' || st == 'blocked') {
          hasSuspendedLicense = true;
          suspendedKey = d['licenseKey'];
        }
      }

      if (hasSuspendedLicense && !hasActiveLicense) {
        _setBlocked(
          message: 'Your account has been blocked . please contact Admin team',
          reason: 'Application license suspended or blocked by administrator',
          licenseKey: suspendedKey,
        );
      } else if (hasActiveLicense && _isBlocked && _blockReason?.contains('license') == true) {
        checkFullStatus(customerId);
      }
    }, onError: (e) {
      debugPrint('BlockEnforcement licenseSub error: $e');
    });

    // 3. Listen to device status
    LicenseClientService.getOrCreateDeviceId().then((devId) {
      _deviceSub = db
          .collection('devices')
          .where('customerId', isEqualTo: customerId)
          .where('deviceId', isEqualTo: devId)
          .snapshots()
          .listen((snap) {
        if (snap.docs.isEmpty) return;
        final d = snap.docs.first.data();
        final st = (d['status'] ?? 'Active').toString().toLowerCase();
        if (st == 'blocked') {
          _setBlocked(
            message: 'Your account has been blocked . please contact Admin team',
            reason: 'This hardware terminal has been blocked by administrator',
          );
        } else if (_isBlocked && _blockReason?.contains('terminal') == true) {
          checkFullStatus(customerId);
        }
      }, onError: (e) {
        debugPrint('BlockEnforcement deviceSub error: $e');
      });
    });

    // Initial check right away
    checkFullStatus(customerId);
  }

  void _setBlocked({
    required String message,
    required String reason,
    String? shopName,
    String? email,
    String? licenseKey,
  }) {
    _isBlocked = true;
    _blockMessage = message;
    _blockReason = reason;
    if (shopName != null && shopName.isNotEmpty) _blockedShopName = shopName;
    if (email != null && email.isNotEmpty) _blockedUserEmail = email;
    if (licenseKey != null && licenseKey.isNotEmpty) _blockedLicenseKey = licenseKey;
    _blockedAt ??= DateTime.now();
    notifyListeners();
  }

  /// Manually check full status from Firestore
  Future<bool> checkFullStatus([String? custId]) async {
    final customerId = custId ?? _currentCustomerId;
    if (customerId == null || customerId.isEmpty) return false;

    _isChecking = true;
    notifyListeners();

    final db = _firestore;
    if (db == null) {
      _isChecking = false;
      notifyListeners();
      return _isBlocked;
    }

    try {
      // 1. Customer Doc
      final custDoc = await db.collection('customers').doc(customerId).get();
      if (custDoc.exists) {
        final d = custDoc.data()!;
        final st = (d['status'] ?? 'Active').toString().toLowerCase();
        if (st == 'blocked' || st == 'suspended') {
          _setBlocked(
            message: 'Your account has been blocked . please contact Admin team',
            reason: 'Customer account suspended by administrator',
            shopName: d['shopName'],
            email: d['email'],
          );
          _isChecking = false;
          notifyListeners();
          return true;
        }
      }

      // 2. Licenses
      final licQuery = await db.collection('licenses').where('customerId', isEqualTo: customerId).get();
      if (licQuery.docs.isNotEmpty) {
        bool hasActive = false;
        bool hasBlocked = false;
        String? key;
        for (final doc in licQuery.docs) {
          final d = doc.data();
          final st = (d['status'] ?? 'Active').toString().toLowerCase();
          final exp = d['expiresAt'] != null ? DateTime.tryParse(d['expiresAt'].toString()) : null;
          final notExp = exp == null || exp.isAfter(DateTime.now());
          if (st == 'active' && notExp) hasActive = true;
          if (st == 'suspended' || st == 'revoked' || st == 'blocked') {
            hasBlocked = true;
            key = d['licenseKey'];
          }
        }
        if (hasBlocked && !hasActive) {
          _setBlocked(
            message: 'Your account has been blocked . please contact Admin team',
            reason: 'Application license suspended or blocked by administrator',
            licenseKey: key,
          );
          _isChecking = false;
          notifyListeners();
          return true;
        }
      }

      // 3. Device
      final devId = await LicenseClientService.getOrCreateDeviceId();
      final devQuery = await db
          .collection('devices')
          .where('customerId', isEqualTo: customerId)
          .where('deviceId', isEqualTo: devId)
          .get();
      if (devQuery.docs.isNotEmpty) {
        final d = devQuery.docs.first.data();
        if ((d['status'] ?? 'Active').toString().toLowerCase() == 'blocked') {
          _setBlocked(
            message: 'Your account has been blocked . please contact Admin team',
            reason: 'This hardware terminal has been blocked by administrator',
          );
          _isChecking = false;
          notifyListeners();
          return true;
        }
      }

      // If all checks are clean -> unblock!
      _isBlocked = false;
      _blockReason = null;
      _blockedAt = null;
      _isChecking = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Error in checkFullStatus: $e');
      _isChecking = false;
      notifyListeners();
      return _isBlocked;
    }
  }

  /// Stop all monitoring listeners
  void stopMonitoring() {
    _customerSub?.cancel();
    _customerSub = null;
    _licenseSub?.cancel();
    _licenseSub = null;
    _deviceSub?.cancel();
    _deviceSub = null;
    _currentCustomerId = null;
    _isBlocked = false;
    _blockReason = null;
    _blockedAt = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopMonitoring();
    super.dispose();
  }
}

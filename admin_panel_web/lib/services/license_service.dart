import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/models/customer_model.dart';
import '../core/models/license_model.dart';
import '../core/models/device_model.dart';
import '../core/models/activity_log_model.dart';
import '../core/models/connection_history_model.dart';
import '../core/models/license_request_model.dart';
import '../core/utils/key_generator.dart';

class LicenseService extends ChangeNotifier {
  final List<CustomerModel> _customers = [];
  final List<LicenseModel> _licenses = [];
  final List<DeviceModel> _devices = [];
  final List<ActivityLogModel> _activityLogs = [];
  final List<ConnectionHistoryModel> _connectionHistory = [];
  final List<LicenseRequestModel> _licenseRequests = [];

  // Firebase backend metadata
  bool isFirebaseConnected = false;
  final String firebaseProjectId = 'shopeeinv-8da75';
  final String firebaseAccountEmail = 'abhinav.8158s@gmail.com';

  // System settings
  int defaultDeviceLimit = 2;
  int defaultTrialDays = 14;
  String minAppVersion = '1.0.0';
  bool allowDeviceDeregistration = true;

  // Active Admin
  String currentAdminName = 'Super Administrator';
  String currentAdminEmail = 'admin@shopeeinv.com';
  String currentAdminRole = 'SUPER_ADMIN';
  bool isAuthenticated = false;

  // Getters
  List<CustomerModel> get customers => List.unmodifiable(_customers);
  List<LicenseModel> get licenses => List.unmodifiable(_licenses);
  List<DeviceModel> get devices => List.unmodifiable(_devices);
  List<ActivityLogModel> get activityLogs => List.unmodifiable(_activityLogs);
  List<ConnectionHistoryModel> get connectionHistory => List.unmodifiable(_connectionHistory);
  List<LicenseRequestModel> get licenseRequests => List.unmodifiable(_licenseRequests);
  int get pendingRequestsCount => _licenseRequests.where((r) => r.isPending).length;

  // Derived counts
  int get totalCustomers => _customers.length;
  int get activeCustomers => _customers.where((c) => c.status == 'Active').length;
  int get blockedCustomers => _customers.where((c) => c.status == 'Blocked').length;

  int get totalLicenses => _licenses.length;
  int get activeLicenses => _licenses.where((l) => l.effectiveStatus == 'Active').length;
  int get expiredLicenses => _licenses.where((l) => l.effectiveStatus == 'Expired').length;
  int get suspendedLicenses => _licenses.where((l) => l.effectiveStatus == 'Suspended').length;

  int get totalConnectedDevices => _devices.where((d) => d.status == 'Active').length;
  int get blockedDevicesCount => _devices.where((d) => d.status == 'Blocked').length;

  int get totalAllowedSlots {
    return _licenses
        .where((l) => l.effectiveStatus == 'Active')
        .fold(0, (total, l) => total + l.maxDevices);
  }

  int get availableSlots => (totalAllowedSlots - totalConnectedDevices).clamp(0, 9999);

  LicenseService() {
    _initFirestoreSync();
  }

  FirebaseFirestore? get _db {
    try {
      return FirebaseFirestore.instance;
    } catch (e) {
      debugPrint('Firestore instance error: $e');
      return null;
    }
  }

  Future<void> _firestoreSet(String col, String id, Map<String, dynamic> data) async {
    try {
      await _db?.collection(col).doc(id).set(data);
    } catch (e) {
      debugPrint('Firestore set error ($col/$id): $e');
    }
  }

  Future<void> _firestoreUpdate(String col, String id, Map<String, dynamic> data) async {
    try {
      await _db?.collection(col).doc(id).update(data);
    } catch (e) {
      debugPrint('Firestore update error ($col/$id): $e');
    }
  }

  Future<void> _firestoreDelete(String col, String id) async {
    try {
      await _db?.collection(col).doc(id).delete();
    } catch (e) {
      debugPrint('Firestore delete error ($col/$id): $e');
    }
  }

  void _initFirestoreSync() {
    final db = _db;
    if (db == null) return;
    isFirebaseConnected = true;

    db.collection('customers').snapshots().listen((snap) {
      _customers.clear();
      for (final doc in snap.docs) {
        _customers.add(CustomerModel.fromMap(doc.data(), doc.id));
      }
      notifyListeners();
    }, onError: (e) {
      debugPrint('Firestore customers stream error: $e');
    });

    db.collection('licenses').snapshots().listen((snap) {
      _licenses.clear();
      for (final doc in snap.docs) {
        _licenses.add(LicenseModel.fromMap(doc.data(), doc.id));
      }
      notifyListeners();
    }, onError: (e) {
      debugPrint('Firestore licenses stream error: $e');
    });

    db.collection('devices').snapshots().listen((snap) {
      _devices.clear();
      for (final doc in snap.docs) {
        _devices.add(DeviceModel.fromMap(doc.data(), doc.id));
      }
      notifyListeners();
    }, onError: (e) {
      debugPrint('Firestore devices stream error: $e');
    });

    db.collection('activity_logs').orderBy('createdAt', descending: true).snapshots().listen((snap) {
      _activityLogs.clear();
      for (final doc in snap.docs) {
        _activityLogs.add(ActivityLogModel.fromMap(doc.data(), doc.id));
      }
      notifyListeners();
    }, onError: (e) {
      debugPrint('Firestore activity_logs stream error: $e');
    });

    db.collection('connection_history').orderBy('timestamp', descending: true).snapshots().listen((snap) {
      _connectionHistory.clear();
      for (final doc in snap.docs) {
        _connectionHistory.add(ConnectionHistoryModel.fromMap(doc.data(), doc.id));
      }
      notifyListeners();
    }, onError: (e) {
      debugPrint('Firestore connection_history stream error: $e');
    });

    db.collection('license_requests').snapshots().listen((snap) {
      _licenseRequests.clear();
      for (final doc in snap.docs) {
        _licenseRequests.add(LicenseRequestModel.fromMap(doc.data(), doc.id));
      }
      _licenseRequests.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
      notifyListeners();
    }, onError: (e) {
      debugPrint('Firestore license_requests stream error: $e');
    });
  }

  // --- Authentication ---
  bool login(String email, String password) {
    if ((email == 'admin@shopeeinv.com' && password == 'admin123') ||
        (email == 'support@shopeeinv.com' && password == 'staff123') ||
        password.isNotEmpty) {
      isAuthenticated = true;
      currentAdminEmail = email;
      currentAdminName = email.contains('support') ? 'Support Agent' : 'Super Administrator';
      currentAdminRole = email.contains('support') ? 'STAFF_ADMIN' : 'SUPER_ADMIN';

      logAdminActivity(
        action: 'ADMIN_LOGIN',
        targetType: 'ADMIN',
        targetId: email,
        details: 'Admin signed in successfully',
      );
      notifyListeners();
      return true;
    }
    return false;
  }

  void logout() {
    isAuthenticated = false;
    notifyListeners();
  }

  // --- Customer Operations ---
  void addCustomer({
    required String name,
    required String shopName,
    required String email,
    required String phone,
    required String address,
    bool issueLicense = true,
    String licenseTier = 'Standard',
    String validityType = '1_year',
    int maxDevices = 2,
  }) {
    final newId = 'cust_${DateTime.now().millisecondsSinceEpoch}';
    final customerCode = 'CUST-${1000 + _customers.length + 1}';

    final customer = CustomerModel(
      id: newId,
      customerCode: customerCode,
      name: name,
      shopName: shopName,
      email: email,
      phone: phone,
      address: address,
      status: 'Active',
      createdAt: DateTime.now(),
      lastLogin: DateTime.now(),
    );

    _customers.insert(0, customer);
    _firestoreSet('customers', customer.id, customer.toMap());

    if (issueLicense) {
      final key = KeyGenerator.generateLicenseKey(prefix: 'POS');
      final expiresAt = KeyGenerator.calculateExpiryDate(validityType);

      final license = LicenseModel(
        id: 'lic_${DateTime.now().millisecondsSinceEpoch}',
        licenseKey: key,
        customerId: customer.id,
        customerName: customer.shopName,
        licenseType: licenseTier,
        status: 'Active',
        maxDevices: maxDevices,
        validityType: validityType,
        issuedAt: DateTime.now(),
        activatedAt: DateTime.now(),
        expiresAt: expiresAt,
        issuedBy: currentAdminName,
      );

      _licenses.insert(0, license);
      _firestoreSet('licenses', license.id, license.toMap());
    }

    logAdminActivity(
      action: 'CREATE_CUSTOMER',
      targetType: 'CUSTOMER',
      targetId: customer.id,
      details: 'Registered customer "${customer.shopName}" (${customer.name})',
    );

    notifyListeners();
  }

  void updateCustomer(String customerId, {required String name, required String shopName, required String email, required String phone, required String status}) {
    final idx = _customers.indexWhere((c) => c.id == customerId);
    if (idx != -1) {
      _customers[idx] = _customers[idx].copyWith(
        name: name,
        shopName: shopName,
        email: email,
        phone: phone,
        status: status,
      );
      _firestoreUpdate('customers', customerId, _customers[idx].toMap());

      logAdminActivity(
        action: 'UPDATE_CUSTOMER',
        targetType: 'CUSTOMER',
        targetId: customerId,
        details: 'Updated details for "$shopName"',
      );
      notifyListeners();
    }
  }

  void toggleCustomerStatus(String customerId) {
    final idx = _customers.indexWhere((c) => c.id == customerId);
    if (idx != -1) {
      final current = _customers[idx].status;
      final newStatus = current == 'Blocked' ? 'Active' : 'Blocked';
      _customers[idx] = _customers[idx].copyWith(status: newStatus);
      _firestoreUpdate('customers', customerId, {'status': newStatus});

      logAdminActivity(
        action: newStatus == 'Blocked' ? 'BLOCK_CUSTOMER' : 'UNBLOCK_CUSTOMER',
        targetType: 'CUSTOMER',
        targetId: customerId,
        details: 'Customer "${_customers[idx].shopName}" marked as $newStatus',
      );
      notifyListeners();
    }
  }

  // --- License Operations ---
  void generateLicense({
    required String customerId,
    required String licenseType,
    required String validityType,
    DateTime? customDate,
    required int maxDevices,
    String notes = '',
  }) {
    final customer = _customers.firstWhere((c) => c.id == customerId);
    final key = KeyGenerator.generateLicenseKey(prefix: 'POS');
    final expiresAt = KeyGenerator.calculateExpiryDate(validityType, customDate: customDate);

    final license = LicenseModel(
      id: 'lic_${DateTime.now().millisecondsSinceEpoch}',
      licenseKey: key,
      customerId: customer.id,
      customerName: customer.shopName,
      licenseType: licenseType,
      status: 'Active',
      maxDevices: maxDevices,
      validityType: validityType,
      issuedAt: DateTime.now(),
      activatedAt: DateTime.now(),
      expiresAt: expiresAt,
      issuedBy: currentAdminName,
      notes: notes,
    );

    _licenses.insert(0, license);
    _firestoreSet('licenses', license.id, license.toMap());

    logAdminActivity(
      action: 'ISSUE_LICENSE',
      targetType: 'LICENSE',
      targetId: license.id,
      details: 'Issued $licenseType license ($key) for "${customer.shopName}" with $maxDevices device slots',
    );

    notifyListeners();
  }

  void extendLicenseValidity(String licenseId, String validityType, {DateTime? customDate}) {
    final idx = _licenses.indexWhere((l) => l.id == licenseId);
    if (idx != -1) {
      final lic = _licenses[idx];
      final baseDate = (lic.expiresAt != null && lic.expiresAt!.isAfter(DateTime.now()))
          ? lic.expiresAt!
          : DateTime.now();

      final newExpiresAt = KeyGenerator.calculateExpiryDate(validityType, fromDate: baseDate, customDate: customDate);

      _licenses[idx] = lic.copyWith(
        status: 'Active',
        expiresAt: newExpiresAt,
        validityType: validityType,
      );
      _firestoreUpdate('licenses', lic.id, {
        'status': 'Active',
        'expiresAt': newExpiresAt?.toIso8601String(),
        'validityType': validityType,
      });

      logAdminActivity(
        action: 'EXTEND_LICENSE',
        targetType: 'LICENSE',
        targetId: lic.id,
        details: 'Extended license ${lic.licenseKey} validity to ${newExpiresAt?.toString().substring(0, 10) ?? "Lifetime"}',
      );
      notifyListeners();
    }
  }

  void updateDeviceLimit(String licenseId, int newLimit) {
    final idx = _licenses.indexWhere((l) => l.id == licenseId);
    if (idx != -1) {
      final oldLimit = _licenses[idx].maxDevices;
      _licenses[idx] = _licenses[idx].copyWith(maxDevices: newLimit);
      _firestoreUpdate('licenses', licenseId, {'maxDevices': newLimit});

      logAdminActivity(
        action: 'CHANGE_DEVICE_LIMIT',
        targetType: 'LICENSE',
        targetId: licenseId,
        details: 'Device limit changed from $oldLimit to $newLimit for key ${_licenses[idx].licenseKey}',
      );
      notifyListeners();
    }
  }

  void updateLicenseStatus(String licenseId, String newStatus) {
    final idx = _licenses.indexWhere((l) => l.id == licenseId);
    if (idx != -1) {
      _licenses[idx] = _licenses[idx].copyWith(status: newStatus);
      _firestoreUpdate('licenses', licenseId, {'status': newStatus});

      logAdminActivity(
        action: 'UPDATE_LICENSE_STATUS',
        targetType: 'LICENSE',
        targetId: licenseId,
        details: 'License ${_licenses[idx].licenseKey} status updated to $newStatus',
      );
      notifyListeners();
    }
  }

  void renewLicense(String licenseId, {String validityType = '1_year', DateTime? customDate}) {
    final idx = _licenses.indexWhere((l) => l.id == licenseId);
    if (idx != -1) {
      final newExpiry = KeyGenerator.calculateExpiryDate(validityType, customDate: customDate);
      _licenses[idx] = _licenses[idx].copyWith(
        status: 'Active',
        expiresAt: newExpiry,
        validityType: validityType,
      );
      _firestoreUpdate('licenses', licenseId, {
        'status': 'Active',
        'expiresAt': newExpiry?.toIso8601String(),
        'validityType': validityType,
      });

      logAdminActivity(
        action: 'RENEW_LICENSE',
        targetType: 'LICENSE',
        targetId: licenseId,
        details: 'Renewed expired license ${_licenses[idx].licenseKey}',
      );
      notifyListeners();
    }
  }

  // --- Device Management Operations ---
  void blockDevice(String deviceId) {
    final idx = _devices.indexWhere((d) => d.id == deviceId);
    if (idx != -1) {
      _devices[idx] = _devices[idx].copyWith(status: 'Blocked');
      _firestoreUpdate('devices', deviceId, {'status': 'Blocked'});

      logAdminActivity(
        action: 'BLOCK_DEVICE',
        targetType: 'DEVICE',
        targetId: deviceId,
        details: 'Blocked device "${_devices[idx].deviceName}" (${_devices[idx].deviceId})',
      );
      notifyListeners();
    }
  }

  void unblockDevice(String deviceId) {
    final idx = _devices.indexWhere((d) => d.id == deviceId);
    if (idx != -1) {
      _devices[idx] = _devices[idx].copyWith(status: 'Active');
      _firestoreUpdate('devices', deviceId, {'status': 'Active'});

      logAdminActivity(
        action: 'UNBLOCK_DEVICE',
        targetType: 'DEVICE',
        targetId: deviceId,
        details: 'Unblocked device "${_devices[idx].deviceName}" (${_devices[idx].deviceId})',
      );
      notifyListeners();
    }
  }

  /// Deactivate / Remove a device from account -> immediately frees up 1 device slot
  void deactivateDevice(String deviceId) {
    final idx = _devices.indexWhere((d) => d.id == deviceId);
    if (idx != -1) {
      final dev = _devices[idx];
      _devices.removeAt(idx);
      _firestoreDelete('devices', dev.id);

      logAdminActivity(
        action: 'DEACTIVATE_DEVICE',
        targetType: 'DEVICE',
        targetId: deviceId,
        details: 'Removed device "${dev.deviceName}" for customer ID ${dev.customerId}. Slot freed.',
      );

      final hist = ConnectionHistoryModel(
        id: 'hist_${DateTime.now().millisecondsSinceEpoch}',
        customerId: dev.customerId,
        customerName: getCustomerName(dev.customerId),
        licenseKey: getLicenseKey(dev.licenseId),
        deviceId: dev.deviceId,
        deviceName: dev.deviceName,
        deviceType: dev.deviceType,
        operatingSystem: dev.operatingSystem,
        action: 'DEACTIVATED',
        status: 'SUCCESS',
        details: 'Device deactivated by administrator to free up license slot',
        timestamp: DateTime.now(),
      );
      _connectionHistory.insert(0, hist);
      _firestoreSet('connection_history', hist.id, hist.toMap());

      notifyListeners();
    }
  }

  void resetCustomerDevices(String customerId) {
    final removed = _devices.where((d) => d.customerId == customerId).toList();
    _devices.removeWhere((d) => d.customerId == customerId);
    for (final dev in removed) {
      _firestoreDelete('devices', dev.id);
    }

    logAdminActivity(
      action: 'RESET_CUSTOMER_DEVICES',
      targetType: 'CUSTOMER',
      targetId: customerId,
      details: 'Disconnected all ${removed.length} devices for customer',
    );
    notifyListeners();
  }

  // --- Real-Time Device Restriction Pipeline (Client Simulator / POS Engine) ---
  SimulateLoginResult simulateClientLogin({
    required String licenseKey,
    required String deviceId,
    required String deviceName,
    required String deviceType,
    required String operatingSystem,
    String appVersion = '1.0.0+1',
  }) {
    // 1. Validate License Existence
    final lic = _licenses.firstWhere(
      (l) => l.licenseKey.trim().toUpperCase() == licenseKey.trim().toUpperCase(),
      orElse: () => LicenseModel(
        id: '',
        licenseKey: '',
        customerId: '',
        customerName: '',
        issuedAt: DateTime.now(),
      ),
    );

    if (lic.id.isEmpty) {
      return SimulateLoginResult(
        allowed: false,
        statusCode: 404,
        errorCode: 'INVALID_LICENSE',
        message: 'Invalid license key. Please check the code and try again.',
      );
    }

    // 2. Validate Customer Status
    final customer = _customers.firstWhere((c) => c.id == lic.customerId);
    if (customer.status != 'Active') {
      _logConnection(
        lic: lic,
        deviceId: deviceId,
        deviceName: deviceName,
        deviceType: deviceType,
        os: operatingSystem,
        action: 'BLOCKED_CUSTOMER_INACTIVE',
        status: 'DENIED',
        details: 'Customer account status is ${customer.status}',
      );

      return SimulateLoginResult(
        allowed: false,
        statusCode: 403,
        errorCode: 'CUSTOMER_BLOCKED',
        message: 'Your customer account is currently ${customer.status}. Please contact the administrator.',
      );
    }

    // 3. Validate License Validity & Expiry
    if (lic.status == 'Revoked' || lic.status == 'Suspended') {
      _logConnection(
        lic: lic,
        deviceId: deviceId,
        deviceName: deviceName,
        deviceType: deviceType,
        os: operatingSystem,
        action: 'BLOCKED_LICENSE_REVOKED',
        status: 'DENIED',
        details: 'License status is ${lic.status}',
      );

      return SimulateLoginResult(
        allowed: false,
        statusCode: 403,
        errorCode: 'LICENSE_REVOKED',
        message: 'Your ShopeeInv license has been ${lic.status.toLowerCase()} by the administrator.',
      );
    }

    if (lic.isExpired) {
      _logConnection(
        lic: lic,
        deviceId: deviceId,
        deviceName: deviceName,
        deviceType: deviceType,
        os: operatingSystem,
        action: 'BLOCKED_LICENSE_EXPIRED',
        status: 'DENIED',
        details: 'License expired on ${lic.expiresAt}',
      );

      return SimulateLoginResult(
        allowed: false,
        statusCode: 403,
        errorCode: 'LICENSE_EXPIRED',
        message: 'Your ShopeeInv license has expired. Please renew your license to continue.',
      );
    }

    // 4. Check If Device Already Registered For This Customer
    final existingIdx = _devices.indexWhere(
      (d) => d.customerId == customer.id && d.deviceId == deviceId,
    );

    if (existingIdx != -1) {
      final existingDevice = _devices[existingIdx];

      // Check device blacklist
      if (existingDevice.status == 'Blocked') {
        _logConnection(
          lic: lic,
          deviceId: deviceId,
          deviceName: deviceName,
          deviceType: deviceType,
          os: operatingSystem,
          action: 'BLOCKED_BLACKLISTED',
          status: 'DENIED',
          details: 'Device is specifically blocked by administrator',
        );

        return SimulateLoginResult(
          allowed: false,
          statusCode: 403,
          errorCode: 'DEVICE_BLOCKED',
          message: 'This device has been specifically blocked by the administrator.',
        );
      }

      // Reconnection: update last active & allow
      _devices[existingIdx] = existingDevice.copyWith(
        deviceName: deviceName,
        deviceType: deviceType,
        operatingSystem: operatingSystem,
        appVersion: appVersion,
        lastActiveAt: DateTime.now(),
      );
      _firestoreUpdate('devices', existingDevice.id, _devices[existingIdx].toMap());

      _logConnection(
        lic: lic,
        deviceId: deviceId,
        deviceName: deviceName,
        deviceType: deviceType,
        os: operatingSystem,
        action: 'RECONNECTED',
        status: 'SUCCESS',
        details: 'Existing recognized device reconnected',
      );

      final usedSlots = _devices.where((d) => d.customerId == customer.id && d.status == 'Active').length;
      notifyListeners();

      return SimulateLoginResult(
        allowed: true,
        statusCode: 200,
        message: 'Welcome back! Recognized device reconnected.',
        usedSlots: usedSlots,
        maxSlots: lic.maxDevices,
      );
    }

    // 5. New Device: Check Available Device Slots
    final activeCount = _devices.where((d) => d.customerId == customer.id && d.status == 'Active').length;

    if (activeCount >= lic.maxDevices) {
      // Limit Reached! Block New Device
      final blockMsg = 'Device Limit Reached! Your license allows only ${lic.maxDevices} connected device${lic.maxDevices > 1 ? "s" : ""}. Please remove an existing device or contact the administrator.';

      _logConnection(
        lic: lic,
        deviceId: deviceId,
        deviceName: deviceName,
        deviceType: deviceType,
        os: operatingSystem,
        action: 'BLOCKED_DEVICE_LIMIT',
        status: 'DENIED',
        details: '$activeCount/${lic.maxDevices} slots occupied. Blocked new device connection.',
      );

      notifyListeners();

      return SimulateLoginResult(
        allowed: false,
        statusCode: 403,
        errorCode: 'DEVICE_LIMIT_REACHED',
        message: blockMsg,
        usedSlots: activeCount,
        maxSlots: lic.maxDevices,
      );
    }

    // 6. Slots Available: Register New Device
    final newDev = DeviceModel(
      id: 'dev_${DateTime.now().millisecondsSinceEpoch}',
      deviceId: deviceId,
      deviceName: deviceName,
      deviceType: deviceType,
      operatingSystem: operatingSystem,
      appVersion: appVersion,
      status: 'Active',
      firstConnectedAt: DateTime.now(),
      lastActiveAt: DateTime.now(),
      licenseId: lic.id,
      customerId: customer.id,
    );

    _devices.add(newDev);
    _firestoreSet('devices', newDev.id, newDev.toMap());

    _logConnection(
      lic: lic,
      deviceId: deviceId,
      deviceName: deviceName,
      deviceType: deviceType,
      os: operatingSystem,
      action: 'CONNECTED',
      status: 'SUCCESS',
      details: 'New device registered (${activeCount + 1}/${lic.maxDevices} slots used)',
    );

    notifyListeners();

    return SimulateLoginResult(
      allowed: true,
      statusCode: 200,
      message: 'New device registered successfully! (${activeCount + 1}/${lic.maxDevices} slots used)',
      usedSlots: activeCount + 1,
      maxSlots: lic.maxDevices,
    );
  }

  void _logConnection({
    required LicenseModel lic,
    required String deviceId,
    required String deviceName,
    required String deviceType,
    required String os,
    required String action,
    required String status,
    required String details,
  }) {
    final record = ConnectionHistoryModel(
      id: 'hist_${DateTime.now().millisecondsSinceEpoch}',
      customerId: lic.customerId,
      customerName: lic.customerName,
      licenseKey: lic.licenseKey,
      deviceId: deviceId,
      deviceName: deviceName,
      deviceType: deviceType,
      operatingSystem: os,
      action: action,
      status: status,
      details: details,
      timestamp: DateTime.now(),
    );
    _connectionHistory.insert(0, record);
    _firestoreSet('connection_history', record.id, record.toMap());
  }

  void logAdminActivity({
    required String action,
    required String targetType,
    required String targetId,
    required String details,
  }) {
    final log = ActivityLogModel(
      id: 'log_${DateTime.now().millisecondsSinceEpoch}',
      adminName: currentAdminName,
      action: action,
      targetType: targetType,
      targetId: targetId,
      details: details,
      createdAt: DateTime.now(),
    );
    _activityLogs.insert(0, log);
    _firestoreSet('activity_logs', log.id, log.toMap());
  }

  String getCustomerName(String customerId) {
    return _customers.firstWhere((c) => c.id == customerId, orElse: () => CustomerModel(id: '', customerCode: '', name: '', shopName: 'Unknown', email: '', phone: '', address: '', createdAt: DateTime.now())).shopName;
  }

  String getLicenseKey(String licenseId) {
    return _licenses.firstWhere((l) => l.id == licenseId, orElse: () => LicenseModel(id: '', licenseKey: 'None', customerId: '', customerName: '', issuedAt: DateTime.now())).licenseKey;
  }

  // --- License Requests Operations ---
  Future<bool> approveLicenseRequest({
    required String requestId,
    required String licenseType,
    required String validityType,
    required int maxDevices,
    String? adminNotes,
  }) async {
    final idx = _licenseRequests.indexWhere((r) => r.id == requestId);
    if (idx == -1) return false;

    final req = _licenseRequests[idx];
    final now = DateTime.now();

    DateTime? expiresAt;
    switch (validityType) {
      case '30_days':
        expiresAt = now.add(const Duration(days: 30));
        break;
      case '3_months':
        expiresAt = now.add(const Duration(days: 90));
        break;
      case '6_months':
        expiresAt = now.add(const Duration(days: 180));
        break;
      case '1_year':
        expiresAt = now.add(const Duration(days: 365));
        break;
      case 'lifetime':
        expiresAt = null;
        break;
      default:
        expiresAt = now.add(const Duration(days: 365));
    }

    final newLicenseId = 'lic_${now.millisecondsSinceEpoch}';
    final licenseKey = KeyGenerator.generateLicenseKey();

    final license = LicenseModel(
      id: newLicenseId,
      licenseKey: licenseKey,
      customerId: req.customerId,
      customerName: req.customerName,
      licenseType: licenseType,
      status: 'Active',
      maxDevices: maxDevices,
      validityType: validityType,
      issuedAt: now,
      activatedAt: now,
      expiresAt: expiresAt,
      issuedBy: currentAdminName,
      notes: adminNotes ?? 'Issued upon approving license request ${req.id}',
    );

    _licenses.insert(0, license);
    await _firestoreSet('licenses', newLicenseId, license.toMap());

    final updatedReq = LicenseRequestModel(
      id: req.id,
      customerId: req.customerId,
      customerName: req.customerName,
      email: req.email,
      phone: req.phone,
      shopId: req.shopId,
      shopName: req.shopName,
      businessType: req.businessType,
      address: req.address,
      gstin: req.gstin,
      status: 'Approved',
      requestedAt: req.requestedAt,
      reviewedAt: now,
      reviewedBy: currentAdminName,
      rejectionReason: null,
      adminNotes: adminNotes,
      licenseKey: licenseKey,
      licenseId: newLicenseId,
      maxDevices: maxDevices,
      licenseType: licenseType,
      validityType: validityType,
    );

    _licenseRequests[idx] = updatedReq;
    await _firestoreUpdate('license_requests', req.id, updatedReq.toMap());

    logAdminActivity(
      action: 'APPROVE_LICENSE_REQUEST',
      targetType: 'LICENSE_REQUEST',
      targetId: requestId,
      details: 'Approved request for "${req.shopName}" (${req.customerName}). License $licenseKey issued.',
    );

    notifyListeners();
    return true;
  }

  Future<bool> rejectLicenseRequest({
    required String requestId,
    required String reason,
    String? adminNotes,
  }) async {
    final idx = _licenseRequests.indexWhere((r) => r.id == requestId);
    if (idx == -1) return false;

    final req = _licenseRequests[idx];
    final now = DateTime.now();

    final updatedReq = LicenseRequestModel(
      id: req.id,
      customerId: req.customerId,
      customerName: req.customerName,
      email: req.email,
      phone: req.phone,
      shopId: req.shopId,
      shopName: req.shopName,
      businessType: req.businessType,
      address: req.address,
      gstin: req.gstin,
      status: 'Rejected',
      requestedAt: req.requestedAt,
      reviewedAt: now,
      reviewedBy: currentAdminName,
      rejectionReason: reason,
      adminNotes: adminNotes,
      licenseKey: null,
      licenseId: null,
      maxDevices: req.maxDevices,
      licenseType: req.licenseType,
      validityType: req.validityType,
    );

    _licenseRequests[idx] = updatedReq;
    await _firestoreUpdate('license_requests', req.id, updatedReq.toMap());

    logAdminActivity(
      action: 'REJECT_LICENSE_REQUEST',
      targetType: 'LICENSE_REQUEST',
      targetId: requestId,
      details: 'Rejected license request for "${req.shopName}". Reason: $reason',
    );

    notifyListeners();
    return true;
  }
}

class SimulateLoginResult {
  final bool allowed;
  final int statusCode;
  final String? errorCode;
  final String message;
  final int? usedSlots;
  final int? maxSlots;

  SimulateLoginResult({
    required this.allowed,
    required this.statusCode,
    this.errorCode,
    required this.message,
    this.usedSlots,
    this.maxSlots,
  });
}

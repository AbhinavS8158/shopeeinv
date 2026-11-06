import 'package:flutter/foundation.dart';
import '../core/models/auth_user.dart';
import '../core/models/auth_license_info.dart';
import '../core/services/auth_api_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthUser? _currentUser;
  AuthLicenseInfo? _currentLicense;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;
  bool _rememberMe = true;

  // Getters
  AuthUser? get currentUser => _currentUser;
  AuthLicenseInfo? get currentLicense => _currentLicense;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get rememberMe => _rememberMe;

  void setRememberMe(bool value) {
    _rememberMe = value;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Called on app startup to restore session
  Future<bool> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await AuthApiService.getSavedToken();
      if (token != null && token.isNotEmpty) {
        final savedUser = await AuthApiService.getSavedUser();
        final savedLicense = await AuthApiService.getSavedLicense();

        if (savedUser != null) {
          _currentUser = savedUser;
          _currentLicense = savedLicense;
          _isAuthenticated = true;
          _isLoading = false;
          notifyListeners();
          return true;
        }
      }
    } catch (e) {
      debugPrint('Error restoring auth session: $e');
    }

    _isAuthenticated = false;
    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Sign Up new user
  Future<bool> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final res = await AuthApiService.register(
      name: name,
      email: email,
      phone: phone,
      password: password,
    );

    _isLoading = false;
    if (!res.success) {
      _errorMessage = res.message;
      notifyListeners();
      return false;
    }

    _errorMessage = null;
    notifyListeners();
    return true;
  }

  /// Sign In existing user (Email + Password only)
  Future<bool> login({
    required String email,
    required String password,
    bool? rememberMe,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final shouldRemember = rememberMe ?? _rememberMe;
    final res = await AuthApiService.login(
      email: email,
      password: password,
      rememberMe: shouldRemember,
    );

    _isLoading = false;

    if (!res.success) {
      _errorMessage = res.message;
      _isAuthenticated = false;
      notifyListeners();
      return false;
    }

    if (res.data != null) {
      final userMap = res.data!['user'] as Map<String, dynamic>;
      final licMap = res.data!['license'] as Map<String, dynamic>?;
      _currentUser = AuthUser.fromMap(userMap);
      _currentLicense = licMap != null ? AuthLicenseInfo.fromMap(licMap) : null;
      _isAuthenticated = true;
      _errorMessage = null;
      notifyListeners();
      return true;
    }

    _errorMessage = 'Unexpected response format';
    notifyListeners();
    return false;
  }

  /// Forgot Password
  Future<String?> forgotPassword(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final res = await AuthApiService.forgotPassword(email);
    _isLoading = false;

    if (!res.success) {
      _errorMessage = res.message;
      notifyListeners();
      return null;
    }

    notifyListeners();
    return res.data;
  }

  /// Reset Password
  Future<bool> resetPassword({
    required String email,
    required String resetCode,
    required String newPassword,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final res = await AuthApiService.resetPassword(
      email: email,
      resetCode: resetCode,
      newPassword: newPassword,
    );

    _isLoading = false;
    if (!res.success) {
      _errorMessage = res.message;
      notifyListeners();
      return false;
    }

    notifyListeners();
    return true;
  }

  bool get hasApprovedLicense => _currentLicense != null && _currentLicense!.isValid;

  /// Refresh user license status from Firestore
  Future<void> refreshLicense() async {
    if (_currentUser == null) return;
    try {
      final lic = await AuthApiService.getSavedLicense();
      if (lic != null) {
        _currentLicense = lic;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error refreshing license: $e');
    }
  }

  void setLicense(AuthLicenseInfo license) {
    _currentLicense = license;
    notifyListeners();
  }

  /// Secure Logout
  Future<void> logout() async {
    await AuthApiService.logout();
    _currentUser = null;
    _currentLicense = null;
    _isAuthenticated = false;
    _errorMessage = null;
    notifyListeners();
  }
}

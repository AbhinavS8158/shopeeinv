import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/api_response.dart';
import '../models/auth_user.dart';
import '../models/auth_license_info.dart';
import '../models/license_request_model.dart';
import '../models/shop_profile.dart';

class LicenseRequestService {
  static FirebaseFirestore? get _firestore {
    if (Firebase.apps.isNotEmpty) {
      return FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: '(default)',
      );
    }
    return null;
  }

  /// Submit a new application license request to admin
  static Future<ApiResponse<LicenseRequestModel>> submitLicenseRequest({
    required AuthUser user,
    required ShopProfile shop,
    String businessType = 'Retail Store',
    String? notes,
  }) async {
    try {
      final db = _firestore;
      if (db == null) {
        return ApiResponse.error(
          message: 'Cloud service unavailable. Please check internet connection.',
          errorCode: 'FIREBASE_UNAVAILABLE',
        );
      }

      final now = DateTime.now();
      final requestId = 'req_${now.millisecondsSinceEpoch}';

      final requestData = {
        'id': requestId,
        'customerId': user.id,
        'customerName': user.name,
        'email': user.email,
        'phone': shop.phone.isNotEmpty ? shop.phone : user.phone,
        'shopId': shop.id,
        'shopName': shop.shopName,
        'businessType': businessType,
        'address': '${shop.address}, ${shop.city}, ${shop.state}',
        'gstin': shop.gstin,
        'status': 'Pending',
        'requestedAt': now.toIso8601String(),
        'reviewedAt': null,
        'reviewedBy': null,
        'rejectionReason': null,
        'adminNotes': notes ?? '',
        'licenseKey': null,
        'licenseId': null,
        'maxDevices': 2,
        'licenseType': 'Standard',
        'validityType': '1_year',
      };

      await db.collection('license_requests').doc(requestId).set(requestData);

      // Log request in admin activity logs
      final logId = 'log_${now.millisecondsSinceEpoch}';
      await db.collection('activity_logs').doc(logId).set({
        'id': logId,
        'action': 'LICENSE_REQUEST_SUBMITTED',
        'targetType': 'LICENSE_REQUEST',
        'targetId': requestId,
        'details': 'New license request submitted by ${user.name} for shop "${shop.shopName}" (${user.email})',
        'createdAt': now.toIso8601String(),
        'performedBy': user.email,
      });

      final model = LicenseRequestModel.fromMap(requestData, requestId);
      return ApiResponse.success(
        statusCode: 201,
        message: 'Your license request has been submitted successfully. Please wait for admin approval.',
        data: model,
      );
    } catch (e) {
      debugPrint('License request submission error: $e');
      return ApiResponse.error(
        message: 'Failed to submit license request: ${e.toString()}',
        errorCode: 'REQUEST_SUBMISSION_FAILED',
      );
    }
  }

  /// Get the latest license request for a customer
  static Future<LicenseRequestModel?> getLatestRequest(String customerId) async {
    try {
      final db = _firestore;
      if (db == null) return null;

      final query = await db
          .collection('license_requests')
          .where('customerId', isEqualTo: customerId)
          .get();

      if (query.docs.isEmpty) return null;

      // Sort by requestedAt descending
      final docs = query.docs.toList()
        ..sort((a, b) {
          final aDate = a.data()['requestedAt']?.toString() ?? '';
          final bDate = b.data()['requestedAt']?.toString() ?? '';
          return bDate.compareTo(aDate);
        });

      return LicenseRequestModel.fromMap(docs.first.data(), docs.first.id);
    } catch (e) {
      debugPrint('Error getting latest license request: $e');
      return null;
    }
  }

  /// Real-time stream of latest license request for a customer
  static Stream<LicenseRequestModel?> streamLatestRequest(String customerId) {
    final db = _firestore;
    if (db == null) return Stream.value(null);

    return db
        .collection('license_requests')
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final docs = snapshot.docs.toList()
        ..sort((a, b) {
          final aDate = a.data()['requestedAt']?.toString() ?? '';
          final bDate = b.data()['requestedAt']?.toString() ?? '';
          return bDate.compareTo(aDate);
        });
      return LicenseRequestModel.fromMap(docs.first.data(), docs.first.id);
    });
  }

  /// Check whether an approved, active license already exists in 'licenses'
  static Future<AuthLicenseInfo?> getActiveLicense(String customerId) async {
    try {
      final db = _firestore;
      if (db == null) return null;

      final licQuery = await db
          .collection('licenses')
          .where('customerId', isEqualTo: customerId)
          .get();

      if (licQuery.docs.isEmpty) return null;

      final activeDocs = licQuery.docs.where((d) {
        final data = d.data();
        final st = data['status']?.toString() ?? 'Active';
        final exp = data['expiresAt'] != null ? DateTime.tryParse(data['expiresAt'].toString()) : null;
        return st == 'Active' && (exp == null || exp.isAfter(DateTime.now()));
      }).toList();

      if (activeDocs.isNotEmpty) {
        return AuthLicenseInfo.fromMap(activeDocs.first.data(), activeDocs.first.id);
      }

      // If no strictly active, return the most recent one (might be expired)
      return AuthLicenseInfo.fromMap(licQuery.docs.first.data(), licQuery.docs.first.id);
    } catch (e) {
      debugPrint('Error fetching active license: $e');
      return null;
    }
  }
}

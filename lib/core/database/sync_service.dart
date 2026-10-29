import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../models/shop_profile.dart';
import '../models/product.dart';
import '../models/customer.dart';
import '../models/invoice.dart';
import '../models/stock_log.dart';
import 'app_database.dart';

class SyncService {
  static final SyncService instance = SyncService._internal();
  SyncService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  bool _isOnline = false;
  bool _isSyncing = false;
  int _pendingSyncCount = 0;
  DateTime? _lastSyncTime;
  String? _syncError;

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  int get pendingSyncCount => _pendingSyncCount;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get syncError => _syncError;

  final ValueNotifier<bool> onlineNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> syncingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> pendingNotifier = ValueNotifier<int>(0);

  bool _isFirebaseReady = false;

  Future<void> init() async {
    // Check initial connectivity
    try {
      final results = await _connectivity.checkConnectivity();
      _isOnline = results.any((r) => r != ConnectivityResult.none);
      onlineNotifier.value = _isOnline;

      _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
        final online = results.any((r) => r != ConnectivityResult.none);
        _isOnline = online;
        onlineNotifier.value = online;
        if (online) {
          syncAll();
        }
      });
    } catch (e) {
      debugPrint('Connectivity check error: $e');
    }

    // Check Firebase availability
    try {
      if (Firebase.apps.isNotEmpty) {
        _isFirebaseReady = true;
      }
    } catch (e) {
      _isFirebaseReady = false;
      debugPrint('Firebase not initialized yet: $e');
    }

    await updatePendingCount();
  }

  Future<int> updatePendingCount() async {
    final db = await AppDatabase.instance.database;
    int count = 0;
    try {
      final p1 = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM products WHERE isSynced = 0')) ?? 0;
      final p2 = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM customers WHERE isSynced = 0')) ?? 0;
      final p3 = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM invoices WHERE isSynced = 0')) ?? 0;
      final p4 = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM shops WHERE isSynced = 0')) ?? 0;
      final p5 = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM stock_logs WHERE isSynced = 0')) ?? 0;
      count = p1 + p2 + p3 + p4 + p5;
      _pendingSyncCount = count;
      pendingNotifier.value = count;
    } catch (e) {
      debugPrint('Error updating pending count: $e');
    }
    return count;
  }

  Future<bool> syncAll() async {
    if (_isSyncing) return false;
    await updatePendingCount();

    if (!_isOnline) {
      _syncError = 'No internet connection';
      return false;
    }

    // Verify Firebase is available
    if (!_isFirebaseReady) {
      try {
        if (Firebase.apps.isNotEmpty) {
          _isFirebaseReady = true;
        } else {
          _syncError = 'Firebase offline mode active';
          return false;
        }
      } catch (e) {
        _syncError = 'Firebase connection unavailable';
        return false;
      }
    }

    _isSyncing = true;
    syncingNotifier.value = true;
    _syncError = null;

    final db = await AppDatabase.instance.database;
    final firestore = FirebaseFirestore.instance;

    try {
      // 1. Sync Shops
      final unsyncedShops = await db.query('shops', where: 'isSynced = 0');
      for (final row in unsyncedShops) {
        final shop = ShopProfile.fromMap(row);
        await firestore.collection('shops').doc(shop.id).set(shop.toMap(), SetOptions(merge: true));
        await db.update('shops', {'isSynced': 1}, where: 'id = ?', whereArgs: [shop.id]);
      }

      // 2. Sync Products
      final unsyncedProducts = await db.query('products', where: 'isSynced = 0');
      for (final row in unsyncedProducts) {
        final product = Product.fromMap(row);
        await firestore
            .collection('shops')
            .doc(product.shopId)
            .collection('products')
            .doc(product.id)
            .set(product.toMap(), SetOptions(merge: true));
        await db.update('products', {'isSynced': 1}, where: 'id = ?', whereArgs: [product.id]);
      }

      // 3. Sync Customers
      final unsyncedCustomers = await db.query('customers', where: 'isSynced = 0');
      for (final row in unsyncedCustomers) {
        final customer = Customer.fromMap(row);
        await firestore
            .collection('shops')
            .doc(customer.shopId)
            .collection('customers')
            .doc(customer.id)
            .set(customer.toMap(), SetOptions(merge: true));
        await db.update('customers', {'isSynced': 1}, where: 'id = ?', whereArgs: [customer.id]);
      }

      // 4. Sync Invoices
      final unsyncedInvoices = await db.query('invoices', where: 'isSynced = 0');
      for (final row in unsyncedInvoices) {
        final invoice = Invoice.fromMap(row);
        await firestore
            .collection('shops')
            .doc(invoice.shopId)
            .collection('invoices')
            .doc(invoice.id)
            .set(invoice.toMap(), SetOptions(merge: true));
        await db.update('invoices', {'isSynced': 1}, where: 'id = ?', whereArgs: [invoice.id]);
      }

      // 5. Sync Stock Logs
      final unsyncedLogs = await db.query('stock_logs', where: 'isSynced = 0');
      for (final row in unsyncedLogs) {
        final log = StockLog.fromMap(row);
        await firestore
            .collection('shops')
            .doc(log.shopId)
            .collection('stock_logs')
            .doc(log.id)
            .set(log.toMap(), SetOptions(merge: true));
        await db.update('stock_logs', {'isSynced': 1}, where: 'id = ?', whereArgs: [log.id]);
      }

      _lastSyncTime = DateTime.now();
      await updatePendingCount();
      return true;
    } catch (e) {
      debugPrint('Sync error: $e');
      _syncError = e.toString();
      return false;
    } finally {
      _isSyncing = false;
      syncingNotifier.value = false;
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}

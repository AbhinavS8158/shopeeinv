import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/database/app_database.dart';
import '../core/database/sync_service.dart';
import '../core/models/shop_profile.dart';

class ShopProvider extends ChangeNotifier {
  ShopProfile? _currentShop;
  List<ShopProfile> _shops = [];
  bool _isLoading = false;

  ShopProfile? get currentShop => _currentShop;
  List<ShopProfile> get shops => _shops;
  bool get isLoading => _isLoading;
  bool get hasShop => _currentShop != null;

  Future<void> loadShops() async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await AppDatabase.instance.database;
      final result = await db.query('shops', orderBy: 'createdAt DESC');
      _shops = result.map((m) => ShopProfile.fromMap(m)).toList();

      final prefs = await SharedPreferences.getInstance();
      final savedShopId = prefs.getString('active_shop_id');

      if (savedShopId != null && _shops.any((s) => s.id == savedShopId)) {
        _currentShop = _shops.firstWhere((s) => s.id == savedShopId);
      } else if (_shops.isNotEmpty) {
        _currentShop = _shops.first;
        await prefs.setString('active_shop_id', _currentShop!.id);
      } else {
        _currentShop = null;
      }
    } catch (e) {
      debugPrint('Error loading shops: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createOrUpdateShop(ShopProfile shop) async {
    try {
      final db = await AppDatabase.instance.database;
      final isNew = !_shops.any((s) => s.id == shop.id);

      if (isNew) {
        await db.insert('shops', shop.toMap());
      } else {
        await db.update(
          'shops',
          shop.copyWith(updatedAt: DateTime.now(), isSynced: false).toMap(),
          where: 'id = ?',
          whereArgs: [shop.id],
        );
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_shop_id', shop.id);
      _currentShop = shop;

      await loadShops();
      SyncService.instance.updatePendingCount();
      SyncService.instance.syncAll();
      return true;
    } catch (e) {
      debugPrint('Error creating/updating shop: $e');
      return false;
    }
  }

  Future<void> switchShop(String shopId) async {
    final found = _shops.firstWhere((s) => s.id == shopId, orElse: () => _currentShop!);
    _currentShop = found;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_shop_id', shopId);
    notifyListeners();
  }
}

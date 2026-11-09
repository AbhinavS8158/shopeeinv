import 'package:flutter/material.dart';
import '../core/database/app_database.dart';
import '../core/database/sync_service.dart';
import '../core/models/combo_offer.dart';

class ComboOfferProvider extends ChangeNotifier {
  List<ComboOffer> _offers = [];
  bool _isLoading = false;

  List<ComboOffer> get offers => _offers;
  bool get isLoading => _isLoading;
  List<ComboOffer> get activeOffers => _offers.where((o) => o.isValidNow).toList();

  Future<void> loadComboOffers(String shopId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await AppDatabase.instance.database;
      final results = await db.query(
        'combo_offers',
        where: 'shopId = ?',
        whereArgs: [shopId],
        orderBy: 'createdAt DESC',
      );
      _offers = results.map((m) => ComboOffer.fromMap(m)).toList();
    } catch (e) {
      debugPrint('Error loading combo offers: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveComboOffer(ComboOffer offer) async {
    try {
      final db = await AppDatabase.instance.database;
      final existing = await db.query('combo_offers', where: 'id = ?', whereArgs: [offer.id]);

      if (existing.isNotEmpty) {
        await db.update(
          'combo_offers',
          offer.toMap(),
          where: 'id = ?',
          whereArgs: [offer.id],
        );
      } else {
        await db.insert('combo_offers', offer.toMap());
      }

      await loadComboOffers(offer.shopId);
      SyncService.instance.updatePendingCount();
      SyncService.instance.syncAll();
      return true;
    } catch (e) {
      debugPrint('Error saving combo offer: $e');
      return false;
    }
  }

  Future<bool> toggleComboOffer(String id, bool isActive, String shopId) async {
    try {
      final db = await AppDatabase.instance.database;
      await db.update(
        'combo_offers',
        {
          'isActive': isActive ? 1 : 0,
          'updatedAt': DateTime.now().toIso8601String(),
          'isSynced': 0,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await loadComboOffers(shopId);
      return true;
    } catch (e) {
      debugPrint('Error toggling combo offer: $e');
      return false;
    }
  }

  Future<bool> deleteComboOffer(String id, String shopId) async {
    try {
      final db = await AppDatabase.instance.database;
      await db.delete('combo_offers', where: 'id = ?', whereArgs: [id]);
      await loadComboOffers(shopId);
      return true;
    } catch (e) {
      debugPrint('Error deleting combo offer: $e');
      return false;
    }
  }
}

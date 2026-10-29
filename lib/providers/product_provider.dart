import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../core/database/app_database.dart';
import '../core/database/sync_service.dart';
import '../core/models/product.dart';
import '../core/models/stock_log.dart';

class ProductProvider extends ChangeNotifier {
  List<Product> _products = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String _selectedCategory = 'All';

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;

  List<String> get categories {
    final set = {'All'};
    for (final p in _products) {
      if (p.category.isNotEmpty) set.add(p.category);
    }
    return set.toList();
  }

  List<Product> get filteredProducts {
    return _products.where((p) {
      final matchesCat = _selectedCategory == 'All' || p.category.toLowerCase() == _selectedCategory.toLowerCase();
      final q = _searchQuery.toLowerCase().trim();
      final matchesSearch = q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          p.barcode.toLowerCase().contains(q) ||
          p.sku.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q);
      return matchesCat && matchesSearch;
    }).toList();
  }

  List<Product> get lowStockProducts {
    return _products.where((p) => p.isLowStock).toList();
  }

  Future<void> loadProducts(String shopId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await AppDatabase.instance.database;
      final result = await db.query(
        'products',
        where: 'shopId = ? AND isDeleted = 0',
        whereArgs: [shopId],
        orderBy: 'name ASC',
      );
      _products = result.map((m) => Product.fromMap(m)).toList();
    } catch (e) {
      debugPrint('Error loading products: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  Product? findByBarcode(String barcode) {
    if (barcode.trim().isEmpty) return null;
    try {
      return _products.firstWhere(
        (p) => p.barcode.trim() == barcode.trim(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> saveProduct(Product product) async {
    try {
      final db = await AppDatabase.instance.database;
      final isExisting = _products.any((p) => p.id == product.id);

      if (!isExisting) {
        await db.insert('products', product.copyWith(isSynced: false).toMap());
        // Initial stock log if stock > 0
        if (product.stockQuantity > 0) {
          final log = StockLog(
            id: const Uuid().v4(),
            shopId: product.shopId,
            productId: product.id,
            productName: product.name,
            changeType: 'purchase',
            quantityChange: product.stockQuantity,
            previousQuantity: 0,
            newQuantity: product.stockQuantity,
            reason: 'Initial Stock Entry',
          );
          await db.insert('stock_logs', log.toMap());
        }
      } else {
        await db.update(
          'products',
          product.copyWith(updatedAt: DateTime.now(), isSynced: false).toMap(),
          where: 'id = ?',
          whereArgs: [product.id],
        );
      }

      await loadProducts(product.shopId);
      SyncService.instance.updatePendingCount();
      SyncService.instance.syncAll();
      return true;
    } catch (e) {
      debugPrint('Error saving product: $e');
      return false;
    }
  }

  Future<bool> deleteProduct(String productId, String shopId) async {
    try {
      final db = await AppDatabase.instance.database;
      await db.update(
        'products',
        {'isDeleted': 1, 'isSynced': 0, 'updatedAt': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [productId],
      );

      await loadProducts(shopId);
      SyncService.instance.updatePendingCount();
      SyncService.instance.syncAll();
      return true;
    } catch (e) {
      debugPrint('Error deleting product: $e');
      return false;
    }
  }

  Future<bool> adjustStock({
    required String shopId,
    required String productId,
    required double newQuantity,
    required String reason,
    required String changeType, // 'adjustment', 'purchase', 'return'
  }) async {
    try {
      final db = await AppDatabase.instance.database;
      final prod = _products.firstWhere((p) => p.id == productId);
      final oldQty = prod.stockQuantity;
      final diff = newQuantity - oldQty;

      await db.update(
        'products',
        {
          'stockQuantity': newQuantity,
          'updatedAt': DateTime.now().toIso8601String(),
          'isSynced': 0,
        },
        where: 'id = ?',
        whereArgs: [productId],
      );

      final log = StockLog(
        id: const Uuid().v4(),
        shopId: shopId,
        productId: productId,
        productName: prod.name,
        changeType: changeType,
        quantityChange: diff,
        previousQuantity: oldQty,
        newQuantity: newQuantity,
        reason: reason,
      );
      await db.insert('stock_logs', log.toMap());

      await loadProducts(shopId);
      SyncService.instance.updatePendingCount();
      SyncService.instance.syncAll();
      return true;
    } catch (e) {
      debugPrint('Error adjusting stock: $e');
      return false;
    }
  }
}

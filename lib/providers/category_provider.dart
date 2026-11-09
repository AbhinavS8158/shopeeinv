import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../core/database/app_database.dart';
import '../core/models/category.dart';

class CategoryProvider extends ChangeNotifier {
  List<ProductCategory> _categories = [];
  bool _isLoading = false;

  List<ProductCategory> get categories => List.unmodifiable(_categories);
  bool get isLoading => _isLoading;

  static const List<String> defaultCategories = [
    'Vegetables',
    'Fruits',
    'Grocery',
    'Spices',
    'Bakery',
    'Dairy Products',
    'General',
  ];

  Future<void> loadCategories(String shopId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await AppDatabase.instance.database;
      final results = await db.query(
        'categories',
        where: 'shopId = ?',
        whereArgs: [shopId],
        orderBy: 'name COLLATE NOCASE ASC',
      );

      if (results.isEmpty) {
        // Seed default categories for this shop
        final now = DateTime.now();
        final batch = db.batch();
        for (final catName in defaultCategories) {
          final cat = ProductCategory(
            id: const Uuid().v4(),
            shopId: shopId,
            name: catName,
            createdAt: now,
            updatedAt: now,
          );
          batch.insert('categories', cat.toMap());
        }
        await batch.commit(noResult: true);

        // Re-query
        final seededResults = await db.query(
          'categories',
          where: 'shopId = ?',
          whereArgs: [shopId],
          orderBy: 'name COLLATE NOCASE ASC',
        );
        _categories = seededResults.map((m) => ProductCategory.fromMap(m)).toList();
      } else {
        _categories = results.map((m) => ProductCategory.fromMap(m)).toList();
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ProductCategory?> addCategory(String shopId, String rawName) async {
    final name = rawName.trim();
    if (name.isEmpty) return null;

    // Check duplicate
    final isDuplicate = _categories.any(
      (c) => c.name.trim().toLowerCase() == name.toLowerCase(),
    );
    if (isDuplicate) {
      throw Exception('Category "$name" already exists.');
    }

    try {
      final db = await AppDatabase.instance.database;
      final newCat = ProductCategory(
        id: const Uuid().v4(),
        shopId: shopId,
        name: name,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await db.insert('categories', newCat.toMap());
      _categories.add(newCat);
      _categories.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      notifyListeners();
      return newCat;
    } catch (e) {
      debugPrint('Error adding category: $e');
      rethrow;
    }
  }

  Future<bool> updateCategory(String id, String shopId, String rawName) async {
    final name = rawName.trim();
    if (name.isEmpty) return false;

    final isDuplicate = _categories.any(
      (c) => c.id != id && c.name.trim().toLowerCase() == name.toLowerCase(),
    );
    if (isDuplicate) {
      throw Exception('Category "$name" already exists.');
    }

    try {
      final db = await AppDatabase.instance.database;
      final now = DateTime.now();
      await db.update(
        'categories',
        {
          'name': name,
          'updatedAt': now.toIso8601String(),
          'isSynced': 0,
        },
        where: 'id = ? AND shopId = ?',
        whereArgs: [id, shopId],
      );

      final index = _categories.indexWhere((c) => c.id == id);
      if (index != -1) {
        _categories[index] = _categories[index].copyWith(name: name, updatedAt: now);
        _categories.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('Error updating category: $e');
      rethrow;
    }
  }

  Future<bool> deleteCategory(String id, String shopId) async {
    try {
      final db = await AppDatabase.instance.database;
      await db.delete(
        'categories',
        where: 'id = ? AND shopId = ?',
        whereArgs: [id, shopId],
      );

      _categories.removeWhere((c) => c.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting category: $e');
      return false;
    }
  }
}

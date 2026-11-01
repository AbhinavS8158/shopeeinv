import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../core/database/app_database.dart';
import '../core/database/sync_service.dart';
import '../core/models/cash_register_session.dart';

class CashRegisterProvider extends ChangeNotifier {
  CashRegisterSession? _currentSession;
  List<CashRegisterSession> _sessionHistory = [];
  bool _isLoading = false;

  CashRegisterSession? get currentSession => _currentSession;
  List<CashRegisterSession> get sessionHistory => _sessionHistory;
  bool get isLoading => _isLoading;
  bool get hasOpenSession => _currentSession != null && _currentSession!.isOpen;

  String get todayDateStr => DateFormat('yyyy-MM-dd').format(DateTime.now());

  Future<void> loadTodaySession(String shopId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await AppDatabase.instance.database;
      // Check for session matching shop and today
      final results = await db.query(
        'cash_register_sessions',
        where: 'shopId = ? AND date = ?',
        whereArgs: [shopId, todayDateStr],
        orderBy: 'openedAt DESC',
        limit: 1,
      );

      if (results.isNotEmpty) {
        _currentSession = CashRegisterSession.fromMap(results.first);
      } else {
        // Check if there is an unclosed session from previous day
        final unclosed = await db.query(
          'cash_register_sessions',
          where: 'shopId = ? AND status = ?',
          whereArgs: [shopId, 'open'],
          orderBy: 'openedAt DESC',
          limit: 1,
        );
        if (unclosed.isNotEmpty) {
          _currentSession = CashRegisterSession.fromMap(unclosed.first);
        } else {
          _currentSession = null;
        }
      }

      // Load recent session history
      final history = await db.query(
        'cash_register_sessions',
        where: 'shopId = ?',
        whereArgs: [shopId],
        orderBy: 'openedAt DESC',
        limit: 30,
      );
      _sessionHistory = history.map((m) => CashRegisterSession.fromMap(m)).toList();
    } catch (e) {
      debugPrint('Error loading cash register session: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> openSession({
    required String shopId,
    required double openingAmount,
    String notes = '',
  }) async {
    try {
      final db = await AppDatabase.instance.database;
      final session = CashRegisterSession(
        id: const Uuid().v4(),
        shopId: shopId,
        date: todayDateStr,
        openingAmount: openingAmount,
        openedAt: DateTime.now(),
        status: 'open',
        notes: notes,
      );

      await db.insert('cash_register_sessions', session.toMap());
      _currentSession = session;
      await loadTodaySession(shopId);

      SyncService.instance.updatePendingCount();
      SyncService.instance.syncAll();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error opening cash register session: $e');
      return false;
    }
  }

  Future<bool> closeSession({
    required String shopId,
    required double closingAmount,
    String notes = '',
  }) async {
    if (_currentSession == null) return false;

    try {
      final db = await AppDatabase.instance.database;
      final updated = _currentSession!.copyWith(
        closingAmount: closingAmount,
        closedAt: DateTime.now(),
        status: 'closed',
        notes: notes.isNotEmpty ? notes : _currentSession!.notes,
        isSynced: false,
      );

      await db.update(
        'cash_register_sessions',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [updated.id],
      );

      _currentSession = updated;
      await loadTodaySession(shopId);

      SyncService.instance.updatePendingCount();
      SyncService.instance.syncAll();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error closing cash register session: $e');
      return false;
    }
  }
}

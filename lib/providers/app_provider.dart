import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../models/blocked_app_model.dart';

class AppProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  List<BlockedApp> _blockedApps = [];
  List<BlockedApp> _activeApps = [];
  bool _isLoading = false;
  String? _error;

  List<BlockedApp> get blockedApps => _blockedApps;
  List<BlockedApp> get activeApps => _activeApps;
  bool get isLoading => _isLoading;
  String? get error => _error;

  AppProvider() {
    _loadApps();
  }

  // ===== LOAD OPERATIONS =====

  Future<void> _loadApps() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _blockedApps = await _db.getAllBlockedApps();
      _activeApps = await _db.getActiveBlockedApps();
      _error = null;
    } catch (e) {
      _error = 'Error loading apps: $e';
      print(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshApps() async {
    await _loadApps();
  }

  // ===== ADD APP =====

  Future<void> addApp(
    String packageName,
    String appName,
    int dailyLimitMinutes,
  ) async {
    try {
      final app = BlockedApp(
        packageName: packageName,
        appName: appName,
        dailyLimitMinutes: dailyLimitMinutes,
        createdAt: DateTime.now(),
      );

      final id = await _db.addBlockedApp(app);
      final newApp = app.copyWith(id: id);
      _blockedApps.add(newApp);
      _activeApps.add(newApp);
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Error adding app: $e';
      print(_error);
      notifyListeners();
    }
  }

  // ===== UPDATE APP =====

  Future<void> updateApp(BlockedApp app) async {
    try {
      await _db.updateBlockedApp(app);
      final index = _blockedApps.indexWhere((a) => a.id == app.id);
      if (index != -1) {
        _blockedApps[index] = app;
      }
      _activeApps = _blockedApps.where((a) => a.isActive).toList();
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Error updating app: $e';
      print(_error);
      notifyListeners();
    }
  }

  // ===== DELETE APP =====

  Future<void> deleteApp(int appId) async {
    try {
      await _db.deleteBlockedApp(appId);
      _blockedApps.removeWhere((a) => a.id == appId);
      _activeApps.removeWhere((a) => a.id == appId);
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Error deleting app: $e';
      print(_error);
      notifyListeners();
    }
  }

  // ===== TOGGLE APP ACTIVE STATUS =====

  Future<void> toggleAppStatus(int appId, bool newStatus) async {
    try {
      final app = _blockedApps.firstWhere((a) => a.id == appId);
      final updatedApp = app.copyWith(isActive: newStatus);
      await updateApp(updatedApp);
    } catch (e) {
      _error = 'Error toggling app status: $e';
      print(_error);
      notifyListeners();
    }
  }

  // ===== UPDATE DAILY LIMIT =====

  Future<void> updateDailyLimit(int appId, int newLimit) async {
    try {
      final app = _blockedApps.firstWhere((a) => a.id == appId);
      final updatedApp = app.copyWith(dailyLimitMinutes: newLimit);
      await updateApp(updatedApp);
    } catch (e) {
      _error = 'Error updating daily limit: $e';
      print(_error);
      notifyListeners();
    }
  }

  // ===== QUERY OPERATIONS =====

  BlockedApp? getAppById(int id) {
    try {
      return _blockedApps.firstWhere((a) => a.id == id);
    } catch (e) {
      return null;
    }
  }

  BlockedApp? getAppByPackage(String packageName) {
    try {
      return _blockedApps.firstWhere((a) => a.packageName == packageName);
    } catch (e) {
      return null;
    }
  }

  bool isAppBlocked(String packageName) {
    return _activeApps.any((a) => a.packageName == packageName);
  }

  int getTotalBlockedApps() => _blockedApps.length;
  int getActiveBlockedApps() => _activeApps.length;
}

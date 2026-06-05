import 'package:flutter/material.dart';
import '../services/app_blocker_service.dart';
import '../services/database_service.dart';
import '../models/daily_usage_model.dart';

class TimerProvider extends ChangeNotifier {
  final AppBlockerService _blocker = AppBlockerService();
  final DatabaseService _db = DatabaseService();

  // Timers for each app (appId -> remaining seconds)
  final Map<int, int> _remainingTimes = {};
  final Map<String, int> _dailyUsage = {};
  final Map<String, int> _dailyLimits = {};

  int getRemainingTime(int appId) => _remainingTimes[appId] ?? 0;
  int getDailyUsage(String packageName) => _dailyUsage[packageName] ?? 0;
  int getDailyLimit(String packageName) => _dailyLimits[packageName] ?? 30;

  TimerProvider() {
    _initializeTimers();
  }

  // ===== INITIALIZATION =====

  Future<void> _initializeTimers() async {
    try {
      await _blocker.performDailyReset();
      print('TimerProvider initialized and daily reset performed');
    } catch (e) {
      print('Error initializing timers: $e');
    }
  }

  // ===== UPDATE USAGE =====

  Future<void> updateUsage(
    String packageName,
    int appId,
    int additionalMinutes,
    int dailyLimit,
  ) async {
    try {
      await _blocker.updateAppUsage(packageName, additionalMinutes);
      _dailyUsage[packageName] =
          (_dailyUsage[packageName] ?? 0) + additionalMinutes;
      _dailyLimits[packageName] = dailyLimit;
      notifyListeners();
    } catch (e) {
      print('Error updating usage: $e');
    }
  }

  // ===== UNLOCK MANAGEMENT =====

  Future<void> unlockApp(int appId, int durationMinutes) async {
    try {
      await _blocker.unlockApp(appId, durationMinutes);
      _remainingTimes[appId] = durationMinutes * 60; // Convert to seconds
      notifyListeners();
      _startUnlockTimer(appId);
    } catch (e) {
      print('Error unlocking app: $e');
    }
  }

  void _startUnlockTimer(int appId) {
    // This would typically use a periodic timer
    // For now, we'll update the remaining time
    Future.delayed(const Duration(seconds: 1), () {
      int? remaining = _remainingTimes[appId];
      if (remaining != null && remaining > 0) {
        _remainingTimes[appId] = remaining - 1;
        notifyListeners();
        _startUnlockTimer(appId); // Continue counting down
      } else if (remaining == 0) {
        _remainingTimes.remove(appId);
        notifyListeners();
      }
    });
  }

  Future<int> getRemainingUnlockTime(int appId) async {
    final remaining = await _blocker.getRemainingUnlockTime(appId);
    _remainingTimes[appId] = remaining;
    notifyListeners();
    return remaining;
  }

  // ===== GET STATUS =====

  Future<int> getTodayUsage(String packageName) async {
    final usage = await _blocker.getTodayUsage(packageName);
    _dailyUsage[packageName] = usage;
    notifyListeners();
    return usage;
  }

  Future<int> getRemainingTimeBeforeLock(String packageName) async {
    final remaining = await _blocker.getRemainingTimeBeforeLock(packageName);
    notifyListeners();
    return remaining;
  }

  // ===== CHECK STATUS =====

  Future<bool?> checkAppStatus(String packageName) async {
    return await _blocker.checkAppStatus(packageName);
  }

  // ===== DAILY RESET =====

  Future<void> performDailyReset() async {
    try {
      await _blocker.performDailyReset();
      _remainingTimes.clear();
      _dailyUsage.clear();
      notifyListeners();
      print('Daily reset performed');
    } catch (e) {
      print('Error performing daily reset: $e');
    }
  }

  // ===== LOAD DAILY USAGE =====

  Future<void> loadDailyUsage(int appId, String packageName) async {
    try {
      final today =
          '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
      final usage = await _db.getDailyUsage(appId, today);
      if (usage != null) {
        _dailyUsage[packageName] = usage.totalMinutes;
      }
      notifyListeners();
    } catch (e) {
      print('Error loading daily usage: $e');
    }
  }
}

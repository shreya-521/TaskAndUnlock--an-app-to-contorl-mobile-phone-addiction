import 'package:shared_preferences/shared_preferences.dart';
import '../models/blocked_app_model.dart';
import '../models/daily_usage_model.dart';
import '../models/exercise_model.dart';
import 'database_service.dart';

class AppBlockerService {
  static final AppBlockerService _instance = AppBlockerService._();
  factory AppBlockerService() => _instance;
  AppBlockerService._();

  final DatabaseService _db = DatabaseService();
  static const String _unlockTimeKey = 'unlock_time_';
  static const String _lastResetDateKey = 'last_reset_date';

  /// Check if an app is blocked based on daily usage
  /// Returns: null if not in blocklist, true if blocked, false if within limit
  Future<bool?> checkAppStatus(String packageName) async {
    try {
      // Check if app is in blocklist
      final blockedApp = await _db.getBlockedAppByPackage(packageName);
      if (blockedApp == null || !blockedApp.isActive) {
        return null; // Not in blocklist
      }

      // Check if app is unlocked temporarily
      if (await _isTemporarilyUnlocked(blockedApp.id!)) {
        return false; // Temporarily unlocked
      }

      // Get today's usage
      final today = _getFormattedDate(DateTime.now());
      final dailyUsage = await _db.getDailyUsage(blockedApp.id!, today);

      if (dailyUsage == null) {
        return false; // No usage today, allow access
      }

      // Check if usage exceeds limit
      if (dailyUsage.totalMinutes >= blockedApp.dailyLimitMinutes) {
        return true; // Blocked - usage exceeded
      }

      return false; // Within limit
    } catch (e) {
      print('Error checking app status: $e');
      return false; // Fail safe - allow access
    }
  }

  /// Update daily usage for an app
  /// Called periodically while app is in foreground
  Future<void> updateAppUsage(String packageName, int additionalMinutes) async {
    try {
      final blockedApp = await _db.getBlockedAppByPackage(packageName);
      if (blockedApp == null) return;

      final today = _getFormattedDate(DateTime.now());
      var dailyUsage = await _db.getDailyUsage(blockedApp.id!, today);

      if (dailyUsage == null) {
        dailyUsage = DailyUsage(
          appId: blockedApp.id!,
          date: today,
          totalMinutes: additionalMinutes,
        );
      } else {
        dailyUsage = dailyUsage.copyWith(
          totalMinutes: dailyUsage.totalMinutes + additionalMinutes,
        );
      }

      await _db.addOrUpdateDailyUsage(dailyUsage);

      // Sync to SharedPreferences for native service
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('usage_$packageName', dailyUsage.totalMinutes);
    } catch (e) {
      print('Error updating app usage: $e');
    }
  }

  /// Unlock app for specified duration after exercise completion
  Future<void> unlockApp(int appId, int durationMinutes) async {
    try {
      final unlockedUntil = DateTime.now().add(Duration(minutes: durationMinutes));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _unlockTimeKey + appId.toString(),
        unlockedUntil.toIso8601String(),
      );

      // Get packageName to sync to SharedPreferences for native service
      final apps = await _db.getAllBlockedApps();
      final app = apps.firstWhere((a) => a.id == appId);
      await prefs.setInt(
        'unlock_until_ms_${app.packageName}',
        unlockedUntil.millisecondsSinceEpoch,
      );

      // Update unlock count
      final today = _getFormattedDate(DateTime.now());
      var dailyUsage = await _db.getDailyUsage(appId, today);
      if (dailyUsage != null) {
        dailyUsage = dailyUsage.copyWith(
          unlockCount: dailyUsage.unlockCount + 1,
        );
        await _db.addOrUpdateDailyUsage(dailyUsage);
      }
    } catch (e) {
      print('Error unlocking app: $e');
    }
  }

  /// Check if app is temporarily unlocked
  Future<bool> _isTemporarilyUnlocked(int appId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final unlockTimeStr = prefs.getString(_unlockTimeKey + appId.toString());

      if (unlockTimeStr == null) return false;

      final unlockedUntil = DateTime.parse(unlockTimeStr);
      if (DateTime.now().isBefore(unlockedUntil)) {
        return true; // Still unlocked
      } else {
        // Unlock expired, clear it
        await prefs.remove(_unlockTimeKey + appId.toString());
        return false;
      }
    } catch (e) {
      print('Error checking unlock status: $e');
      return false;
    }
  }

  /// Get remaining unlock time for app (in seconds)
  Future<int> getRemainingUnlockTime(int appId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final unlockTimeStr = prefs.getString(_unlockTimeKey + appId.toString());

      if (unlockTimeStr == null) return 0;

      final unlockedUntil = DateTime.parse(unlockTimeStr);
      final remaining = unlockedUntil.difference(DateTime.now()).inSeconds;

      if (remaining > 0) return remaining;
      return 0;
    } catch (e) {
      print('Error getting remaining unlock time: $e');
      return 0;
    }
  }

  /// Perform daily reset at midnight
  Future<void> performDailyReset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _getFormattedDate(DateTime.now());
      final lastReset = prefs.getString(_lastResetDateKey);

      if (lastReset != today) {
        // Clear all unlock times and usages
        final apps = await _db.getAllBlockedApps();
        for (var app in apps) {
          await prefs.remove(_unlockTimeKey + app.id.toString());
          await prefs.remove('unlock_until_ms_${app.packageName}');
          await prefs.remove('usage_${app.packageName}');
        }

        // Update last reset date
        await prefs.setString(_lastResetDateKey, today);
        print('Daily reset performed at $today');
      }
    } catch (e) {
      print('Error performing daily reset: $e');
    }
  }

  /// Synchronize SQLite data with SharedPreferences for native background accessibility service
  Future<void> syncBlockedAppsToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final apps = await _db.getAllBlockedApps();
      final today = _getFormattedDate(DateTime.now());

      for (var app in apps) {
        final pkg = app.packageName;
        // Block state & limit
        await prefs.setBool('blocked_package_$pkg', app.isActive);
        await prefs.setInt('limit_$pkg', app.dailyLimitMinutes);

        // Daily usage
        final usage = await _db.getDailyUsage(app.id!, today);
        await prefs.setInt('usage_$pkg', usage?.totalMinutes ?? 0);

        // Unlock status
        final unlockTimeStr = prefs.getString(_unlockTimeKey + app.id.toString());
        if (unlockTimeStr != null) {
          final unlockedUntil = DateTime.parse(unlockTimeStr);
          if (DateTime.now().isBefore(unlockedUntil)) {
            await prefs.setInt('unlock_until_ms_$pkg', unlockedUntil.millisecondsSinceEpoch);
          } else {
            await prefs.remove('unlock_until_ms_$pkg');
          }
        } else {
          await prefs.remove('unlock_until_ms_$pkg');
        }
      }
      print('Synchronized ${apps.length} apps with SharedPreferences');
    } catch (e) {
      print('Error syncing blocked apps: $e');
    }
  }

  /// Get today's total usage for an app
  Future<int> getTodayUsage(String packageName) async {
    try {
      final blockedApp = await _db.getBlockedAppByPackage(packageName);
      if (blockedApp == null) return 0;

      final today = _getFormattedDate(DateTime.now());
      final dailyUsage = await _db.getDailyUsage(blockedApp.id!, today);

      return dailyUsage?.totalMinutes ?? 0;
    } catch (e) {
      print('Error getting today usage: $e');
      return 0;
    }
  }

  /// Get daily limit for an app
  Future<int> getDailyLimit(String packageName) async {
    try {
      final blockedApp = await _db.getBlockedAppByPackage(packageName);
      return blockedApp?.dailyLimitMinutes ?? 0;
    } catch (e) {
      print('Error getting daily limit: $e');
      return 0;
    }
  }

  /// Get remaining time until app is locked (in minutes)
  Future<int> getRemainingTimeBeforeLock(String packageName) async {
    try {
      final blockedApp = await _db.getBlockedAppByPackage(packageName);
      if (blockedApp == null) return -1;

      final today = _getFormattedDate(DateTime.now());
      final dailyUsage = await _db.getDailyUsage(blockedApp.id!, today);
      final usedMinutes = dailyUsage?.totalMinutes ?? 0;

      final remaining = blockedApp.dailyLimitMinutes - usedMinutes;
      return remaining > 0 ? remaining : 0;
    } catch (e) {
      print('Error getting remaining time: $e');
      return -1;
    }
  }

  /// Helper function to format date as YYYY-MM-DD
  String _getFormattedDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

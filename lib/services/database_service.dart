import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/blocked_app_model.dart';
import '../models/daily_usage_model.dart';
import '../models/exercise_model.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._();
  factory DatabaseService() => _instance;
  DatabaseService._();

  Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'task_and_unlock.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE blocked_apps (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            packageName TEXT UNIQUE NOT NULL,
            appName TEXT NOT NULL,
            dailyLimitMinutes INTEGER DEFAULT 30,
            isActive INTEGER DEFAULT 1,
            createdAt TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE daily_usage (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            appId INTEGER NOT NULL,
            date TEXT NOT NULL,
            totalMinutes INTEGER DEFAULT 0,
            unlockCount INTEGER DEFAULT 0,
            UNIQUE(appId, date)
          )
        ''');

        await db.execute('''
          CREATE TABLE exercises (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            repsRequired INTEGER NOT NULL,
            repsCompleted INTEGER NOT NULL,
            completedAt TEXT NOT NULL,
            unlockedUntil TEXT NOT NULL,
            unlockDurationMinutes INTEGER DEFAULT 5
          )
        ''');
      },
    );
  }

  Future<List<BlockedApp>> getAllBlockedApps() async {
    final db = await database;
    final maps = await db.query('blocked_apps', orderBy: 'createdAt DESC');
    return maps.map(BlockedApp.fromMap).toList();
  }

  Future<List<BlockedApp>> getActiveBlockedApps() async {
    final db = await database;
    final maps = await db.query(
      'blocked_apps',
      where: 'isActive = ?',
      whereArgs: [1],
      orderBy: 'createdAt DESC',
    );
    return maps.map(BlockedApp.fromMap).toList();
  }

  Future<BlockedApp?> getBlockedAppByPackage(String packageName) async {
    final db = await database;
    final maps = await db.query(
      'blocked_apps',
      where: 'packageName = ?',
      whereArgs: [packageName],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return BlockedApp.fromMap(maps.first);
  }

  Future<int> addBlockedApp(BlockedApp app) async {
    final db = await database;
    return db.insert('blocked_apps', app.toMap());
  }

  Future<void> updateBlockedApp(BlockedApp app) async {
    final db = await database;
    await db.update(
      'blocked_apps',
      app.toMap(),
      where: 'id = ?',
      whereArgs: [app.id],
    );
  }

  Future<void> deleteBlockedApp(int appId) async {
    final db = await database;
    await db.delete('blocked_apps', where: 'id = ?', whereArgs: [appId]);
    await db.delete('daily_usage', where: 'appId = ?', whereArgs: [appId]);
  }

  Future<DailyUsage?> getDailyUsage(int appId, String date) async {
    final db = await database;
    final maps = await db.query(
      'daily_usage',
      where: 'appId = ? AND date = ?',
      whereArgs: [appId, date],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return DailyUsage.fromMap(maps.first);
  }

  Future<void> addOrUpdateDailyUsage(DailyUsage usage) async {
    final db = await database;
    if (usage.id != null) {
      await db.update(
        'daily_usage',
        usage.toMap(),
        where: 'id = ?',
        whereArgs: [usage.id],
      );
      return;
    }

    final existing = await getDailyUsage(usage.appId, usage.date);
    if (existing != null) {
      await db.update(
        'daily_usage',
        usage.copyWith(id: existing.id).toMap(),
        where: 'id = ?',
        whereArgs: [existing.id],
      );
      return;
    }

    await db.insert('daily_usage', usage.toMap());
  }

  Future<int> addExercise(Exercise exercise) async {
    final db = await database;
    return db.insert('exercises', exercise.toMap());
  }

  Future<List<Exercise>> getExerciseHistory(int days) async {
    final db = await database;
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final maps = await db.query(
      'exercises',
      where: 'completedAt >= ?',
      whereArgs: [cutoff.toIso8601String()],
      orderBy: 'completedAt DESC',
    );
    return maps.map(Exercise.fromMap).toList();
  }

  Future<List<Exercise>> getExercisesByDate(String date) async {
    final db = await database;
    final maps = await db.query(
      'exercises',
      where: 'completedAt LIKE ?',
      whereArgs: ['$date%'],
      orderBy: 'completedAt DESC',
    );
    return maps.map(Exercise.fromMap).toList();
  }

  Future<void> deleteOldData(int daysToKeep) async {
    final db = await database;
    final cutoff = DateTime.now().subtract(Duration(days: daysToKeep));
    await db.delete(
      'exercises',
      where: 'completedAt < ?',
      whereArgs: [cutoff.toIso8601String()],
    );
    await db.delete(
      'daily_usage',
      where: 'date < ?',
      whereArgs: [cutoff.toIso8601String().substring(0, 10)],
    );
  }
}

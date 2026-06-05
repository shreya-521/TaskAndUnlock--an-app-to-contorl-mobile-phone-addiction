import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/exercise_model.dart';

class ExerciseProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  List<Exercise> _exercises = [];
  List<Exercise> _todayExercises = [];
  bool _isLoading = false;

  List<Exercise> get exercises => _exercises;
  List<Exercise> get todayExercises => _todayExercises;
  bool get isLoading => _isLoading;

  ExerciseProvider() {
    _loadExercises();
  }

  // ===== LOAD OPERATIONS =====

  Future<void> _loadExercises() async {
    _isLoading = true;
    notifyListeners();

    try {
      _exercises = await _db.getExerciseHistory(30);
      await _loadTodayExercises();
    } catch (e) {
      print('Error loading exercises: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadTodayExercises() async {
    try {
      final today =
          '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
      _todayExercises = await _db.getExercisesByDate(today);
      notifyListeners();
    } catch (e) {
      print('Error loading today exercises: $e');
    }
  }

  Future<void> refreshExercises() async {
    await _loadExercises();
  }

  // ===== ADD EXERCISE =====

  Future<void> addExercise(Exercise exercise) async {
    try {
      final id = await _db.addExercise(exercise);
      final newExercise = exercise.copyWith(id: id);
      _exercises.insert(0, newExercise);
      _todayExercises.insert(0, newExercise);
      notifyListeners();
    } catch (e) {
      print('Error adding exercise: $e');
    }
  }

  // ===== STATISTICS =====

  int getTodayExerciseCount() => _todayExercises.length;

  int getTotalRepsToday(ExerciseType type) {
    return _todayExercises
        .where((e) => e.type == type && e.isCompleted)
        .fold(0, (sum, e) => sum + e.repsCompleted);
  }

  int getCompletedExercisesToday() =>
      _todayExercises.where((e) => e.isCompleted).length;

  Map<ExerciseType, int> getExerciseCountByType() {
    Map<ExerciseType, int> counts = {};
    for (var exercise in _todayExercises) {
      if (!counts.containsKey(exercise.type)) {
        counts[exercise.type] = 0;
      }
      counts[exercise.type] = counts[exercise.type]! + 1;
    }
    return counts;
  }

  // ===== HISTORY =====

  Future<List<Exercise>> getExerciseHistory(int days) async {
    try {
      return await _db.getExerciseHistory(days);
    } catch (e) {
      print('Error getting exercise history: $e');
      return [];
    }
  }

  Future<int> getTotalExercisesInWeek() async {
    try {
      final week = await _db.getExerciseHistory(7);
      return week.length;
    } catch (e) {
      print('Error getting weekly total: $e');
      return 0;
    }
  }

  // ===== CLEANUP =====

  Future<void> deleteOldExercises(int daysToKeep) async {
    try {
      await _db.deleteOldData(daysToKeep);
      await _loadExercises();
    } catch (e) {
      print('Error deleting old exercises: $e');
    }
  }
}

enum ExerciseType { pushups, jumps }

class Exercise {
  static const int pushupsReps = 5;
  static const int jumpsReps = 5;
  static const int defaultUnlockDurationMinutes = 5;

  final int? id;
  final ExerciseType type;
  final int repsRequired;
  final int repsCompleted;
  final DateTime completedAt;
  final DateTime unlockedUntil;
  final int unlockDurationMinutes;

  const Exercise({
    this.id,
    required this.type,
    required this.repsRequired,
    required this.repsCompleted,
    required this.completedAt,
    required this.unlockedUntil,
    this.unlockDurationMinutes = defaultUnlockDurationMinutes,
  });

  bool get isCompleted => repsCompleted >= repsRequired;

  Exercise copyWith({
    int? id,
    ExerciseType? type,
    int? repsRequired,
    int? repsCompleted,
    DateTime? completedAt,
    DateTime? unlockedUntil,
    int? unlockDurationMinutes,
  }) {
    return Exercise(
      id: id ?? this.id,
      type: type ?? this.type,
      repsRequired: repsRequired ?? this.repsRequired,
      repsCompleted: repsCompleted ?? this.repsCompleted,
      completedAt: completedAt ?? this.completedAt,
      unlockedUntil: unlockedUntil ?? this.unlockedUntil,
      unlockDurationMinutes:
          unlockDurationMinutes ?? this.unlockDurationMinutes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'repsRequired': repsRequired,
      'repsCompleted': repsCompleted,
      'completedAt': completedAt.toIso8601String(),
      'unlockedUntil': unlockedUntil.toIso8601String(),
      'unlockDurationMinutes': unlockDurationMinutes,
    };
  }

  factory Exercise.fromMap(Map<String, dynamic> map) {
    return Exercise(
      id: map['id'] as int?,
      type: ExerciseType.values.firstWhere(
        (value) => value.name == map['type'],
        orElse: () => ExerciseType.pushups,
      ),
      repsRequired: map['repsRequired'] as int,
      repsCompleted: map['repsCompleted'] as int,
      completedAt: DateTime.parse(map['completedAt'] as String),
      unlockedUntil: DateTime.parse(map['unlockedUntil'] as String),
      unlockDurationMinutes:
          map['unlockDurationMinutes'] as int? ?? defaultUnlockDurationMinutes,
    );
  }
}

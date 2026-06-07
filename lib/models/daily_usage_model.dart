class DailyUsage {
  final int? id;
  final int appId;
  final String date;
  final int totalMinutes;
  final int unlockCount;

  const DailyUsage({
    this.id,
    required this.appId,
    required this.date,
    this.totalMinutes = 0,
    this.unlockCount = 0,
  });

  DailyUsage copyWith({
    int? id,
    int? appId,
    String? date,
    int? totalMinutes,
    int? unlockCount,
  }) {
    return DailyUsage(
      id: id ?? this.id,
      appId: appId ?? this.appId,
      date: date ?? this.date,
      totalMinutes: totalMinutes ?? this.totalMinutes,
      unlockCount: unlockCount ?? this.unlockCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'appId': appId,
      'date': date,
      'totalMinutes': totalMinutes,
      'unlockCount': unlockCount,
    };
  }

  factory DailyUsage.fromMap(Map<String, dynamic> map) {
    return DailyUsage(
      id: map['id'] as int?,
      appId: map['appId'] as int,
      date: map['date'] as String,
      totalMinutes: map['totalMinutes'] as int? ?? 0,
      unlockCount: map['unlockCount'] as int? ?? 0,
    );
  }
}

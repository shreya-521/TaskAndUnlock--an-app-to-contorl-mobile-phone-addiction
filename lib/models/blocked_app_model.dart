class BlockedApp {
  static const int defaultDailyLimitMinutes = 30;

  final int? id;
  final String packageName;
  final String appName;
  final int dailyLimitMinutes;
  final bool isActive;
  final DateTime createdAt;

  const BlockedApp({
    this.id,
    required this.packageName,
    required this.appName,
    this.dailyLimitMinutes = defaultDailyLimitMinutes,
    this.isActive = true,
    required this.createdAt,
  });

  BlockedApp copyWith({
    int? id,
    String? packageName,
    String? appName,
    int? dailyLimitMinutes,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return BlockedApp(
      id: id ?? this.id,
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
      dailyLimitMinutes: dailyLimitMinutes ?? this.dailyLimitMinutes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'packageName': packageName,
      'appName': appName,
      'dailyLimitMinutes': dailyLimitMinutes,
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory BlockedApp.fromMap(Map<String, dynamic> map) {
    return BlockedApp(
      id: map['id'] as int?,
      packageName: map['packageName'] as String,
      appName: map['appName'] as String,
      dailyLimitMinutes: map['dailyLimitMinutes'] as int? ?? defaultDailyLimitMinutes,
      isActive: (map['isActive'] as int? ?? 1) == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}

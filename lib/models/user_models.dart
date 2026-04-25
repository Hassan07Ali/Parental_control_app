/// Database model classes for the auth & multi-user system.
library;

class ParentUser {
  final int? id;
  final String name;
  final String email;
  final String passwordHash;
  final String? createdAt;

  ParentUser({
    this.id,
    required this.name,
    required this.email,
    required this.passwordHash,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'password': passwordHash,
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
    };
  }

  factory ParentUser.fromMap(Map<String, dynamic> map) {
    return ParentUser(
      id: map['id'] as int?,
      name: map['name'] as String,
      email: map['email'] as String,
      passwordHash: map['password'] as String,
      createdAt: map['created_at'] as String?,
    );
  }
}

class ChildUser {
  final int? id;
  final int parentId;
  String name;
  String avatarEmoji;
  int age;
  int dailyLimitMins;
  int rewardPoints;
  String pin;

  ChildUser({
    this.id,
    required this.parentId,
    required this.name,
    this.avatarEmoji = '👧',
    this.age = 8,
    this.dailyLimitMins = 120,
    this.rewardPoints = 0,
    this.pin = '1234',
  });

  Map<String, dynamic> toMap() {
    return {
      'parent_id': parentId,
      'name': name,
      'avatar_emoji': avatarEmoji,
      'age': age,
      'daily_limit_mins': dailyLimitMins,
      'reward_points': rewardPoints,
      'pin': pin,
    };
  }

  factory ChildUser.fromMap(Map<String, dynamic> map) {
    return ChildUser(
      id: map['id'] as int?,
      parentId: map['parent_id'] as int,
      name: map['name'] as String,
      avatarEmoji: (map['avatar_emoji'] as String?) ?? '👧',
      age: (map['age'] as int?) ?? 8,
      dailyLimitMins: (map['daily_limit_mins'] as int?) ?? 120,
      rewardPoints: (map['reward_points'] as int?) ?? 0,
      pin: (map['pin'] as String?) ?? '1234',
    );
  }
}

class AppLimitEntry {
  final int? id;
  final int childId;
  final String packageName;
  final String appName;
  int limitMinutes;
  bool isActive;

  AppLimitEntry({
    this.id,
    required this.childId,
    required this.packageName,
    this.appName = '',
    this.limitMinutes = 60,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'child_id': childId,
      'package_name': packageName,
      'app_name': appName,
      'limit_minutes': limitMinutes,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory AppLimitEntry.fromMap(Map<String, dynamic> map) {
    return AppLimitEntry(
      id: map['id'] as int?,
      childId: map['child_id'] as int,
      packageName: map['package_name'] as String,
      appName: (map['app_name'] as String?) ?? '',
      limitMinutes: (map['limit_minutes'] as int?) ?? 60,
      isActive: (map['is_active'] as int?) == 1,
    );
  }
}

/// user_models.dart — updated for Firebase.
/// ONLY change from SQLite version: id fields are String? (Firebase UID)
/// instead of int? (SQLite autoincrement). Nothing else changed.

class ParentUser {
  final String? id;       // Firebase UID e.g. "xK9mN2pQr..."
  final String name;
  final String email;
  final String passwordHash; // always '' — Firebase manages passwords
  final String? createdAt;

  ParentUser({
    this.id,
    required this.name,
    required this.email,
    this.passwordHash = '',
    this.createdAt,
  });
}

class ChildUser {
  final String? id;        // Firestore doc ID e.g. "uid_child"
  final dynamic parentId;  // Firebase UID string
  String name;
  String avatarEmoji;
  int age;
  int dailyLimitMins;
  int rewardPoints;
  String pin;

  // Pet fields
  String petName;
  String petSpecies;
  int lifetimePoints;
  int petHappiness;
  int streakDays;
  String lastComplianceDate;

  ChildUser({
    this.id,
    required this.parentId,
    required this.name,
    this.avatarEmoji           = '👧',
    this.age                   = 8,
    this.dailyLimitMins        = 120,
    this.rewardPoints          = 0,
    this.pin                   = '1234',
    this.petName               = 'Buddy',
    this.petSpecies            = 'cat',
    this.lifetimePoints        = 0,
    this.petHappiness          = 50,
    this.streakDays            = 0,
    this.lastComplianceDate    = '',
  });

  int get petLevel {
    if (lifetimePoints >= 2000) return 6;
    if (lifetimePoints >= 1200) return 5;
    if (lifetimePoints >= 700)  return 4;
    if (lifetimePoints >= 350)  return 3;
    if (lifetimePoints >= 150)  return 2;
    if (lifetimePoints >= 50)   return 1;
    return 0;
  }

  String get petLevelName {
    const names = ['Egg','Hatchling','Baby','Child','Teen','Adult','Legend'];
    return names[petLevel];
  }

  int get pointsForNextLevel {
    const thresholds = [50, 150, 350, 700, 1200, 2000];
    if (petLevel >= 6) return 0;
    return thresholds[petLevel] - lifetimePoints;
  }

  Map<String, dynamic> toMap() => {
    'parentId':            parentId,
    'name':                name,
    'avatarEmoji':         avatarEmoji,
    'age':                 age,
    'dailyLimitMins':      dailyLimitMins,
    'rewardPoints':        rewardPoints,
    'pin':                 pin,
    'petName':             petName,
    'petSpecies':          petSpecies,
    'lifetimePoints':      lifetimePoints,
    'petHappiness':        petHappiness,
    'streakDays':          streakDays,
    'lastComplianceDate':  lastComplianceDate,
  };

  factory ChildUser.fromMap(Map<String, dynamic> m, String id) => ChildUser(
    id:                   id,
    parentId:             m['parentId'],
    name:                 m['name'] ?? '',
    avatarEmoji:          m['avatarEmoji'] ?? '👧',
    age:                  m['age'] ?? 8,
    dailyLimitMins:       m['dailyLimitMins'] ?? 120,
    rewardPoints:         m['rewardPoints'] ?? 0,
    pin:                  m['pin'] ?? '1234',
    petName:              m['petName'] ?? 'Buddy',
    petSpecies:           m['petSpecies'] ?? 'cat',
    lifetimePoints:       m['lifetimePoints'] ?? 0,
    petHappiness:         m['petHappiness'] ?? 50,
    streakDays:           m['streakDays'] ?? 0,
    lastComplianceDate:   m['lastComplianceDate'] ?? '',
  );
}

class AppLimitEntry {
  final String? id;
  final dynamic childId;  // String child doc ID
  final String packageName;
  final String appName;
  int limitMinutes;
  bool isActive;

  AppLimitEntry({
    this.id,
    required this.childId,
    required this.packageName,
    this.appName      = '',
    this.limitMinutes = 60,
    this.isActive     = true,
  });

  Map<String, dynamic> toMap() => {
    'childId':      childId,
    'packageName':  packageName,
    'appName':      appName,
    'limitMinutes': limitMinutes,
    'isActive':     isActive,
  };
}
import 'dart:typed_data';

// ─── App Category System ──────────────────────────────────────────────────────
enum AppCategory { education, socialMedia, gaming, productivity, others }

extension AppCategoryExtension on AppCategory {
  String get displayName {
    switch (this) {
      case AppCategory.education: return 'Education';
      case AppCategory.socialMedia: return 'Social Media';
      case AppCategory.gaming: return 'Gaming';
      case AppCategory.productivity: return 'Productivity';
      case AppCategory.others: return 'Others';
    }
  }

  String get emoji {
    switch (this) {
      case AppCategory.education: return '📚';
      case AppCategory.socialMedia: return '💬';
      case AppCategory.gaming: return '🎮';
      case AppCategory.productivity: return '💼';
      case AppCategory.others: return '📱';
    }
  }
}

// ─── Child Profile ────────────────────────────────────────────────────────────
class ChildProfile {
  String name;
  String avatarEmoji;
  int age;
  int dailyLimitMinutes;
  int _usedMinutes;
  String pin;
  int rewardPoints;

  ChildProfile({
    required this.name,
    required this.avatarEmoji,
    required this.age,
    required this.dailyLimitMinutes,
    int usedMinutes = 0,
    required this.pin,
    this.rewardPoints = 0,
  }) : _usedMinutes = usedMinutes.clamp(0, 1440); // max 24 hours

  // Clamped getter/setter to prevent negative or overflow values
  int get usedMinutes => _usedMinutes;
  set usedMinutes(int value) {
    _usedMinutes = value.clamp(0, 1440);
  }

  double get usagePercentage => dailyLimitMinutes > 0
      ? (usedMinutes / dailyLimitMinutes).clamp(0.0, 1.0)
      : 0.0;

  int get remainingMinutes =>
      (dailyLimitMinutes - usedMinutes).clamp(0, dailyLimitMinutes);

  /// Productivity score based on categorized app usage data.
  /// Computed from real data passed in; returns 0-100.
  static double computeProductivityScore(
      int productiveMinutes, int totalMinutes) {
    if (totalMinutes <= 0) return 0.0;
    return ((productiveMinutes / totalMinutes) * 100).clamp(0.0, 100.0);
  }

  void resetDaily() {
    _usedMinutes = 0;
  }
}

// ─── App Usage ────────────────────────────────────────────────────────────────
class AppUsage {
  final String appName;
  final String packageName;
  AppCategory category;
  int minutesUsed;
  final String iconEmoji;
  final int limitMinutes;
  final Uint8List? iconBytes;

  AppUsage({
    required this.appName,
    required this.packageName,
    this.category = AppCategory.others,
    required this.minutesUsed,
    required this.iconEmoji,
    required this.limitMinutes,
    this.iconBytes,
  });
}

// ─── Daily Usage Entry (for weekly chart) ─────────────────────────────────────
class DailyUsageEntry {
  final DateTime date;
  final int totalMinutes;
  final Map<AppCategory, int> categoryMinutes;

  DailyUsageEntry({
    required this.date,
    required this.totalMinutes,
    this.categoryMinutes = const {},
  });

  int get productiveMinutes =>
      (categoryMinutes[AppCategory.education] ?? 0) +
      (categoryMinutes[AppCategory.productivity] ?? 0);
}

// ─── Reward Option ────────────────────────────────────────────────────────────
class RewardOption {
  final String title;
  final String emoji;
  final String description;
  final int cost;
  final int bonusMinutes;

  const RewardOption({
    required this.title,
    required this.emoji,
    required this.description,
    required this.cost,
    required this.bonusMinutes,
  });
}

// ─── Category Classifier ──────────────────────────────────────────────────────
class CategoryClassifier {
  // Known package → category mappings
  static final Map<String, AppCategory> _knownPackages = {
    // Social Media
    'com.instagram.android': AppCategory.socialMedia,
    'com.facebook.katana': AppCategory.socialMedia,
    'com.facebook.orca': AppCategory.socialMedia,
    'com.twitter.android': AppCategory.socialMedia,
    'com.snapchat.android': AppCategory.socialMedia,
    'com.whatsapp': AppCategory.socialMedia,
    'com.zhiliaoapp.musically': AppCategory.socialMedia, // TikTok
    'com.tiktok': AppCategory.socialMedia,
    'org.telegram.messenger': AppCategory.socialMedia,
    'com.discord': AppCategory.socialMedia,
    'com.pinterest': AppCategory.socialMedia,
    'com.reddit.frontpage': AppCategory.socialMedia,
    'com.linkedin.android': AppCategory.socialMedia,

    // Gaming
    'com.supercell.clashofclans': AppCategory.gaming,
    'com.supercell.clashroyale': AppCategory.gaming,
    'com.kiloo.subwaysurf': AppCategory.gaming,
    'com.mojang.minecraftpe': AppCategory.gaming,
    'com.activision.callofduty.shooter': AppCategory.gaming,
    'com.tencent.ig': AppCategory.gaming, // PUBG
    'com.garena.game.codm': AppCategory.gaming,
    'com.roblox.client': AppCategory.gaming,
    'com.epicgames.fortnite': AppCategory.gaming,

    // Education
    'com.duolingo': AppCategory.education,
    'com.google.android.apps.classroom': AppCategory.education,
    'com.khan.academy': AppCategory.education,
    'com.quizlet.quizletandroid': AppCategory.education,
    'com.photomath.photomath': AppCategory.education,
    'com.microsoft.teams': AppCategory.education,
    'us.zoom.videomeeting': AppCategory.education,
    'com.byju': AppCategory.education,

    // Productivity
    'com.google.android.apps.docs': AppCategory.productivity,
    'com.google.android.apps.docs.editors.docs': AppCategory.productivity,
    'com.google.android.apps.docs.editors.sheets': AppCategory.productivity,
    'com.google.android.apps.docs.editors.slides': AppCategory.productivity,
    'com.google.android.calendar': AppCategory.productivity,
    'com.google.android.keep': AppCategory.productivity,
    'com.microsoft.office.word': AppCategory.productivity,
    'com.microsoft.office.excel': AppCategory.productivity,
    'com.microsoft.office.powerpoint': AppCategory.productivity,
    'com.microsoft.office.onenote': AppCategory.productivity,
    'com.todoist': AppCategory.productivity,
    'com.notion.id': AppCategory.productivity,
  };

  // Keyword-based fallback classification
  static final Map<String, AppCategory> _keywords = {
    'game': AppCategory.gaming,
    'play': AppCategory.gaming,
    'craft': AppCategory.gaming,
    'puzzle': AppCategory.gaming,
    'racing': AppCategory.gaming,
    'shooter': AppCategory.gaming,
    'chat': AppCategory.socialMedia,
    'social': AppCategory.socialMedia,
    'messenger': AppCategory.socialMedia,
    'learn': AppCategory.education,
    'edu': AppCategory.education,
    'school': AppCategory.education,
    'academy': AppCategory.education,
    'study': AppCategory.education,
    'office': AppCategory.productivity,
    'note': AppCategory.productivity,
    'calendar': AppCategory.productivity,
    'task': AppCategory.productivity,
  };

  static AppCategory classify(String packageName) {
    // 1. Check known packages first
    if (_knownPackages.containsKey(packageName)) {
      return _knownPackages[packageName]!;
    }
    // 2. Keyword-based fallback
    final lower = packageName.toLowerCase();
    for (final entry in _keywords.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }
    // 3. Default
    return AppCategory.others;
  }
}

// ─── Global State ─────────────────────────────────────────────────────────────
class SampleData {
  static ChildProfile parentProfile = ChildProfile(
    name: 'James Mathew',
    avatarEmoji: '👨',
    age: 35,
    dailyLimitMinutes: 180,
    usedMinutes: 0,
    pin: '1234',
  );

  static List<ChildProfile> children = [
    ChildProfile(
      name: 'Emma',
      avatarEmoji: '👧',
      age: 8,
      dailyLimitMinutes: 120,
      usedMinutes: 0,
      pin: '1234',
    ),
    ChildProfile(
      name: 'Liam',
      avatarEmoji: '👦',
      age: 12,
      dailyLimitMinutes: 90,
      usedMinutes: 0,
      pin: '1234',
    ),
  ];

  /// FIX 1.2: Safe accessor for the active child.
  /// Returns children[0] if available, or a safe default fallback.
  /// Prevents RangeError crashes throughout the app.
  static ChildProfile get activeChild {
    if (children.isNotEmpty) return children[0];
    return _fallbackChild;
  }

  /// Fallback child used when the children list is empty.
  static final ChildProfile _fallbackChild = ChildProfile(
    name: 'Child',
    avatarEmoji: '👧',
    age: 8,
    dailyLimitMinutes: 120,
    usedMinutes: 0,
    pin: '0000',
  );

  static List<AppUsage> recentApps = [];

  // Weekly history fetched from real Android UsageStats
  static List<DailyUsageEntry> weeklyHistory = [];

  // Available reward options
  static const List<RewardOption> rewardOptions = [
    RewardOption(
      title: '+15 Minutes',
      emoji: '🕐',
      description: 'Add 15 minutes of extra screen time today',
      cost: 50,
      bonusMinutes: 15,
    ),
    RewardOption(
      title: '+30 Minutes',
      emoji: '⏰',
      description: 'Add 30 minutes of extra screen time today',
      cost: 90,
      bonusMinutes: 30,
    ),
    RewardOption(
      title: '+1 Hour',
      emoji: '🎉',
      description: 'Add a full extra hour of screen time today',
      cost: 160,
      bonusMinutes: 60,
    ),
  ];
}
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user_models.dart';

/// Central SQLite database helper — handles all CRUD operations for auth & data.
class DbHelper {
  static final DbHelper _instance = DbHelper._internal();
  factory DbHelper() => _instance;
  DbHelper._internal();

  static Database? _db;
  static bool _isInitializing = false;

  Future<Database> get database async {
    if (_db != null) return _db!;
    
    // Wait if initialization is already in progress
    while (_isInitializing) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (_db != null) return _db!;
    }
    
    _isInitializing = true;
    try {
      _db = await _initDatabase();
    } finally {
      _isInitializing = false;
    }
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'safescreen.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createTables,
      onOpen: (db) async { await db.execute('PRAGMA foreign_keys = ON'); },
    );
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE parents (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        name        TEXT    NOT NULL,
        email       TEXT    UNIQUE NOT NULL,
        password    TEXT    NOT NULL,
        created_at  TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE children (
        id                INTEGER PRIMARY KEY AUTOINCREMENT,
        parent_id         INTEGER NOT NULL,
        name              TEXT    NOT NULL,
        avatar_emoji      TEXT    DEFAULT '👧',
        age               INTEGER DEFAULT 8,
        daily_limit_mins  INTEGER DEFAULT 120,
        reward_points     INTEGER DEFAULT 0,
        pin               TEXT    DEFAULT '1234',
        FOREIGN KEY (parent_id) REFERENCES parents(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE app_limits (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        child_id      INTEGER NOT NULL,
        package_name  TEXT    NOT NULL,
        app_name      TEXT    DEFAULT '',
        limit_minutes INTEGER DEFAULT 60,
        is_active     INTEGER DEFAULT 1,
        FOREIGN KEY (child_id) REFERENCES children(id) ON DELETE CASCADE
      )
    ''');
  }

  // ─── Password Hashing ─────────────────────────────────────────────────────
  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  // ─── Parent CRUD ──────────────────────────────────────────────────────────

  /// Register a new parent. Returns the new parent's ID.
  Future<int> registerParent(String name, String email, String password) async {
    final db = await database;
    return await db.insert('parents', {
      'name': name,
      'email': email.toLowerCase().trim(),
      'password': hashPassword(password),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Login: returns the ParentUser if credentials match, null otherwise.
  Future<ParentUser?> loginParent(String email, String password) async {
    final db = await database;
    final results = await db.query(
      'parents',
      where: 'email = ? AND password = ?',
      whereArgs: [email.toLowerCase().trim(), hashPassword(password)],
    );
    if (results.isEmpty) return null;
    return ParentUser.fromMap(results.first);
  }

  /// Check if email is already registered.
  Future<bool> emailExists(String email) async {
    final db = await database;
    final results = await db.query(
      'parents',
      where: 'email = ?',
      whereArgs: [email.toLowerCase().trim()],
    );
    return results.isNotEmpty;
  }

  /// Get parent by ID.
  Future<ParentUser?> getParentById(int id) async {
    final db = await database;
    final results = await db.query('parents', where: 'id = ?', whereArgs: [id]);
    if (results.isEmpty) return null;
    return ParentUser.fromMap(results.first);
  }

  // ─── Child CRUD ───────────────────────────────────────────────────────────

  /// Insert a child for a parent. Returns the child's ID.
  Future<int> insertChild(ChildUser child) async {
    final db = await database;
    return await db.insert('children', child.toMap());
  }

  /// Get all children for a parent.
  Future<List<ChildUser>> getChildrenForParent(int parentId) async {
    final db = await database;
    final results = await db.query(
      'children',
      where: 'parent_id = ?',
      whereArgs: [parentId],
    );
    return results.map((m) => ChildUser.fromMap(m)).toList();
  }

  /// Get a single child by ID.
  Future<ChildUser?> getChildById(int childId) async {
    final db = await database;
    final results = await db.query('children', where: 'id = ?', whereArgs: [childId]);
    if (results.isEmpty) return null;
    return ChildUser.fromMap(results.first);
  }

  /// Update a child's reward points.
  Future<void> updateRewardPoints(int childId, int points) async {
    final db = await database;
    await db.update(
      'children',
      {'reward_points': points},
      where: 'id = ?',
      whereArgs: [childId],
    );
  }

  /// Update a child's daily limit.
  Future<void> updateDailyLimit(int childId, int limitMins) async {
    final db = await database;
    await db.update(
      'children',
      {'daily_limit_mins': limitMins},
      where: 'id = ?',
      whereArgs: [childId],
    );
  }

  // ─── App Limits CRUD ──────────────────────────────────────────────────────

  /// Save or update app limits for a child.
  /// Replaces all existing limits with the new ones.
  Future<void> saveAppLimits(int childId, List<AppLimitEntry> limits) async {
    final db = await database;
    await db.transaction((txn) async {
      // Clear existing limits for this child
      await txn.delete('app_limits', where: 'child_id = ?', whereArgs: [childId]);
      // Insert all new limits
      for (final limit in limits) {
        await txn.insert('app_limits', limit.toMap());
      }
    });
  }

  /// Get all active app limits for a child.
  Future<List<AppLimitEntry>> getAppLimits(int childId) async {
    final db = await database;
    final results = await db.query(
      'app_limits',
      where: 'child_id = ?',
      whereArgs: [childId],
    );
    return results.map((m) => AppLimitEntry.fromMap(m)).toList();
  }

  // ─── Parent Profile Updates ───────────────────────────────────────────────

  /// Update parent display name.
  Future<void> updateParentName(int parentId, String newName) async {
    final db = await database;
    await db.update('parents', {'name': newName.trim()},
        where: 'id = ?', whereArgs: [parentId]);
  }

  /// Update parent email — checks for duplicates first.
  /// Returns true on success, false if email already taken.
  Future<bool> updateParentEmail(int parentId, String newEmail) async {
    final db = await database;
    final norm = newEmail.toLowerCase().trim();
    final existing = await db.query('parents',
        where: 'email = ? AND id != ?', whereArgs: [norm, parentId]);
    if (existing.isNotEmpty) return false;
    await db.update('parents', {'email': norm},
        where: 'id = ?', whereArgs: [parentId]);
    return true;
  }

  /// Update parent password — verifies old password first.
  /// Returns true on success, false if old password is wrong.
  Future<bool> updateParentPassword(
      int parentId, String oldPassword, String newPassword) async {
    final db = await database;
    final check = await db.query('parents',
        where: 'id = ? AND password = ?',
        whereArgs: [parentId, hashPassword(oldPassword)]);
    if (check.isEmpty) return false;
    await db.update('parents', {'password': hashPassword(newPassword)},
        where: 'id = ?', whereArgs: [parentId]);
    return true;
  }

  // ─── Child Profile Updates ────────────────────────────────────────────────

  /// Update child name, avatar, and age together.
  Future<void> updateChildProfile(
      int childId, String name, String avatarEmoji, int age) async {
    final db = await database;
    await db.update(
      'children',
      {'name': name.trim(), 'avatar_emoji': avatarEmoji, 'age': age},
      where: 'id = ?',
      whereArgs: [childId],
    );
  }

  /// Update the child-facing PIN.
  /// FIX 2.1: Hash the PIN before storing (same SHA-256 as parent passwords).
  Future<void> updateChildPin(int childId, String newPin) async {
    final db = await database;
    await db.update('children', {'pin': hashPassword(newPin)},
        where: 'id = ?', whereArgs: [childId]);
  }

  /// Get a child's current PIN hash (for verification before changing).
  /// FIX 2.1: Returns the stored hash, not plain text.
  Future<String?> getChildPin(int childId) async {
    final db = await database;
    final results = await db.query('children',
        columns: ['pin'], where: 'id = ?', whereArgs: [childId]);
    if (results.isEmpty) return null;
    return results.first['pin'] as String?;
  }

  /// Get ALL children across all parents (used on the child selector screen).
  Future<List<ChildUser>> getAllChildren() async {
    final db = await database;
    final results = await db.query('children', orderBy: 'name ASC');
    return results.map((m) => ChildUser.fromMap(m)).toList();
  }

  /// Verify a child's PIN. Returns the ChildUser on success, null on failure.
  /// FIX 2.1: Hash the input PIN before comparing against the stored hash.
  Future<ChildUser?> loginChildByPin(int childId, String pin) async {
    final db = await database;
    final results = await db.query(
      'children',
      where: 'id = ? AND pin = ?',
      whereArgs: [childId, hashPassword(pin)],
    );
    if (results.isEmpty) return null;
    return ChildUser.fromMap(results.first);
  }

}
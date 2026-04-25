import 'package:shared_preferences/shared_preferences.dart';
import '../database/db_helper.dart';
import '../models/user_models.dart';

/// Tracks auth'd user session using shared_preferences.
/// Stores the logged-in role ('parent' | 'child') and the relevant ID
/// so the app can skip login on next launch and route to the correct shell.
class SessionService {
  static const _keyRole     = 'session_role';       // 'parent' | 'child'
  static const _keyParentId = 'session_parent_id';
  static const _keyChildId  = 'session_child_id';

  // ─── Role-aware session saves ────────────────────────────────────────────

  /// Save a parent login session.
  static Future<void> saveParentSession(int parentId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRole, 'parent');
    await prefs.setInt(_keyParentId, parentId);
    await prefs.remove(_keyChildId);
  }

  /// Save a child login session.
  static Future<void> saveChildSession(int childId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRole, 'child');
    await prefs.setInt(_keyChildId, childId);
    // Don't clear parentId — a child still belongs to a parent
  }

  // ─── Legacy helper (kept for backward compat) ───────────────────────────

  /// Save parent ID (backward compat — prefer saveParentSession).
  static Future<void> saveSession(int parentId) async {
    await saveParentSession(parentId);
  }

  /// Save the currently active child's ID (from within parent context).
  static Future<void> saveActiveChild(int childId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyChildId, childId);
  }

  // ─── Role queries ───────────────────────────────────────────────────────

  /// Get the stored role: 'parent', 'child', or null.
  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRole);
  }

  /// Check if any user is currently logged in (parent or child).
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_keyRole);
  }

  /// True if the current session is a parent session.
  static Future<bool> isParentLoggedIn() async {
    return (await getRole()) == 'parent';
  }

  /// True if the current session is a child session.
  static Future<bool> isChildLoggedIn() async {
    return (await getRole()) == 'child';
  }

  // ─── ID getters ─────────────────────────────────────────────────────────

  /// Get the logged-in parent's ID (null if not logged in).
  static Future<int?> getParentId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyParentId);
  }

  /// Get the currently active child's ID.
  static Future<int?> getActiveChildId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyChildId);
  }

  // ─── Object getters (from DB) ───────────────────────────────────────────

  /// Get the logged-in parent object from DB.
  static Future<ParentUser?> getCurrentParent() async {
    final parentId = await getParentId();
    if (parentId == null) return null;
    return await DbHelper().getParentById(parentId);
  }

  /// Get the active child object from DB.
  static Future<ChildUser?> getActiveChild() async {
    final childId = await getActiveChildId();
    if (childId == null) return null;
    return await DbHelper().getChildById(childId);
  }

  // ─── Clear ──────────────────────────────────────────────────────────────

  /// Clear the session (log out).
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRole);
    await prefs.remove(_keyParentId);
    await prefs.remove(_keyChildId);
  }
}

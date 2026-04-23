import 'package:shared_preferences/shared_preferences.dart';
import '../database/db_helper.dart';
import '../models/user_models.dart';

/// Tracks authd user session using shared_preferences.
/// Stores the logged-in parent's ID so the app can skip login on next launch.
class SessionService {
  static const _keyParentId = 'session_parent_id';
  static const _keyChildId = 'session_child_id';

  /// Save the logged-in parent's ID.
  static Future<void> saveSession(int parentId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyParentId, parentId);
  }

  /// Save the currently active child's ID.
  static Future<void> saveActiveChild(int childId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyChildId, childId);
  }

  /// Check if a user is currently logged in.
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_keyParentId);
  }

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

  /// Clear the session (log out).
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyParentId);
    await prefs.remove(_keyChildId);
  }
}

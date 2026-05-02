import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/db_helper.dart';
import '../models/user_models.dart';

/// SessionService — Firebase version with dual parent/child role support.
/// ALL original method signatures kept — no screen changes needed.
class SessionService {
  static const _keyChildId  = 'session_child_id';   // stores String child doc ID
  static const _keyRole     = 'session_role';        // 'parent' | 'child'

  // ── Login state ────────────────────────────────────────────────────────────

  /// True if Firebase Auth has a current user.
  static Future<bool> isLoggedIn() async =>
      FirebaseAuth.instance.currentUser != null;

  static String? getCurrentUid() =>
      FirebaseAuth.instance.currentUser?.uid;

  // ── Role ───────────────────────────────────────────────────────────────────

  static Future<void> saveRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRole, role);
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRole);
  }

  // ── Parent session ─────────────────────────────────────────────────────────

  /// Called after parent login/register. Firebase persists auth automatically.
  static Future<void> saveSession(dynamic parentId) async {
    await saveRole('parent');
  }

  /// Alias used by signup_screen.dart
  static Future<void> saveParentSession(dynamic parentId) async {
    await saveSession(parentId);
  }

  /// Returns int hashCode for screens expecting int (backwards compat).
  static Future<int?> getParentId() async {
    final uid = getCurrentUid();
    return uid?.hashCode;
  }

  /// Get the logged-in parent object from Firestore.
  static Future<ParentUser?> getCurrentParent() async {
    final uid = getCurrentUid();
    if (uid == null) return null;
    return DbHelper().getParentById(uid);
  }

  // ── Child session ──────────────────────────────────────────────────────────

  /// Save active child doc ID. Accepts String or int.
  static Future<void> saveActiveChild(dynamic childId) async {
    final prefs = await SharedPreferences.getInstance();
    final uid   = getCurrentUid();
    String id;
    if (childId is String && childId.contains('_child')) {
      id = childId;
    } else if (uid != null) {
      id = '${uid}_child';
    } else {
      id = childId.toString();
    }
    await prefs.setString(_keyChildId, id);
  }

  /// Called from child_pin_screen after successful PIN login.
  static Future<void> saveChildSession(dynamic childId) async {
    await saveActiveChild(childId);
    await saveRole('child');
  }

  static Future<void> saveChildMode() async => saveRole('child');

  /// Returns int hashCode for screens expecting int.
  static Future<int?> getActiveChildId() async {
    final docId = await _getActiveChildDocId();
    return docId?.hashCode;
  }

  static Future<String?> _getActiveChildDocId() async {
    final prefs  = await SharedPreferences.getInstance();
    final stored = prefs.getString(_keyChildId);
    if (stored != null) return stored;
    // Fallback: build from current Firebase UID
    final uid = getCurrentUid();
    return uid != null ? '${uid}_child' : null;
  }

  /// Get the active child object from Firestore.
  static Future<ChildUser?> getActiveChild() async {
    final docId = await _getActiveChildDocId();
    if (docId == null) return null;
    return DbHelper().getChildById(docId);
  }

  // ── Logout ─────────────────────────────────────────────────────────────────

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyChildId);
    await prefs.remove(_keyRole);
    await FirebaseAuth.instance.signOut();
  }
}
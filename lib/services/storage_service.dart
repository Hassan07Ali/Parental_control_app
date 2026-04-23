import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistence layer for the Nanny AI app.
class StorageService {
  static const _keyRewardPoints = 'reward_points';
  static const _keyDailyCreditDate = 'daily_credit_date';
  static const _keyChildName = 'child_name';
  static const _keyAppLimits = 'app_limits'; // Map of pkg -> minutes

  /// Save reward points
  static Future<void> saveRewardPoints(int points) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyRewardPoints, points.clamp(0, 999999));
  }

  /// Load reward points
  static Future<int> loadRewardPoints() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyRewardPoints) ?? 0;
  }

  /// Save child name
  static Future<void> saveChildName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyChildName, name);
  }

  /// Load child name
  static Future<String?> loadChildName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyChildName);
  }

  /// Save app limits
  static Future<void> saveAppLimits(Map<String, int> limits) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAppLimits, jsonEncode(limits));
  }

  /// Load app limits
  static Future<Map<String, int>> loadAppLimits() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keyAppLimits);
    if (data == null) return {};
    try {
      final decoded = jsonDecode(data) as Map<String, dynamic>;
      return decoded.map((key, value) => MapEntry(key, value as int));
    } catch (_) {
      return {};
    }
  }

  /// Get the date of the last awarded daily bonus points
  static Future<String?> getLastAwardDate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDailyCreditDate);
  }

  /// Set the date of the last awarded daily bonus points
  static Future<void> setLastAwardDate(String dateString) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDailyCreditDate, dateString);
  }
}

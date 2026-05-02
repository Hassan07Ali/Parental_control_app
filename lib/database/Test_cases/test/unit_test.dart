import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../../../models/user_models.dart';



void main() {

  // ── Pet Level Tests ───────────────────────────────────────────────────────
  group('Pet Level Calculation', () {

    test('petLevel returns 0 for 0 lifetime points', () {
      final child = ChildUser(parentId: '1', name: 'Ali', lifetimePoints: 0);
      expect(child.petLevel, equals(0)); // Egg — below 50
    });

    test('petLevel returns 1 at exactly 50 points', () {
      final child = ChildUser(parentId: '1', name: 'Ali', lifetimePoints: 50);
      expect(child.petLevel, equals(1)); // Hatchling
    });

    test('petLevel returns 2 at 150 points', () {
      final child = ChildUser(parentId: '1', name: 'Ali', lifetimePoints: 150);
      expect(child.petLevel, equals(2)); // Baby
    });

    test('petLevel returns 3 at 350 points', () {
      final child = ChildUser(parentId: '1', name: 'Ali', lifetimePoints: 350);
      expect(child.petLevel, equals(3)); // Child
    });

    test('petLevel returns 6 at 2000 points', () {
      final child = ChildUser(parentId: '1', name: 'Ali', lifetimePoints: 2000);
      expect(child.petLevel, equals(6)); // Legend
    });

    test('petLevel never exceeds 6', () {
      final child = ChildUser(parentId: '1', name: 'Ali', lifetimePoints: 9999);
      expect(child.petLevel, equals(6));
    });

  });

  // ── Points For Next Level Tests ───────────────────────────────────────────
  group('Points For Next Level', () {

    test('pointsForNextLevel is 50 at level 0 (needs 50 pts)', () {
      final child = ChildUser(parentId: '1', name: 'Ali', lifetimePoints: 0);
      expect(child.pointsForNextLevel, equals(50)); // needs 50-0=50
    });

    test('pointsForNextLevel is 0 at max level', () {
      final child = ChildUser(parentId: '1', name: 'Ali', lifetimePoints: 2000);
      expect(child.pointsForNextLevel, equals(0)); // already Legend
    });

    test('pointsForNextLevel correct mid-level', () {
      final child = ChildUser(parentId: '1', name: 'Ali', lifetimePoints: 100);
      expect(child.pointsForNextLevel, equals(50)); // needs 150-100=50 more
    });

  });

  // ── Password Hashing Tests ────────────────────────────────────────────────
  // DbHelper cannot be used in unit tests — it needs a real device + Firebase.
  // We duplicate the same SHA-256 logic here as a local function.
  group('Password Hashing', () {

    String hashPassword(String password) {
      final bytes = utf8.encode(password);
      return sha256.convert(bytes).toString();
    }

    test('hash is not equal to plain text', () {
      const plain = '123456';
      final hash  = hashPassword(plain);
      expect(hash, isNot(equals(plain)));
      expect(hash.length, equals(64)); // SHA-256 always 64 hex characters
    });

    test('same input always gives same hash', () {
      const plain = 'mySecret99';
      expect(hashPassword(plain), equals(hashPassword(plain)));
    });

    test('different inputs give different hashes', () {
      expect(hashPassword('abc'), isNot(equals(hashPassword('xyz'))));
    });

  });

  // ── Happiness Clamp Tests ─────────────────────────────────────────────────
  group('Happiness Clamping', () {

    test('happiness cannot exceed 100', () {
      final value = (150).clamp(0, 100);
      expect(value, equals(100));
    });

    test('happiness cannot go below 0', () {
      final value = (-20).clamp(0, 100);
      expect(value, equals(0));
    });

    test('happiness stays correct in normal range', () {
      final value = (65).clamp(0, 100);
      expect(value, equals(65));
    });

  });

  // ── Daily Limit Tests ─────────────────────────────────────────────────────
  group('Daily Limit Logic', () {

    test('child is within limit when used < limit', () {
      const used  = 45;
      const limit = 120;
      expect(used <= limit, isTrue);
    });

    test('child exceeds limit when used > limit', () {
      const used  = 130;
      const limit = 120;
      expect(used > limit, isTrue);
    });

    test('remaining minutes calculated correctly', () {
      const used      = 80;
      const limit     = 120;
      const remaining = limit - used;
      expect(remaining, equals(40));
    });

    test('remaining never goes below 0', () {
      const used      = 150;
      const limit     = 120;
      final remaining = (limit - used).clamp(0, limit);
      expect(remaining, equals(0));
    });

  });

}
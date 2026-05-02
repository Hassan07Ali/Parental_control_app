import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_models.dart';

class DbHelper {
  static final DbHelper _instance = DbHelper._internal();
  factory DbHelper() => _instance;
  DbHelper._internal();

  final _auth = FirebaseAuth.instance;
  final _db   = FirebaseFirestore.instance;

  String _childDocId(String uid) => '${uid}_child';

  // ── hashPassword — compatibility stub ─────────────────────────────────────
  // Firebase Auth handles password security. PINs stored as plain text.
  
  static String hashPassword(String input) => input;

  // ── Auth ───────────────────────────────────────────────────────────────────

  Future<int> registerParent(String name, String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(), password: password);
    final uid = cred.user!.uid;
    await _db.collection('parents').doc(uid).set({
      'name':      name.trim(),
      'email':     email.trim().toLowerCase(),
      'createdAt': DateTime.now().toIso8601String(),
      'role':      'parent',
    });
    return uid.hashCode;
  }

  Future<ParentUser?> loginParent(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
          email: email.trim().toLowerCase(), password: password);
      final uid = cred.user!.uid;
      final doc = await _db.collection('parents').doc(uid).get();
      if (!doc.exists) return null;
      return ParentUser(id: uid, name: doc['name'], email: doc['email']);
    } on FirebaseAuthException {
      return null;
    }
  }

  Future<bool> emailExists(String email) async {
    final methods = await _auth.fetchSignInMethodsForEmail(
        email.trim().toLowerCase());
    return methods.isNotEmpty;
  }

  Future<ParentUser?> getParentById(dynamic id) async {
    final uid = _resolveUid(id);
    if (uid == null) return null;
    final doc = await _db.collection('parents').doc(uid).get();
    if (!doc.exists) return null;
    return ParentUser(id: uid, name: doc['name'], email: doc['email']);
  }

  bool isLoggedIn() => _auth.currentUser != null;
  String? getCurrentUid() => _auth.currentUser?.uid;
  Future<void> signOut() => _auth.signOut();

  // ── Children ───────────────────────────────────────────────────────────────

  Future<int> insertChild(ChildUser child) async {
    final uid     = _auth.currentUser!.uid;
    final childId = _childDocId(uid);
    await _db.collection('children').doc(childId).set({
      ...child.toMap(),
      'parentId': uid,
    });
    return childId.hashCode;
  }

  Future<List<ChildUser>> getChildrenForParent(dynamic parentId) async {
    final uid     = _resolveUid(parentId) ?? _auth.currentUser?.uid;
    if (uid == null) return [];
    final childId = _childDocId(uid);
    final doc     = await _db.collection('children').doc(childId).get();
    if (!doc.exists) return [];
    return [ChildUser.fromMap(doc.data()!, childId)];
  }

  Future<ChildUser?> getChildById(dynamic childId) async {
    final id  = _resolveChildId(childId);
    if (id == null) return null;
    final doc = await _db.collection('children').doc(id).get();
    if (!doc.exists) return null;
    return ChildUser.fromMap(doc.data()!, id);
  }

  Future<List<ChildUser>> getAllChildren() async {
    final snap = await _db.collection('children').get();
    return snap.docs.map((d) => ChildUser.fromMap(d.data(), d.id)).toList();
  }

  // ── Child updates ──────────────────────────────────────────────────────────

  Future<void> updateRewardPoints(dynamic childId, int points) async {
    final id = _resolveChildId(childId)!;
    await _db.collection('children').doc(id).update({'rewardPoints': points});
  }

  Future<void> updateDailyLimit(dynamic childId, int limitMins) async {
    final id = _resolveChildId(childId)!;
    await _db.collection('children').doc(id).update({'dailyLimitMins': limitMins});
  }

  Future<void> updateChildProfile(
      dynamic childId, String name, String avatarEmoji, int age) async {
    final id = _resolveChildId(childId)!;
    await _db.collection('children').doc(id)
        .update({'name': name, 'avatarEmoji': avatarEmoji, 'age': age});
  }

  Future<void> updateChildPin(dynamic childId, String newPin) async {
    final id = _resolveChildId(childId)!;
    await _db.collection('children').doc(id).update({'pin': newPin});
  }

  Future<String?> getChildPin(dynamic childId) async {
    final id  = _resolveChildId(childId)!;
    final doc = await _db.collection('children').doc(id).get();
    return doc.exists ? doc['pin'] as String? : null;
  }

  Future<ChildUser?> loginChildByPin(dynamic childId, String pin) async {
    final id  = _resolveChildId(childId)!;
    final doc = await _db.collection('children').doc(id).get();
    if (!doc.exists) return null;
    if (doc['pin'] != pin) return null;
    return ChildUser.fromMap(doc.data()!, id);
  }

  // ── Parent updates ─────────────────────────────────────────────────────────

  Future<void> updateParentName(dynamic parentId, String newName) async {
    final uid = _resolveUid(parentId) ?? _auth.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('parents').doc(uid).update({'name': newName});
  }

  Future<bool> updateParentEmail(dynamic parentId, String newEmail) async {
    try {
      await _auth.currentUser!
          .verifyBeforeUpdateEmail(newEmail.trim().toLowerCase());
      final uid = _resolveUid(parentId) ?? _auth.currentUser?.uid;
      if (uid != null) {
        await _db.collection('parents').doc(uid)
            .update({'email': newEmail.trim().toLowerCase()});
      }
      return true;
    } catch (_) { return false; }
  }

  Future<bool> updateParentPassword(
      dynamic parentId, String oldPassword, String newPassword) async {
    try {
      final user = _auth.currentUser!;
      final cred = EmailAuthProvider.credential(
          email: user.email!, password: oldPassword);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);
      return true;
    } catch (_) { return false; }
  }

  // ── App Limits ─────────────────────────────────────────────────────────────

  Future<void> saveAppLimits(
      dynamic childId, List<AppLimitEntry> limits) async {
    final id    = _resolveChildId(childId)!;
    final batch = _db.batch();
    final col   = _db.collection('app_limits').doc(id).collection('limits');
    final old   = await col.get();
    for (final doc in old.docs) batch.delete(doc.reference);
    for (final limit in limits) {
      final key = limit.packageName.replaceAll('.', '_');
      batch.set(col.doc(key), {
        'packageName':  limit.packageName,
        'appName':      limit.appName,
        'limitMinutes': limit.limitMinutes,
        'isActive':     limit.isActive,
        'childId':      id,
      });
    }
    await batch.commit();
  }

  Future<List<AppLimitEntry>> getAppLimits(dynamic childId) async {
    final id   = _resolveChildId(childId)!;
    final snap = await _db
        .collection('app_limits').doc(id).collection('limits')
        .where('isActive', isEqualTo: true)
        .get();
    return snap.docs.map((doc) => AppLimitEntry(
      childId:      id,
      packageName:  doc['packageName'],
      appName:      doc['appName'] ?? '',
      limitMinutes: doc['limitMinutes'] ?? 60,
      isActive:     doc['isActive'] ?? true,
    )).toList();
  }

  // ── Pet methods ────────────────────────────────────────────────────────────

  Future<void> updatePet(dynamic childId, String petName, String petSpecies) async {
    final id = _resolveChildId(childId)!;
    await _db.collection('children').doc(id)
        .update({'petName': petName, 'petSpecies': petSpecies});
  }

  Future<void> updatePetHappiness(dynamic childId, int happiness) async {
    final id = _resolveChildId(childId)!;
    await _db.collection('children').doc(id)
        .update({'petHappiness': happiness.clamp(0, 100)});
  }

  Future<void> updateStreak(dynamic childId, int streakDays, String date) async {
    final id = _resolveChildId(childId)!;
    await _db.collection('children').doc(id)
        .update({'streakDays': streakDays, 'lastComplianceDate': date});
  }

  Future<Map<String, dynamic>> checkAndAwardDailyPoints(
    dynamic childId, int usedMinutes, int limitMinutes,
    int eduMinutes, String today,
  ) async {
    final id  = _resolveChildId(childId)!;
    final doc = await _db.collection('children').doc(id).get();
    if (!doc.exists) return {'awarded': 0, 'message': ''};

    final data     = doc.data()!;
    final lastDate = (data['lastComplianceDate'] as String?) ?? '';
    if (lastDate == today) return {'awarded': 0, 'message': ''};

    if (usedMinutes > limitMinutes || limitMinutes == 0) {
      final happiness = ((data['petHappiness'] as int?) ?? 50) - 15;
      await _db.collection('children').doc(id).update({
        'streakDays':          0,
        'petHappiness':        happiness.clamp(0, 100),
        'lastComplianceDate':  today,
      });
      return {'awarded': 0, 'message': 'Limit exceeded'};
    }

    int    points  = 10;
    String message = '+10 pts';
    if (usedMinutes <= limitMinutes * 0.5) { points += 10; message += ', +10 restraint'; }
    final eduBonus = (eduMinutes ~/ 15) * 5;
    if (eduBonus > 0) { points += eduBonus; message += ', +$eduBonus edu'; }
    int streak = ((data['streakDays'] as int?) ?? 0) + 1;
    if (streak == 3)  { points += 15; }
    if (streak == 7)  { points += 50; }
    if (streak == 14) { points += 120; }
    points = points.clamp(0, 100);

    final newReward   = ((data['rewardPoints']   as int?) ?? 0) + points;
    final newLifetime = ((data['lifetimePoints'] as int?) ?? 0) + points;
    final happiness   = ((data['petHappiness']   as int?) ?? 50) + 20;

    await _db.collection('children').doc(id).update({
      'rewardPoints':        newReward,
      'lifetimePoints':      newLifetime,
      'petHappiness':        happiness.clamp(0, 100),
      'streakDays':          streak,
      'lastComplianceDate':  today,
    });
    return {'awarded': points, 'message': message};
  }

  Future<void> migratePetColumns() async {}

  // ── ID resolution helpers ──────────────────────────────────────────────────

  String? _resolveUid(dynamic id) {
    if (id == null) return _auth.currentUser?.uid;
    if (id is String) return id;
    return _auth.currentUser?.uid;
  }

  String? _resolveChildId(dynamic id) {
    if (id == null) {
      final uid = _auth.currentUser?.uid;
      return uid != null ? _childDocId(uid) : null;
    }
    if (id is String && id.contains('_child')) return id;
    if (id is String) return _childDocId(id);
    final uid = _auth.currentUser?.uid;
    return uid != null ? _childDocId(uid) : null;
  }
}
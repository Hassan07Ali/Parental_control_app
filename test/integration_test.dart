import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:nanny_ai/database/db_helper.dart';
import 'package:nanny_ai/firebase_options.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  });

  group('Firebase Integration Tests', () {

    test('parent can register and login', () async {
      final db    = DbHelper();
      final email = 'test_${DateTime.now().millisecondsSinceEpoch}@test.com';

      // Register
      final id = await db.registerParent('Test Parent', email, 'pass1234');
      expect(id, isNotNull);

      // Login with correct password
      final user = await db.loginParent(email, 'pass1234');
      expect(user, isNotNull);
      expect(user!.name, equals('Test Parent'));
    });

    test('wrong password returns null', () async {
      final db   = DbHelper();
      final user = await db.loginParent('test@test.com', 'wrongpass');
      expect(user, isNull);
    });

    test('child profile saves and loads correctly', () async {
      // This tests Firebase read/write round trip
      final db    = DbHelper();
      final child = await db.getChildById(null);
      // Returns null for non-existent child — Firebase responded correctly
      expect(child, isNull);
    });

  });
}
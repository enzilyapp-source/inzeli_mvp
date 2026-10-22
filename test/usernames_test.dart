import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inzeli/api_username.dart';
import 'package:inzeli/username_rules.dart';
import 'package:inzeli/state.dart';
import 'package:inzeli/widgets/username_settings_tile.dart';

class ClaimTestState extends AppState {
  @override
  Future<void> claimUsername(String value) async {
    if (value == 'taken_name') throw const UsernameException('USERNAME_TAKEN');
    username = value;
    notifyListeners();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('Handles normalize consistently and reject misleading or reserved names',
      () {
    expect(normalizedUsername(' @Ali_92 '), 'ali_92');
    expect(usernameValidationError('Ali_92'), isNull);
    for (final invalid in ['', 'ab', '12ali', 'علي', 'ali.name', 'SUPPORT']) {
      expect(usernameValidationError(invalid), isNotNull);
    }
  });
  test('Claim requests send only the public handle with the existing session',
      () async {
    final client = MockClient((request) async {
      expect(request.method, 'PATCH');
      expect(request.url.path, '/api/users/me/username');
      expect(request.headers['authorization'], 'Bearer old-session');
      expect(jsonDecode(request.body), {'username': 'ali_92'});
      return http.Response(
          jsonEncode({
            'ok': true,
            'data': {'id': 'fixed-id', 'username': 'ali_92'}
          }),
          200);
    });
    expect(
        (await ApiUsernames.claim('@Ali_92',
            token: 'old-session', client: client))['username'],
        'ali_92');
    client.close();
  });
  test('An old server is reported without losing account state', () async {
    final client = MockClient((_) async => http.Response('{}', 404));
    await expectLater(
        ApiUsernames.claim('ali_92', token: 'old-session', client: client),
        throwsA(isA<UsernameException>()
            .having((e) => e.code, 'code', 'SERVER_UPDATE_REQUIRED')));
    client.close();
  });
  test('Username persistence preserves stable IDs and room identity', () async {
    final app = AppState()
      ..userId = 'fixed-id'
      ..publicId = 'fixed-public-id'
      ..username = 'ali_92'
      ..roomCode = 'ROOM12';
    await app.saveState();
    final restored = AppState();
    await restored.load();
    expect(restored.username, 'ali_92');
    expect(restored.userId, 'fixed-id');
    expect(restored.publicId, 'fixed-public-id');
    expect(restored.roomCode, 'ROOM12');
  });
  test('Players sharing a display name keep separate histories by stable ID',
      () {
    final app = AppState();
    for (final id in ['one', 'two']) {
      app.timeline.add(TimelineEntry(
          game: 'كوت',
          roomCode: id,
          winner: 'لاعب',
          winners: const ['لاعب'],
          losers: const [],
          ts: DateTime.now(),
          meta: {
            'winners': [id]
          }));
    }
    expect(app.userMatches('one').map((e) => e.roomCode), ['one']);
    expect(app.userMatches('two').map((e) => e.roomCode), ['two']);
  });
  testWidgets(
      'A taken handle keeps the editor open and preserves the old handle',
      (tester) async {
    final app = ClaimTestState()
      ..username = 'old_name'
      ..userId = 'fixed-id'
      ..roomCode = 'ROOM12';
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: UsernameSettingsTile(app: app))));
    await tester.tap(find.text('تغيير'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'taken_name');
    await tester.tap(find.text('حفظ اسم المستخدم'));
    await tester.pumpAndSettle();
    expect(find.text('اسم المستخدم محجوز، اختَر اسمًا آخر'), findsOneWidget);
    expect(app.username, 'old_name');
    await tester.enterText(find.byType(TextFormField), 'new_name');
    await tester.tap(find.text('حفظ اسم المستخدم'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('@new_name'), findsOneWidget);
    expect(app.userId, 'fixed-id');
    expect(app.roomCode, 'ROOM12');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

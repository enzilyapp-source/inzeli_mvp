import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:inzeli/scorekeeper/score_api.dart';
import 'package:inzeli/scorekeeper/score_document.dart';
import 'package:inzeli/scorekeeper/score_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'every card game has its own/general options; Uno and Dafan are general only',
      () {
    for (final game in ['هند', 'كوت', 'بلوت', 'سبيتة', 'تريكس']) {
      expect(ScoreKind.supports(game), isTrue);
      expect(ScoreKind.forGame(game), isNotNull);
    }
    for (final game in ['اونو', 'دفان']) {
      expect(ScoreKind.supports(game), isTrue);
      expect(ScoreKind.forGame(game), isNull);
    }
    expect(ScoreKind.supports('قدم'), isFalse);
  });
  test('timer uses actual elapsed time, clamps at zero and survives a resize',
      () {
    final now = DateTime.utc(2026, 11, 8, 12);
    final room = ScoreRoomInfo(
        code: 'ABCD',
        game: 'هند',
        hostId: 'host',
        players: const [],
        teamMode: false,
        startedAt: now,
        timerSeconds: 60);
    expect(room.remaining(now.add(const Duration(seconds: 23))), 37);
    expect(room.remaining(now.add(const Duration(seconds: 80))), 0);
  });
  test(
      'same names keep separate stable account IDs and avatars can fail safely',
      () {
    final a = ScorePerson.fromRoom({
      'userId': '1',
      'user': {'displayName': 'سالم', 'avatarPath': 'javascript:alert(1)'}
    });
    final b = ScorePerson.fromRoom({
      'userId': '2',
      'user': {'displayName': 'سالم'}
    });
    expect(a.name, b.name);
    expect(a.id, isNot(b.id));
    expect(a.avatar, isNull);
  });
  test('corrupt profile images fall back without losing the player identity',
      () async {
    const person = ScorePerson(
        id: 'one', name: 'سالم', avatar: 'data:image/jpeg;base64,@@');
    final small = await person.thumbnail();
    expect(small.id, 'one');
    expect(small.name, 'سالم');
    expect(small.avatar, isNull);
  });
  test('all six documents are self-contained and safely embed untrusted names',
      () async {
    for (final kind in ScoreKind.values) {
      final html = await ScoreDocument.build(
          kind: kind,
          people: const [
            ScorePerson(id: '1', name: '</script><script>bad()</script>'),
            ScorePerson(id: '2', name: 'علي'),
            ScorePerson(id: '3', name: 'حمد'),
            ScorePerson(id: '4', name: 'سالم'),
          ],
          teamMode: false,
          editable: false);
      expect(html, contains('window.InzeliConfig='));
      expect(html, contains('"editable":false'));
      expect(html, isNot(contains('</script><script>bad()')));
      expect(RegExp(r'<script[^>]+src=').hasMatch(html), isFalse);
      expect(RegExp(r'<link rel="stylesheet"').hasMatch(html), isFalse);
      expect(html, contains('InzeliPublish'));
      expect(html, contains('room-avatar'));
    }
  });
  test(
      'score API uses the authenticated companion endpoint and preserves revisions',
      () async {
    final snapshot = ScoreSnapshot(
        kind: ScoreKind.general,
        rosterIds: const ['host', 'guest'],
        teamMode: false,
        teams: const {'host': null, 'guest': null},
        storage: const {'jinjfa_score_v1': '{}'});
    final api = ScoreApi(
        code: 'ABCD',
        token: 'test-session',
        client: MockClient((req) async {
          expect(req.url.path, endsWith('/rooms/ABCD/score-sheet'));
          expect(req.headers['Authorization'], 'Bearer test-session');
          expect(req.method, 'PUT');
          expect(jsonDecode(req.body)['revision'], 3);
          return http.Response(
              jsonEncode({
                'ok': true,
                'data': {
                  'revision': 4,
                  'canEdit': true,
                  'snapshot': snapshot.toJson()
                }
              }),
              200);
        }));
    final result = await api.write(3, snapshot);
    expect(result.revision, 4);
    expect(result.snapshot!.signature, snapshot.signature);
    api.dispose();
  });
  test('stale revision returns a conflict rather than overwriting silently',
      () async {
    final api = ScoreApi(
        code: 'ABCD',
        token: 'test',
        client: MockClient((_) async =>
            http.Response('{"message":"SCORE_SHEET_CONFLICT"}', 409)));
    expect(api.read(),
        throwsA(isA<ScoreApiError>().having((e) => e.status, 'status', 409)));
    api.dispose();
  });
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inzeli/state.dart';
import 'package:inzeli/operations_gate.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('Hiding a main game preserves its catalog and achievement history', () {
    final app = AppState();
    app.gamePearls['كوت'] = 12;
    app.setSelectedGame('كوت', category: 'جنجفة');
    app.applyHiddenGames(['كوت']);
    expect(app.mainGames['جنجفة'], isNot(contains('كوت')));
    expect(app.games['جنجفة'], contains('كوت'));
    expect(app.gamePearls['كوت'], 12);
    expect(app.selectedGame, isNull);
    app.applyHiddenGames([]);
    expect(app.mainGames['جنجفة'], contains('كوت'));
  });
  test(
      'Inbox expires old notices, deduplicates pushes and rejects other accounts',
      () {
    final app = AppState()
      ..token = 'qa-token'
      ..userId = 'qa-user';
    app.addNotification(
        id: 'expired',
        type: 'push',
        title: 'Old',
        body: '',
        createdAt: DateTime.now().subtract(const Duration(hours: 25)));
    expect(app.notifications, isEmpty);
    final notice = <String, dynamic>{
      'id': 'push-1',
      'title': 'Winner',
      'body': 'wins 3 losses 1',
      'data': {'inAppNotificationId': 'event-1', 'recipientUserId': 'qa-user'}
    };
    app.receivePush(notice);
    app.markNotificationsRead();
    app.receivePush(notice);
    expect(app.notifications.length, 1);
    expect(app.unreadNotificationCount, 0);
    app.receivePush({
      'id': 'other-user',
      'data': {'recipientUserId': 'another-user'}
    });
    expect(app.notifications.length, 1);
    app.notifications.add(AppNotificationEntry(
        id: 'old-restored',
        type: 'push',
        title: 'Old',
        body: '',
        createdAt: DateTime.now().subtract(const Duration(hours: 25)),
        read: false,
        data: {}));
    app.pruneNotifications();
    expect(app.notifications.length, 1);
  });
  testWidgets(
      'Maintenance covers existing routes and reopens after the admin disables it',
      (tester) async {
    bool maintenance = true;
    int plays = 0;
    final client = MockClient((_) async => http.Response(
        jsonEncode({
          'ok': true,
          'data': {
            'maintenanceEnabled': maintenance,
            'maintenanceMessage': 'QA maintenance',
            'hiddenGameIds': ['كوت']
          }
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'}));
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) =>
            OperationsGate(client: client, child: child!),
        home: Scaffold(
            body: TextButton(
                onPressed: () => plays++, child: const Text('Play')))));
    await tester.pumpAndSettle();
    expect(find.text('QA maintenance'), findsOneWidget);
    await tester.tap(find.text('Play'), warnIfMissed: false);
    expect(plays, 0);
    maintenance = false;
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();
    expect(find.text('QA maintenance'), findsNothing);
    await tester.tap(find.text('Play'));
    expect(plays, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    client.close();
  });
}

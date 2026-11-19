import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inzeli/challenge_rewards.dart';
import 'package:inzeli/state.dart';
import 'package:inzeli/pages/challenge_rewards_page.dart';
import 'package:inzeli/widgets/challenge_rank_visuals.dart';
import 'package:inzeli/widgets/reward_avatar_frame.dart';

Map<String, dynamic> snapshot() => {
      'ownedRewardIds': ['reward_rank_professional'],
      'rewards': [
        {
          'id': 'reward_rank_professional',
          'name': 'إطار محترف الفضي',
          'kind': 'rank',
          'slot': 2,
          'target': 15,
          'progress': 15,
          'unlocked': true,
          'games': []
        },
        {
          'id': 'reward_chess',
          'name': 'بطل الشطرنج',
          'kind': 'wins',
          'slot': 8,
          'target': 5,
          'progress': 3,
          'unlocked': false,
          'games': ['شطرنج']
        },
      ],
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    for (final name in [
      'OneSignal',
      'OneSignal#debug',
      'OneSignal#user',
      'OneSignal#pushsubscription',
      'OneSignal#notifications',
      'OneSignal#inappmessages'
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              MethodChannel(name),
              (call) async =>
                  call.method == 'OneSignal#permission' ? false : null);
    }
    await (FontLoader('Tajawal')
          ..addFont(rootBundle.load('lib/assets/Tajawal/Tajawal-Regular.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });

  test(
      'Ownership survives a season reset and a restart, but not sign-out into another account',
      () async {
    final app = AppState()
      ..freeThemesOwned = {'blueThunder'}
      ..userId = 'alice'
      ..themeId = 'reward_rank_professional';
    await app.applyRewardSnapshot(snapshot());
    app.pearlsResetMonth = '2020-01';
    expect(app.badgeProgressForGame('كوت'), 5);
    expect(app.earnedRewardIds, contains('reward_rank_professional'));
    await app.saveState();
    final restored = AppState();
    await restored.load();
    expect(restored.earnedRewardIds, contains('reward_rank_professional'));
    expect(restored.themeId, 'reward_rank_professional');
    await restored.clearAuth();
    expect(restored.earnedRewardIds, isEmpty);
    expect(restored.challengeRewards, isEmpty);
    expect(restored.themeId, isNull);
    expect(restored.freeThemesOwned, contains('blueThunder'));
  });

  test(
      'Offline refresh keeps cached ownership and a delayed result cannot leak accounts',
      () async {
    final app = AppState()
      ..userId = 'alice'
      ..token = 'local-test';
    await app.applyRewardSnapshot(snapshot());
    await http.runWithClient(() async {
      expect(await app.refreshChallengeRewards(), false);
      expect(app.earnedRewardIds, contains('reward_rank_professional'));
    }, () => MockClient((_) async => http.Response('Cannot GET', 404)));
    final pending = Completer<http.Response>();
    await http.runWithClient(() async {
      final refresh = app.refreshChallengeRewards();
      app.userId = 'bob';
      app.earnedRewardIds.clear();
      pending.complete(http.Response(
          jsonEncode({'ok': true, 'data': snapshot()}), 200,
          headers: {'content-type': 'application/json; charset=utf-8'}));
      expect(await refresh, false);
      expect(app.earnedRewardIds, isEmpty);
    }, () => MockClient((_) => pending.future));
  });

  test(
      'Applying a frame requires server acceptance and does not change a locked selection',
      () async {
    final app = AppState()
      ..userId = 'alice'
      ..token = 'local-test'
      ..themeId = 'frame_ice';
    await app.applyRewardSnapshot(snapshot());
    await http.runWithClient(() async {
      expect(await app.equipChallengeReward('reward_rank_professional'), false);
      expect(app.themeId, 'frame_ice');
      expect(await app.equipChallengeReward('reward_rank_crown'), false);
    },
        () => MockClient((_) async => http.Response(
            jsonEncode({'ok': false, 'message': 'REWARD_LOCKED'}), 200)));
    await http.runWithClient(() async {
      expect(await app.equipChallengeReward('reward_rank_professional'), true);
      expect(app.themeId, 'reward_rank_professional');
    },
        () => MockClient((request) async {
              expect(request.url.path, endsWith('/store/apply'));
              expect(jsonDecode(request.body),
                  {'themeId': 'reward_rank_professional'});
              return http.Response(
                  jsonEncode({
                    'ok': true,
                    'data': {'themeId': 'reward_rank_professional'}
                  }),
                  200);
            }));
  });

  for (final width in [320.0, 840.0]) {
    testWidgets(
        'Challenge cards fit width $width and only earned rewards apply',
        (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var applied = 0;
      final app = AppState();
      final rewards = (snapshot()['rewards'] as List)
          .map((row) => ChallengeReward.fromJson(row as Map<String, dynamic>))
          .toList();
      await tester.pumpWidget(MaterialApp(
          theme: ThemeData.dark().copyWith(
              textTheme:
                  ThemeData.dark().textTheme.apply(fontFamily: 'Tajawal')),
          home: Scaffold(
              body: Directionality(
            textDirection: TextDirection.rtl,
            child: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
                child: ListView(children: [
                  for (final reward in rewards)
                    ChallengeRewardCard(
                        reward: reward,
                        app: app,
                        equipped: false,
                        busy: false,
                        onEquip: () => applied++),
                ])),
          ))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تطبيق الإطار'));
      expect(applied, 1);
      final locked = tester.widget<OutlinedButton>(find.ancestor(
          of: find.text('لم يُفتح بعد'),
          matching: find.byType(OutlinedButton)));
      expect(locked.onPressed, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  test('Heritage slots and collection survive cached snapshot round-trips', () {
    final reward = ChallengeReward.fromJson({
      'id': 'reward_heritage_chess',
      'collection': 'heritage',
      'slot': 26,
      'name': 'فارس الشطرنج',
      'kind': 'wins',
      'target': 15,
      'progress': 15,
      'unlocked': true,
      'games': ['شطرنج'],
    });
    final restored = ChallengeReward.fromJson(reward.toJson());
    expect(restored.slot, 26);
    expect(restored.collection, 'heritage');
    expect(restored.unlocked, true);
    expect(ChallengeReward.fromJson(snapshot()['rewards'][0]).collection,
        'classic');
  });

  testWidgets(
      'All thirty-two frame sprites preserve original slots and render around portraits',
      (tester) async {
    tester.view.physicalSize = const Size(600, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final options = kThemeVisualOptions
        .where((option) => option.rewardSlot != null)
        .toList();
    expect(options.length, 32);
    expect(options.take(15).last.id, 'reward_moon');
    expect(options.skip(15).take(12).map((option) => option.rewardSlot),
        List.generate(12, (i) => i + 15));
    expect(options.map((option) => option.id).toSet().length, 32);
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark().copyWith(
            textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Tajawal')),
        home: Scaffold(
          backgroundColor: const Color(0xFF142A40),
          body: Center(
              child: Wrap(children: [
            for (final option in options)
              SizedBox(
                  width: 120,
                  height: 120,
                  child: Center(
                      child: buildAvatarThemeWidget(
                          themeId: option.id,
                          size: 104,
                          animate: false,
                          child: const CircleAvatar(
                              backgroundColor: Color(0xFF314E65),
                              child: Text('M'))))),
          ])),
        )));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      for (final asset in ['avatar_frames_v1.png', 'heritage_frames_v1.png']) {
        await precacheImage(
            ResizeImage(AssetImage('lib/assets/rewards/$asset'), width: 1620),
            tester.element(find.byType(Scaffold)));
      }
    });
    await tester.pumpAndSettle();
    expect(find.byType(RewardAvatarFrame), findsNWidgets(32));
    expect(tester.takeException(), isNull);
    await expectLater(
        find.byType(Scaffold), matchesGoldenFile('goldens/reward_frames.png'));
    await tester.pumpWidget(const SizedBox());
  });
}

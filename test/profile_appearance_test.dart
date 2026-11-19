import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inzeli/state.dart';
import 'package:inzeli/pages/profile_appearance_editor.dart';
import 'package:inzeli/widgets/rank_identity.dart';
import 'package:inzeli/widgets/rank_levels_sheet.dart';
import 'package:inzeli/widgets/challenge_rank_visuals.dart';

class _EditorApp extends AppState {
  @override
  Future<bool> refreshChallengeRewards() async => true;
  @override
  Future<bool> applyProfileAppearance(
      {required String? selectedThemeId,
      required String? selectedCardId}) async {
    themeId = selectedThemeId;
    cardId = selectedCardId;
    return true;
  }
}

_EditorApp _fixture() => _EditorApp()
  ..displayName = 'MariamA'
  ..themeId = 'reward_tier_beginner'
  ..cardId = 'reward_banner_beginner'
  ..earnedRewardIds = {'reward_tier_beginner', 'reward_banner_beginner'};
Widget host(AppState app) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark().copyWith(
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Tajawal')),
    home: Scaffold(
        body: Builder(
            builder: (context) => Center(
                child: FilledButton(
                    onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        showDragHandle: true,
                        backgroundColor: const Color(0xFF172C41),
                        builder: (_) => ProfileAppearanceEditor(
                            app: app,
                            onPickPhoto: () async {},
                            onRemovePhoto: () async {})),
                    child: const Text('تعديل'))))));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    await (FontLoader('Tajawal')
          ..addFont(rootBundle.load('lib/assets/Tajawal/Tajawal-Regular.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  test(
      'Approved rank order pairs Bronze/Silver/Gold/Diamond/Crown with stable level thresholds',
      () {
    expect(rankIdentities.map((rank) => rank.arabic),
        ['عليمي', 'زين', 'محترف', 'أسطوري', 'أحسن واحد']);
    expect(rankIdentities.map((rank) => rank.metalEn),
        ['Bronze', 'Silver', 'Gold', 'Diamond', 'Crown']);
    expect(rankIdentities.map((rank) => rank.threshold), [5, 10, 15, 20, 30]);
    expect(
        rankIdentities.map((rank) => themeVisualById(rank.frameId)?.rewardSlot),
        [1, 2, 3, 4, 5]);
  });
  test(
      'Saving appearance is one server-validated update; rejection leaves existing choices intact',
      () async {
    final app = AppState()
      ..token = 'local-test'
      ..userId = 'alice'
      ..themeId = 'frame_ice'
      ..cardId = 'blue'
      ..earnedRewardIds = {'reward_tier_beginner', 'reward_banner_beginner'};
    var calls = 0;
    await http.runWithClient(() async {
      expect(
          await app.applyProfileAppearance(
              selectedThemeId: 'reward_tier_beginner',
              selectedCardId: 'reward_banner_beginner'),
          false);
      expect(app.themeId, 'frame_ice');
      expect(app.cardId, 'blue');
    }, () => MockClient((_) async => http.Response('{"ok":false}', 200)));
    await http.runWithClient(() async {
      expect(
          await app.applyProfileAppearance(
              selectedThemeId: 'reward_tier_beginner',
              selectedCardId: 'reward_banner_beginner'),
          true);
    },
        () => MockClient((request) async {
              calls++;
              expect(request.method, 'PATCH');
              final body = jsonDecode(request.body);
              expect(body, {
                'themeId': 'reward_tier_beginner',
                'cardId': 'reward_banner_beginner'
              });
              return http.Response(jsonEncode({'ok': true, 'data': body}), 200);
            }));
    expect(calls, 1);
    expect(app.cardId, 'reward_banner_beginner');
  });
  for (final width in [320.0, 430.0]) {
    testWidgets(
        'Editor only offers owned frame/banner and saves a draft at width $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final app = _fixture();
      await tester.pumpWidget(host(app));
      await tester.tap(find.text('تعديل'));
      await tester.pumpAndSettle();
      expect(find.text('إطار عليمي البرونزي'), findsOneWidget);
      expect(find.text('إطار أسطوري الماسي'), findsNothing);
      expect(find.text('بنر عليمي • برونزي'), findsOneWidget);
      expect(find.text('بنر أسطوري • ماسي'), findsNothing);
      if (width == 430) {
        await tester.runAsync(() => precacheImage(
            const ResizeImage(
                AssetImage('lib/assets/rewards/avatar_frames_v1.png'),
                width: 1620),
            tester.element(find.byType(ProfileAppearanceEditor))));
        await tester.pumpAndSettle();
        await expectLater(find.byType(MaterialApp),
            matchesGoldenFile('goldens/profile_appearance_editor.png'));
      }
      await tester.ensureVisible(find.text('بدون إطار'));
      await tester.tap(find.text('بدون إطار'));
      await tester.pumpAndSettle();
      expect(app.themeId, 'reward_tier_beginner');
      await tester.scrollUntilVisible(find.text('حفظ المظهر'), 240,
          scrollable: find.byType(Scrollable).last);
      await tester.tap(find.text('حفظ المظهر'));
      await tester.pumpAndSettle();
      expect(app.themeId, isNull);
      expect(app.cardId, 'reward_banner_beginner');
      if (width == 430) {
        await tester.tap(find.text('تعديل'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('إطار عليمي البرونزي'));
        await tester.tap(find.text('إطار عليمي البرونزي'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.byTooltip('إغلاق المحرر'), -220,
            scrollable: find.byType(Scrollable).last);
        await tester.tap(find.byTooltip('إغلاق المحرر'));
        await tester.pumpAndSettle();
        expect(app.themeId,
            isNull); // Dismissed draft does not change saved appearance.
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('Level sheet shows all five identities and medal artwork',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = _fixture();
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: RankLevelsSheet(app: app, currentThreshold: 5))));
    await tester.pumpAndSettle();
    expect(find.text('عليمي • برونزي'), findsOneWidget);
    expect(find.text('زين • فضي'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('أحسن واحد • تاج'), 250,
        scrollable: find.byType(Scrollable).first);
    expect(find.byType(RankMedal), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

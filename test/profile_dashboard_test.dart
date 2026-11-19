import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inzeli/pages/profile_page.dart';
import 'package:inzeli/state.dart';

class _ProfileFixture extends AppState {
  @override
  int winsOf(String playerName, String game) => game == 'كوت' ? 9 : 0;
  @override
  int lossesOf(String playerName, String game) => game == 'شطرنج' ? 2 : 0;
}

AppState fixture() {
  final now = DateTime.now();
  return _ProfileFixture()
    ..displayName = 'MariamA'
    ..publicId = '9xb39t'
    ..soundMuted = true
    ..pearlsResetMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}'
    ..creditPoints = 12
    ..playedGameIds = {'كوت', 'شطرنج'}
    ..gamePearls = {'كوت': 2, 'شطرنج': 5}
    ..gameBadgeProgress = {'كوت': 17, 'شطرنج': 8}
    ..badges = [
      {'gameId': 'كوت', 'label': 'Professional', 'threshold': 15}
    ]
    ..timeline.addAll([
      TimelineEntry(
          game: 'كوت',
          roomCode: 'TEST01',
          winner: 'MariamA',
          losers: ['Guest'],
          ts: DateTime(2026, 11, 19)),
      TimelineEntry(
          game: 'شطرنج',
          roomCode: 'TEST02',
          winner: 'Guest',
          losers: ['MariamA'],
          ts: DateTime(2026, 11, 18)),
    ]);
}

Widget profile(AppState app, {double scale = 1}) => MaterialApp(
      theme: ThemeData.dark().copyWith(
          platform: TargetPlatform.iOS,
          textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Tajawal')),
      home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
              backgroundColor: const Color(0xFF245063),
              body: ProfilePage(app: app))),
    );

Future<void> openAchievements(WidgetTester tester) async {
  final title = find.text('إنجازاتي');
  await tester.scrollUntilVisible(title, 220,
      scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(title);
  await tester.pumpAndSettle();
  await tester.tap(title);
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('achievement-progress')), findsOneWidget);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('Tajawal')
      ..addFont(rootBundle.load('lib/assets/Tajawal/Tajawal-Regular.ttf'))
      ..addFont(rootBundle.load('lib/assets/Tajawal/Tajawal-Bold.ttf'));
    await font.load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
      'Overview totals span games; progress opens only from achievements',
      (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(profile(fixture()));
    await tester.pumpAndSettle();
    expect(find.text('11'), findsOneWidget);
    expect(find.byKey(const ValueKey('achievement-progress')), findsNothing);
    await openAchievements(tester);
    expect(find.byKey(const ValueKey('achievement-progress')), findsOneWidget);
    // The wallet for Kout is 2; achievement progress is 17, so spending pearls
    // must not visually erase level progress.
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('achievement-progress')),
            matching: find.text('17')),
        findsOneWidget);
    await tester.tap(find.byTooltip('إغلاق'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('achievement-progress')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final config in [(320.0, 1.6), (430.0, 1.0), (840.0, 1.0)]) {
    testWidgets(
        'Profile and achievement sheet fit width ${config.$1} text ${config.$2}',
        (tester) async {
      tester.view.physicalSize = Size(config.$1, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(profile(fixture(), scale: config.$2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await openAchievements(tester);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('Recent games include losses and no invented empty awards',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(profile(fixture()));
    await tester.pumpAndSettle();
    expect(find.text('فوز'), findsOneWidget);
    expect(find.text('خسارة'), findsOneWidget);
    expect(find.bySemanticsLabel('وسام مقفل'), findsNWidgets(4));
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(Scaffold),
        matchesGoldenFile('goldens/profile_dashboard.png'));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Empty profile opens achievements without fake progress',
      (tester) async {
    await tester.pumpWidget(profile(AppState()));
    await tester.pumpAndSettle();
    await openAchievements(tester);
    expect(find.text('لا توجد ألعاب مسجلة بعد'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

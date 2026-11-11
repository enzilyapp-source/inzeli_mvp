import 'dart:ui' show DisplayFeature, DisplayFeatureType, DisplayFeatureState;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inzeli/widgets/adaptive_game_frame.dart';

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(600, 800),
    const Size(850, 900),
    const Size(1200, 800),
    const Size(844, 390)
  ]) {
    testWidgets('score layout stays within ${size.width} by ${size.height}',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SafeArea(
                  child: AdaptiveGameFrame(
        panel: Column(
            children: List.generate(
                8,
                (i) =>
                    Text('لاعب $i', textScaler: const TextScaler.linear(1.5)))),
        content: const ColoredBox(
            key: ValueKey('score'),
            color: Colors.white,
            child: SizedBox.expand()),
      )))));
      expect(tester.takeException(), isNull);
      final rect = tester.getRect(find.byKey(const ValueKey('score')));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(size.width));
      expect(rect.height, greaterThan(100));
      expect(rect.bottom, lessThanOrEqualTo(size.height));
    });
  }
  testWidgets('reported hinge stays outside the full app surface',
      (tester) async {
    tester.view.physicalSize = const Size(820, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const hinge = Rect.fromLTWH(400, 0, 20, 800);
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(size: Size(820, 800), displayFeatures: [
              DisplayFeature(
                  bounds: hinge,
                  type: DisplayFeatureType.hinge,
                  state: DisplayFeatureState.postureHalfOpened)
            ]),
            child: const FoldAwareApp(
                child: SizedBox.expand(key: ValueKey('surface'))))));
    expect(tester.takeException(), isNull);
    final rect = tester.getRect(find.byKey(const ValueKey('surface')));
    expect(rect.overlaps(hinge), isFalse);
  });
}

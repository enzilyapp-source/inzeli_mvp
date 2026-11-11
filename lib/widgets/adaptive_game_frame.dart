import 'dart:ui' show DisplayFeatureType, DisplayFeatureState;
import 'package:flutter/material.dart';

/// Use reported display geometry; never infer a fold from a phone model name.
/// On a flat unfolded screen the whole width is used. Obstructing hinges and
/// half-open folds stay outside tappable content, including navigator overlays.
class FoldAwareApp extends StatelessWidget {
  const FoldAwareApp({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final obstructed = media.displayFeatures.any((f) =>
        f.type == DisplayFeatureType.hinge ||
        (f.type == DisplayFeatureType.fold &&
            f.state == DisplayFeatureState.postureHalfOpened));
    return obstructed
        ? DisplayFeatureSubScreen(anchorPoint: Offset.zero, child: child)
        : child;
  }
}

/// Scoreboard + companion room panel: one scrolling panel on phones, two panes
/// when unfolded/tablet width allows. Child state survives changing constraints.
class AdaptiveGameFrame extends StatelessWidget {
  const AdaptiveGameFrame(
      {super.key, required this.panel, required this.content});
  final Widget panel, content;
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth >= 840 && constraints.maxHeight >= 460) {
          return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
                width: 270,
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16), child: panel)),
            const VerticalDivider(width: 1),
            Expanded(child: content),
          ]);
        }
        return Column(children: [
          ConstrainedBox(
              constraints:
                  BoxConstraints(maxHeight: constraints.maxHeight * .32),
              child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: panel)),
          Expanded(child: content),
        ]);
      });
}

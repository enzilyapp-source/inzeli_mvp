import 'package:flutter/material.dart';

class AnwatRow extends StatelessWidget {
  final int wins;
  const AnwatRow({super.key, required this.wins});

  static const _thresholds = [5, 10, 15, 20, 30];
  static const _labels = ['عليمي', 'زين', 'محترف', 'أسطوري', 'أحسن واحد'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isAndroid = Theme.of(context).platform == TargetPlatform.android;
    final row = Row(
      children: List.generate(_thresholds.length, (i) {
        final t = _thresholds[i];
        final achieved = wins >= t;
        final fill = achieved
            ? cs.primary
            : cs.surfaceContainerHighest.withValues(alpha: .6);
        final border = achieved ? cs.primary : cs.outline.withValues(alpha: .4);
        return Padding(
          padding: EdgeInsetsDirectional.only(
              end: i == _thresholds.length - 1 ? 0 : 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fill.withValues(alpha: .12),
                  border: Border.all(color: border, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$t',
                  style: TextStyle(
                    color: fill,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 62,
                child: Text(
                  _labels[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: .7),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
    if (isAndroid) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(top: 8),
        child: row,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: row,
    );
  }
}
//anwat_row.dart

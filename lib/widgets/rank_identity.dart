import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Presentation identities follow the existing 5/10/15/20/30 rules. Versioned
/// frame IDs preserve the inventory of players who earned the older artwork.
class RankIdentity {
  const RankIdentity(this.key, this.threshold, this.arabic, this.english,
      this.metalAr, this.metalEn, this.slot, this.colors);
  final String key, arabic, english, metalAr, metalEn;
  final int threshold, slot;
  final List<Color> colors;
  String get frameId => 'reward_tier_$key';
  String get bannerId => 'reward_banner_$key';
}

const rankIdentities = [
  RankIdentity('beginner', 5, 'عليمي', 'Beginner', 'برونزي', 'Bronze', 1,
      [Color(0xFFFFD7B5), Color(0xFFA45D39)]),
  RankIdentity('good', 10, 'زين', 'Good', 'فضي', 'Silver', 2,
      [Color(0xFFF3F7FF), Color(0xFF8290A6)]),
  RankIdentity('professional', 15, 'محترف', 'Professional', 'ذهبي', 'Gold', 3,
      [Color(0xFFFFEDAE), Color(0xFFC18A26)]),
  RankIdentity('legend', 20, 'أسطوري', 'Legendary', 'ماسي', 'Diamond', 4,
      [Color(0xFFCCF7FF), Color(0xFF328FCE)]),
  RankIdentity('best', 30, 'أحسن واحد', 'Best', 'تاج', 'Crown', 5,
      [Color(0xFFFFDF7F), Color(0xFFA174D0)]),
];
RankIdentity rankIdentityForThreshold(int threshold) =>
    rankIdentities.reversed.firstWhere((rank) => threshold >= rank.threshold,
        orElse: () => rankIdentities.first);
RankIdentity? rankIdentityForBanner(String? id) {
  for (final rank in rankIdentities) {
    if (rank.bannerId == id) return rank;
  }
  return null;
}

Color profileBaseColor(String? id) => switch (id) {
      'violet' => const Color(0xFF2D1B46),
      'navy' => const Color(0xFF0F1D32),
      _ => const Color(0xFF10283E),
    };

class RankMedal extends StatelessWidget {
  const RankMedal(
      {super.key,
      required this.threshold,
      this.size = 36,
      this.locked = false});
  final int threshold;
  final double size;
  final bool locked;
  @override
  Widget build(BuildContext context) {
    final rank = rankIdentityForThreshold(threshold);
    return Semantics(
      image: true,
      label: locked ? 'وسام مقفل' : 'نوط ${rank.arabic} ${rank.metalAr}',
      child: CustomPaint(
          painter: _RankMedalPainter(rank, locked),
          child: SizedBox(
              width: size,
              height: size * 1.1,
              child: locked
                  ? Icon(Icons.lock_outline,
                      size: size * .46, color: Colors.white38)
                  : rank.threshold == 30
                      ? const SizedBox()
                      : Icon(
                          rank.threshold == 20
                              ? Icons.diamond_outlined
                              : rank.threshold == 15
                                  ? Icons.emoji_events_rounded
                                  : Icons.star_rounded,
                          size: size * .48,
                          color: rank.colors.first))),
    );
  }
}

class _RankMedalPainter extends CustomPainter {
  const _RankMedalPainter(this.rank, this.locked);
  final RankIdentity rank;
  final bool locked;
  @override
  void paint(Canvas canvas, Size size) {
    final colors =
        locked ? const [Color(0xFF3C6070), Color(0xFF1C344A)] : rank.colors;
    final rect = Rect.fromLTWH(
        size.width * .1, size.height * .05, size.width * .8, size.height * .9);
    final shield = Path()
      ..moveTo(size.width / 2, rect.top)
      ..lineTo(rect.right, size.height * .24)
      ..lineTo(rect.right - size.width * .03, size.height * .64)
      ..quadraticBezierTo(
          size.width * .75, size.height * .87, size.width / 2, rect.bottom)
      ..quadraticBezierTo(size.width * .25, size.height * .87,
          rect.left + size.width * .03, size.height * .64)
      ..lineTo(rect.left, size.height * .24)
      ..close();
    canvas.drawShadow(shield, Colors.black54, 3, false);
    canvas.drawPath(
        shield,
        Paint()
          ..shader = LinearGradient(colors: [
            colors.first,
            colors.last,
            colors.first,
            colors.last
          ], stops: const [
            0,
            .38,
            .55,
            1
          ], begin: Alignment.topLeft, end: Alignment.bottomRight)
              .createShader(rect));
    canvas.save();
    canvas.translate(size.width * .1, size.height * .1);
    canvas.scale(.8);
    canvas.drawPath(shield,
        Paint()..color = const Color(0xFF14243B).withValues(alpha: .68));
    canvas.restore();
    if (rank.threshold == 30 && !locked) {
      final crown = Path()
        ..moveTo(size.width * .25, size.height * .39)
        ..lineTo(size.width * .37, size.height * .48)
        ..lineTo(size.width * .5, size.height * .29)
        ..lineTo(size.width * .63, size.height * .48)
        ..lineTo(size.width * .75, size.height * .39)
        ..lineTo(size.width * .68, size.height * .66)
        ..lineTo(size.width * .32, size.height * .66)
        ..close();
      canvas.drawPath(crown, Paint()..color = const Color(0xFFFFD56D));
      canvas.drawLine(
          Offset(size.width * .32, size.height * .72),
          Offset(size.width * .68, size.height * .72),
          Paint()
            ..color = const Color(0xFFFFD56D)
            ..strokeWidth = size.width * .045
            ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_RankMedalPainter oldDelegate) =>
      rank != oldDelegate.rank || locked != oldDelegate.locked;
}

/// Scalable banner decoration; no user photos or text are baked into the art.
class RankBannerPainter extends CustomPainter {
  const RankBannerPainter(this.rank);
  final RankIdentity rank;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(colors: [
            Color(0xFF0D1B29),
            Color(0xFF102D40),
            Color(0xFF0A1829)
          ], begin: Alignment.topCenter, end: Alignment.bottomCenter)
              .createShader(Offset.zero & size));
    final line = Paint()
      ..color = rank.colors.last.withValues(alpha: .5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final border = RRect.fromRectAndRadius(
        Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
        const Radius.circular(26));
    canvas.drawRRect(border, line);
    for (final left in [true, false]) {
      canvas.save();
      if (!left) {
        canvas.translate(size.width, 0);
        canvas.scale(-1, 1);
      }
      final width = math.min(size.width * .23, 100.0);
      final path = Path()
        ..moveTo(0, size.height * .43)
        ..cubicTo(width * .1, size.height * .7, width * .9, size.height * .75,
            width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
          path, Paint()..color = rank.colors.last.withValues(alpha: .07));
      canvas.drawPath(path, line);
      canvas.save();
      canvas.clipPath(path);
      for (double y = 0; y < size.height + 20; y += 18) {
        for (double x = 0; x < width + 20; x += 18) {
          final diamond = Path()
            ..moveTo(x + 7, y)
            ..lineTo(x + 14, y + 7)
            ..lineTo(x + 7, y + 14)
            ..lineTo(x, y + 7)
            ..close();
          canvas.drawPath(
              diamond,
              Paint()
                ..color = rank.colors.first.withValues(alpha: .09)
                ..style = PaintingStyle.stroke
                ..strokeWidth = .7);
        }
      }
      canvas.restore();
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(RankBannerPainter oldDelegate) => rank != oldDelegate.rank;
}

class RankBannerPreview extends StatelessWidget {
  const RankBannerPreview({super.key, required this.rank, this.height = 74});
  final RankIdentity rank;
  final double height;
  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
              painter: RankBannerPainter(rank),
              child: Center(
                  child: RankMedal(
                      threshold: rank.threshold, size: height * .45)))));
}

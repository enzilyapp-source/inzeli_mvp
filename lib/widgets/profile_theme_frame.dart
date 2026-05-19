import 'dart:math' as math;

import 'package:flutter/material.dart';

enum ProfileThemeFrame {
  sadu,
  janjfa,
  dama,
  diwaniya,
  fanar,
  nokhatha,
  ice,
  neon,
  royalGold,
  purpleGem,
  warrior,
  lightning,
  sakura,
  wave,
  phoenix,
  galaxy,
  dragon,
  darkRuby,
  angel,
  cyber,
  crystal,
}

class ProfileThemeFrameWidget extends StatefulWidget {
  final ProfileThemeFrame frame;
  final double size;
  final ImageProvider? image;
  final Widget? child;
  final bool animated;

  const ProfileThemeFrameWidget({
    super.key,
    required this.frame,
    this.image,
    this.child,
    this.size = 120,
    this.animated = true,
  }) : assert(image != null || child != null);

  @override
  State<ProfileThemeFrameWidget> createState() =>
      _ProfileThemeFrameWidgetState();
}

class _ProfileThemeFrameWidgetState extends State<ProfileThemeFrameWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    if (widget.animated) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant ProfileThemeFrameWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animated && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animated && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ThemeFrameStyle get style => getProfileThemeFrameStyle(widget.frame);

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final st = style;

    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final t = _controller.value;
        final pulse = 1 + math.sin(t * math.pi * 2) * 0.025;

        return Transform.scale(
          scale: widget.animated ? pulse : 1,
          child: SizedBox(
            width: s,
            height: s,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: s,
                  height: s,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: st.colors.last.withValues(alpha: .65),
                        blurRadius: 28,
                        spreadRadius: 4,
                      ),
                      BoxShadow(
                        color: st.colors.first.withValues(alpha: .35),
                        blurRadius: 45,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                ),
                Transform.rotate(
                  angle: widget.animated ? t * math.pi * 2 : 0,
                  child: CustomPaint(
                    size: Size(s, s),
                    painter: _EnergyRingPainter(
                      colors: st.colors,
                      spikes: st.spikes,
                      strokeWidth: st.strokeWidth,
                    ),
                  ),
                ),
                Transform.rotate(
                  angle: widget.animated ? -t * math.pi * 1.4 : 0,
                  child: CustomPaint(
                    size: Size(s * .92, s * .92),
                    painter: _SparkRingPainter(
                      color: st.sparkColor,
                      count: st.sparkCount,
                    ),
                  ),
                ),
                Container(
                  width: s * .78,
                  height: s * .78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF0B1020),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .12),
                      width: 2,
                    ),
                  ),
                ),
                SizedBox(
                  width: s * .70,
                  height: s * .70,
                  child: widget.child ??
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          image: DecorationImage(
                            image: widget.image!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                ),
                Positioned(
                  top: s * .16,
                  left: s * .22,
                  child: Container(
                    width: s * .18,
                    height: s * .06,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: Colors.white.withValues(alpha: .22),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -4,
                  child: Container(
                    width: s * .31,
                    height: s * .31,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: st.colors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .9),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: st.colors.last.withValues(alpha: .7),
                          blurRadius: 16,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      st.icon,
                      color: Colors.white,
                      size: s * .16,
                    ),
                  ),
                ),
                if (st.topIcon != null)
                  Positioned(
                    top: -s * .08,
                    child: Icon(
                      st.topIcon,
                      color: st.colors.last,
                      size: s * .26,
                      shadows: [
                        Shadow(
                          color: st.colors.last.withValues(alpha: .9),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ThemeFrameStyle {
  final String name;
  final String description;
  final List<Color> colors;
  final Color sparkColor;
  final IconData icon;
  final IconData? topIcon;
  final int spikes;
  final int sparkCount;
  final double strokeWidth;

  const ThemeFrameStyle({
    required this.name,
    required this.description,
    required this.colors,
    required this.sparkColor,
    required this.icon,
    this.topIcon,
    this.spikes = 18,
    this.sparkCount = 18,
    this.strokeWidth = 7,
  });
}

ThemeFrameStyle getProfileThemeFrameStyle(ProfileThemeFrame frame) {
  switch (frame) {
    case ProfileThemeFrame.sadu:
      return const ThemeFrameStyle(
        name: 'سدو',
        description: 'تراث',
        colors: [Color(0xFF7F1D1D), Color(0xFFDC2626), Color(0xFFF59E0B)],
        sparkColor: Color(0xFFFFD166),
        icon: Icons.texture,
        topIcon: Icons.auto_awesome,
        spikes: 24,
        sparkCount: 22,
      );
    case ProfileThemeFrame.janjfa:
      return const ThemeFrameStyle(
        name: 'جنجفة',
        description: 'ورق',
        colors: [Color(0xFF111827), Color(0xFFB91C1C), Color(0xFFFFFFFF)],
        sparkColor: Color(0xFFFFE5E5),
        icon: Icons.style,
        topIcon: Icons.casino,
        spikes: 18,
        sparkCount: 18,
      );
    case ProfileThemeFrame.dama:
      return const ThemeFrameStyle(
        name: 'دامة',
        description: 'ذكاء',
        colors: [Color(0xFF111111), Color(0xFFFFFFFF), Color(0xFFD4AF37)],
        sparkColor: Color(0xFFFFF3CD),
        icon: Icons.grid_view_rounded,
        topIcon: Icons.blur_on,
        spikes: 14,
        sparkCount: 16,
      );
    case ProfileThemeFrame.diwaniya:
      return const ThemeFrameStyle(
        name: 'ديوانية',
        description: 'قهوة',
        colors: [Color(0xFF3E2723), Color(0xFF8D6E63), Color(0xFFD7B899)],
        sparkColor: Color(0xFFF3D9C3),
        icon: Icons.coffee,
        topIcon: Icons.weekend,
        spikes: 16,
        sparkCount: 20,
      );
    case ProfileThemeFrame.fanar:
      return const ThemeFrameStyle(
        name: 'فنر',
        description: 'نور',
        colors: [Color(0xFF5B3716), Color(0xFFD4A373), Color(0xFFFFD166)],
        sparkColor: Color(0xFFFFF0B3),
        icon: Icons.light_mode,
        topIcon: Icons.wb_incandescent_rounded,
        spikes: 22,
        sparkCount: 24,
      );
    case ProfileThemeFrame.nokhatha:
      return const ThemeFrameStyle(
        name: 'نوخذة',
        description: 'بحر',
        colors: [Color(0xFF023047), Color(0xFF219EBC), Color(0xFF8ECAE6)],
        sparkColor: Color(0xFFD7F3FF),
        icon: Icons.sailing,
        topIcon: Icons.explore,
        spikes: 20,
        sparkCount: 26,
      );
    case ProfileThemeFrame.ice:
      return const ThemeFrameStyle(
        name: 'بارد',
        description: 'ثلجي',
        colors: [Color(0xFFBDEBFF), Color(0xFF4CC9F0), Color(0xFF3A86FF)],
        sparkColor: Color(0xFFDFF8FF),
        icon: Icons.diamond,
        topIcon: Icons.ac_unit,
      );
    case ProfileThemeFrame.neon:
      return const ThemeFrameStyle(
        name: 'فلاش',
        description: 'لمعة',
        colors: [Color(0xFF00F5D4), Color(0xFF00BBF9), Color(0xFF00A896)],
        sparkColor: Color(0xFF7CFFE8),
        icon: Icons.bolt,
      );
    case ProfileThemeFrame.royalGold:
      return const ThemeFrameStyle(
        name: 'ذهبي',
        description: 'فخم',
        colors: [Color(0xFF8C5A00), Color(0xFFFFD166), Color(0xFFFFB703)],
        sparkColor: Color(0xFFFFF2B8),
        icon: Icons.workspace_premium,
        topIcon: Icons.emoji_events,
        spikes: 14,
      );
    case ProfileThemeFrame.purpleGem:
      return const ThemeFrameStyle(
        name: 'هيبة',
        description: 'غامج',
        colors: [Color(0xFF3A0CA3), Color(0xFF8338EC), Color(0xFFC77DFF)],
        sparkColor: Color(0xFFE0AAFF),
        icon: Icons.diamond,
        topIcon: Icons.change_history,
      );
    case ProfileThemeFrame.warrior:
      return const ThemeFrameStyle(
        name: 'وحش',
        description: 'قوي',
        colors: [Color(0xFF111827), Color(0xFFEF233C), Color(0xFFFF6B35)],
        sparkColor: Color(0xFFFF3D3D),
        icon: Icons.local_fire_department,
        spikes: 22,
      );
    case ProfileThemeFrame.lightning:
      return const ThemeFrameStyle(
        name: 'صاك',
        description: 'برق',
        colors: [Color(0xFF023E8A), Color(0xFF3A86FF), Color(0xFF90E0EF)],
        sparkColor: Color(0xFFCAF0F8),
        icon: Icons.flash_on,
        spikes: 24,
      );
    case ProfileThemeFrame.sakura:
      return const ThemeFrameStyle(
        name: 'وردي',
        description: 'ناعم',
        colors: [Color(0xFFFFAFCC), Color(0xFFFF4D8D), Color(0xFFFFC8DD)],
        sparkColor: Color(0xFFFFE5EC),
        icon: Icons.local_florist,
        topIcon: Icons.filter_vintage,
        spikes: 12,
        sparkCount: 28,
      );
    case ProfileThemeFrame.wave:
      return const ThemeFrameStyle(
        name: 'مد',
        description: 'بحري',
        colors: [Color(0xFF0077B6), Color(0xFF00B4D8), Color(0xFFCAF0F8)],
        sparkColor: Color(0xFFBDEFFF),
        icon: Icons.water,
        spikes: 20,
      );
    case ProfileThemeFrame.phoenix:
      return const ThemeFrameStyle(
        name: 'شعلة',
        description: 'حار',
        colors: [Color(0xFFD00000), Color(0xFFFB5607), Color(0xFFFFBE0B)],
        sparkColor: Color(0xFFFFDD8A),
        icon: Icons.whatshot,
        topIcon: Icons.local_fire_department,
        spikes: 26,
      );
    case ProfileThemeFrame.galaxy:
      return const ThemeFrameStyle(
        name: 'فضا',
        description: 'نجمي',
        colors: [Color(0xFF240046), Color(0xFF7209B7), Color(0xFF4CC9F0)],
        sparkColor: Color(0xFFC77DFF),
        icon: Icons.stars,
        topIcon: Icons.public,
        spikes: 16,
        sparkCount: 30,
      );
    case ProfileThemeFrame.dragon:
      return const ThemeFrameStyle(
        name: 'صامل',
        description: 'ناري',
        colors: [Color(0xFF6A040F), Color(0xFFFFBA08), Color(0xFFF48C06)],
        sparkColor: Color(0xFFFFD166),
        icon: Icons.local_fire_department,
        topIcon: Icons.auto_awesome,
        spikes: 28,
      );
    case ProfileThemeFrame.darkRuby:
      return const ThemeFrameStyle(
        name: 'كحل',
        description: 'غامق',
        colors: [Color(0xFF03071E), Color(0xFF6A040F), Color(0xFFDC2F02)],
        sparkColor: Color(0xFFFF3C38),
        icon: Icons.diamond,
        spikes: 24,
      );
    case ProfileThemeFrame.angel:
      return const ThemeFrameStyle(
        name: 'صافي',
        description: 'نقي',
        colors: [Color(0xFFEAF4F4), Color(0xFFB8C0FF), Color(0xFFFFFFFF)],
        sparkColor: Color(0xFFFFFFFF),
        icon: Icons.diamond,
        topIcon: Icons.auto_awesome,
        spikes: 18,
      );
    case ProfileThemeFrame.cyber:
      return const ThemeFrameStyle(
        name: 'تكنو',
        description: 'رقمي',
        colors: [Color(0xFF00BBF9), Color(0xFF4361EE), Color(0xFFF72585)],
        sparkColor: Color(0xFF4CC9F0),
        icon: Icons.memory,
        topIcon: Icons.hub,
        spikes: 20,
      );
    case ProfileThemeFrame.crystal:
      return const ThemeFrameStyle(
        name: 'لؤلؤ',
        description: 'لمعة',
        colors: [Color(0xFFFFAFCC), Color(0xFFB5179E), Color(0xFFF72585)],
        sparkColor: Color(0xFFFFC8DD),
        icon: Icons.diamond,
        topIcon: Icons.change_history,
        spikes: 16,
      );
  }
}

ProfileThemeFrame? profileThemeFrameById(String? id) {
  switch (id) {
    case 'frame_sadu':
      return ProfileThemeFrame.sadu;
    case 'frame_janjfa':
      return ProfileThemeFrame.janjfa;
    case 'frame_dama':
      return ProfileThemeFrame.dama;
    case 'frame_diwaniya':
      return ProfileThemeFrame.diwaniya;
    case 'frame_fanar':
      return ProfileThemeFrame.fanar;
    case 'frame_nokhatha':
      return ProfileThemeFrame.nokhatha;
    case 'frame_ice':
      return ProfileThemeFrame.ice;
    case 'frame_neon':
      return ProfileThemeFrame.neon;
    case 'frame_royalGold':
      return ProfileThemeFrame.royalGold;
    case 'frame_purpleGem':
      return ProfileThemeFrame.purpleGem;
    case 'frame_warrior':
      return ProfileThemeFrame.warrior;
    case 'frame_lightning':
      return ProfileThemeFrame.lightning;
    case 'frame_sakura':
      return ProfileThemeFrame.sakura;
    case 'frame_wave':
      return ProfileThemeFrame.wave;
    case 'frame_phoenix':
      return ProfileThemeFrame.phoenix;
    case 'frame_galaxy':
      return ProfileThemeFrame.galaxy;
    case 'frame_dragon':
      return ProfileThemeFrame.dragon;
    case 'frame_darkRuby':
      return ProfileThemeFrame.darkRuby;
    case 'frame_angel':
      return ProfileThemeFrame.angel;
    case 'frame_cyber':
      return ProfileThemeFrame.cyber;
    case 'frame_crystal':
      return ProfileThemeFrame.crystal;
    default:
      return null;
  }
}

class _EnergyRingPainter extends CustomPainter {
  final List<Color> colors;
  final int spikes;
  final double strokeWidth;

  _EnergyRingPainter({
    required this.colors,
    required this.spikes,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - strokeWidth;

    final ringPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.white.withValues(alpha: .85),
          ...colors,
          Colors.white.withValues(alpha: .85),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, ringPaint);

    final spikePaint = Paint()
      ..shader = SweepGradient(colors: colors).createShader(
        Rect.fromCircle(center: center, radius: radius),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * .55
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < spikes; i++) {
      final a = (math.pi * 2 / spikes) * i;
      final start = Offset(
        center.dx + math.cos(a) * (radius - 2),
        center.dy + math.sin(a) * (radius - 2),
      );
      final end = Offset(
        center.dx + math.cos(a) * (radius + 10),
        center.dy + math.sin(a) * (radius + 10),
      );

      canvas.drawLine(start, end, spikePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _EnergyRingPainter oldDelegate) => true;
}

class _SparkRingPainter extends CustomPainter {
  final Color color;
  final int count;

  _SparkRingPainter({
    required this.color,
    required this.count,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 4;

    final paint = Paint()
      ..color = color.withValues(alpha: .85)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < count; i++) {
      final a = (math.pi * 2 / count) * i;
      final r = i.isEven ? radius : radius - 8;

      final p = Offset(
        center.dx + math.cos(a) * r,
        center.dy + math.sin(a) * r,
      );

      canvas.drawCircle(p, i.isEven ? 2.2 : 1.2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkRingPainter oldDelegate) => true;
}

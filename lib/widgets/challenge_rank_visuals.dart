import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'avatar_effects.dart';
import 'profile_theme_frame.dart';

enum PlayerRank {
  beginner,
  advance,
  professional,
  legend,
  goat,
}

class RankData {
  final String english;
  final String arabic;
  final IconData icon;
  final List<Color> colors;

  const RankData({
    required this.english,
    required this.arabic,
    required this.icon,
    required this.colors,
  });
}

RankData getRankData(PlayerRank rank) {
  switch (rank) {
    case PlayerRank.beginner:
      return const RankData(
        english: 'Beginner',
        arabic: 'عليمي',
        icon: Icons.sentiment_satisfied_alt,
        colors: [
          Color(0xFF5C677D),
          Color(0xFFA5B4CB),
        ],
      );
    case PlayerRank.advance:
      return const RankData(
        english: 'Advance',
        arabic: 'يمشي حاله',
        icon: Icons.sports_esports,
        colors: [
          Color(0xFF1B998B),
          Color(0xFF55D6BE),
        ],
      );
    case PlayerRank.professional:
      return const RankData(
        english: 'Professional',
        arabic: 'زين',
        icon: Icons.workspace_premium,
        colors: [
          Color(0xFFE09F3E),
          Color(0xFFFFD166),
        ],
      );
    case PlayerRank.legend:
      return const RankData(
        english: 'Legend',
        arabic: 'فنان',
        icon: Icons.local_fire_department,
        colors: [
          Color(0xFF9D4EDD),
          Color(0xFFF72585),
        ],
      );
    case PlayerRank.goat:
      return const RankData(
        english: 'GOAT',
        arabic: 'فلتة',
        icon: Icons.auto_awesome,
        colors: [
          Color(0xFFFFD700),
          Color(0xFFFF006E),
          Color(0xFF8338EC),
        ],
      );
  }
}

PlayerRank playerRankForPearls(int pearls) {
  if (pearls >= 30) return PlayerRank.goat;
  if (pearls >= 20) return PlayerRank.legend;
  if (pearls >= 15) return PlayerRank.professional;
  if (pearls >= 10) return PlayerRank.advance;
  return PlayerRank.beginner;
}

PlayerRank playerRankForThreshold(int threshold) {
  return playerRankForPearls(threshold);
}

PlayerRank playerRankForLabel(String? label) {
  switch ((label ?? '').trim()) {
    case 'GOAT':
    case 'فلتة':
    case 'فلته':
      return PlayerRank.goat;
    case 'Legend':
    case 'فنان':
      return PlayerRank.legend;
    case 'Professional':
    case 'زين':
      return PlayerRank.professional;
    case 'Advance':
    case 'يمشي حاله':
      return PlayerRank.advance;
    case 'Beginner':
    case 'عليمي':
    default:
      return PlayerRank.beginner;
  }
}

class ThemeVisualOption {
  final String id;
  final String label;
  final AvatarEffectType? effect;
  final PlayerRank? rank;
  final ProfileThemeFrame? frame;
  final String? description;
  final int? unlockThreshold;
  final bool vipOnly;

  const ThemeVisualOption({
    required this.id,
    required this.label,
    this.effect,
    this.rank,
    this.frame,
    this.description,
    this.unlockThreshold,
    this.vipOnly = false,
  });
}

const String kVipMonthlyItemId = 'vip_monthly';
const Set<String> kVipThemeIds = {
  'frame_sadu',
  'frame_janjfa',
  'frame_dama',
  'frame_diwaniya',
  'frame_fanar',
  'frame_nokhatha',
};

const List<ThemeVisualOption> kThemeVisualOptions = [
  ThemeVisualOption(
    id: 'frame_sadu',
    label: 'سدو',
    frame: ProfileThemeFrame.sadu,
    description: 'تراث',
    vipOnly: true,
  ),
  ThemeVisualOption(
    id: 'frame_janjfa',
    label: 'جنجفة',
    frame: ProfileThemeFrame.janjfa,
    description: 'ورق',
    vipOnly: true,
  ),
  ThemeVisualOption(
    id: 'frame_dama',
    label: 'دامة',
    frame: ProfileThemeFrame.dama,
    description: 'ذكاء',
    vipOnly: true,
  ),
  ThemeVisualOption(
    id: 'frame_diwaniya',
    label: 'ديوانية',
    frame: ProfileThemeFrame.diwaniya,
    description: 'قهوة',
    vipOnly: true,
  ),
  ThemeVisualOption(
    id: 'frame_fanar',
    label: 'فنر',
    frame: ProfileThemeFrame.fanar,
    description: 'نور',
    vipOnly: true,
  ),
  ThemeVisualOption(
    id: 'frame_nokhatha',
    label: 'نوخذة',
    frame: ProfileThemeFrame.nokhatha,
    description: 'بحر',
    vipOnly: true,
  ),
  ThemeVisualOption(
    id: 'blueThunder',
    label: 'لعيب',
    effect: AvatarEffectType.blueThunder,
  ),
  ThemeVisualOption(
    id: 'goldLightning',
    label: 'ذهبي',
    effect: AvatarEffectType.goldLightning,
  ),
  ThemeVisualOption(
    id: 'kuwait',
    label: 'ديرتي',
    effect: AvatarEffectType.kuwaitSparkles,
  ),
  ThemeVisualOption(
    id: 'greenLeaf',
    label: 'روق',
    effect: AvatarEffectType.greenLeaf,
  ),
  ThemeVisualOption(
    id: 'flameBlue',
    label: 'وله',
    effect: AvatarEffectType.flameBlue,
  ),
  ThemeVisualOption(
    id: 'whiteSparkle',
    label: 'سنا',
    effect: AvatarEffectType.whiteSparkle,
  ),
  ThemeVisualOption(
    id: 'frame_ice',
    label: 'بارد',
    frame: ProfileThemeFrame.ice,
    description: 'ثلجي',
  ),
  ThemeVisualOption(
    id: 'frame_neon',
    label: 'فلاش',
    frame: ProfileThemeFrame.neon,
    description: 'لمعة',
  ),
  ThemeVisualOption(
    id: 'frame_royalGold',
    label: 'ذهبي',
    frame: ProfileThemeFrame.royalGold,
    description: 'فخم',
  ),
  ThemeVisualOption(
    id: 'frame_purpleGem',
    label: 'هيبة',
    frame: ProfileThemeFrame.purpleGem,
    description: 'غامج',
  ),
  ThemeVisualOption(
    id: 'frame_warrior',
    label: 'وحش',
    frame: ProfileThemeFrame.warrior,
    description: 'قوي',
  ),
  ThemeVisualOption(
    id: 'frame_lightning',
    label: 'صاك',
    frame: ProfileThemeFrame.lightning,
    description: 'برق',
  ),
  ThemeVisualOption(
    id: 'frame_sakura',
    label: 'وردي',
    frame: ProfileThemeFrame.sakura,
    description: 'ناعم',
  ),
  ThemeVisualOption(
    id: 'frame_wave',
    label: 'مد',
    frame: ProfileThemeFrame.wave,
    description: 'بحري',
  ),
  ThemeVisualOption(
    id: 'frame_phoenix',
    label: 'شعلة',
    frame: ProfileThemeFrame.phoenix,
    description: 'حار',
  ),
  ThemeVisualOption(
    id: 'frame_galaxy',
    label: 'فضا',
    frame: ProfileThemeFrame.galaxy,
    description: 'نجمي',
  ),
  ThemeVisualOption(
    id: 'frame_dragon',
    label: 'صامل',
    frame: ProfileThemeFrame.dragon,
    description: 'ناري',
  ),
  ThemeVisualOption(
    id: 'frame_darkRuby',
    label: 'كحل',
    frame: ProfileThemeFrame.darkRuby,
    description: 'غامق',
  ),
  ThemeVisualOption(
    id: 'frame_angel',
    label: 'صافي',
    frame: ProfileThemeFrame.angel,
    description: 'نقي',
  ),
  ThemeVisualOption(
    id: 'frame_cyber',
    label: 'تكنو',
    frame: ProfileThemeFrame.cyber,
    description: 'رقمي',
  ),
  ThemeVisualOption(
    id: 'frame_crystal',
    label: 'لؤلؤ',
    frame: ProfileThemeFrame.crystal,
    description: 'لمعة',
  ),
  ThemeVisualOption(
    id: 'rank_beginner',
    label: 'نوط عليمي',
    rank: PlayerRank.beginner,
    unlockThreshold: 5,
  ),
  ThemeVisualOption(
    id: 'rank_advance',
    label: 'نوط يمشي حاله',
    rank: PlayerRank.advance,
    unlockThreshold: 10,
  ),
  ThemeVisualOption(
    id: 'rank_professional',
    label: 'نوط زين',
    rank: PlayerRank.professional,
    unlockThreshold: 15,
  ),
  ThemeVisualOption(
    id: 'rank_legend',
    label: 'نوط فنان',
    rank: PlayerRank.legend,
    unlockThreshold: 20,
  ),
  ThemeVisualOption(
    id: 'rank_goat',
    label: 'نوط فلتة',
    rank: PlayerRank.goat,
    unlockThreshold: 30,
  ),
];

ThemeVisualOption? themeVisualById(String? id) {
  if (id == null || id.trim().isEmpty) return null;
  for (final option in kThemeVisualOptions) {
    if (option.id == id) return option;
  }
  return null;
}

Widget buildAvatarThemeWidget({
  required String? themeId,
  required Widget child,
  required double size,
  bool animate = true,
}) {
  final option = themeVisualById(themeId);
  if (option == null) return child;
  if (option.rank != null) {
    return ChallengeAvatarFrame(
      rank: option.rank!,
      size: size,
      animate: animate,
      childSizeFactor: 0.78,
      child: child,
    );
  }
  if (option.frame != null) {
    return ProfileThemeFrameWidget(
      frame: option.frame!,
      size: size,
      animated: animate,
      child: child,
    );
  }
  if (option.effect != null) {
    return AvatarEffect(
      effect: option.effect!,
      size: size,
      animate: animate,
      child: child,
    );
  }
  return child;
}

class RankBadge extends StatelessWidget {
  final PlayerRank rank;
  final bool compact;

  const RankBadge({
    super.key,
    required this.rank,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final data = getRankData(rank);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            data.colors.first.withValues(alpha: 0.25),
            data.colors.last.withValues(alpha: 0.16),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: data.colors.last.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            data.icon,
            size: compact ? 14 : 16,
            color: data.colors.last,
          ),
          const SizedBox(width: 6),
          Text(
            data.arabic,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: compact ? 13 : 14,
              color: data.colors.last,
            ),
          ),
        ],
      ),
    );
  }
}

class ChallengeAvatarFrame extends StatefulWidget {
  final Widget child;
  final double size;
  final PlayerRank rank;
  final bool animate;
  final Duration duration;
  final double childSizeFactor;

  const ChallengeAvatarFrame({
    super.key,
    required this.child,
    required this.rank,
    this.size = 110,
    this.animate = true,
    this.duration = const Duration(seconds: 5),
    this.childSizeFactor = 0.84,
  });

  @override
  State<ChallengeAvatarFrame> createState() => _ChallengeAvatarFrameState();
}

class _ChallengeAvatarFrameState extends State<ChallengeAvatarFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    if (widget.animate) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant ChallengeAvatarFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = getRankData(widget.rank);
    final s = widget.size;

    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return SizedBox(
          width: s,
          height: s,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Transform.rotate(
                angle: widget.animate ? _controller.value * math.pi * 2 : 0,
                child: Container(
                  width: s,
                  height: s,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        Colors.white,
                        ...data.colors,
                        Colors.white,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: data.colors.last.withValues(alpha: 0.5),
                        blurRadius: 24,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: s - 10,
                height: s - 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF0B1020),
                ),
              ),
              SizedBox(
                width: s * widget.childSizeFactor,
                height: s * widget.childSizeFactor,
                child: Center(child: widget.child),
              ),
              Positioned(
                bottom: -2,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: data.colors),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: data.colors.last.withValues(alpha: 0.3),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    data.icon,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

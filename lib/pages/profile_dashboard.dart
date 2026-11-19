part of 'profile_page.dart';

const _profileAmber = Color(0xFFFFAF27);

/// Native surfaces and medals keep the profile sharp on phones and foldables.
/// All values come from AppState; the reference mockup's sample XP is not used.
class _ProfilePanel extends StatelessWidget {
  const _ProfilePanel(
      {super.key,
      required this.title,
      required this.icon,
      required this.child,
      required this.actionLabel,
      required this.onAction,
      this.onTitleTap});
  final String title, actionLabel;
  final IconData icon;
  final Widget child;
  final VoidCallback onAction;
  final VoidCallback? onTitleTap;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: _profileSurface(),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
                child: InkWell(
              onTap: onTitleTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    Icon(icon, color: _profileAmber, size: 26),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(title,
                            style: const TextStyle(
                                fontSize: 19, fontWeight: FontWeight.w800))),
                  ])),
            )),
            const SizedBox(width: 8),
            TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF6E8D9D)),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(44, 40)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(actionLabel,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, size: 18),
                ])),
          ]),
          const SizedBox(height: 10),
          child,
        ]),
      );
}

BoxDecoration _profileSurface({bool bright = false}) => BoxDecoration(
      gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: bright
              ? const [Color(0xFF215467), Color(0xFF18364B)]
              : const [Color(0xFF1B394D), Color(0xFF112337)]),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFF718B9B).withValues(alpha: .38)),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withValues(alpha: .12),
            blurRadius: 14,
            offset: const Offset(0, 6))
      ],
    );

class _ProfileHero extends StatelessWidget {
  const _ProfileHero(
      {required this.app,
      required this.name,
      required this.handle,
      required this.avatar,
      required this.themeId,
      required this.background,
      required this.game,
      required this.threshold,
      required this.rankLabel,
      required this.nextThreshold,
      required this.onSettings,
      required this.onAvatar,
      required this.onRank});
  final AppState app;
  final String name, handle, rankLabel;
  final String? themeId;
  final ImageProvider? avatar;
  final Color background;
  final _ProfileGameSummary game;
  final int threshold;
  final int? nextThreshold;
  final VoidCallback onSettings, onAvatar, onRank;

  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: .12)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: .2),
                  blurRadius: 18,
                  offset: const Offset(0, 8))
            ]),
        child: CustomPaint(
            painter: rankIdentityForBanner(app.cardId) != null
                ? RankBannerPainter(rankIdentityForBanner(app.cardId)!)
                : const _ProfileWavePainter(),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                Row(
                    textDirection: TextDirection.ltr,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      OutlinedButton.icon(
                          onPressed: onRank,
                          style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Color(0xFF778797)),
                              shape: const StadiumBorder()),
                          icon: RankMedal(threshold: threshold, size: 24),
                          label: Text(rankLabel,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800))),
                      IconButton.filledTonal(
                          onPressed: onSettings,
                          tooltip: app.tr(ar: 'الإعدادات', en: 'Settings'),
                          style: IconButton.styleFrom(
                              backgroundColor:
                                  Colors.white.withValues(alpha: .08),
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Color(0xFF596E81))),
                          icon: const Icon(Icons.settings_outlined)),
                    ]),
                // The avatar is in normal flow, so names and accessibility text can grow.
                Stack(alignment: Alignment.bottomRight, children: [
                  Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: (themeId?.startsWith('reward_') ?? false)
                              ? null
                              : const LinearGradient(colors: [
                                  Color(0xFFF4F7FC),
                                  Color(0xFF69788E),
                                  Color(0xFFE2E8F1)
                                ])),
                      child: buildAvatarThemeWidget(
                          themeId: themeId,
                          size: 106,
                          animate: true,
                          child: CircleAvatar(
                              radius: 46,
                              backgroundImage: avatar,
                              backgroundColor: const Color(0xFF283347),
                              child: avatar == null
                                  ? Text(
                                      name.isEmpty
                                          ? '؟'
                                          : name.characters.first,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 38,
                                          fontWeight: FontWeight.w800))
                                  : null))),
                  Material(
                      color: const Color(0xFF35475B),
                      shape: const CircleBorder(),
                      child: IconButton(
                          onPressed: onAvatar,
                          tooltip: app.tr(
                              ar: 'تعديل الصورة والثيم',
                              en: 'Edit photo and theme'),
                          constraints:
                              const BoxConstraints(minWidth: 44, minHeight: 44),
                          icon: const Icon(Icons.edit_outlined,
                              size: 20, color: Colors.white))),
                ]),
                const SizedBox(height: 10),
                Text(name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 25, fontWeight: FontWeight.w800)),
                if (handle.isNotEmpty)
                  Text(handle,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                          color: Color(0xFFAFBDCC), fontSize: 13)),
                const SizedBox(height: 8),
                InkWell(
                    onTap: onRank,
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .07),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.white24)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          _ProfileMedal(threshold: threshold, size: 32),
                          const SizedBox(width: 6),
                          Text(
                              app.tr(
                                  ar: 'المستوى: $rankLabel',
                                  en: 'Level: $rankLabel'),
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700)),
                        ]))),
                const SizedBox(height: 14),
                Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .05),
                        borderRadius: BorderRadius.circular(19),
                        border: Border.all(color: Colors.white12)),
                    child: LayoutBuilder(builder: (context, constraints) {
                      final balance =
                          Column(mainAxisSize: MainAxisSize.min, children: [
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Image.asset('lib/assets/pearl.png',
                              width: 25, height: 25),
                          const SizedBox(width: 6),
                          Flexible(
                              child: Text('${app.pearls}',
                                  style: const TextStyle(
                                      fontSize: 23,
                                      fontWeight: FontWeight.w800))),
                        ]),
                        Text(app.tr(ar: 'رصيد اللآلئ', en: 'Pearl balance'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.white70)),
                      ]);
                      final progress = Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                                game.gameId.isEmpty
                                    ? app.tr(
                                        ar: 'ابدأ أول مباراة',
                                        en: 'Play your first match')
                                    : game.label,
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 3),
                            Text(
                                nextThreshold == null
                                    ? app.tr(
                                        ar: 'وصلت لأعلى مستوى',
                                        en: 'Top level reached')
                                    : app.tr(
                                        ar:
                                            '${game.badgeProgress} / $nextThreshold حتى المستوى التالي',
                                        en:
                                            '${game.badgeProgress} / $nextThreshold to next level'),
                                style: const TextStyle(
                                    fontSize: 10, color: Color(0xFFB6C7D7))),
                            const SizedBox(height: 6),
                            LinearProgressIndicator(
                                value:
                                    (game.badgeProgress / (nextThreshold ?? 30))
                                        .clamp(0.0, 1.0),
                                minHeight: 7,
                                borderRadius: BorderRadius.circular(12),
                                backgroundColor: Colors.white12,
                                color: _profileAmber),
                          ]);
                      if (constraints.maxWidth < 280 ||
                          MediaQuery.textScalerOf(context).scale(1) > 1.3) {
                        return Column(children: [
                          balance,
                          const SizedBox(height: 12),
                          progress
                        ]);
                      }
                      return Row(children: [
                        Expanded(flex: 3, child: progress),
                        Container(
                            width: 1,
                            height: 35,
                            color: Colors.white24,
                            margin: const EdgeInsets.symmetric(horizontal: 12)),
                        Flexible(flex: 2, child: balance)
                      ]);
                    })),
              ]),
            )),
      );
}

class _ProfileWavePainter extends CustomPainter {
  const _ProfileWavePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height * .42)
      ..cubicTo(size.width * .32, size.height * .08, size.width * .66,
          size.height * .89, size.width, size.height * .3)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
        path,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF102D41), Color(0xFF0C1B2D)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ).createShader(Offset.zero & size));
  }

  @override
  bool shouldRepaint(_ProfileWavePainter oldDelegate) => false;
}

class _ProfileStats extends StatelessWidget {
  const _ProfileStats(
      {required this.app, required this.wins, required this.losses});
  final AppState app;
  final int wins, losses;
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final items = [
          (
            Icons.sports_esports_outlined,
            app.tr(ar: 'عدد الألعاب', en: 'Games'),
            wins + losses
          ),
          (
            Icons.emoji_events_outlined,
            app.tr(ar: 'الانتصارات', en: 'Wins'),
            wins
          ),
          (Icons.cancel_outlined, app.tr(ar: 'الهزائم', en: 'Losses'), losses),
        ];
        final stacked = constraints.maxWidth < 270 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.3;
        final width =
            stacked ? constraints.maxWidth : (constraints.maxWidth - 16) / 3;
        return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items
                .map((item) => Container(
                      width: width,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 12),
                      decoration: _profileSurface(bright: true),
                      child: Column(children: [
                        Icon(item.$1, color: Colors.white, size: 27),
                        const SizedBox(height: 8),
                        Text(item.$2,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 5),
                        Text('${item.$3}',
                            style: const TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.w800,
                                color: _profileAmber)),
                      ]),
                    ))
                .toList());
      });
}

/// Rank thresholds retain the existing 5/10/15/20/30 achievement rules.
/// Metallic shields are drawn natively rather than stretching the icon sheet.
class _ProfileMedal extends StatelessWidget {
  const _ProfileMedal(
      {required this.threshold, this.size = 58, this.locked = false});
  final int threshold;
  final double size;
  final bool locked;
  @override
  Widget build(BuildContext context) =>
      RankMedal(threshold: threshold, size: size, locked: locked);
}

class _ProfileMedals extends StatelessWidget {
  const _ProfileMedals(
      {required this.app, required this.badges, required this.onTap});
  final AppState app;
  final List<_EarnedBadgeEntry> badges;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: LayoutBuilder(builder: (context, constraints) {
              // Earned medals only; locked slots never imply an unearned award.
              final visible = badges.take(5).toList();
              return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(5, (i) {
                    final badge = i < visible.length ? visible[i] : null;
                    final label = badge == null
                        ? app.tr(ar: 'وسام مقفل', en: 'Locked medal')
                        : '${badge.badgeLabel} • ${badge.gameLabel}';
                    return Tooltip(
                        message: label,
                        child: Semantics(
                            label: label,
                            image: true,
                            child: ExcludeSemantics(
                                child: _ProfileMedal(
                                    threshold: badge?.threshold ?? 5,
                                    locked: badge == null,
                                    size: math.min(
                                        58, constraints.maxWidth / 5 - 6)))));
                  }));
            })),
      );
}

class _ProfileRecentGames extends StatelessWidget {
  const _ProfileRecentGames(
      {required this.app, required this.matches, required this.onTap});
  final AppState app;
  final List<_AchievementEntry> matches;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
              app.tr(
                  ar: 'أول مباراة لك بتظهر هنا',
                  en: 'Your first match will appear here'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFADBDCD))));
    }
    return Column(
        children: matches
            .map((match) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color: Colors.white.withValues(alpha: .035),
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                        onTap: onTap,
                        borderRadius: BorderRadius.circular(18),
                        child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(children: [
                              if (_profileGameAssetById[match.gameId]
                                  case final asset?)
                                Image.asset(asset,
                                    width: 34,
                                    height: 38,
                                    fit: BoxFit.contain,
                                    cacheWidth: 102)
                              else
                                const Icon(Icons.style_outlined,
                                    size: 28, color: Colors.white),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(match.game,
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 4),
                                    Text(
                                        '${match.date.day}/${match.date.month}/${match.date.year}',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFFADBDCD))),
                                  ])),
                              const SizedBox(width: 8),
                              Flexible(
                                  child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 9, vertical: 5),
                                      decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(30),
                                          border: Border.all(
                                              color: match.isWin
                                                  ? _profileAmber
                                                  : const Color(0xFFFF806D))),
                                      child: Text(match.outcomeLabel,
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: match.isWin
                                                  ? _profileAmber
                                                  : const Color(0xFFFFA092))))),
                              const Icon(Icons.chevron_left_rounded,
                                  size: 20, color: Colors.white70),
                            ]))),
                  ),
                ))
            .toList());
  }
}

class _ProfileMenuTile extends StatelessWidget {
  const _ProfileMenuTile(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Container(
        decoration: _profileSurface(),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          child: ListTile(
              onTap: onTap,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
              leading: Icon(icon, color: Colors.white, size: 30),
              title: Text(title,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800)),
              subtitle: Text(subtitle,
                  style:
                      const TextStyle(color: Color(0xFFADBDCD), fontSize: 12)),
              trailing: const Icon(Icons.chevron_left_rounded,
                  color: Colors.white70)),
        ),
      );
}

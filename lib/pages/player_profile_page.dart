//player_profile_page.dart
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../state.dart';
import '../widgets/challenge_rank_visuals.dart';

const Map<String, String> _playerProfileGameSvgAssetById = <String, String>{
  'قدم': 'lib/assets/games_svg/games-01.svg',
  'طائره': 'lib/assets/games_svg/games-02.svg',
  'سله': 'lib/assets/games_svg/games-03.svg',
  'دفان': 'lib/assets/games_svg/games-26.svg',
  'تنس ارضي': 'lib/assets/games_svg/games-05.svg',
  'بيبيفوت': 'lib/assets/games_svg/games-06.svg',
  'بادل': 'lib/assets/games_svg/games-07.svg',
  'بلوت': 'lib/assets/games_svg/games-24.svg',
  'هند': 'lib/assets/games_svg/games-09.svg',
  'كوت': 'lib/assets/games_svg/games-08.svg',
  'سبيتة': 'lib/assets/games_svg/games-25.svg',
  'بولنج': 'lib/assets/games_svg/games-16.svg',
  'بلياردو': 'lib/assets/games_svg/games-15.svg',
  'تنس طاولة': 'lib/assets/games_svg/games-17.svg',
  'شطرنج': 'lib/assets/games_svg/games-18.svg',
  'تريكس': 'lib/assets/games_svg/games-11.svg',
  'دامه': 'lib/assets/games_svg/games-19.svg',
  'كيرم': 'lib/assets/games_svg/games-20.svg',
  'دومنه': 'lib/assets/games_svg/games-21.svg',
  'طاوله': 'lib/assets/games_svg/games-22.svg',
  'اونو': 'lib/assets/games_svg/games-13.svg',
  'جاكارو': 'lib/assets/games_svg/games-23.svg',
};

class PlayerProfilePage extends StatefulWidget {
  final AppState app;
  final String playerName;
  final String? userId;
  const PlayerProfilePage(
      {super.key, required this.app, required this.playerName, this.userId});

  @override
  State<PlayerProfilePage> createState() => _PlayerProfilePageState();
}

class _PlayerProfilePageState extends State<PlayerProfilePage> {
  bool _showAllMatches = false;

  @override
  Widget build(BuildContext context) {
    final playerName = widget.playerName;
    const headerBg = Color(0xFF1E2F4D);
    const cardBg = Color(0xFF132339);
    String norm(String? s) => (s ?? '').trim().toLowerCase();
    final app = widget.app;
    final isMe = widget.userId != null
        ? widget.userId == app.userId
        : norm(playerName) == norm(app.displayName) ||
            norm(playerName) == norm(app.name) ||
            norm(playerName) == norm(app.email) ||
            norm(playerName) == norm(app.userId) ||
            norm(playerName) == norm(app.publicId);
    final isPrivate = (app.profilePrivate ?? false) && !isMe;
    final profileKey =
        widget.userId ?? (isMe ? (app.displayName ?? playerName) : playerName);
    Map<String, dynamic>? backendProfile;
    if (app.userProfiles.containsKey(profileKey)) {
      backendProfile = app.userProfiles[profileKey];
    }
    final p = app.profile(profileKey) ??
        (backendProfile != null
            ? PlayerProfile(
                phone: backendProfile['phone']?.toString(),
                displayName: backendProfile['displayName']?.toString(),
                avatarUrl: backendProfile['avatarUrl']?.toString(),
                avatarBase64: backendProfile['avatarBase64']?.toString(),
                themeId: backendProfile['themeId']?.toString(),
              )
            : null) ??
        (isMe
            ? PlayerProfile(
                phone: app.phone,
                displayName: app.displayName,
                avatarUrl: app.avatarPath,
                avatarBase64: app.avatarBase64,
                themeId: app.themeId,
              )
            : null);
    final stats = app.userStats[profileKey];
    final game = app.selectedGame ?? '';
    final w = (stats?['wins'] as num?)?.toInt() ?? app.winsOf(profileKey, game);
    final l =
        (stats?['losses'] as num?)?.toInt() ?? app.lossesOf(profileKey, game);
    final matches = app.userMatches(profileKey)
      ..sort((a, b) => b.ts.compareTo(a.ts));
    final notFound =
        p == null && stats == null && backendProfile == null && !isMe;
    final publicUsername =
        isMe ? app.username : backendProfile?['username']?.toString();
    final displayId = isMe
        ? (app.publicId ?? app.userId ?? '')
        : (stats?['publicId']?.toString() ?? stats?['id']?.toString() ?? '');

    Map<String, int> pearls = {};
    final gp = stats?['gamePearls'];
    if (gp is Map) {
      pearls =
          gp.map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0));
    } else {
      pearls = app.gamePearls;
    }

    Map<String, int> badgeProgress = {};
    final rawBadgeProgress = stats?['gameBadgeProgress'];
    if (rawBadgeProgress is Map) {
      badgeProgress = rawBadgeProgress.map(
        (k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0),
      );
    } else if (isMe || app.gameBadgeProgress.isNotEmpty) {
      badgeProgress = app.gameBadgeProgress;
    }

    final favoriteGame =
        _favoriteGame(pearls, badgeProgress, matches, profileKey, app);
    final topGame = favoriteGame.label;
    final topPearls = favoriteGame.pearls;
    final rankVisual = playerRankForThreshold(
      AppState.badgeThresholdForPearls(favoriteGame.badgeProgress),
    );
    final earnedBadges = _earnedBadgeEntries(
      badgeProgress.isNotEmpty ? badgeProgress : pearls,
      matches,
      profileKey,
      app,
    );
    final showMoreVisible = matches.length > 10;
    final visibleMatches =
        _showAllMatches ? matches : matches.take(10).toList();

    // avatar & theme
    ImageProvider? avatarImage;
    final avatarB64 =
        backendProfile?['avatarBase64']?.toString() ?? p?.avatarBase64;
    final avatarUrl = backendProfile?['avatarUrl']?.toString() ?? p?.avatarUrl;
    final themeId = backendProfile?['themeId']?.toString() ?? p?.themeId;
    if (avatarB64 != null && avatarB64.isNotEmpty) {
      try {
        avatarImage = MemoryImage(base64Decode(avatarB64));
      } catch (_) {}
    } else if (avatarUrl != null && avatarUrl.isNotEmpty) {
      avatarImage = NetworkImage(avatarUrl);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F1D32),
      appBar: AppBar(title: Text('ملف: $playerName')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Hero card
          Card(
            elevation: 6,
            clipBehavior: Clip.none,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: SizedBox(
              height: 170,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: headerBg,
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    bottom: -18,
                    child: _PearlBadge(
                      game: topGame,
                      pearls: topPearls,
                      size: 62,
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 12,
                    child: _PlayerGameRankBadge(
                      rank: rankVisual,
                      gameId: favoriteGame.gameId,
                      gameLabel: favoriteGame.label,
                    ),
                  ),
                  Positioned(
                    right: 12,
                    bottom: -18,
                    child: _PlayerEarnedBadgeStack(
                      badges: earnedBadges,
                      size: 44,
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        buildAvatarThemeWidget(
                          themeId: themeId,
                          size: 112,
                          animate: true,
                          child: CircleAvatar(
                            radius: 48,
                            backgroundImage: avatarImage,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.12),
                            child: avatarImage == null
                                ? Text(
                                    _initials(playerName),
                                    style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          playerName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                        if (displayId.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            publicUsername != null
                                ? '@$publicUsername'
                                : _shortId(displayId),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .72),
                              fontSize: 12,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          Card(
            color: cardBg,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StatPill(
                      icon: Icons.emoji_events_outlined,
                      label: 'فوز',
                      value: '$w'),
                  _StatPill(
                      icon: Icons.cancel_outlined, label: 'خسارة', value: '$l'),
                  _StatPill(
                      icon: Icons.sports_esports_outlined,
                      label: 'مباريات',
                      value: '${w + l}'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          if (pearls.isNotEmpty)
            Card(
              color: cardBg,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: _PearlCircleGrid(
                  entries: _pearlEntries(pearls, app),
                  maxValue: 30,
                ),
              ),
            ),

          if (!isPrivate && !notFound && matches.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('آخر المباريات',
                style: TextStyle(
                    fontWeight: FontWeight.w900, color: Colors.white70)),
            const SizedBox(height: 6),
            ...visibleMatches.map((t) => Card(
                  color: cardBg,
                  child: ListTile(
                    leading: const Icon(Icons.sports_esports_outlined,
                        color: Colors.white70),
                    title: Text('${t.game} — ${t.roomCode}',
                        style: const TextStyle(color: Colors.white)),
                    subtitle: Directionality(
                      textDirection:
                          app.isEnglish ? TextDirection.ltr : TextDirection.rtl,
                      child: Text(
                        'فائز: ${t.winner} • خاسرون: ${t.losers.join(app.isEnglish ? ', ' : '، ')}\n${t.ts}',
                        maxLines: 2,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75)),
                      ),
                    ),
                  ),
                )),
            if (showMoreVisible)
              Align(
                alignment: Alignment.center,
                child: TextButton.icon(
                  onPressed: () =>
                      setState(() => _showAllMatches = !_showAllMatches),
                  icon: Icon(
                      _showAllMatches ? Icons.expand_less : Icons.expand_more),
                  label: Text(_showAllMatches ? 'إخفاء' : 'عرض المزيد'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatPill(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: Colors.white.withValues(alpha: 0.08),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w900, color: Colors.white)),
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72), fontSize: 12)),
      ],
    );
  }
}

String _initials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return '؟';
  if (parts.length == 1) return parts.first.characters.take(2).toString();
  return (parts[0].characters.take(1).toString() +
      parts[1].characters.take(1).toString());
}

List<(String, int)> _pearlEntries(Map<String, int> pearls, AppState app) {
  final list =
      pearls.entries.map((e) => (app.gameLabel(e.key), e.value)).toList();
  list.sort((a, b) => a.$1.compareTo(b.$1));
  return list;
}

bool _isMatchEvent(TimelineEntry entry) {
  final kind = entry.kind.trim().toUpperCase();
  return kind.isEmpty ||
      kind == 'MATCH' ||
      kind == 'MATCH_WIN' ||
      kind == 'MATCH_LOSS' ||
      kind == 'MATCH_FINISHED';
}

bool _entryInvolvesPlayer(TimelineEntry entry, String player) {
  return entry.winner == player ||
      entry.winners.contains(player) ||
      entry.losers.contains(player);
}

Set<String> _playedGameIds(
  List<TimelineEntry> matches,
  String player,
  AppState app,
) {
  final played = <String>{};
  for (final entry in app.timeline) {
    final gameId = entry.game.trim();
    if (gameId.isEmpty) continue;
    if (_isMatchEvent(entry) && _entryInvolvesPlayer(entry, player)) {
      played.add(gameId);
    }
  }
  for (final entry in matches) {
    final gameId = entry.game.trim();
    if (gameId.isEmpty) continue;
    if (_isMatchEvent(entry) && _entryInvolvesPlayer(entry, player)) {
      played.add(gameId);
    }
  }
  return played;
}

int _timelinePlayedCount(
  List<TimelineEntry> matches,
  String player,
  String gameId,
  AppState app,
) {
  final source = app.timeline.isNotEmpty ? app.timeline : matches;
  return source
      .where((entry) =>
          entry.game.trim() == gameId &&
          _isMatchEvent(entry) &&
          _entryInvolvesPlayer(entry, player))
      .length;
}

_PlayerGameSummary _favoriteGame(
  Map<String, int> pearls,
  Map<String, int> badgeProgress,
  List<TimelineEntry> matches,
  String player,
  AppState app,
) {
  final played = _playedGameIds(matches, player, app);
  final gameIds = <String>{
    ...played,
    ...pearls.keys,
    ...badgeProgress.keys,
    if (app.selectedGame != null && app.selectedGame!.isNotEmpty)
      app.selectedGame!,
  };

  final summaries = <_PlayerGameSummary>[];
  for (final raw in gameIds) {
    final gameId = raw.trim();
    if (gameId.isEmpty) continue;
    final playedCount = _timelinePlayedCount(matches, player, gameId, app);
    final active = played.contains(gameId) || playedCount > 0;
    if (!active && !pearls.containsKey(gameId)) continue;
    summaries.add(_PlayerGameSummary(
      gameId: gameId,
      label: app.gameLabel(gameId),
      pearls: pearls[gameId] ?? app.pearlsForGame(gameId),
      badgeProgress: badgeProgress[gameId] ??
          pearls[gameId] ??
          app.badgeProgressForGame(gameId),
      playedCount: playedCount,
    ));
  }

  if (summaries.isEmpty) {
    return _PlayerGameSummary(
      gameId: '',
      label: app.tr(ar: 'بدون لعبة', en: 'No game'),
      pearls: 0,
      badgeProgress: 0,
      playedCount: 0,
    );
  }

  summaries.sort((a, b) {
    if (a.playedCount != b.playedCount) {
      return b.playedCount.compareTo(a.playedCount);
    }
    if (a.badgeProgress != b.badgeProgress) {
      return b.badgeProgress.compareTo(a.badgeProgress);
    }
    if (a.pearls != b.pearls) return b.pearls.compareTo(a.pearls);
    return a.label.compareTo(b.label);
  });
  return summaries.first;
}

List<_PlayerEarnedBadgeEntry> _earnedBadgeEntries(
  Map<String, int> pearls,
  List<TimelineEntry> matches,
  String player,
  AppState app,
) {
  final played = _playedGameIds(matches, player, app);
  final entries = <_PlayerEarnedBadgeEntry>[];
  for (final entry in pearls.entries) {
    final gameId = entry.key.trim();
    if (gameId.isEmpty) continue;
    final threshold = AppState.badgeThresholdForPearls(entry.value);
    if (threshold <= 5) continue;
    if (!played.contains(gameId) &&
        _timelinePlayedCount(matches, player, gameId, app) == 0) {
      continue;
    }
    entries.add(_PlayerEarnedBadgeEntry(
      gameId: gameId,
      gameLabel: app.gameLabel(gameId),
      threshold: threshold,
    ));
  }
  entries.sort((a, b) {
    if (a.threshold != b.threshold) return b.threshold.compareTo(a.threshold);
    return a.gameLabel.compareTo(b.gameLabel);
  });
  return entries;
}

String _shortId(String id) {
  final clean = id.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
  if (clean.isEmpty) return '';
  final short = clean.length > 6
      ? clean.substring(clean.length - 6)
      : clean.padLeft(6, '0');
  return '#$short';
}

class _PearlBadge extends StatelessWidget {
  final String game;
  final int pearls;
  final double size;
  const _PearlBadge({required this.game, required this.pearls, this.size = 72});

  @override
  Widget build(BuildContext context) {
    final double topOffset = size * 0.2;
    final double bottomOffset = size * 0.18;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: topOffset,
            left: 0,
            right: 0,
            child: Text(
              '$pearls',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF1E2F4D),
                fontWeight: FontWeight.w900,
                fontSize: size * 0.28,
              ),
            ),
          ),
          Positioned(
            bottom: bottomOffset,
            left: 8,
            right: 8,
            child: Text(
              game,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w700,
                fontSize: size * 0.17,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerGameSummary {
  final String gameId;
  final String label;
  final int pearls;
  final int badgeProgress;
  final int playedCount;

  const _PlayerGameSummary({
    required this.gameId,
    required this.label,
    required this.pearls,
    required this.badgeProgress,
    required this.playedCount,
  });
}

class _PlayerEarnedBadgeEntry {
  final String gameId;
  final String gameLabel;
  final int threshold;

  const _PlayerEarnedBadgeEntry({
    required this.gameId,
    required this.gameLabel,
    required this.threshold,
  });
}

class _PlayerGameIconBadge extends StatelessWidget {
  final String gameId;
  final double size;
  final Color? iconColor;
  final Color backgroundColor;

  const _PlayerGameIconBadge({
    required this.gameId,
    this.size = 22,
    this.iconColor,
    this.backgroundColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final asset = _playerProfileGameSvgAssetById[gameId];
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.16),
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: asset == null
          ? Icon(
              Icons.sports_esports_rounded,
              size: size * 0.62,
              color: iconColor ?? const Color(0xFF1E2F4D),
            )
          : SvgPicture.asset(
              asset,
              fit: BoxFit.contain,
              colorFilter: iconColor == null
                  ? null
                  : ColorFilter.mode(iconColor!, BlendMode.srcIn),
            ),
    );
  }
}

class _PlayerGameRankBadge extends StatelessWidget {
  final PlayerRank rank;
  final String gameId;
  final String gameLabel;

  const _PlayerGameRankBadge({
    required this.rank,
    required this.gameId,
    required this.gameLabel,
  });

  @override
  Widget build(BuildContext context) {
    final data = getRankData(rank);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 170),
        padding: const EdgeInsetsDirectional.fromSTEB(9, 6, 10, 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
          boxShadow: [
            BoxShadow(
              color: data.colors.last.withValues(alpha: 0.12),
              blurRadius: 14,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PlayerGameIconBadge(
              gameId: gameId,
              size: 24,
              iconColor: const Color(0xFF1E2F4D),
              backgroundColor: Colors.white.withValues(alpha: 0.92),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                gameId.isEmpty ? data.arabic : '${data.arabic} • $gameLabel',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerEarnedBadgeStack extends StatelessWidget {
  final List<_PlayerEarnedBadgeEntry> badges;
  final double size;
  const _PlayerEarnedBadgeStack({required this.badges, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final visible = badges.take(3).toList();
    if (visible.isEmpty) return SizedBox(width: size, height: size);
    final overlap = size * 0.52;
    final width = size + (visible.length - 1) * overlap;
    return Tooltip(
      message: visible
          .map((badge) => '${badge.gameLabel} • ${badge.threshold}')
          .join('\n'),
      child: SizedBox(
        width: width,
        height: size + 8,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < visible.length; i++)
              PositionedDirectional(
                end: i * overlap,
                top: 0,
                child: _PlayerEarnedBadgeCircle(
                  badge: visible[i],
                  size: size,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlayerEarnedBadgeCircle extends StatelessWidget {
  final _PlayerEarnedBadgeEntry badge;
  final double size;
  const _PlayerEarnedBadgeCircle({required this.badge, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final rank = playerRankForThreshold(badge.threshold);
    final rankData = getRankData(rank);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: rankData.colors,
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: rankData.colors.last.withValues(alpha: 0.32),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            rankData.icon,
            size: size * 0.48,
            color: Colors.white.withValues(alpha: 0.92),
          ),
          PositionedDirectional(
            end: size * 0.05,
            bottom: size * 0.05,
            child: _PlayerGameIconBadge(
              gameId: badge.gameId,
              size: size * 0.42,
              iconColor: const Color(0xFF1E2F4D),
            ),
          ),
        ],
      ),
    );
  }
}

class _PearlCircleGrid extends StatelessWidget {
  final List<(String, int)> entries;
  final int maxValue;
  const _PearlCircleGrid({required this.entries, required this.maxValue});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Text('لا توجد بيانات',
          style: TextStyle(color: Colors.white70));
    }
    const accent = Color(0xFFF1A949);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: entries.map((e) {
        final game = e.$1;
        final value = e.$2.clamp(0, maxValue);
        final pct = value / maxValue;
        return SizedBox(
          width: 90,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 74,
                    height: 74,
                    child: CustomPaint(
                      painter: _ArcPainter(
                        progress: pct,
                        color: accent,
                        bgColor: Colors.grey.shade700,
                        strokeWidth: 7,
                      ),
                    ),
                  ),
                  Text('$value',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, color: Colors.white)),
                ],
              ),
              const SizedBox(height: 6),
              Text(game,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress; // 0..1
  final Color color;
  final Color bgColor;
  final double strokeWidth;

  _ArcPainter(
      {required this.progress,
      required this.color,
      required this.bgColor,
      required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final start = -math.pi / 2;
    final sweep = 2 * math.pi * progress;

    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, bgPaint);

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, start, sweep, false, fgPaint);
  }

  @override
  bool shouldRepaint(covariant _ArcPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.bgColor != bgColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
//pages/player_profile_pages

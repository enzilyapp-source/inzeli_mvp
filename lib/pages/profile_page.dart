// lib/pages/profile_page.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/app_snackbar.dart';

import '../state.dart';
import '../widgets/username_settings_tile.dart';
import '../biometric_auth.dart';
import '../widgets/avatar_effects.dart';
import '../widgets/challenge_rank_visuals.dart';
import 'store_page.dart';
import 'my_items_page.dart';
import '../sfx.dart';
import 'signin_page.dart';
import '../api_user.dart';
import 'player_profile_page.dart';
import 'challenge_rewards_page.dart';
import 'profile_appearance_editor.dart';
import '../widgets/rank_identity.dart';
import '../widgets/rank_levels_sheet.dart';

part 'profile_dashboard.dart';

const Map<String, String> _profileGameAssetById = <String, String>{
  'قدم': 'lib/assets/games_png/games-01.png',
  'طائره': 'lib/assets/games_png/games-02.png',
  'سله': 'lib/assets/games_png/games-03.png',
  'دفان': 'lib/assets/games_png/games-26.png',
  'تنس ارضي': 'lib/assets/games_png/games-05.png',
  'بيبيفوت': 'lib/assets/games_png/games-06.png',
  'بادل': 'lib/assets/games_png/games-07.png',
  'بلوت': 'lib/assets/games_png/games-24.png',
  'هند': 'lib/assets/games_png/games-09.png',
  'كوت': 'lib/assets/games_png/games-08.png',
  'سبيتة': 'lib/assets/games_png/games-25.png',
  'بولنج': 'lib/assets/games_png/games-16.png',
  'بلياردو': 'lib/assets/games_png/games-15.png',
  'تنس طاولة': 'lib/assets/games_png/games-17.png',
  'شطرنج': 'lib/assets/games_png/games-18.png',
  'تريكس': 'lib/assets/games_png/games-11.png',
  'دامه': 'lib/assets/games_png/games-19.png',
  'كيرم': 'lib/assets/games_png/games-20.png',
  'دومنه': 'lib/assets/games_png/games-21.png',
  'طاوله': 'lib/assets/games_png/games-22.png',
  'اونو': 'lib/assets/games_png/games-13.png',
  'جاكارو': 'lib/assets/games_png/games-23.png',
};

class ProfilePage extends StatefulWidget {
  final AppState app;
  const ProfilePage({super.key, required this.app});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const _deleteUrl = 'https://web.enzily.app/delete-account.html';
  // thresholds and labels for the player classification
  static const List<int> _milestones = [5, 10, 15, 20, 30];
  String? _selectedThemeId;
  List<String> _labels(AppState app) => [
        app.tr(ar: 'عليمي', en: 'Beginner'),
        app.tr(ar: 'زين', en: 'Good'),
        app.tr(ar: 'محترف', en: 'Professional'),
        app.tr(ar: 'أسطوري', en: 'Legendary'),
        app.tr(ar: 'أحسن واحد', en: 'Best'),
      ];

  final ImagePicker _picker = ImagePicker();
  int _wins = 0;
  int _losses = 0;
  bool _showChallenges = false;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  @override
  void initState() {
    super.initState();
    _selectedThemeId = widget.app.themeId;
    _nameCtrl = TextEditingController(text: _meName());
    _emailCtrl = TextEditingController(text: widget.app.email ?? '');
    _phoneCtrl = TextEditingController(text: widget.app.phone ?? '');
    // The dashboard totals cover all games, not only the favorite game.
    for (final game in _playedGameIds(_meName())) {
      _wins += widget.app.winsOf(_meName(), game);
      _losses += widget.app.lossesOf(_meName(), game);
    }
    _loadStats();
  }

  String _meName() => widget.app.displayName ?? widget.app.name ?? 'لاعب';
  Set<String> _playedGameIds(String player) {
    final played = <String>{...widget.app.playedGameIds};
    for (final cat in widget.app.games.values) {
      for (final gameId in cat) {
        if (widget.app.winsOf(player, gameId) +
                widget.app.lossesOf(player, gameId) >
            0) {
          played.add(gameId);
        }
      }
    }

    for (final entry in widget.app.timeline) {
      final gameId = entry.game.trim();
      if (gameId.isEmpty) continue;
      if (_isMatchEvent(entry) && _entryInvolvesPlayer(entry, player)) {
        played.add(gameId);
      }
    }
    return played;
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

  bool _hasPlayedGame(String gameId, String player) {
    return _playedGameIds(player).contains(gameId);
  }

  int _timelinePlayedCount(String player, String gameId) {
    return widget.app.timeline
        .where((entry) =>
            entry.game.trim() == gameId &&
            _isMatchEvent(entry) &&
            _entryInvolvesPlayer(entry, player))
        .length;
  }

  _ProfileGameSummary _favoriteGame(AppState app, String player) {
    final played = _playedGameIds(player);
    final gameIds = <String>{
      ...played,
      ...app.gamePearls.keys,
      ...app.gameBadgeProgress.keys,
      if (app.selectedGame != null && app.selectedGame!.isNotEmpty)
        app.selectedGame!,
    };
    for (final cat in app.games.values) {
      gameIds.addAll(cat);
    }

    final summaries = <_ProfileGameSummary>[];
    for (final gameId in gameIds) {
      final id = gameId.trim();
      if (id.isEmpty) continue;
      final statsPlayed = app.winsOf(player, id) + app.lossesOf(player, id);
      final timelinePlayed = _timelinePlayedCount(player, id);
      final active =
          played.contains(id) || statsPlayed > 0 || timelinePlayed > 0;
      if (!active) continue;
      summaries.add(_ProfileGameSummary(
        gameId: id,
        label: app.gameLabel(id),
        pearls: app.pearlsForGame(id),
        badgeProgress: app.badgeProgressForGame(id),
        playedCount: math.max(statsPlayed, timelinePlayed),
      ));
    }

    if (summaries.isEmpty) {
      return _ProfileGameSummary(
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

  Map<String, dynamic>? _bestBadgeForGame(String gameId) {
    if (!_hasPlayedGame(gameId, _meName())) return null;
    final candidates = widget.app.badges
        .where((b) => (b['gameId'] ?? '').toString() == gameId)
        .toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) {
      final thresholdA = (a['threshold'] as num?)?.toInt() ?? 0;
      final thresholdB = (b['threshold'] as num?)?.toInt() ?? 0;
      if (thresholdA != thresholdB) return thresholdB.compareTo(thresholdA);
      final dateA = DateTime.tryParse((a['lastEarnedAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final dateB = DateTime.tryParse((b['lastEarnedAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return dateB.compareTo(dateA);
    });
    return candidates.first;
  }

  int _badgeThresholdForGame(String gameId, int pearls) {
    final saved =
        (_bestBadgeForGame(gameId)?['threshold'] as num?)?.toInt() ?? 0;
    final current = AppState.badgeThresholdForPearls(pearls);
    return math.max(saved, current);
  }

  int _currentBadgeThresholdForGame(String gameId) {
    return AppState.badgeThresholdForPearls(
      widget.app.badgeProgressForGame(gameId),
    );
  }

  String? _badgeLabelForGame(String gameId) {
    final badge = _bestBadgeForGame(gameId);
    final label = badge?['label']?.toString();
    if (label != null && label.isNotEmpty) return _rankName(label);
    return null;
  }

  bool _isAchievementMatch(TimelineEntry entry, String player) {
    return _isMatchEvent(entry) && _entryInvolvesPlayer(entry, player);
  }

  String? _badgeChangeForMatch(TimelineEntry match, String player) {
    final gameId = match.game.trim();
    if (gameId.isEmpty) return null;
    final roomCode = match.roomCode.trim();
    final changes = widget.app.timeline.where((entry) {
      final kind = entry.kind.trim().toUpperCase();
      final isBadgeChange = kind == 'LEVEL_UP' ||
          kind == 'BADGE' ||
          kind == 'BADGE_UP' ||
          kind == 'BADGE_EARNED';
      if (!isBadgeChange || entry.game.trim() != gameId) return false;
      if (!_entryInvolvesPlayer(entry, player)) return false;
      final entryRoom = entry.roomCode.trim();
      if (roomCode.isNotEmpty &&
          entryRoom.isNotEmpty &&
          entryRoom != roomCode) {
        return false;
      }
      return entry.ts.difference(match.ts).inMinutes.abs() <= 10;
    }).toList()
      ..sort((a, b) => b.ts.compareTo(a.ts));
    if (changes.isEmpty) return null;
    final meta = changes.first.meta ?? const <String, dynamic>{};
    final label = (meta['to'] ??
            meta['badgeLabel'] ??
            meta['label'] ??
            meta['rankLabelAr'] ??
            meta['achievementAr'] ??
            '')
        .toString()
        .trim();
    if (label.isEmpty) return _badgeLabelForGame(gameId);
    return _rankName(label);
  }

  List<_EarnedBadgeEntry> _earnedBadgeEntries(String player) {
    final played = _playedGameIds(player);
    final byGame = <String, _EarnedBadgeEntry>{};
    for (final badge in widget.app.badges) {
      final gameId = (badge['gameId'] ?? '').toString().trim();
      if (gameId.isEmpty || !played.contains(gameId)) continue;
      final label = (badge['label'] ?? '').toString().trim();
      final threshold = (badge['threshold'] as num?)?.toInt() ??
          AppState.badgeThresholdForLabel(label);
      if (threshold <= 5) continue;
      final earnedAt =
          DateTime.tryParse((badge['lastEarnedAt'] ?? '').toString()) ??
              DateTime.fromMillisecondsSinceEpoch(0);
      final entry = _EarnedBadgeEntry(
        gameId: gameId,
        gameLabel: widget.app.gameLabel(gameId),
        badgeLabel: label.isEmpty ? _labelFor(threshold) : _rankName(label),
        threshold: threshold,
        earnedAt: earnedAt,
      );
      final existing = byGame[gameId];
      if (existing == null ||
          entry.threshold > existing.threshold ||
          (entry.threshold == existing.threshold &&
              entry.earnedAt.isAfter(existing.earnedAt))) {
        byGame[gameId] = entry;
      }
    }
    for (final game in _gamePearlEntries(widget.app, player)) {
      if (!game.active || game.threshold <= 5) continue;
      final entry = _EarnedBadgeEntry(
        gameId: game.gameId,
        gameLabel: game.label,
        badgeLabel: _labelFor(game.threshold),
        threshold: game.threshold,
        earnedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );
      final existing = byGame[game.gameId];
      if (existing == null || entry.threshold > existing.threshold) {
        byGame[game.gameId] = entry;
      }
    }

    final entries = byGame.values.toList()
      ..sort((a, b) {
        if (a.threshold != b.threshold) {
          return b.threshold.compareTo(a.threshold);
        }
        return b.earnedAt.compareTo(a.earnedAt);
      });
    return entries;
  }

  List<_AchievementEntry> _recentMatches(String player) {
    final playedGames = _playedGameIds(player);
    final matches = widget.app.timeline
        .where((t) => _isAchievementMatch(t, player))
        .toList()
      ..sort((a, b) => b.ts.compareTo(a.ts));

    final deduped = <_AchievementEntry>[];
    final seen = <String>{};
    for (final t in matches) {
      final isWin = t.winner == player || t.winners.contains(player);
      final gameId = t.game.trim();
      if (gameId.isEmpty || !playedGames.contains(gameId)) continue;
      final roomKey = t.roomCode.trim().isNotEmpty
          ? t.roomCode.trim()
          : '$gameId|${t.ts.toIso8601String()}';
      final key = '$gameId|$roomKey';
      if (!seen.add(key)) continue;

      final badgeChange = _badgeChangeForMatch(t, player);
      final badgeLabel = badgeChange ?? _badgeLabelForGame(gameId);
      deduped.add(_AchievementEntry(
        gameId: gameId,
        game: widget.app.gameLabel(gameId),
        typeLabel: widget.app.tr(ar: 'قيم', en: 'Match'),
        badgeLabel: badgeLabel ?? '',
        outcomeLabel: widget.app
            .tr(ar: isWin ? 'فوز' : 'خسارة', en: isWin ? 'Win' : 'Loss'),
        detailLabel: badgeChange == null
            ? (badgeLabel == null
                ? widget.app.tr(
                    ar: isWin ? 'فوز مسجل' : 'خسارة مسجلة',
                    en: isWin ? 'Recorded win' : 'Recorded loss')
                : 'مستواك الحالي: $badgeLabel')
            : 'تغير مستواك إلى $badgeChange',
        isWin: isWin,
        isSeasonAward: false,
        date: t.ts,
      ));
    }
    return deduped;
  }

  String _shortId(String id) {
    final clean = id.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (clean.isEmpty) return '';
    final short = clean.length > 6
        ? clean.substring(clean.length - 6)
        : clean.padLeft(6, '0');
    return '#$short';
  }

  Future<void> _loadStats() async {
    final uid = widget.app.userId;
    if (uid == null || uid.isEmpty) return;
    try {
      final stats = await getUserStats(uid, token: widget.app.token);
      if (stats == null || widget.app.userId != uid) return;
      if (!mounted) return;
      setState(() {
        _wins = (stats['wins'] as num?)?.toInt() ?? _wins;
        _losses = (stats['losses'] as num?)?.toInt() ?? _losses;
      });
      final gp = stats['gamePearls'];
      if (gp is Map) {
        widget.app.gamePearls =
            gp.map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0));
      }
      await widget.app.applyAchievementSnapshot(stats, notify: false);
      if (mounted) setState(() {});
      await _syncChallengeUnlocks();
      await widget.app.refreshChallengeRewards();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  List<_ThemeChallenge> _themeChallenges() {
    return const [
      _ThemeChallenge(
        id: 'blueThunder',
        title: 'برق أزرق',
        gameId: 'شطرنج',
        targetWins: 3,
        effect: AvatarEffectType.blueThunder,
      ),
      _ThemeChallenge(
        id: 'goldLightning',
        title: 'برق ذهبي',
        gameId: 'كوت',
        targetWins: 3,
        effect: AvatarEffectType.goldLightning,
      ),
      _ThemeChallenge(
        id: 'kuwait',
        title: 'ألوان العلم',
        gameId: 'بلوت',
        targetWins: 3,
        effect: AvatarEffectType.kuwaitSparkles,
      ),
      _ThemeChallenge(
        id: 'greenLeaf',
        title: 'أخضر',
        gameId: 'جاكارو',
        targetWins: 3,
        effect: AvatarEffectType.greenLeaf,
      ),
      _ThemeChallenge(
        id: 'flameBlue',
        title: 'لهب أزرق',
        gameId: 'بلياردو',
        targetWins: 3,
        effect: AvatarEffectType.flameBlue,
      ),
      _ThemeChallenge(
        id: 'whiteSparkle',
        title: 'سباركل أبيض',
        gameId: 'تنس طاولة',
        targetWins: 3,
        effect: AvatarEffectType.whiteSparkle,
      ),
    ];
  }

  Future<void> _syncChallengeUnlocks() async {
    bool changed = false;
    final me = _meName();
    for (final challenge in _themeChallenges()) {
      final wins = widget.app.winsOf(me, challenge.gameId);
      if (wins >= challenge.targetWins &&
          !widget.app.freeThemesOwned.contains(challenge.id)) {
        widget.app.freeThemesOwned.add(challenge.id);
        changed = true;
      }
    }
    if (changed) {
      await widget.app.saveState();
      if (mounted) setState(() {});
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final picked = await _picker.pickImage(
          source: ImageSource.gallery, imageQuality: 85);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (kIsWeb) {
        await widget.app.setAvatarBytes(bytes, fallbackPath: null);
      } else {
        await widget.app.setAvatarBytes(bytes, fallbackPath: picked.path);
      }
      if (mounted) {
        Sfx.tap(mute: widget.app.soundMuted == true);
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;
      Sfx.error(mute: widget.app.soundMuted == true);
      _msg('فشل اختيار الصورة: $e');
    }
  }

  Future<void> _removeAvatar() async {
    try {
      await widget.app.removeAvatar();
      if (!mounted) return;
      Sfx.tap(mute: widget.app.soundMuted == true);
      setState(() {});
      _msg('تمت إزالة الصورة', success: true);
    } catch (e) {
      if (!mounted) return;
      Sfx.error(mute: widget.app.soundMuted == true);
      _msg('فشل إزالة الصورة: $e', error: true);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _msg(String text, {bool error = false, bool success = false}) {
    showAppSnack(context, text, error: error, success: success);
  }

  Future<void> _openDeleteWeb() async {
    final app = widget.app;
    final uri = Uri.parse(_deleteUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      _msg(
          app.tr(ar: 'تعذّر فتح رابط الحذف', en: 'Could not open delete link'));
    }
  }

  Future<void> _confirmDelete(AppState app) async {
    if (app.token == null || app.token!.isEmpty) {
      _msg('سجّل الدخول أولاً');
      return;
    }

    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        bool confirmed = false;
        return StatefulBuilder(
          builder: (ctx, setDialog) => AlertDialog(
            title: Text(
                app.tr(ar: 'تأكيد حذف الحساب', en: 'Confirm account deletion')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(app.tr(
                  ar: 'سيتم حذف حسابك وجميع بياناتك نهائياً ولا يمكن التراجع.',
                  en: 'Your account and data will be permanently deleted and cannot be restored.',
                )),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: confirmed,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(app.tr(
                    ar: 'أوافق على حذف الحساب نهائياً',
                    en: 'I understand and agree to delete my account',
                  )),
                  onChanged: (v) => setDialog(() => confirmed = v ?? false),
                ),
                const SizedBox(height: 6),
                TextButton(
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft),
                  onPressed: () => _openDeleteWeb(),
                  child: Text(
                    app.tr(
                      ar: 'بدلاً من ذلك، احذف الحساب عبر الويب',
                      en: 'Alternatively, delete your account on the web',
                    ),
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.primary),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(app.tr(ar: 'إلغاء', en: 'Cancel')),
              ),
              TextButton(
                onPressed: confirmed ? () => Navigator.of(ctx).pop(true) : null,
                child: Text(
                  app.tr(ar: 'حذف نهائياً', en: 'Delete'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (sure != true) return;
    if (!mounted) return;

    // show quick loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final res = await deleteAccount(token: app.token!);

    if (mounted) Navigator.of(context).pop(); // close loader

    if (res['ok'] == true) {
      await app.clearAuth();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => SignInPage(app: app)),
        (route) => false,
      );
      if (!mounted) return;
      _msg(app.tr(ar: 'تم حذف الحساب', en: 'Account deleted'));
    } else {
      if (!mounted) return;
      _msg(res['message']?.toString() ??
          app.tr(ar: 'فشل الحذف', en: 'Deletion failed'));
    }
  }

  Future<void> _openStore(AppState app) async {
    if (!app.isSignedIn) {
      _msg('سجّل الدخول أولاً');
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StorePage(app: app)),
    );
    setState(() {});
  }

  Future<void> _openItems(AppState app) async {
    if (!app.isSignedIn) {
      _msg('سجّل الدخول أولاً');
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MyItemsPage(app: app)),
    );
    if (mounted) setState(() => _selectedThemeId = app.themeId);
  }

  Future<void> _openPlayerSearch() async {
    final ctrl = TextEditingController();
    List<Map<String, dynamic>> results = const [];
    var loading = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            16 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'بحث عن لاعب',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: ctrl,
                        textInputAction: TextInputAction.search,
                        decoration: const InputDecoration(
                          hintText: 'اسم المستخدم أو الاسم أو المعرّف',
                        ),
                        onSubmitted: (value) async {
                          final query = value.trim();
                          if (query.isEmpty) return;
                          setSheetState(() => loading = true);
                          try {
                            results = await searchUsers(query,
                                token: widget.app.token);
                          } finally {
                            if (sheetCtx.mounted) {
                              setSheetState(() => loading = false);
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () async {
                        final query = ctrl.text.trim();
                        if (query.isEmpty) return;
                        setSheetState(() => loading = true);
                        try {
                          results =
                              await searchUsers(query, token: widget.app.token);
                        } finally {
                          if (sheetCtx.mounted) {
                            setSheetState(() => loading = false);
                          }
                        }
                      },
                      child: const Icon(Icons.search),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (loading)
                  const Center(child: CircularProgressIndicator())
                else if (results.isEmpty)
                  const SizedBox.shrink()
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: results.length,
                      separatorBuilder: (_, __) => const Divider(height: 0),
                      itemBuilder: (_, i) {
                        final user = results[i];
                        final display = (user['displayName'] ??
                                user['name'] ??
                                user['email'] ??
                                'لاعب')
                            .toString();
                        return ListTile(
                          onTap: () async {
                            final uid = (user['id'] ?? '').toString();
                            final profileKey = uid.isNotEmpty ? uid : display;
                            widget.app.upsertUserProfile(profileKey, user);
                            if (uid.isNotEmpty) {
                              final stats = await getUserStats(uid,
                                  token: widget.app.token);
                              if (stats != null) {
                                widget.app.upsertUserStats(profileKey, stats);
                              }
                            }
                            if (!mounted || !sheetCtx.mounted) return;
                            Navigator.pop(sheetCtx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PlayerProfilePage(
                                  app: widget.app,
                                  playerName: display,
                                  userId: uid.isNotEmpty ? uid : null,
                                ),
                              ),
                            );
                          },
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFF273347),
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          title: Text(display),
                          subtitle: Text(
                            user['username'] != null
                                ? '@${user['username']}'
                                : (user['publicId'] ?? user['id'] ?? '')
                                    .toString(),
                          ),
                          trailing:
                              const Icon(Icons.arrow_back_ios_new, size: 16),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    ctrl.dispose();
  }

  Future<void> _openAllAchievements(List<_AchievementEntry> entries) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'كل المسيرة',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 12,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    itemBuilder: (_, i) {
                      final win = entries[i];
                      return Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color:
                                  (win.isWin ? Colors.amber : Colors.redAccent)
                                      .withValues(alpha: .18),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              win.isSeasonAward
                                  ? Icons.auto_awesome_rounded
                                  : win.isWin
                                      ? Icons.workspace_premium
                                      : Icons.close_rounded,
                              color:
                                  win.isWin ? Colors.amber : Colors.redAccent,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${win.outcomeLabel} • ${win.game}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  win.detailLabel,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: .68),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _formatAchievementDate(win.date),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .65),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatAchievementDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  void _openSettings(AppState app) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final androidArabicOnly =
            !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
        String selected = app.isEnglish ? 'en' : 'ar';
        bool muted = app.soundMuted ?? false;
        bool privateProfile = app.profilePrivate ?? false;
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            bool biometricEnabled = app.biometricEnabled;
            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('إعدادات الحساب',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 10),
                    UsernameSettingsTile(app: app),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'الاسم'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(labelText: 'الإيميل'),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _phoneCtrl,
                      decoration:
                          const InputDecoration(labelText: 'رقم الجوال'),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('تغيير الصورة'),
                      onPressed: _pickAvatar,
                    ),
                    if ((app.avatarBase64?.isNotEmpty ?? false) ||
                        (app.avatarPath?.isNotEmpty ?? false)) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('إزالة الصورة'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                        ),
                        onPressed: () async {
                          await _removeAvatar();
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Text('إعدادات التطبيق',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 15)),
                    const SizedBox(height: 10),
                    if (!androidArabicOnly) ...[
                      const Text('اللغة',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'ar', label: Text('العربية')),
                          ButtonSegment(value: 'en', label: Text('English')),
                        ],
                        selected: {selected},
                        onSelectionChanged: (s) {
                          selected = s.first;
                          app.setLanguage(selected);
                          setState(() {});
                          setSheet(() {});
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    SwitchListTile(
                      value: muted,
                      onChanged: (v) {
                        muted = v;
                        app.setSoundMuted(v);
                        setState(() {});
                        setSheet(() {});
                      },
                      title: const Text('كتم الصوت'),
                      subtitle: const Text('إيقاف المؤثرات الصوتية'),
                    ),
                    SwitchListTile(
                      value: privateProfile,
                      onChanged: (v) {
                        privateProfile = v;
                        app.setProfilePrivate(v);
                        setState(() {});
                        setSheet(() {});
                      },
                      title: const Text('إخفاء الملف الشخصي'),
                      subtitle: const Text(
                          'يخفي تفاصيلك العامة ويترك الإحصاءات الأساسية فقط'),
                    ),
                    SwitchListTile(
                      value: biometricEnabled,
                      onChanged: (v) async {
                        if (v) {
                          final available =
                              await BiometricAuthService.isAvailable();
                          if (!available) {
                            if (mounted) {
                              _msg('Face ID غير متاح على هذا الجهاز');
                            }
                            return;
                          }

                          final ok = await BiometricAuthService.authenticate(
                            reason: 'فعّل Face ID للدخول إلى إنزلي',
                          );
                          if (!ok) return;
                        }

                        if (!ctx.mounted) return;
                        app.setBiometricEnabled(v);
                        biometricEnabled = v;
                        if (mounted) setState(() {});
                        setSheet(() {});
                      },
                      title: const Text('الدخول بـ Face ID'),
                      subtitle:
                          const Text('يفتح الجلسة المحفوظة على هذا الجهاز'),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.close),
                          label: const Text('إغلاق'),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                        FilledButton.icon(
                          icon: const Icon(Icons.save),
                          label: const Text('حفظ التغييرات'),
                          onPressed: () async {
                            final oldName = (app.displayName ?? '').trim();
                            app.displayName = _nameCtrl.text.trim().isEmpty
                                ? app.displayName
                                : _nameCtrl.text.trim();
                            app.name = app.displayName ?? app.name;
                            app.email = _emailCtrl.text.trim().isEmpty
                                ? app.email
                                : _emailCtrl.text.trim();
                            app.phone = _phoneCtrl.text.trim().isEmpty
                                ? app.phone
                                : _phoneCtrl.text.trim();
                            await app.saveState();
                            final synced = await app.syncProfileToServer(
                              includeAvatarData: false,
                              includeThemeData: false,
                            );
                            await app.refreshSessionFromServer(force: true);
                            if (mounted &&
                                !synced &&
                                oldName != (app.displayName ?? '').trim()) {
                              _msg(
                                'تعذر حفظ الاسم على الخادم. تأكد من الاتصال ثم أعد الحفظ.',
                                error: true,
                              );
                            }
                            if (mounted) setState(() {});
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                        ),
                      ],
                    ),
                    if (app.isSignedIn) ...[
                      const SizedBox(height: 12),
                      const Divider(),
                      TextButton.icon(
                        icon: const Icon(Icons.logout, color: Colors.red),
                        label: Text(
                          app.tr(ar: 'تسجيل خروج', en: 'Log out'),
                          style: const TextStyle(
                              color: Colors.red, fontWeight: FontWeight.w700),
                        ),
                        onPressed: () async {
                          await app.clearAuth();
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          if (!mounted) return;
                          setState(() {});
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                                builder: (_) => SignInPage(app: app)),
                            (route) => false,
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      TextButton.icon(
                        icon:
                            const Icon(Icons.delete_forever, color: Colors.red),
                        label: Text(
                          app.tr(ar: 'حذف الحساب', en: 'Delete account'),
                          style: const TextStyle(
                              color: Colors.red, fontWeight: FontWeight.w800),
                        ),
                        onPressed: () => _confirmDelete(app),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openAvatarThemePicker() async {
    await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF172C41),
        builder: (_) => ProfileAppearanceEditor(
            app: widget.app,
            onPickPhoto: _pickAvatar,
            onRemovePhoto: _removeAvatar));
    if (mounted) setState(() => _selectedThemeId = widget.app.themeId);
  }

  void _openRankSheet(int currentRankThreshold) {
    showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF172C41),
        builder: (_) => RankLevelsSheet(
            app: widget.app, currentThreshold: currentRankThreshold));
  }

  // Progress stays in a separate sheet: the overview remains quick to scan.
  void _openAchievements() {
    final app = widget.app;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFF13273D),
      builder: (context) => Directionality(
        textDirection: app.isEnglish ? TextDirection.ltr : TextDirection.rtl,
        child: SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: .72,
            minChildSize: .35,
            maxChildSize: .92,
            builder: (context, controller) => ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              children: [
                Row(children: [
                  Expanded(
                      child: Text(app.tr(ar: 'إنجازاتي', en: 'My achievements'),
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w800))),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      tooltip: app.tr(ar: 'إغلاق', en: 'Close'),
                      icon: const Icon(Icons.close)),
                ]),
                Text(
                    app.tr(
                        ar: 'تقدم مستواك في كل لعبة',
                        en: 'Your progress in each game'),
                    style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 24),
                _PearlCircleGrid(
                  key: const ValueKey('achievement-progress'),
                  entries: _gamePearlEntries(app, _meName()),
                  maxValue: _milestones.last,
                  milestones: _milestones,
                  rankLabel: _labelFor,
                  rankName: _rankName,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openChallengeRewards() async {
    await Navigator.push<void>(
        context,
        MaterialPageRoute(
            builder: (_) => ChallengeRewardsPage(app: widget.app)));
    if (mounted) setState(() => _selectedThemeId = widget.app.themeId);
  }

  void _openStatistics() {
    final app = widget.app;
    final games = _playedGameIds(_meName()).toList();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => Directionality(
        textDirection: app.isEnglish ? TextDirection.ltr : TextDirection.rtl,
        child: SafeArea(
            child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .8),
          child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(20),
              children: [
                Text(app.tr(ar: 'إحصائياتي', en: 'My statistics'),
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                _ProfileStats(app: app, wins: _wins, losses: _losses),
                const SizedBox(height: 16),
                ...games.map((game) => ListTile(
                      title: Text(app.gameLabel(game)),
                      subtitle: Text(app.tr(
                          ar: 'فوز: ${app.winsOf(_meName(), game)} • خسارة: ${app.lossesOf(_meName(), game)}',
                          en: 'Wins: ${app.winsOf(_meName(), game)} • Losses: ${app.lossesOf(_meName(), game)}')),
                    )),
              ]),
        )),
      ),
    );
  }

  void _openHelp() {
    final app = widget.app;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
          child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(app.tr(ar: 'مركز المساعدة', en: 'Help center'),
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(app.tr(
              ar: 'للمساعدة أو الإبلاغ عن مشكلة، تواصل مع فريق إنزلي.',
              en: 'Contact the Enzily team for help or to report a problem.')),
          const SizedBox(height: 16),
          OutlinedButton.icon(
              onPressed: () async {
                final opened =
                    await launchUrl(Uri.parse('mailto:support@enzily.app'));
                if (!opened && mounted) {
                  _msg(app.tr(
                      ar: 'راسلنا على support@enzily.app',
                      en: 'Email support@enzily.app'));
                }
              },
              icon: const Icon(Icons.mail_outline),
              label: const Text('support@enzily.app')),
        ]),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final meName = _meName();
    final favoriteGame = _favoriteGame(app, meName);
    final rankThreshold = _currentBadgeThresholdForGame(favoriteGame.gameId);
    final matches = _recentMatches(meName);
    final badges = _earnedBadgeEntries(meName);
    ImageProvider? avatarImage;
    if (app.avatarBase64?.isNotEmpty ?? false) {
      try {
        avatarImage = MemoryImage(base64Decode(app.avatarBase64!));
      } catch (_) {}
    }
    final nextThreshold =
        _milestones.where((m) => m > favoriteGame.badgeProgress).firstOrNull;
    return Directionality(
      textDirection: app.isEnglish ? TextDirection.ltr : TextDirection.rtl,
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              key: const ValueKey('profile-dashboard'),
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 28),
              children: [
                _ProfileHero(
                  app: app,
                  name: meName,
                  handle: app.username != null
                      ? '@${app.username}'
                      : _shortId(app.publicId ?? app.userId ?? ''),
                  avatar: avatarImage,
                  themeId: _selectedThemeId,
                  background: profileBaseColor(app.cardId),
                  game: favoriteGame,
                  threshold: rankThreshold,
                  rankLabel: _rankName(
                      getRankData(playerRankForThreshold(rankThreshold))
                          .arabic),
                  nextThreshold: nextThreshold,
                  onSettings: () => _openSettings(app),
                  onAvatar: _openAvatarThemePicker,
                  onRank: () => _openRankSheet(rankThreshold),
                ),
                const SizedBox(height: 14),
                _ProfilePanel(
                  key: const ValueKey('my-statistics'),
                  title: app.tr(ar: 'إحصائياتي', en: 'My statistics'),
                  icon: Icons.bar_chart_rounded,
                  actionLabel: app.tr(ar: 'عرض الكل', en: 'View all'),
                  onAction: _openStatistics,
                  child: _ProfileStats(app: app, wins: _wins, losses: _losses),
                ),
                const SizedBox(height: 14),
                _ProfilePanel(
                  key: const ValueKey('my-achievements'),
                  title: app.tr(ar: 'إنجازاتي', en: 'My achievements'),
                  icon: Icons.workspace_premium_outlined,
                  actionLabel: app.tr(ar: 'عرض الكل', en: 'View all'),
                  onAction: _openAchievements,
                  onTitleTap: _openAchievements,
                  child: _ProfileMedals(
                      app: app, badges: badges, onTap: _openAchievements),
                ),
                const SizedBox(height: 14),
                _ProfilePanel(
                  title: app.tr(ar: 'آخر الألعاب', en: 'Recent games'),
                  icon: Icons.history_rounded,
                  actionLabel: app.tr(ar: 'عرض الكل', en: 'View all'),
                  onAction: () => _openAllAchievements(matches),
                  child: _ProfileRecentGames(
                      app: app,
                      matches: matches.take(2).toList(),
                      onTap: () => _openAllAchievements(matches)),
                ),
                const SizedBox(height: 14),
                _ProfileMenuTile(
                    icon: Icons.person_outline_rounded,
                    title: app.tr(ar: 'الملف الشخصي', en: 'Personal profile'),
                    subtitle: app.tr(
                        ar: 'تعديل البيانات والصورة',
                        en: 'Edit your details and photo'),
                    onTap: () => _openSettings(app)),
                const SizedBox(height: 10),
                _ProfileMenuTile(
                    icon: Icons.settings_outlined,
                    title: app.tr(ar: 'الإعدادات', en: 'Settings'),
                    subtitle: app.tr(
                        ar: 'الصوت والخصوصية والحساب',
                        en: 'Sound, privacy and account'),
                    onTap: () => _openSettings(app)),
                const SizedBox(height: 10),
                _ProfileMenuTile(
                    icon: Icons.help_outline_rounded,
                    title: app.tr(ar: 'مركز المساعدة', en: 'Help center'),
                    subtitle:
                        app.tr(ar: 'المساعدة والدعم', en: 'Help and support'),
                    onTap: _openHelp),
                const SizedBox(height: 18),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _QuickActionChip(
                      icon: Icons.shopping_bag_outlined,
                      label: app.tr(ar: 'المتجر', en: 'Market'),
                      onTap: () => _openStore(app)),
                  _QuickActionChip(
                      icon: Icons.search,
                      label: app.tr(ar: 'بحث', en: 'Search'),
                      onTap: _openPlayerSearch),
                  _QuickActionChip(
                      icon: Icons.style_outlined,
                      label: app.tr(ar: 'ثيماتي', en: 'My themes'),
                      onTap: () => _openItems(app)),
                  _QuickActionChip(
                      icon: Icons.flag_outlined,
                      label: app.tr(ar: 'التحديات', en: 'Challenges'),
                      onTap: _openChallengeRewards),
                ]),
                TextButton.icon(
                    onPressed: () =>
                        setState(() => _showChallenges = !_showChallenges),
                    icon: const Icon(Icons.style_outlined),
                    label: Text(app.tr(
                        ar: 'تحديات الثيمات السابقة',
                        en: 'Original theme challenges'))),
                if (_showChallenges) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'تحديات الثيمات',
                            style: TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 16),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'كل ما تخلص تحدي، ينفتح لك الثيم تلقائيًا داخل ثيماتك.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.72),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ..._themeChallenges().map((challenge) {
                            final wins =
                                widget.app.winsOf(meName, challenge.gameId);
                            final unlocked = widget.app.freeThemesOwned
                                .contains(challenge.id);
                            final progress =
                                (wins / challenge.targetWins).clamp(0.0, 1.0);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Row(
                                children: [
                                  AvatarEffect(
                                    effect: challenge.effect,
                                    size: 54,
                                    animate: unlocked,
                                    child: const CircleAvatar(
                                      radius: 18,
                                      backgroundColor: Colors.white24,
                                      child: Icon(Icons.style,
                                          color: Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          challenge.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'الفوز في لعبة ${widget.app.gameLabel(challenge.gameId)} ${challenge.targetWins} مرات',
                                          style: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: 0.72),
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        LinearProgressIndicator(
                                          value: progress,
                                          minHeight: 6,
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    unlocked
                                        ? 'مفتوح'
                                        : '$wins/${challenge.targetWins}',
                                    style: TextStyle(
                                      color: unlocked
                                          ? Colors.greenAccent
                                          : Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- helpers ----------

  String _labelFor(int milestone) {
    final labels = _labels(widget.app);
    final idx = _milestones.indexOf(milestone);
    return (idx >= 0 && idx < labels.length) ? labels[idx] : '';
    // Legacy API labels are converted to the new display names here.
  }

  String _rankName(String name) {
    final arName = switch (name) {
      'Beginner' => 'عليمي',
      'Advance' || 'يمشي حاله' || 'Good' => 'زين',
      'Professional' || 'زين' || 'محترف' => 'محترف',
      'Legend' || 'Legendary' || 'فنان' => 'أسطوري',
      'GOAT' || 'Best' || 'فلته' || 'فلتة' || 'احسن واحد' => 'أحسن واحد',
      _ => name,
    };
    return widget.app.tr(
      ar: arName,
      en: switch (arName) {
        'عليمي' => 'Beginner',
        'زين' => 'Good',
        'محترف' => 'Professional',
        'أسطوري' => 'Legendary',
        'أحسن واحد' => 'Best',
        'بدايات' => 'Newbie',
        _ => name,
      },
    );
  }

  List<_GamePearlEntry> _gamePearlEntries(AppState app, String player) {
    final entries = <_GamePearlEntry>[];
    final playedGames = _playedGameIds(player);
    for (final cat in app.games.values) {
      for (final g in cat) {
        if (!playedGames.contains(g)) continue;
        final pearls = app.pearlsForGame(g);
        final badgeProgress = app.badgeProgressForGame(g);
        final played = app.winsOf(player, g) + app.lossesOf(player, g);
        final threshold = _badgeThresholdForGame(g, badgeProgress);
        final hasEarnedBadge = _bestBadgeForGame(g) != null;
        entries.add(_GamePearlEntry(
          gameId: g,
          label: app.gameLabel(g),
          pearls: pearls,
          progress: badgeProgress,
          threshold: threshold,
          active: played > 0 || hasEarnedBadge,
        ));
      }
    }
    for (final g in playedGames) {
      if (entries.any((entry) => entry.gameId == g)) continue;
      final pearls = app.pearlsForGame(g);
      final badgeProgress = app.badgeProgressForGame(g);
      final threshold = _badgeThresholdForGame(g, badgeProgress);
      entries.add(_GamePearlEntry(
        gameId: g,
        label: app.gameLabel(g),
        pearls: pearls,
        progress: badgeProgress,
        threshold: threshold,
        active: true,
      ));
    }
    final seen = <String>{};
    final uniq = <_GamePearlEntry>[];
    for (final e in entries) {
      if (seen.add(e.gameId)) uniq.add(e);
    }
    uniq.sort((a, b) {
      if (a.active != b.active) return a.active ? -1 : 1;
      if (a.pearls != b.pearls) return b.pearls.compareTo(a.pearls);
      if (a.threshold != b.threshold) return b.threshold.compareTo(a.threshold);
      return a.label.compareTo(b.label);
    });
    return uniq;
  }
}

/* ---------------- painters / small widgets ---------------- */

class _AchievementEntry {
  final String gameId;
  final String game;
  final String typeLabel;
  final String badgeLabel;
  final String outcomeLabel;
  final String detailLabel;
  final bool isWin;
  final bool isSeasonAward;
  final DateTime date;

  const _AchievementEntry({
    required this.gameId,
    required this.game,
    required this.typeLabel,
    required this.badgeLabel,
    required this.outcomeLabel,
    required this.detailLabel,
    required this.isWin,
    required this.isSeasonAward,
    required this.date,
  });
}

class _ProfileGameSummary {
  final String gameId;
  final String label;
  final int pearls;
  final int badgeProgress;
  final int playedCount;

  const _ProfileGameSummary({
    required this.gameId,
    required this.label,
    required this.pearls,
    required this.badgeProgress,
    required this.playedCount,
  });
}

class _EarnedBadgeEntry {
  final String gameId;
  final String gameLabel;
  final String badgeLabel;
  final int threshold;
  final DateTime earnedAt;

  const _EarnedBadgeEntry({
    required this.gameId,
    required this.gameLabel,
    required this.badgeLabel,
    required this.threshold,
    required this.earnedAt,
  });
}

class _ThemeChallenge {
  final String id;
  final String title;
  final String gameId;
  final int targetWins;
  final AvatarEffectType effect;

  const _ThemeChallenge({
    required this.id,
    required this.title,
    required this.gameId,
    required this.targetWins,
    required this.effect,
  });
}

class _GamePearlEntry {
  final String gameId;
  final String label;
  final int pearls;
  final int progress;
  final int threshold;
  final bool active;

  const _GamePearlEntry({
    required this.gameId,
    required this.label,
    required this.pearls,
    required this.progress,
    required this.threshold,
    required this.active,
  });
}

class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickActionChip(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFF1A949);
    return ActionChip(
      onPressed: onTap,
      avatar: Icon(icon, size: 18, color: accent),
      label: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: accent,
        ),
      ),
      shape: StadiumBorder(
          side: BorderSide(color: accent.withValues(alpha: 0.35))),
      backgroundColor: Colors.white,
      elevation: 2,
      shadowColor: Colors.black12,
    );
  }
}

class _PearlCircleGrid extends StatelessWidget {
  final List<_GamePearlEntry> entries;
  final int maxValue;
  final List<int> milestones;
  final String Function(int) rankLabel;
  final String Function(String) rankName;
  const _PearlCircleGrid(
      {super.key,
      required this.entries,
      required this.maxValue,
      required this.milestones,
      required this.rankLabel,
      required this.rankName});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Text('لا توجد ألعاب مسجلة بعد', textAlign: TextAlign.center);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = 3;
        const hGap = 8.0;
        const vGap = 12.0;
        final tileWidth =
            (constraints.maxWidth - ((columns - 1) * hGap)) / columns;
        final ringSize = math.min(74.0, math.max(66.0, tileWidth * 0.84));
        final gameFont = tileWidth < 90 ? 11.5 : 12.5;
        final rankFont = tileWidth < 90 ? 10.0 : 11.0;

        return Wrap(
          alignment: WrapAlignment.spaceBetween,
          runSpacing: vGap,
          children: entries.map((e) {
            final game = e.label;
            final value = e.progress.clamp(0, maxValue);
            final pct = value / maxValue;
            final ringColor = _colorForThreshold(e.threshold);
            final opacity = e.active ? 1.0 : 0.58;
            return SizedBox(
              width: tileWidth,
              child: Opacity(
                opacity: opacity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: pct),
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOutCubic,
                          builder: (_, v, __) => SizedBox(
                            width: ringSize,
                            height: ringSize,
                            child: CustomPaint(
                              painter: _ArcPainter(
                                progress: v,
                                color: ringColor,
                                bgColor: Colors.grey.shade800,
                                strokeWidth: 7,
                              ),
                            ),
                          ),
                        ),
                        Text('$value',
                            style:
                                const TextStyle(fontWeight: FontWeight.w900)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      game,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: gameFont,
                      ),
                    ),
                    Text(
                      e.threshold > 0
                          ? rankName(rankLabel(_nearestRank(e.threshold)))
                          : rankLabel(_nearestRank(value)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: rankFont,
                        color: e.threshold > 0 ? ringColor : Colors.white70,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  int _nearestRank(int value) {
    for (final m in milestones) {
      if (value <= m) return m;
    }
    return milestones.last;
  }

  Color _colorForThreshold(int threshold) {
    return switch (threshold) {
      >= 30 => const Color(0xFFF1A949),
      >= 20 => const Color(0xFFBA68C8),
      >= 15 => const Color(0xFF4FC3F7),
      >= 10 => const Color(0xFF81C784),
      >= 5 => const Color(0xFFFFB74D),
      _ => ThemeData.dark().colorScheme.primary,
    };
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

    // background
    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, bgPaint);

    // progress
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
//profile_page.dart

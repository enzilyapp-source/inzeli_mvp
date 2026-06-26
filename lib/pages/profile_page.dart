// lib/pages/profile_page.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/app_snackbar.dart';

import '../state.dart';
import '../biometric_auth.dart';
import '../widgets/avatar_effects.dart';
import '../widgets/challenge_rank_visuals.dart';
import 'store_page.dart';
import 'my_items_page.dart';
import '../sfx.dart';
import 'signin_page.dart';
import '../api_user.dart';
import 'player_profile_page.dart';

class ProfilePage extends StatefulWidget {
  final AppState app;
  const ProfilePage({super.key, required this.app});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const _deleteUrl = 'https://web.enzily.app/delete-account.html';
  // thresholds and labels for “الأنواط”
  static const List<int> _milestones = [5, 10, 15, 20, 30];
  String? _selectedThemeId;
  int _cardThemeIndex = 0; // 0: blue, 1: navy, 2: violet
  List<String> _labels(AppState app) => [
        app.tr(ar: 'عليمي', en: 'Beginner'),
        app.tr(ar: 'يمشي حاله', en: 'Advance'),
        app.tr(ar: 'زين', en: 'Professional'),
        app.tr(ar: 'فنان', en: 'Legend'),
        app.tr(ar: 'فلتة', en: 'GOAT'),
      ];

  final ImagePicker _picker = ImagePicker();
  int _wins = 0;
  int _losses = 0;
  bool _showPearlProgress = false;
  bool _showChallenges = false;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  @override
  void initState() {
    super.initState();
    _selectedThemeId = widget.app.themeId;
    _cardThemeIndex = _cardIndexFromId(widget.app.cardId);
    _nameCtrl = TextEditingController(text: _meName());
    _emailCtrl = TextEditingController(text: widget.app.email ?? '');
    _phoneCtrl = TextEditingController(text: widget.app.phone ?? '');
    _wins = widget.app.winsOf(_meName(), _currentGame());
    _losses = widget.app.lossesOf(_meName(), _currentGame());
    _loadStats();
  }

  String _meName() => widget.app.displayName ?? widget.app.name ?? 'لاعب';
  String _currentGame() {
    String game = widget.app.selectedGame ?? '—';
    if (widget.app.gamePearls.isNotEmpty) {
      final top = widget.app.gamePearls.entries
          .reduce((a, b) => a.value >= b.value ? a : b);
      game = top.key;
    }
    return game;
  }

  (String, int) _topPearlGame(AppState app) {
    if (app.gamePearls.isNotEmpty) {
      final top =
          app.gamePearls.entries.reduce((a, b) => a.value >= b.value ? a : b);
      return (app.gameLabel(top.key), top.value);
    }
    if (app.selectedGame != null && app.selectedGame!.isNotEmpty) {
      return (
        app.gameLabel(app.selectedGame!),
        app.pearlsForGame(app.selectedGame!)
      );
    }
    return (app.tr(ar: 'بدون لعبة', en: 'No game'), 0);
  }

  Map<String, dynamic>? _bestBadgeForGame(String gameId) {
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

  String _scopeLabel(Map<String, dynamic>? badge) {
    return switch ((badge?['scope'] ?? '').toString().toUpperCase()) {
      'SPONSOR' => widget.app.tr(ar: 'سبونسر', en: 'Sponsor'),
      'DEWANYAH' => widget.app.tr(ar: 'دوانية', en: 'Dewanyah'),
      _ => widget.app.tr(ar: 'عام', en: 'General'),
    };
  }

  int _badgeThresholdForGame(String gameId, int pearls) {
    final saved =
        (_bestBadgeForGame(gameId)?['threshold'] as num?)?.toInt() ?? 0;
    final current = AppState.badgeThresholdForPearls(pearls);
    return math.max(saved, current);
  }

  String? _badgeLabelForGame(String gameId) {
    final badge = _bestBadgeForGame(gameId);
    final label = badge?['label']?.toString();
    if (label != null && label.isNotEmpty) return _rankName(label);
    return null;
  }

  bool _isAchievementMatch(TimelineEntry entry, String player) {
    final kind = entry.kind.trim().toUpperCase();
    if (kind.startsWith('SEASON_LEADERBOARD')) return true;
    final isWinner = entry.winner == player || entry.winners.contains(player);
    final isLoser = entry.losers.contains(player);
    if (!isWinner && !isLoser) return false;
    if (kind.isEmpty) return true;
    return kind == 'MATCH' ||
        kind == 'MATCH_WIN' ||
        kind == 'MATCH_LOSS' ||
        kind == 'MATCH_FINISHED';
  }

  List<_AchievementEntry> _recentWins(String player) {
    final matches = widget.app.timeline
        .where((t) => _isAchievementMatch(t, player))
        .toList()
      ..sort((a, b) => b.ts.compareTo(a.ts));

    final deduped = <_AchievementEntry>[];
    final seen = <String>{};
    for (final t in matches) {
      final kind = t.kind.trim().toUpperCase();
      if (kind.startsWith('SEASON_LEADERBOARD')) {
        final meta = t.meta ?? const <String, dynamic>{};
        final seasonYm = (meta['seasonYm'] ?? '').toString();
        final scope = (meta['scope'] ?? '').toString();
        final scopeName = (meta['scopeName'] ?? '').toString().trim();
        final gameName = (meta['gameName'] ?? '').toString().trim();
        final scopeLabel =
            (meta['scopeLabelAr'] ?? widget.app.tr(ar: 'العام', en: 'General'))
                .toString();
        final rankLabel =
            (meta['rankLabelAr'] ?? meta['achievementAr'] ?? 'مركز متقدم')
                .toString();
        final detail = scopeName.isNotEmpty
            ? 'ليدر بورد: $scopeLabel - $scopeName'
            : 'ليدر بورد: $scopeLabel';
        final key = [
          'season',
          seasonYm,
          scope,
          t.game,
          (meta['rank'] ?? '').toString(),
          (meta['sponsorCode'] ?? '').toString(),
          (meta['dewanyahId'] ?? '').toString(),
        ].join('|');
        if (!seen.add(key)) continue;
        deduped.add(_AchievementEntry(
          game: gameName.isNotEmpty ? gameName : widget.app.gameLabel(t.game),
          typeLabel: scopeLabel,
          badgeLabel: rankLabel,
          outcomeLabel: rankLabel,
          detailLabel: detail,
          isWin: true,
          isSeasonAward: true,
          date: t.ts,
        ));
        if (deduped.length >= 10) break;
        continue;
      }

      final isWin = t.winner == player || t.winners.contains(player);
      final outcome = isWin ? 'win' : 'loss';
      final roomKey = t.roomCode.trim().isNotEmpty
          ? t.roomCode.trim()
          : '${t.game}|${t.ts.toIso8601String()}|$outcome';
      final key = '${t.game}|$roomKey|$outcome';
      if (!seen.add(key)) continue;

      final badge = _bestBadgeForGame(t.game);
      final badgeLabel = _badgeLabelForGame(t.game);
      deduped.add(_AchievementEntry(
        game: widget.app.gameLabel(t.game),
        typeLabel: badge == null
            ? widget.app.tr(ar: 'لعب', en: 'Match')
            : _scopeLabel(badge),
        badgeLabel: badgeLabel ?? '',
        outcomeLabel: isWin ? 'فاز' : 'خسر',
        detailLabel:
            badgeLabel == null ? 'نتيجة لعب حقيقية' : 'النوط: $badgeLabel',
        isWin: isWin,
        isSeasonAward: false,
        date: t.ts,
      ));
      if (deduped.length >= 10) break;
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

  int _currentRankThreshold() {
    final (_, topPearls) = _topPearlGame(widget.app);
    final savedRank = widget.app.bestBadgeLabel();
    final savedThreshold = widget.app.bestBadgeThreshold();
    final currentThreshold = AppState.badgeThresholdForPearls(topPearls);
    return savedRank != null && savedThreshold > currentThreshold
        ? savedThreshold
        : currentThreshold;
  }

  int _cardIndexFromId(String? id) {
    switch (id) {
      case 'navy':
        return 1;
      case 'violet':
        return 2;
      case 'blue':
      default:
        return 0;
    }
  }

  String _cardId(int idx) {
    switch (idx) {
      case 1:
        return 'navy';
      case 2:
        return 'violet';
      default:
        return 'blue';
    }
  }

  Future<void> _loadStats() async {
    final uid = widget.app.userId;
    if (uid == null || uid.isEmpty) return;
    try {
      final stats = await getUserStats(uid, token: widget.app.token);
      if (stats == null) return;
      setState(() {
        _wins = (stats['wins'] as num?)?.toInt() ?? _wins;
        _losses = (stats['losses'] as num?)?.toInt() ?? _losses;
      });
      final gp = stats['gamePearls'];
      if (gp is Map) {
        widget.app.gamePearls =
            gp.map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0));
        await widget.app.saveState();
        if (mounted) setState(() {});
      }
      await _syncChallengeUnlocks();
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
    setState(() {});
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
                          hintText: 'الاسم أو المعرّف',
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
                            widget.app.upsertUserProfile(display, user);
                            final uid = (user['id'] ?? '').toString();
                            if (uid.isNotEmpty) {
                              final stats = await getUserStats(uid,
                                  token: widget.app.token);
                              if (stats != null) {
                                widget.app.upsertUserStats(display, stats);
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
                            ((user['publicId'] ?? user['id'] ?? '') as Object)
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

  void _openAvatarThemePicker() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFF22324B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        final currentRankThreshold = _currentRankThreshold();
        final ownedThemeIds = <String>{
          ...widget.app.freeThemesOwned,
          if (_selectedThemeId != null && _selectedThemeId!.isNotEmpty)
            _selectedThemeId!,
        };
        final availableThemes = kThemeVisualOptions.where((option) {
          if (option.vipOnly && widget.app.hasActiveVip) return true;
          if (option.unlockThreshold != null) {
            return currentRankThreshold >= option.unlockThreshold!;
          }
          return ownedThemeIds.contains(option.id);
        }).toList();
        final effects = <(String?, String)>[
          (null, 'بدون ثيم'),
          ...availableThemes.map((e) => (e.id, e.label)),
        ];
        final cardThemes = [
          ('أزرق', 0),
          ('كحلي', 1),
          ('بنفسجي', 2),
        ];
        return SafeArea(
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'تعديل الصورة والثيم',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: Color(0xFFDBE7F6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'كل ثيم ينعرض يمينك لليسار، والنوط يبقى ثابت فوق بشكل مستقل.',
                        style: const TextStyle(
                          color: Color(0xFFA8BCD8),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.icon(
                            onPressed: _pickAvatar,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFDCE8F8),
                              foregroundColor: const Color(0xFF22324B),
                            ),
                            icon: const Icon(Icons.image_outlined),
                            label: const Text(
                              'تغيير الصورة',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          if ((widget.app.avatarBase64?.isNotEmpty ?? false) ||
                              (widget.app.avatarPath?.isNotEmpty ?? false))
                            OutlinedButton.icon(
                              onPressed: () async {
                                await _removeAvatar();
                                if (ctx.mounted) Navigator.pop(ctx);
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFDCE8F8),
                                side:
                                    const BorderSide(color: Color(0xFF8AA7C8)),
                              ),
                              icon: const Icon(Icons.delete_outline),
                              label: const Text(
                                'إزالة الصورة',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'ثيم الهالة حول الصورة',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFDBE7F6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 140,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          reverse: true,
                          itemCount: effects.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 10),
                          itemBuilder: (_, index) {
                            final e = effects[index];
                            final selected = _selectedThemeId == e.$1;
                            final preview = CircleAvatar(
                              radius: 26,
                              backgroundColor: const Color(0xFF2A3953),
                              child: Text(
                                e.$2.characters.first,
                                style: const TextStyle(color: Colors.white),
                              ),
                            );
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedThemeId = e.$1),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                width: 104,
                                padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? const Color(0xFFDCE8F8)
                                      : const Color(0xFFCCDCEE),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: selected
                                        ? const Color(0xFF8CB3DA)
                                        : const Color(0xFF8AA7C8),
                                    width: selected ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    buildAvatarThemeWidget(
                                      themeId: e.$1,
                                      size: 74,
                                      animate: e.$1 != null,
                                      child: preview,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      e.$2,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: const Color(0xFF22324B),
                                        fontWeight: selected
                                            ? FontWeight.w800
                                            : FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'ثيم كرت الملف',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFDBE7F6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: cardThemes.map((c) {
                          final selected = _cardThemeIndex == c.$2;
                          return ChoiceChip(
                            label: Text(
                              c.$1,
                              style: const TextStyle(color: Color(0xFF22324B)),
                            ),
                            selected: selected,
                            selectedColor: const Color(0xFFDCE8F8),
                            backgroundColor: const Color(0xFFCCDCEE),
                            side: BorderSide(
                              color: selected
                                  ? const Color(0xFF8CB3DA)
                                  : const Color(0xFF8AA7C8),
                            ),
                            onSelected: (_) =>
                                setState(() => _cardThemeIndex = c.$2),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: () async {
                            widget.app.themeId = _selectedThemeId;
                            widget.app.cardId = _cardId(_cardThemeIndex);
                            await widget.app.saveState();
                            await widget.app.syncProfileToServer(
                              includeAvatarData: false,
                            );
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            setState(() {});
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFDCE8F8),
                            foregroundColor: const Color(0xFF22324B),
                          ),
                          icon: const Icon(Icons.save),
                          label: const Text(
                            'حفظ',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openRankSheet(int currentRankThreshold) {
    final currentRank = playerRankForThreshold(currentRankThreshold);
    final ranks = PlayerRank.values;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'الأنواط',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              const SizedBox(height: 14),
              ...ranks.map((rank) {
                final data = getRankData(rank);
                final active = rank == currentRank;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: active ? 0.08 : 0.04),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: active
                          ? data.colors.last.withValues(alpha: 0.8)
                          : Colors.white12,
                    ),
                  ),
                  child: Row(
                    children: [
                      RankBadge(rank: rank),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${data.arabic} • ${data.english}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final meName = app.displayName ?? app.name ?? 'لاعب';
    final displayUserId = app.publicId ?? app.userId ?? '';
    final (topGameName, topPearls) = _topPearlGame(app);
    final savedRank = app.bestBadgeLabel();
    final savedThreshold = app.bestBadgeThreshold();
    final currentThreshold = AppState.badgeThresholdForPearls(topPearls);
    final currentRankThreshold =
        savedRank != null && savedThreshold > currentThreshold
            ? savedThreshold
            : currentThreshold;
    final currentRankVisual = playerRankForThreshold(currentRankThreshold);
    final recentWins = _recentWins(meName);
    final screenWidth = MediaQuery.of(context).size.width;
    final compactHeader = screenWidth < 390;
    final headerHeight = compactHeader ? 184.0 : 192.0;
    final avatarRadius = compactHeader ? 38.0 : 42.0;
    final pearlBadgeSize = compactHeader ? 54.0 : 60.0;
    final trophySize = compactHeader ? 36.0 : 42.0;
    final badgeTopGap = compactHeader ? 0.0 : 2.0;
    final badgeRowLift = compactHeader ? -24.0 : -22.0;
    final badgeRowSlotHeight = compactHeader ? 32.0 : 34.0;
    final badgeRowMaxHeight = compactHeader ? 88.0 : 96.0;
    final headerBg = _cardThemeIndex == 0
        ? const Color(0xFF1E2F4D)
        : _cardThemeIndex == 1
            ? const Color(0xFF0F1D32)
            : const Color(0xFF2D1B46); // violet theme option

    ImageProvider? avatarImage;
    if (app.avatarBase64 != null && app.avatarBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(app.avatarBase64!);
        avatarImage = MemoryImage(bytes);
      } catch (_) {}
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header (hero with avatar, top game pearls, and recent trophies)
        Card(
          elevation: 6,
          clipBehavior: Clip.antiAlias,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: SizedBox(
            height: headerHeight,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: headerBg,
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                PositionedDirectional(
                  top: 12,
                  start: 12,
                  child: GestureDetector(
                    onTap: () => _openRankSheet(currentRankThreshold),
                    child: RankBadge(rank: currentRankVisual),
                  ),
                ),
                PositionedDirectional(
                  top: 12,
                  end: 12,
                  child: Material(
                    color: const Color(0xFF121D30).withValues(alpha: 0.82),
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: app.tr(ar: 'الإعدادات', en: 'Settings'),
                      onPressed: () => _openSettings(app),
                      icon: const Icon(Icons.settings_outlined,
                          color: Colors.white, size: 20),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          buildAvatarThemeWidget(
                            themeId: _selectedThemeId,
                            size: compactHeader ? 96.0 : 108.0,
                            animate: true,
                            child: CircleAvatar(
                              radius: avatarRadius,
                              backgroundImage: avatarImage,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.12),
                              child: avatarImage == null
                                  ? Text(
                                      meName.isNotEmpty
                                          ? meName.characters.first
                                          : '؟',
                                      style: const TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white),
                                    )
                                  : null,
                            ),
                          ),
                          Positioned(
                            bottom: 2,
                            right: 4,
                            child: InkWell(
                              onTap: _openAvatarThemePicker,
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.edit,
                                    size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        meName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                      if (displayUserId.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          _shortId(displayUserId),
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
        SizedBox(height: badgeTopGap),
        SizedBox(
          height: badgeRowSlotHeight,
          child: OverflowBox(
            minHeight: 0,
            maxHeight: badgeRowMaxHeight,
            alignment: Alignment.topCenter,
            child: Transform.translate(
              offset: Offset(0, badgeRowLift),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _PearlBadge(
                      game: topGameName,
                      pearls: topPearls,
                      size: pearlBadgeSize,
                    ),
                    _TrophyStrip(
                      recentWins: recentWins,
                      size: trophySize,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: compactHeader ? 0 : 2),

        // Stats row (icons فقط)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _IconStat(
                icon: Icons.emoji_events_outlined,
                value: _wins,
                sparkleColor: Colors.greenAccent),
            _IconStat(
                icon: Icons.cancel_outlined,
                value: _losses,
                sparkleColor: Colors.redAccent),
          ],
        ),

        const SizedBox(height: 10),
        _AchievementsCard(
          recentWins: recentWins,
          onShowAll: recentWins.length > 5
              ? () => _openAllAchievements(recentWins)
              : null,
        ),

        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: Divider(
                color: Colors.white.withValues(alpha: 0.28),
                thickness: 1.2,
                endIndent: 10,
              ),
            ),
            InkWell(
              onTap: () =>
                  setState(() => _showPearlProgress = !_showPearlProgress),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: Icon(
                  _showPearlProgress
                      ? Icons.expand_less_rounded
                      : Icons.more_horiz_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: Colors.white.withValues(alpha: 0.28),
                thickness: 1.2,
                indent: 10,
              ),
            ),
          ],
        ),

        if (_showPearlProgress) ...[
          const SizedBox(height: 8),
          // Pearls per game (دائرة تعبئة لكل لعبة)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _PearlCircleGrid(
                entries: _gamePearlEntries(app, meName),
                maxValue: _milestones.last,
                milestones: _milestones,
                rankLabel: _labelFor,
                rankName: _rankName,
              ),
            ),
          ),
        ],

        const SizedBox(height: 12),

        // Quick actions row moved to bottom
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _QuickActionChip(
              icon: Icons.shopping_bag_outlined,
              label: app.tr(ar: 'المتجر', en: 'Market'),
              onTap: () => _openStore(app),
            ),
            _QuickActionChip(
              icon: Icons.search,
              label: app.tr(ar: 'بحث', en: 'Search'),
              onTap: _openPlayerSearch,
            ),
            _QuickActionChip(
              icon: Icons.style_outlined,
              label: app.tr(ar: 'ثيماتي', en: 'My Themes'),
              onTap: () => _openItems(app),
            ),
            _QuickActionChip(
              icon: Icons.flag_outlined,
              label: app.tr(ar: 'التحديات', en: 'Challenges'),
              onTap: () => setState(() => _showChallenges = !_showChallenges),
            ),
          ],
        ),

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
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
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
                    final wins = widget.app.winsOf(meName, challenge.gameId);
                    final unlocked =
                        widget.app.freeThemesOwned.contains(challenge.id);
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
                              child: Icon(Icons.style, color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                    color: Colors.white.withValues(alpha: 0.72),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 6,
                                  borderRadius: BorderRadius.circular(999),
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
                              color:
                                  unlocked ? Colors.greenAccent : Colors.white,
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
        const SizedBox(height: 12),
      ],
    );
  }

  // ---------- helpers ----------

  String _labelFor(int milestone) {
    final labels = _labels(widget.app);
    final idx = _milestones.indexOf(milestone);
    return (idx >= 0 && idx < labels.length) ? labels[idx] : '';
    // 5: عليمي, 10: يمشي حاله, 15: زين, 20: فنان, 30: فلتة
  }

  String _rankName(String name) {
    final arName = switch (name) {
      'Beginner' => 'عليمي',
      'Advance' => 'يمشي حاله',
      'Professional' => 'زين',
      'Legend' => 'فنان',
      'GOAT' || 'فلته' => 'فلتة',
      _ => name,
    };
    return widget.app.tr(
      ar: arName,
      en: switch (arName) {
        'عليمي' => 'Beginner',
        'يمشي حاله' => 'Advance',
        'زين' => 'Professional',
        'فنان' => 'Legend',
        'فلتة' => 'GOAT',
        'بدايات' => 'Newbie',
        _ => name,
      },
    );
  }

  List<_GamePearlEntry> _gamePearlEntries(AppState app, String player) {
    final entries = <_GamePearlEntry>[];
    for (final cat in app.games.values) {
      for (final g in cat) {
        final pearls = app.pearlsForGame(g);
        final played = app.winsOf(player, g) + app.lossesOf(player, g);
        final threshold = _badgeThresholdForGame(g, pearls);
        final hasEarnedBadge = _bestBadgeForGame(g) != null;
        entries.add(_GamePearlEntry(
          gameId: g,
          label: app.gameLabel(g),
          pearls: pearls,
          threshold: threshold,
          active: played > 0 || pearls != 5 || hasEarnedBadge,
        ));
      }
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
  final String game;
  final String typeLabel;
  final String badgeLabel;
  final String outcomeLabel;
  final String detailLabel;
  final bool isWin;
  final bool isSeasonAward;
  final DateTime date;

  const _AchievementEntry({
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
  final int threshold;
  final bool active;

  const _GamePearlEntry({
    required this.gameId,
    required this.label,
    required this.pearls,
    required this.threshold,
    required this.active,
  });
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
    return Stack(
      alignment: Alignment.center,
      children: [
        _SparkleOnce(
          color: const Color(0xFFF1A949),
          size: size + 16,
        ),
        Container(
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
        ),
      ],
    );
  }
}

class _AchievementsCard extends StatelessWidget {
  final List<_AchievementEntry> recentWins;
  final VoidCallback? onShowAll;
  const _AchievementsCard({required this.recentWins, this.onShowAll});

  String _date(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final wins = recentWins.take(5).toList();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.emoji_events_rounded, color: Colors.amber),
                  SizedBox(width: 8),
                  Text(
                    'مسيرتي',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (wins.isNotEmpty)
                ...wins.map(
                  (win) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: (win.isWin ? Colors.amber : Colors.redAccent)
                                .withValues(alpha: .18),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            win.isSeasonAward
                                ? Icons.auto_awesome_rounded
                                : win.isWin
                                    ? Icons.workspace_premium
                                    : Icons.close_rounded,
                            color: win.isWin ? Colors.amber : Colors.redAccent,
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
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                win.detailLabel,
                                textAlign: TextAlign.right,
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
                          _date(win.date),
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .65),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (onShowAll != null) ...[
                const SizedBox(height: 2),
                Center(
                  child: IconButton(
                    onPressed: onShowAll,
                    tooltip: 'عرض كل المسيرة',
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      color: Colors.white.withValues(alpha: 0.9),
                      size: 24,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TrophyStrip extends StatelessWidget {
  final List<_AchievementEntry> recentWins;
  final double size;
  const _TrophyStrip({required this.recentWins, this.size = 46});

  @override
  Widget build(BuildContext context) {
    final trophies = recentWins.take(3).toList();
    const trophyFill = Color(0xFFE3E6EF);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        if (i >= trophies.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: _TrophyCircle(
              label: '—',
              date: null,
              filled: false,
              color: Colors.white.withValues(alpha: .4),
              size: size,
            ),
          );
        }
        final t = trophies[i];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: _TrophyCircle(
            label: t.game,
            date: t.date,
            filled: true,
            color: trophyFill,
            size: size,
          ),
        );
      }),
    );
  }
}

class _TrophyCircle extends StatelessWidget {
  final String label;
  final DateTime? date;
  final bool filled;
  final Color color;
  final double size;
  const _TrophyCircle(
      {required this.label,
      required this.date,
      required this.filled,
      required this.color,
      this.size = 46});

  @override
  Widget build(BuildContext context) {
    final textColor = filled ? Colors.black : Colors.white;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: filled ? color : Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events_rounded,
                size: size * 0.35, color: Colors.amber),
            if (filled) ...[
              SizedBox(height: size * 0.05),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w800,
                  fontSize: size * 0.22,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SparkleOnce extends StatefulWidget {
  final Color color;
  final double size;
  const _SparkleOnce({
    required this.color,
    this.size = 60,
  });

  @override
  State<_SparkleOnce> createState() => _SparkleOnceState();
}

class _SparkleOnceState extends State<_SparkleOnce>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _SparklePainter(
            color: widget.color,
            progress: Curves.easeOut.transform(_ctrl.value),
          ),
        ),
      ),
    );
  }
}

class _SparklePainter extends CustomPainter {
  final Color color;
  final double progress; // 0..1
  _SparklePainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseR = size.shortestSide / 2.8;
    final sparkles = 16;
    final maxBurst = size.shortestSide * 0.45;
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < sparkles; i++) {
      final angle = (2 * math.pi / sparkles) * i;
      final burst = baseR + progress * maxBurst;
      final pos = center + Offset(math.cos(angle), math.sin(angle)) * burst;
      final fade = (1 - progress).clamp(0.0, 1.0);
      final alpha = (fade * 0.7).clamp(0.0, 0.7);
      paint.color = color.withValues(alpha: alpha);
      final radius = (1.2 + (i % 3) * 0.4) * fade * 1.8;
      canvas.drawCircle(pos, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class _IconStat extends StatefulWidget {
  final IconData icon;
  final int value;
  final Color? sparkleColor;
  const _IconStat({required this.icon, required this.value, this.sparkleColor});

  @override
  State<_IconStat> createState() => _IconStatState();
}

class _IconStatState extends State<_IconStat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _scale = Tween<double>(begin: 1, end: 0.9)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _ctrl.forward();
  void _onTapCancel() => _ctrl.reverse();
  void _onTapUp(TapUpDetails _) => _ctrl.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapCancel: _onTapCancel,
      onTapUp: _onTapUp,
      child: ScaleTransition(
        scale: _scale,
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                if (widget.sparkleColor != null)
                  _SparkleOnce(
                    color: widget.sparkleColor!,
                    size: 54,
                  ),
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  child: Icon(widget.icon, color: Colors.white, size: 22),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('${widget.value}',
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
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
      {required this.entries,
      required this.maxValue,
      required this.milestones,
      required this.rankLabel,
      required this.rankName});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const Text('لا توجد بيانات');
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
            final value = e.pearls.clamp(0, maxValue);
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

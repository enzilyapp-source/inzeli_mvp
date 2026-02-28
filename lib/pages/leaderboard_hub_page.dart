// lib/pages/leaderboard_hub_page.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import '../widgets/avatar_effects.dart';
import '../state.dart';
import '../api_leaderboard.dart';
import '../api_sponsor.dart';
import '../api_dewanyah.dart';
import '../api_user.dart';
import 'sponsor_page.dart';
import 'games_page.dart';
import 'player_profile_page.dart';
import 'dewanyah_list_page.dart';

class LeaderboardHubPage extends StatefulWidget {
  final AppState app;
  final int initialTab; // 0=regular, 1=sponsor, 2=dewanyah
  const LeaderboardHubPage({super.key, required this.app, this.initialTab = 0});

  @override
  State<LeaderboardHubPage> createState() => _LeaderboardHubPageState();
}

class _LeaderboardHubPageState extends State<LeaderboardHubPage> {
  late int tab; // 0 = Regular, 1 = Sponsor, 2 = Dewanyah

  // sponsor selection inside sponsor leaderboard
  String? _sponsorCode;
  String? _sponsorName;
  String? _selectedGameId;

  final PageController _regularPager = PageController();
  final PageController _sponsorPager = PageController();
  final PageController _dewPager = PageController();
  bool _tutorialShown = false;

  int _regularPage = 0;
  int _sponsorPage = 0;
  int _dewPage = 0;

  final TextEditingController _playerSearchCtrl = TextEditingController();
  final TextEditingController _dewNameCtrl = TextEditingController();
  final TextEditingController _dewContactCtrl = TextEditingController();
  final TextEditingController _dewNoteCtrl = TextEditingController();
  String _dewGame = 'بلوت';

  late List<Map<String, dynamic>> _dewanyahSpaces;
  bool _loadingSponsors = false;
  bool _loadingDew = false;
  bool _loadingGames = false;
  String? _sponsorError;
  String? _dewError;
  List<Map<String, dynamic>> _sponsors = const [];
  List<Map<String, dynamic>> _sponsorGames = const [];

  static const List<Map<String, dynamic>> _mockSponsors = [
    {
      "code": "SP-BOBYAN",
      "name": "بوبيان",
      "games": [
        {"gameId": "بلوت", "name": "بلوت", "prizeAmount": 300},
        {"gameId": "كوت", "name": "كوت", "prizeAmount": 180},
      ]
    },
    {
      "code": "SP-OOREEDO",
      "name": "أوريدو",
      "games": [
        {"gameId": "كونكان", "name": "كونكان", "prizeAmount": 200},
        {"gameId": "دومينو", "name": "دومينو", "prizeAmount": 120},
      ]
    },
  ];

  @override
  void initState() {
    super.initState();
    tab = widget.initialTab.clamp(0, 2);
    _dewanyahSpaces = [..._seedDewanyahs(), ..._ownedAsSpaces()];
    _loadSponsors();
    _loadDewanyahs();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTutorial());
  }

  @override
  void dispose() {
    _regularPager.dispose();
    _sponsorPager.dispose();
    _dewPager.dispose();
    _playerSearchCtrl.dispose();
    _dewNameCtrl.dispose();
    _dewContactCtrl.dispose();
    _dewNoteCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _seedDewanyahs() => [
        {
          'name': 'ديوانية المشاري',
          'owner': 'المشاري',
          'gameId': 'بلوت',
          'prizeAmount': 120,
          'status': 'live',
          'startingPearls': 5,
          'players': _mockBoard(basePearls: 5),
        },
        {
          'name': 'ديوانية قرطبة',
          'owner': 'أبو علي',
          'gameId': 'كونكان',
          'prizeAmount': 90,
          'status': 'live',
          'startingPearls': 5,
          'players': _mockBoard(basePearls: 5),
        },
      ];

  List<Map<String, dynamic>> _ownedAsSpaces() {
    if (widget.app.ownedDewanyahs.isEmpty) return const [];
    return widget.app.ownedDewanyahs.map((d) {
      return {
        'name': d['name'] ?? 'ديوانية جديدة',
        'owner': d['ownerName'] ?? widget.app.displayName ?? 'أنت',
        'gameId': d['gameId'] ?? 'بلوت',
        'prizeAmount': d['prizeAmount'] ?? 50,
        'status': d['status'] ?? 'pending',
        'startingPearls': d['startingPearls'] ?? 5,
        'players': d['players'] is List ? d['players'] : _mockBoard(basePearls: 5),
      };
    }).toList();
  }

  Future<void> _loadSponsors() async {
    setState(() {
      _loadingSponsors = true;
      _sponsorError = null;
    });
    try {
      final list = await ApiSponsors.listSponsors();
      setState(() {
        _sponsors = list.isNotEmpty ? list : _mockSponsors;
      });

      final source = _sponsors;
      if (source.isNotEmpty) {
        final first = source.first;
        final code = (first['code'] ?? '').toString();
        final name = (first['name'] ?? code).toString();
        await _selectSponsor(code, name);
      } else {
        setState(() {
          _sponsorCode = null;
          _sponsorName = null;
          _selectedGameId = null;
          _sponsorGames = const [];
        });
      }
    } catch (e) {
      setState(() => _sponsorError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingSponsors = false);
    }
  }

  Future<void> _loadDewanyahs() async {
    setState(() {
      _loadingDew = true;
      _dewError = null;
    });
    try {
      final list = await ApiDewanyah.listAll();
      final mapped = list.map((d) {
        final games = (d['games'] as List?) ?? const [];
        final gid = games.isNotEmpty
            ? (games.first is Map ? (games.first['gameId'] ?? games.first['id']) : games.first).toString()
            : (d['gameId'] ?? '').toString();
        return {
          'id': d['id']?.toString(),
          'name': d['name'],
          'owner': d['ownerName'] ?? d['owner'] ?? '',
          'ownerUserId': d['ownerUserId'],
          'gameId': gid,
          'games': games,
          'status': d['status'] ?? 'active',
          'players': const <Map<String, dynamic>>[],
          'prizeAmount': d['prizeAmount'] ?? 50,
        };
      }).toList();

      setState(() {
        _dewanyahSpaces = mapped.isNotEmpty ? mapped : _seedDewanyahs();
        _dewPage = 0;
        if (_dewPager.hasClients) _dewPager.jumpToPage(0);
      });
    } catch (e) {
      setState(() => _dewError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingDew = false);
    }
  }

  Future<void> _maybeShowTutorial() async {
    if (_tutorialShown || widget.app.tutorialSeen == true) return;
    _tutorialShown = true;
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('جولة سريعة', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 10),
              _tutorialRow(Icons.sports_esports, '١) اختر اللعبة', 'من الشريط العلوي: العاب إنزلي / سبونسرات / دواوين.'),
              const SizedBox(height: 6),
              _tutorialRow(Icons.play_circle_fill, '٢) اضغط انزلي وبلّش التحدي', 'يُنفتح روم، وانتظر لاعبين ثم شغّل العدّاد.'),
              const SizedBox(height: 6),
              _tutorialRow(Icons.flag, '٣) النتيجة بعد انتهاء العدّاد', 'إذا صفّر العداد احسم النتيجة واختر الفائز. اللآلئ تُخصم من الخاسرين فقط.'),
              const SizedBox(height: 6),
              _tutorialRow(Icons.trending_up, '٤) ادخل شسالفة وشوف شسالفة!', 'تابع الخط الزمني والستريك وآخر النتائج.'),
              const SizedBox(height: 10),
              _tutorialRow(Icons.emoji_events, 'المراتب', 'شوف وين واصل كل لاعب.'),
              _tutorialRow(Icons.sports_esports, 'الألعاب', 'الروم والعدّاد والحسم.'),
              _tutorialRow(Icons.help, 'شسالفة؟', 'الخطة الزمنية للتحديثات.'),
              _tutorialRow(Icons.tv, 'سبونسرات', 'لآلئ الرعاة لكل لعبة.'),
              _tutorialRow(Icons.person, 'ملفي', 'بياناتك وإعداداتك.'),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    widget.app.markTutorialSeen();
                    Navigator.pop(context);
                  },
                  child: const Text('تم'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tutorialRow(IconData icon, String title, String body) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2, left: 12),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(body, style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _selectSponsor(String code, String name) async {
    setState(() {
      _sponsorCode = code;
      _sponsorName = name;
      _loadingGames = true;
      _sponsorError = null;
      _sponsorGames = const [];
      _selectedGameId = null;
    });

    try {
      final detail = await ApiSponsors.getSponsorDetail(code: code, token: widget.app.token);
      final rawGames = (detail['games'] as List?) ?? const [];
      final games = <Map<String, dynamic>>[];

      for (final g in rawGames) {
        if (g is! Map) continue;
        final gameObj = (g['game'] as Map?)?.cast<String, dynamic>() ?? const {};
        final gid = (g['gameId'] ?? gameObj['id'] ?? '').toString();
        if (gid.isEmpty) continue;
        games.add({
          'gameId': gid,
          'name': (gameObj['name'] ?? gid).toString(),
          'prizeAmount': (g['prizeAmount'] as num?)?.toInt() ?? 0,
        });
      }

      setState(() {
        _sponsorGames = games;
        if (games.isNotEmpty) {
          _selectedGameId = games.first['gameId'] as String;
          _sponsorPage = 0;
          if (_sponsorPager.hasClients) {
            _sponsorPager.jumpToPage(0);
          }
        }
      });
    } catch (e) {
      setState(() => _sponsorError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingGames = false);
    }
  }

  List<Map<String, dynamic>> _mockBoard({int basePearls = 5}) => [
        {"displayName": "Nasser H.", "pearls": basePearls, "streak": 5},
        {"displayName": "Ahmad", "pearls": basePearls - 1, "streak": 2},
        {"displayName": "Saad", "pearls": basePearls - 2, "streak": 0},
        {"displayName": "Futun", "pearls": basePearls - 3, "streak": 0},
      ];

  void _msg(String text, {bool error = false, bool success = false}) {
    if (!mounted) return;
    final Color color = error
        ? Colors.redAccent
        : success
            ? Colors.green
            : Theme.of(context).colorScheme.secondary;
    final IconData icon = error
        ? Icons.close
        : success
            ? Icons.check_circle
            : Icons.info_outline;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.black87,
        content: Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Expanded(child: Text(text)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPlayerProfile() async {
    final name = _playerSearchCtrl.text.trim();
    if (name.isEmpty) {
      _msg('اكتب اسم اللاعب للبحث', error: true);
      return;
    }
    try {
      _msg('جارِ البحث ...');
      final results = await searchUsers(name, token: widget.app.token);
      if (results.isEmpty) {
      _msg('لم يتم العثور على اللاعب', error: true);
      return;
    }
      Map<String, dynamic> pickExact() {
        String norm(String? s) => (s ?? '').trim().toLowerCase();
        for (final r in results) {
          if (norm(r['displayName']) == norm(name) || norm(r['name']) == norm(name)) {
            return r;
          }
        }
        return results.first;
      }

      final user = pickExact();
      final display = (user['displayName'] ?? user['name'] ?? name).toString();
      final profileKey = display;
      widget.app.upsertUserProfile(profileKey, {
        'id': user['id'] ?? user['userId'],
        'publicId': user['publicId'],
        'email': user['email'],
        'phone': user['phone'],
        'displayName': display,
        'avatarUrl': user['avatarUrl'] ?? user['avatarPath'] ?? user['avatar'],
        'avatarBase64': user['avatarBase64'],
        'themeId': user['themeId'],
      });

      final uid = (user['id'] ?? user['userId'])?.toString();
      if (uid != null && uid.isNotEmpty) {
        final stats = await getUserStats(uid, token: widget.app.token, gameId: widget.app.selectedGame);
        if (stats != null) {
          widget.app.upsertUserStats(profileKey, stats);
        }
      }

      if (!mounted) return;
      await _showSearchResultsSheet(results);
    } catch (_) {
      _msg('تعذر إحضار بيانات اللاعب، حاول مرة أخرى', error: true);
    }
  }

  VoidCallback _ctaActionForTab() {
    if (tab == 0) {
      return () => Navigator.push(context, MaterialPageRoute(builder: (_) => GamesPage(app: widget.app)));
    }
    if (tab == 1) {
      return _openSponsorPage;
    }
    return _openDewanyahList;
  }

  String _ctaLabelForTab() {
    if (tab == 0) return widget.app.tr(ar: 'انــزلـي', en: 'Start');
    if (tab == 1) return widget.app.tr(ar: 'سبونسرات', en: 'Sponsors');
    return widget.app.tr(ar: 'دواوين', en: 'Dewanyahs');
  }

  void _openSponsorPage() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => SponsorPage(app: widget.app)));
  }

  void _openDewanyahList() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DewanyahListPage(app: widget.app)),
    );
  }

  Future<void> _submitDewanyahRequest({bool closeSheet = false}) async {
    final name = _dewNameCtrl.text.trim();
    final contact = _dewContactCtrl.text.trim();
    if (name.isEmpty || contact.isEmpty) {
      _msg('عبئ اسم الديوانية ووسيلة التواصل', error: true);
      return;
    }
    final note = _dewNoteCtrl.text.trim();
    await widget.app.addDewanyahRequest(name: name, contact: contact, gameId: _dewGame, note: note);

    if (!mounted) return;
    setState(() {
      _dewanyahSpaces.insert(0, {
        'name': name,
        'owner': widget.app.displayName ?? 'أنت',
        'gameId': _dewGame,
        'prizeAmount': 50,
        'status': 'pending',
        'startingPearls': 5,
        'players': [
          {'displayName': widget.app.displayName ?? 'أنت', 'pearls': 5, 'streak': 0},
        ],
      });
      _dewPage = 0;
      _dewPager.jumpToPage(0);
    });

    _dewNameCtrl.clear();
    _dewContactCtrl.clear();
    _dewNoteCtrl.clear();
    _msg('استلمنا طلب الديوانية، سنتواصل معك للتفعيل', success: true);
    if (closeSheet && mounted) Navigator.pop(context);
  }

  List<_BoardSpec> _regularBoards(AppState app) {
    final games = <String>{};
    for (final list in app.games.values) {
      games.addAll(list);
    }
    if (games.isEmpty) return const [];

    return games.map((g) {
      return _BoardSpec(
        title: 'Top Players • ${app.gameLabel(g)}',
        gameId: g,
        prize: null,
        showSponsorPearls: false,
        loader: () async {
          final rows = await ApiLeaderboard.globalTop(token: app.token, gameId: g);
          if (rows.isEmpty) return _mockBoard(basePearls: 5);
          return rows
              .map((r) => {
                    'displayName': (r['displayName'] ?? r['name'] ?? '').toString(),
                    'pearls': (r['pearls'] ?? r['permanentScore'] ?? 0),
                    'streak': 0,
                  })
              .toList();
        },
        fallback: _mockBoard(basePearls: 5),
      );
    }).toList();
  }

  List<_BoardSpec> _sponsorBoards(AppState app) {
    if (_sponsorCode == null || _sponsorGames.isEmpty) return const [];

    return _sponsorGames.map((g) {
      final gid = (g['gameId'] ?? '').toString();
      final gameName = (g['name'] ?? gid).toString();
      final prize = (g['prizeAmount'] as num?)?.toInt();
      return _BoardSpec(
        title: '${_sponsorName ?? _sponsorCode ?? 'السبونسر'} • $gameName',
        gameId: gameName,
        prize: prize,
        showSponsorPearls: true,
        loader: () => ApiLeaderboard.sponsorGameTop(
          sponsorCode: _sponsorCode!,
          gameId: gid,
          token: app.token,
        ),
        fallback: _mockBoard(basePearls: 5),
      );
    }).toList();
  }

  List<_BoardSpec> _dewBoards() {
    final specs = <_BoardSpec>[];
    for (final d in _dewanyahSpaces) {
      final dewId = d['id']?.toString();
      final games = ((d['games'] as List?) ?? const [])
          .map((g) => g is Map ? (g['gameId']?.toString() ?? '') : g.toString())
          .where((g) => g.isNotEmpty)
          .toList();
      final fallbackGame = (d['gameId'] ?? '').toString();
      final gameIds = games.isNotEmpty ? games : [fallbackGame];

      for (final gid in gameIds) {
        specs.add(
          _BoardSpec(
            title: '${d['name']?.toString() ?? 'ديوانية'} • $gid',
            gameId: gid.isNotEmpty ? gid : '—',
            prize: d['prizeAmount'] is int ? d['prizeAmount'] as int : null,
            showSponsorPearls: false,
            fallback: (d['players'] as List?)?.cast<Map<String, dynamic>>() ?? _mockBoard(basePearls: 5),
            badge: d['status']?.toString(),
            owner: d['owner']?.toString(),
            fivePearlsNote: true,
            loader: dewId == null ? null : () => ApiDewanyah.leaderboard(dewanyahId: dewId),
          ),
        );
      }
    }
    return specs;
  }

  void _openBoardDetail(List<_BoardSpec> specs, int index) {
    if (specs.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _BoardDetailPage(
          specs: specs,
          initialIndex: index.clamp(0, specs.length - 1),
        ),
      ),
    );
  }

  Widget _buildApplyFields({bool compact = false}) {
    final spacing = compact ? 8.0 : 12.0;
    final gameOptions = <String>[];
    for (final cat in widget.app.categories) {
      for (final g in widget.app.games[cat] ?? const <String>[]) {
        if (!gameOptions.contains(g)) gameOptions.add(g);
      }
    }
    final currentGame =
        gameOptions.contains(_dewGame) ? _dewGame : (gameOptions.isNotEmpty ? gameOptions.first : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _dewNameCtrl,
          decoration: const InputDecoration(labelText: 'اسم الديوانية'),
        ),
        SizedBox(height: spacing),
        DropdownButtonFormField<String>(
          initialValue: currentGame,
          decoration: const InputDecoration(labelText: 'اللعبة الأساسية'),
          items: gameOptions
              .map((g) => DropdownMenuItem(
                    value: g,
                    child: Text(widget.app.gameLabel(g)),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _dewGame = v ?? _dewGame),
        ),
        SizedBox(height: spacing),
        TextField(
          controller: _dewContactCtrl,
          decoration: const InputDecoration(labelText: 'رقم/إيميل للتواصل'),
        ),
        SizedBox(height: spacing),
        TextField(
          controller: _dewNoteCtrl,
          maxLines: compact ? 2 : 3,
          decoration: const InputDecoration(labelText: 'ملاحظات / قواعد خاصة'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    final regularSpecs = _regularBoards(app);
    final sponsorSpecs = _sponsorBoards(app);
    final dewSpecs = _dewBoards();
    final sponsorOnlyMode = widget.initialTab == 1;

    if (sponsorOnlyMode) {
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'سبونسر',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: onSurface,
                  fontSize: 20,
                ),
                ),
              ),
              TextButton.icon(
                onPressed: _loadSponsors,
                icon: const Icon(Icons.refresh),
                label: const Text('تحديث'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildSponsorSelectorCard(),
          const SizedBox(height: 10),
          _SectionTitle('لوحة السبونسر', icon: Icons.local_fire_department),
          const SizedBox(height: 6),
          _buildSponsorLeaderboards(sponsorSpecs),
          const SizedBox(height: 10),
          _PrimaryCtaButton(
            label: _ctaLabelForTab(),
            onPressed: _ctaActionForTab(),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Tabs
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF172133).withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Expanded(
                child: _TabChip(
                  selected: tab == 0,
                  text: widget.app.tr(ar: 'انزلي', en: 'Start'),
                  onTap: () => setState(() => tab = 0),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _TabChip(
                  selected: tab == 1,
                  text: widget.app.tr(ar: 'سبونسرات', en: 'Sponsors'),
                  onTap: () => setState(() => tab = 1),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _TabChip(
                  selected: tab == 2,
                  text: widget.app.tr(ar: 'دواوين', en: 'Dewanyahs'),
                  onTap: () => setState(() => tab = 2),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        _PlayerSearchBar(
          controller: _playerSearchCtrl,
          onSearch: _openPlayerProfile,
        ),

        const SizedBox(height: 12),

        if (tab == 0) ...[
          _SectionTitle('Top Players (العام)', icon: Icons.emoji_events),
          const SizedBox(height: 8),
          _LeaderboardPager(
            controller: _regularPager,
            current: _regularPage,
            specs: regularSpecs,
            onPageChanged: (i) => setState(() => _regularPage = i),
            onOpen: (i) => _openBoardDetail(regularSpecs, i),
          ),
        ] else if (tab == 1) ...[
          _buildSponsorSelectorCard(),
          const SizedBox(height: 10),
          _SectionTitle('Top Players (${_sponsorName ?? _sponsorCode ?? 'السبونسر'})',
              icon: Icons.local_fire_department),
          const SizedBox(height: 8),
          _buildSponsorLeaderboards(sponsorSpecs),
        ] else if (tab == 1) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  'سبونسر',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: onSurface,
                    fontSize: 20,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _loadSponsors,
                icon: const Icon(Icons.refresh),
                label: const Text('تحديث'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildSponsorSelectorCard(),
          const SizedBox(height: 10),
          _SectionTitle('لوحة السبونسر', icon: Icons.local_fire_department),
          const SizedBox(height: 6),
          _buildSponsorLeaderboards(sponsorSpecs),
        ] else ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text('الدواوين', style: TextStyle(fontWeight: FontWeight.w900, color: onSurface)),
              ),
              TextButton.icon(
                onPressed: _loadDewanyahs,
                icon: const Icon(Icons.refresh),
                label: const Text('تحديث'),
              ),
            ],
          ),
          if (_loadingDew)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (_dewError != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('تعذّر تحميل الدواوين', style: TextStyle(fontWeight: FontWeight.w900, color: onSurface)),
                    const SizedBox(height: 6),
                    Text(_dewError!, style: TextStyle(color: onSurface.withValues(alpha: 0.7))),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _loadDewanyahs,
                      icon: const Icon(Icons.refresh),
                      label: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            ),
          _buildApplyCard(),
          const SizedBox(height: 12),
          _SectionTitle('لوحة الديوانيات', icon: Icons.groups_3),
          const SizedBox(height: 8),
        _LeaderboardPager(
          controller: _dewPager,
          current: _dewPage,
          specs: dewSpecs,
          onPageChanged: (i) => setState(() => _dewPage = i),
          onOpen: (i) => _openBoardDetail(dewSpecs, i),
          showDots: false,
        ),
        ],
        const SizedBox(height: 14),
        _PrimaryCtaButton(
          label: _ctaLabelForTab(),
          onPressed: _ctaActionForTab(),
        ),
      ],
    );
  }

  Widget _buildSponsorSelectorCard() {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final currentGame = _sponsorGames.firstWhere(
      (g) => g['gameId'] == _selectedGameId,
      orElse: () => _sponsorGames.isNotEmpty ? _sponsorGames.first : <String, dynamic>{},
    );
    final currentPrize = (currentGame['prizeAmount'] as num?)?.toInt();
    final currentGameName = (currentGame['name'] ?? currentGame['gameId'])?.toString();

    if (_loadingSponsors) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_sponsorError != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('تعذّر تحميل الرعاة', style: TextStyle(color: onSurface, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(_sponsorError!, style: TextStyle(color: onSurface.withValues(alpha: 0.7))),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _loadSponsors,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    if (_sponsors.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('لا يوجد رعاة متاحون حالياً'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // sponsor chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _sponsors.map((s) {
                final code = (s['code'] ?? '').toString();
                final name = (s['name'] ?? code).toString();
                final selected = code == _sponsorCode;
                return ChoiceChip(
                  selected: selected,
                  label: Text(name),
                  labelStyle: TextStyle(
                    color: selected ? const Color(0xFFE49A2C) : onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                  selectedColor: const Color(0xFFE9F2FB),
                  onSelected: (_) => _selectSponsor(code, name),
                );
              }).toList(),
            ),

            const SizedBox(height: 12),
            if (_loadingGames) const LinearProgressIndicator(),
            if (!_loadingGames && _sponsorGames.isEmpty)
              const Text('لا توجد ألعاب لهذا السبونسر حالياً.')
            else if (!_loadingGames) ...[
              if (currentGameName != null)
                Text(
                  currentPrize != null ? 'اللعبة الحالية: $currentGameName — جائزة: $currentPrize' : 'اللعبة الحالية: $currentGameName',
                  style: TextStyle(color: onSurface.withValues(alpha: 0.8), fontWeight: FontWeight.w700),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _sponsorGames.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final g = entry.value;
                  final gid = (g['gameId'] ?? '').toString();
                  final name = (g['name'] ?? gid).toString();
                  final prize = (g['prizeAmount'] as num?)?.toInt();
                  final selected = gid == _selectedGameId || (idx == 0 && _selectedGameId == null);
                  return ChoiceChip(
                    selected: selected,
                    label: Text(prize != null ? '$name ($prize)' : name),
                    onSelected: (_) {
                      setState(() {
                        _selectedGameId = gid;
                        _sponsorPage = idx;
                        if (_sponsorPager.hasClients) {
                          _sponsorPager.jumpToPage(idx);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSponsorLeaderboards(List<_BoardSpec> sponsorSpecs) {
    if (_loadingGames) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_sponsorCode == null || sponsorSpecs.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('اختر راعي ولعبة لعرض المراتب'),
        ),
      );
    }

    final safePage = _sponsorPage >= sponsorSpecs.length ? 0 : _sponsorPage;
    if (safePage != _sponsorPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _sponsorPage = safePage);
        if (_sponsorPager.hasClients) {
          _sponsorPager.jumpToPage(safePage);
        }
      });
    }

    return _LeaderboardPager(
      controller: _sponsorPager,
      current: safePage,
      specs: sponsorSpecs,
      onPageChanged: (i) => setState(() => _sponsorPage = i),
      onOpen: (i) => _openBoardDetail(sponsorSpecs, i),
      showDots: false,
    );
  }

  Widget _buildApplyCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.group_add_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'افتح ديوانية — نراجع الطلب ونتواصل معك للتفعيل',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildApplyFields(),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _submitDewanyahRequest,
              icon: const Icon(Icons.rocket_launch_outlined),
              label: const Text('إرسال الطلب وفتح لوحة الديوانية'),
            ),
            const SizedBox(height: 6),
            Text(
              'نرجع لك لنوضح القواعد ونفتح لك لوحة المراتب.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

extension _UserResultCard on _LeaderboardHubPageState {
  Future<void> _showSearchResultsSheet(List<Map<String, dynamic>> results) async {
    final limited = results.take(6).toList();
    final enriched = <Map<String, dynamic>>[];
    for (final r in limited) {
      final uid = (r['id'] ?? r['userId'])?.toString();
      Map<String, dynamic>? stats;
      if (uid != null && uid.isNotEmpty) {
        stats = await getUserStats(uid, token: widget.app.token, gameId: widget.app.selectedGame);
      }
      enriched.add({
        'displayName': (r['displayName'] ?? r['name'] ?? 'لاعب').toString(),
        'email': r['email']?.toString(),
        'avatarUrl': r['avatarUrl']?.toString(),
        'avatarBase64': r['avatarBase64']?.toString(),
        'themeId': r['themeId']?.toString(),
        'id': uid,
        'stats': stats,
      });
    }

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('نتائج البحث', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 8),
            ...enriched.map((u) {
              final stats = u['stats'] as Map<String, dynamic>?;
              final pearls = stats?['pearls'] ?? stats?['points'] ?? 0;
              final totalGames = (stats?['wins'] ?? 0) + (stats?['losses'] ?? 0);
              final streak = stats?['streak'] ?? 0;
              final display = u['displayName']?.toString() ?? 'لاعب';
              final themeId = (u['themeId'] ?? '').toString().isNotEmpty
                  ? u['themeId'].toString()
                  : (u['id']?.toString() == widget.app.userId ? widget.app.themeId : null);
              AvatarEffectType? effectFromId(String? id) {
                switch (id) {
                  case 'blueThunder':
                    return AvatarEffectType.blueThunder;
                  case 'goldLightning':
                    return AvatarEffectType.goldLightning;
                  case 'kuwait':
                    return AvatarEffectType.kuwaitSparkles;
                  case 'greenLeaf':
                    return AvatarEffectType.greenLeaf;
                  case 'flameBlue':
                    return AvatarEffectType.flameBlue;
                  default:
                    return null;
                }
              }
              return Card(
                child: ListTile(
                  leading: () {
                    final url = (u['avatarUrl'] ?? '').toString();
                    final b64 = (u['avatarBase64'] ?? '').toString();
                    final effect = effectFromId(themeId);
                    if (url.isNotEmpty) {
                      return AvatarEffect(
                        effect: effect ?? AvatarEffectType.blueThunder,
                        size: 46,
                        child: CircleAvatar(backgroundImage: NetworkImage(url)),
                      );
                    }
                    if (b64.isNotEmpty) {
                      try {
                        return AvatarEffect(
                          effect: effect ?? AvatarEffectType.blueThunder,
                          size: 46,
                          child: CircleAvatar(backgroundImage: MemoryImage(base64Decode(b64))),
                        );
                      } catch (_) {}
                    }
                    return AvatarEffect(
                      effect: effect ?? AvatarEffectType.blueThunder,
                      size: 46,
                      child: CircleAvatar(child: Text(display.characters.take(2).toString())),
                    );
                  }(),
                  title: Text(display, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _tag('لآلئ: $pearls'),
                      _tag('مباريات: $totalGames'),
                      if (streak is num && streak > 0) _tag('ستريك: $streak'),
                    ],
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => PlayerProfilePage(app: widget.app, playerName: display)),
                    );
                  },
                ),
              );
            }),
            if (enriched.isEmpty) const Text('لا توجد نتائج', style: TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _BoardSpec {
  final String title;
  final String gameId;
  final int? prize;
  final bool showSponsorPearls;
  final Future<List<Map<String, dynamic>>> Function()? loader;
  final List<Map<String, dynamic>> fallback;
  final String? badge;
  final String? owner;
  final bool fivePearlsNote;

  const _BoardSpec({
    required this.title,
    required this.gameId,
    this.prize,
    required this.showSponsorPearls,
    this.loader,
    required this.fallback,
    this.badge,
    this.owner,
    this.fivePearlsNote = false,
  });
}

class _LeaderboardPager extends StatelessWidget {
  final PageController controller;
  final int current;
  final List<_BoardSpec> specs;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int>? onOpen;
  final bool showDots;
  const _LeaderboardPager({
    required this.controller,
    required this.current,
    required this.specs,
    required this.onPageChanged,
    this.onOpen,
    this.showDots = true,
  });

  @override
  Widget build(BuildContext context) {
    if (specs.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('لا يوجد لوحات متاحة حالياً'),
        ),
      );
    }
    return Column(
      children: [
        SizedBox(
          height: 380,
          child: PageView.builder(
            controller: controller,
            onPageChanged: onPageChanged,
            itemCount: specs.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: GestureDetector(
                onTap: onOpen != null ? () => onOpen!(i) : null,
                child: _LeaderboardPanel(spec: specs[i]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (showDots) _Dots(count: specs.length, current: current),
      ],
    );
  }
}

class _LeaderboardPanel extends StatelessWidget {
  final _BoardSpec spec;
  const _LeaderboardPanel({required this.spec});

  @override
  Widget build(BuildContext context) {
    Widget buildCard(List<Map<String, dynamic>> list) {
      return _BoardCard(items: list, showSponsorPearls: spec.showSponsorPearls);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spec.title,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        'اللعبة الحالية: ${spec.gameId}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                      if (spec.owner != null)
                        Text(
                          'المالك: ${spec.owner}',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                        ),
                    ],
                  ),
                ),
                if (spec.badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(spec.badge!, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                const SizedBox(width: 8),
                if (spec.prize != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF172133).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.card_giftcard, size: 18),
                        const SizedBox(width: 6),
                        Text('${spec.prize}'),
                      ],
                    ),
                  ),
              ],
            ),
            if (spec.fivePearlsNote)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'كل لاعب يبدأ بـ٥ لآلئ في هذه الديوانية. نفعّل الطلبات بعد المراجعة السريعة.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: spec.loader?.call().catchError((_) => spec.fallback),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting && spec.loader != null) {
                    return const Card(
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final list = snap.data ?? spec.fallback;
                  return buildCard(list);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final bool selected;
  final String text;
  final VoidCallback onTap;
  const _TabChip({required this.selected, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg = selected ? const Color(0xFFE9F2FB) : Colors.transparent;
    final border = selected ? Colors.transparent : Colors.white.withValues(alpha: 0.25);
    final textColor = selected ? const Color(0xFFE49A2C) : Colors.white;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(fontWeight: FontWeight.w900, color: textColor),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionTitle(this.title, {required this.icon});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Row(
      children: [
        Icon(icon, color: onSurface.withValues(alpha: 0.9)),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: onSurface,
          ),
        ),
      ],
    );
  }
}

class _BoardCard extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final bool showSponsorPearls;
  const _BoardCard({required this.items, required this.showSponsorPearls});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 0),
        physics: const BouncingScrollPhysics(),
        itemBuilder: (_, i) {
          final it = items[i];
          final name = (it['displayName'] ?? it['name'] ?? '—').toString();
          final pearls = (it['pearls'] ?? 0);
          final streak = (it['streak'] ?? 0);
          final isTop = i == 0;

          return ListTile(
            leading: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  backgroundColor: isTop ? const Color(0xFFFFC16B) : const Color(0xFF273347),
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: isTop ? Colors.black : Colors.white,
                    ),
                  ),
                ),
                if (isTop)
                  Positioned(
                    top: -6,
                    right: -10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFA53A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'الأول',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(name, style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
                if ((streak is num ? streak : 0) >= 3)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.local_fire_department, color: Colors.orange),
                  ),
              ],
            ),
            subtitle: showSponsorPearls
                ? const Text('لآلئ السبونسر')
                : const Text('اللآلئ العامة'),
            trailing: _PearlPill(value: pearls),
          );
        },
      ),
    );
  }
}

class _PearlPill extends StatelessWidget {
  final dynamic value;
  const _PearlPill({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF232E4A),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'lib/assets/pearl.png',
            width: 18,
            height: 18,
          ),
          const SizedBox(width: 6),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _PrimaryCtaButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _PrimaryCtaButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60, maxWidth: 260),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment(-0.6, -0.8),
              end: Alignment(0.9, 0.9),
              colors: [
                Color(0xFFEFF6FB),
                Color(0xFFD8E7F4),
                Color(0xFFC7DBED),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: TextButton(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFF1A949),
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            onPressed: onPressed,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int current;
  const _Dots({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return Container(
          width: active ? 12 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: active ? 0.9 : 0.4),
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }
}

class _BoardDetailPage extends StatefulWidget {
  final List<_BoardSpec> specs;
  final int initialIndex;
  const _BoardDetailPage({required this.specs, required this.initialIndex});

  @override
  State<_BoardDetailPage> createState() => _BoardDetailPageState();
}

class _BoardDetailPageState extends State<_BoardDetailPage> {
  late PageController _ctrl;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _ctrl = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final specs = widget.specs;
    final currentSpec = specs[_index];

    return Scaffold(
      appBar: AppBar(
        title: Text(currentSpec.title),
      ),
      body: Column(
        children: [
          if (currentSpec.prize != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('الجائزة: ${currentSpec.prize}', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          Expanded(
            child: PageView.builder(
              controller: _ctrl,
              itemCount: specs.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) {
                final spec = specs[i];
                return Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: spec.loader?.call().catchError((_) => spec.fallback),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting && spec.loader != null) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final list = snap.data ?? spec.fallback;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            spec.title,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                          ),
                          Text(
                            'اللعبة: ${spec.gameId}',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                          ),
                          const SizedBox(height: 12),
                          Expanded(child: _BoardCard(items: list, showSponsorPearls: spec.showSponsorPearls)),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          _Dots(count: specs.length, current: _index),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _PlayerSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSearch;
  const _PlayerSearchBar({
    required this.controller,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            const Icon(Icons.search),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'ابحث بالاسم وافتح ملف اللاعب',
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => onSearch(),
              ),
            ),
            IconButton(
              onPressed: () => controller.clear(),
              icon: const Icon(Icons.close),
              tooltip: 'مسح النص',
            ),
            const SizedBox(width: 4),
            IconButton.filled(
              onPressed: onSearch,
              icon: const Icon(Icons.search),
              tooltip: 'بحث',
            )
          ],
        ),
      ),
    );
  }
}

// تم إلغاء بطاقة القواعد استجابة لطلب إزالة النص

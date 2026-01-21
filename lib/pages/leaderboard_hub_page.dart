// lib/pages/leaderboard_hub_page.dart
import 'package:flutter/material.dart';
import '../state.dart';
import '../api_leaderboard.dart';
import '../api_sponsor.dart';
import 'sponsor_page.dart';
import 'games_page.dart';
import 'player_profile_page.dart';
import 'owner_dashboard_page.dart';
import 'sponsor_game_page.dart';

class LeaderboardHubPage extends StatefulWidget {
  final AppState app;
  final int initialTab; // 0=regular, 1=sponsor, 2=dewanyah
  const LeaderboardHubPage({super.key, required this.app, this.initialTab = 0});

  @override
  State<LeaderboardHubPage> createState() => _LeaderboardHubPageState();
}

class _LeaderboardHubPageState extends State<LeaderboardHubPage> {
  late int tab; // 0 = Regular, 1 = Sponsor, 2 = Dewanyah
  bool _searchExpanded = false;

  // sponsor selection inside sponsor leaderboard
  String? _sponsorCode;
  String? _sponsorName;
  String? _selectedGameId;

  final PageController _regularPager = PageController();
  final PageController _sponsorPager = PageController();
  final PageController _dewPager = PageController();

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
  bool _loadingGames = false;
  String? _sponsorError;
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

  void _msg(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  void _openStart() {
    if (tab == 0) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => GamesPage(app: widget.app)));
      return;
    }
    _showApplySheet();
  }

  void _openPlayerProfile() {
    final name = _playerSearchCtrl.text.trim();
    if (name.isEmpty) {
      _msg('اكتب اسم اللاعب للبحث');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlayerProfilePage(app: widget.app, playerName: name)),
    );
  }

  VoidCallback _ctaActionForTab() {
    if (tab == 0) {
      return () => Navigator.push(context, MaterialPageRoute(builder: (_) => GamesPage(app: widget.app)));
    }
    if (tab == 1) {
      return _openSponsorPage;
    }
    return _showApplySheet;
  }

  String _ctaLabelForTab() {
    if (tab == 0) return widget.app.tr(ar: 'انزلي', en: 'Start');
    if (tab == 1) return widget.app.tr(ar: 'انزلي سبونسر', en: 'Start Sponsor');
    return widget.app.tr(ar: 'انزلي ديوانية', en: 'Start Dewanyah');
  }

  void _openSponsorPage() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => SponsorPage(app: widget.app)));
  }

  Future<void> _submitDewanyahRequest({bool closeSheet = false}) async {
    final name = _dewNameCtrl.text.trim();
    final contact = _dewContactCtrl.text.trim();
    if (name.isEmpty || contact.isEmpty) {
      _msg('عبئ اسم الديوانية ووسيلة التواصل');
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
    _msg('استلمنا طلب الديوانية، سنتواصل معك للتفعيل');
    if (closeSheet && mounted) Navigator.pop(context);
  }

  void _showApplySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          top: 16,
          left: 16,
          right: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('طلب فتح ديوانية', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            _buildApplyFields(compact: true),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _submitDewanyahRequest(closeSheet: true),
              icon: const Icon(Icons.send),
              label: const Text('إرسال الطلب'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSponsorGameScreen() async {
    final code = _sponsorCode;
    if (code == null || code.isEmpty) {
      _msg('اختَر سبونسر أولاً');
      return;
    }
    final gameId = _selectedGameId ??
        (_sponsorGames.isNotEmpty ? (_sponsorGames.first['gameId'] ?? '').toString() : null);
    if (gameId == null || gameId.isEmpty) {
      _msg('اختَر لعبة السبونسر أولاً');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SponsorGameScreen(
          app: widget.app,
          sponsorCode: code,
          initialGameId: gameId,
        ),
      ),
    );
  }

  List<_BoardSpec> _regularBoards(AppState app) => [
        _BoardSpec(
          title: 'Top Players • بلوت',
          gameId: 'بلوت',
          prize: 300,
          showSponsorPearls: false,
          loader: () => ApiLeaderboard.globalTop(token: app.token),
          fallback: _mockBoard(),
        ),
        _BoardSpec(
          title: 'Top Players • كونكان',
          gameId: 'كونكان',
          prize: 200,
          showSponsorPearls: false,
          fallback: _mockBoard(basePearls: 5),
        ),
        _BoardSpec(
          title: 'Top Players • كوت',
          gameId: 'كوت',
          prize: 180,
          showSponsorPearls: false,
          fallback: _mockBoard(basePearls: 5),
        ),
      ];

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
    return _dewanyahSpaces.map((d) {
      return _BoardSpec(
        title: d['name']?.toString() ?? 'ديوانية',
        gameId: d['gameId']?.toString() ?? '—',
        prize: d['prizeAmount'] is int ? d['prizeAmount'] as int : null,
        showSponsorPearls: false,
        fallback: (d['players'] as List?)?.cast<Map<String, dynamic>>() ?? _mockBoard(basePearls: 5),
        badge: d['status']?.toString(),
        owner: d['owner']?.toString(),
        fivePearlsNote: true,
      );
    }).toList();
  }

  Widget _buildApplyFields({bool compact = false}) {
    final spacing = compact ? 8.0 : 12.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _dewNameCtrl,
          decoration: const InputDecoration(labelText: 'اسم الديوانية'),
        ),
        SizedBox(height: spacing),
        DropdownButtonFormField<String>(
          initialValue: _dewGame,
          decoration: const InputDecoration(labelText: 'اللعبة الأساسية'),
          items: const [
            DropdownMenuItem(value: 'بلوت', child: Text('بلوت')),
            DropdownMenuItem(value: 'كونكان', child: Text('كونكان')),
            DropdownMenuItem(value: 'كوت', child: Text('كوت')),
            DropdownMenuItem(value: 'دومينو', child: Text('دومينو')),
          ],
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
                  'الرعاة',
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
          const SizedBox(height: 12),
          _SectionTitle('لوحة السبونسر', icon: Icons.local_fire_department),
          const SizedBox(height: 8),
          _SponsorPlayCtas(onPlay: _openSponsorGameScreen),
          const SizedBox(height: 10),
          _buildSponsorLeaderboards(sponsorSpecs),
          const SizedBox(height: 14),
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
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.dashboard_customize_outlined),
            label: const Text('لوحة المالك'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => OwnerDashboardPage(app: app)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _PlayerSearchBar(
          controller: _playerSearchCtrl,
          onSearch: _openPlayerProfile,
          expanded: _searchExpanded,
          onToggle: () => setState(() => _searchExpanded = !_searchExpanded),
        ),
        const SizedBox(height: 4),
        // Tabs
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF172133).withOpacity(0.7),
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
                  text: widget.app.tr(ar: 'انزلي سبونسر', en: 'Start Sponsor'),
                  onTap: () => setState(() => tab = 1),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _TabChip(
                  selected: tab == 2,
                  text: widget.app.tr(ar: 'انزلي ديوانية', en: 'Start Dewanyah'),
                  onTap: () => setState(() => tab = 2),
                ),
              ),
            ],
          ),
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
          ),
        ] else if (tab == 1) ...[
          _buildSponsorSelectorCard(),
          const SizedBox(height: 10),
          _SectionTitle('Top Players (${_sponsorName ?? _sponsorCode ?? 'السبونسر'})',
              icon: Icons.local_fire_department),
          const SizedBox(height: 8),
          _SponsorPlayCtas(onPlay: _openSponsorGameScreen),
          const SizedBox(height: 10),
          _buildSponsorLeaderboards(sponsorSpecs),
        ] else if (tab == 1) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  'الرعاة',
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
          const SizedBox(height: 12),
          _SectionTitle('لوحة السبونسر', icon: Icons.local_fire_department),
          const SizedBox(height: 8),
          _SponsorPlayCtas(onPlay: _openSponsorGameScreen),
          const SizedBox(height: 10),
          _buildSponsorLeaderboards(sponsorSpecs),
        ] else ...[
          _DewanyahRulesCard(),
          const SizedBox(height: 10),
          _buildApplyCard(),
          const SizedBox(height: 12),
          _SectionTitle('لوحة الديوانيات', icon: Icons.groups_3),
          const SizedBox(height: 8),
          _LeaderboardPager(
            controller: _dewPager,
            current: _dewPage,
            specs: dewSpecs,
            onPageChanged: (i) => setState(() => _dewPage = i),
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
              Text(_sponsorError!, style: TextStyle(color: onSurface.withOpacity(0.7))),
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
            Text('اختر سبونسر + لعبة', style: TextStyle(fontWeight: FontWeight.w900, color: onSurface)),
            const SizedBox(height: 10),

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
                  style: TextStyle(color: onSurface.withOpacity(0.8), fontWeight: FontWeight.w700),
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
                    'افتح ديوانية صغيرة لك ولرفاقك — نراجع الطلب ونتواصل معك للتفعيل',
                    style: TextStyle(color: Colors.white.withOpacity(0.8)),
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
              'كل لعبة في الديوانية تبدأ بـ 5 لآلئ — نرجع لك لنوضح القواعد ونفتح لك لوحة المراتب.',
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
            ),
          ],
        ),
      ),
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
  const _LeaderboardPager({
    required this.controller,
    required this.current,
    required this.specs,
    required this.onPageChanged,
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
          height: 330,
          child: PageView.builder(
            controller: controller,
            onPageChanged: onPageChanged,
            itemCount: specs.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _LeaderboardPanel(spec: specs[i]),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _Dots(count: specs.length, current: current),
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
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                      if (spec.owner != null)
                        Text(
                          'المالك: ${spec.owner}',
                          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                        ),
                    ],
                  ),
                ),
                if (spec.badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(spec.badge!, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                const SizedBox(width: 8),
                if (spec.prize != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF172133).withOpacity(0.85),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
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
                  style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12),
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
    final border = selected ? Colors.transparent : Colors.white.withOpacity(0.25);
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
        Icon(icon, color: onSurface.withOpacity(0.9)),
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

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF273347),
              child: Text(
                '${i + 1}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
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
                ? const Text('لآلئ السبونسر (لهاللعبة فقط)')
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

class _SponsorPlayCtas extends StatelessWidget {
  final VoidCallback onPlay;
  const _SponsorPlayCtas({required this.onPlay});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: onPlay,
            icon: const Icon(Icons.sports_esports),
            label: const Text('ابدأ / انضم مباراة السبونسر'),
          ),
        ),
      ],
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
        constraints: const BoxConstraints(minHeight: 60, maxWidth: 420),
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
                color: Colors.black.withOpacity(0.12),
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
            color: Colors.white.withOpacity(active ? 0.9 : 0.4),
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }
}

class _PlayerSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSearch;
  final bool expanded;
  final VoidCallback onToggle;
  const _PlayerSearchBar({
    required this.controller,
    required this.onSearch,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (!expanded) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              IconButton.filledTonal(
                onPressed: onToggle,
                icon: const Icon(Icons.search),
                tooltip: 'بحث اللاعب',
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'بحث بالاسم وفتح ملف اللاعب',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      );
    }

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
              onPressed: onToggle,
              icon: const Icon(Icons.close),
              tooltip: 'إغلاق البحث',
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

class _DewanyahRulesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.rule_folder_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'قواعد الديوانية',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'الديوانية للمجتمع الصغير — نراجع الطلب، نفتح لك لوحة المراتب، وكل لعبة تبدأ بـ ٥ لآلئ. التزم بقواعد اللعب واحترام الجميع.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

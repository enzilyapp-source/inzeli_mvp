import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../state.dart';
import '../api_leaderboard.dart';
import '../api_dewanyah.dart';
import '../api_user.dart';
import '../api_room.dart';
import 'player_profile_page.dart';
import 'dewanyah_list_page.dart';
import 'match_page.dart';
import 'scan_page.dart';
import '../widgets/primary_pill_button.dart';
import '../widgets/room_timer_banner.dart';
import 'package:geolocator/geolocator.dart';

const Map<String, String> _quickGamePngAssetById = <String, String>{
  'قدم': 'lib/assets/games_png/games-01.png',
  'طائره': 'lib/assets/games_png/games-02.png',
  'سله': 'lib/assets/games_png/games-03.png',
  'دفان': 'lib/assets/games_png/games-10.png',
  'تنس ارضي': 'lib/assets/games_png/games-05.png',
  'بيبيفوت': 'lib/assets/games_png/games-06.png',
  'بادل': 'lib/assets/games_png/games-07.png',
  'بلوت': 'lib/assets/games_png/games-10.png',
  'هند': 'lib/assets/games_png/games-09.png',
  'كوت': 'lib/assets/games_png/games-08.png',
  'سبيتة': 'lib/assets/games_png/games-12.png',
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

const Map<String, String> _quickGameSvgAssetById = <String, String>{
  'قدم': 'lib/assets/games_svg/games-01.svg',
  'طائره': 'lib/assets/games_svg/games-02.svg',
  'سله': 'lib/assets/games_svg/games-03.svg',
  'دفان': 'lib/assets/games_svg/games-10.svg',
  'تنس ارضي': 'lib/assets/games_svg/games-05.svg',
  'بيبيفوت': 'lib/assets/games_svg/games-06.svg',
  'بادل': 'lib/assets/games_svg/games-07.svg',
  'بلوت': 'lib/assets/games_svg/games-10.svg',
  'هند': 'lib/assets/games_svg/games-09.svg',
  'كوت': 'lib/assets/games_svg/games-08.svg',
  'سبيتة': 'lib/assets/games_svg/games-12.svg',
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

const Map<String, String> _quickCategoryIconPngById = <String, String>{
  'رياضة': 'lib/assets/category_icons/sports.png',
  'ألعاب شعبية': 'lib/assets/category_icons/popular.png',
  'جنجفة': 'lib/assets/category_icons/cards.png',
};

const Map<String, String> _quickCategoryDisplayArabic = <String, String>{
  'رياضة': 'ريــــاضة',
  'ألعاب شعبية': 'ألعــــاب شعبية',
  'جنجفة': 'جنجـــــــفه',
};

class LeaderboardHubPage extends StatefulWidget {
  final AppState app;
  final int initialTab; // 0=regular, 1=sponsor, 2=dewanyah
  const LeaderboardHubPage({super.key, required this.app, this.initialTab = 0});

  @override
  State<LeaderboardHubPage> createState() => _LeaderboardHubPageState();
}

class _LeaderboardHubPageState extends State<LeaderboardHubPage> {
  late int tab; // 0 = Regular, 1 = Sponsor, 2 = Dewanyah
  String? _homeSelectedCategoryId;
  String? _homeSelectedGameId;

  final PageController _regularPager = PageController();
  final PageController _dewPager = PageController();
  bool _tutorialShown = false;

  int _regularPage = 0;
  int _dewPage = 0;

  final TextEditingController _dewNameCtrl = TextEditingController();
  final TextEditingController _dewContactCtrl = TextEditingController();
  final TextEditingController _dewPrizeCtrl = TextEditingController(text: '50');
  final TextEditingController _dewNoteCtrl = TextEditingController();
  String _dewGame = 'بلوت';
  bool _dewLockLocation = false;
  bool _showMoreDewanyahs = false;
  bool _showDewApplyForm = false;
  int _dewRadiusMeters = 100;

  late List<Map<String, dynamic>> _dewanyahSpaces;
  bool _loadingDew = false;
  String? _dewError;

  @override
  void initState() {
    super.initState();
    widget.app.addListener(_onAppChanged);
    tab = widget.initialTab.clamp(0, 2);
    _dewanyahSpaces = [..._seedDewanyahs(), ..._ownedAsSpaces()];
    _loadDewanyahs();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTutorial());
  }

  @override
  void dispose() {
    widget.app.removeListener(_onAppChanged);
    _regularPager.dispose();
    _dewPager.dispose();
    _dewNameCtrl.dispose();
    _dewContactCtrl.dispose();
    _dewPrizeCtrl.dispose();
    _dewNoteCtrl.dispose();
    super.dispose();
  }

  void _onAppChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openCurrentRoom() async {
    final code = widget.app.roomCode;
    if (code == null || code.isEmpty) return;
    try {
      final room = await ApiRoom.getRoomByCode(code, token: widget.app.token);
      final status = room['status']?.toString();
      if (status != null && status != 'waiting' && status != 'running') {
        widget.app.setRoomCode(null);
        if (!mounted) return;
        _msg('الروم السابق انتهى');
        return;
      }
      final roomGame = (room['gameId'] ?? '').toString().trim();
      if (roomGame.isNotEmpty) {
        widget.app.setSelectedGame(
          roomGame,
          category: _categoryForGame(roomGame),
        );
      }
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MatchPage(app: widget.app, room: room),
        ),
      );
    } catch (e) {
      if (e.toString().contains('ROOM_NOT_FOUND') || e.toString().contains('HTTP 404')) {
        widget.app.setRoomCode(null);
      }
      if (!mounted) return;
      _msg('فشل فتح الروم الحالي: ${ApiRoom.friendlyError(e)}', error: true);
    }
  }

  Map<String, List<String>> get _gameMap => widget.app.games;

  List<String> get _categories => widget.app.categories;

  String _categoryForGame(String gameId) {
    for (final entry in _gameMap.entries) {
      if (entry.value.contains(gameId)) return entry.key;
    }
    return _categories.isNotEmpty ? _categories.first : '';
  }

  List<String> _dewGameIds(Map<String, dynamic> dew) {
    final games = ((dew['games'] as List?) ?? const [])
        .map((g) => g is Map ? (g['gameId'] ?? g['id']).toString() : g.toString())
        .where((g) => g.isNotEmpty)
        .toList();
    final fallback = (dew['gameId'] ?? '').toString();
    if (games.isEmpty && fallback.isNotEmpty) return [fallback];
    return games;
  }

  bool _dewMatchesGame(Map<String, dynamic> dew, String gameId) {
    if (gameId.trim().isEmpty) return true;
    return _dewGameIds(dew).contains(gameId);
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
        'players':
            d['players'] is List ? d['players'] : _mockBoard(basePearls: 5),
      };
    }).toList();
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
            ? (games.first is Map
                    ? (games.first['gameId'] ?? games.first['id'])
                    : games.first)
                .toString()
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
    var completed = false;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('جولة سريعة',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 10),
              _tutorialRow(Icons.sports_esports, '١) اختر اللعبة',
                  'من الشريط العلوي: العاب إنزلي / سبونسرات / دواوين.'),
              const SizedBox(height: 6),
              _tutorialRow(Icons.play_circle_fill, '٢) اضغط انزلي وبلّش التحدي',
                  'يُنفتح روم، وانتظر لاعبين ثم شغّل العدّاد.'),
              const SizedBox(height: 6),
              _tutorialRow(Icons.flag, '٣) النتيجة بعد انتهاء العدّاد',
                  'إذا صفّر العداد احسم النتيجة واختر الفائز. اللآلئ تُخصم من الخاسرين فقط.'),
              const SizedBox(height: 6),
              _tutorialRow(Icons.trending_up, '٤) تابع المراتب',
                  'شوف ترتيبك وترتيب اللاعبين في كل لعبة.'),
              const SizedBox(height: 10),
              _tutorialRow(
                  Icons.emoji_events, 'المراتب', 'شوف وين واصل كل لاعب.'),
              _tutorialRow(
                  Icons.sports_esports, 'الألعاب', 'الروم والعدّاد والحسم.'),
              _tutorialRow(Icons.tv, 'سبونسرات', 'لآلئ الرعاة لكل لعبة.'),
              _tutorialRow(Icons.person, 'ملفي', 'بياناتك وإعداداتك.'),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    completed = true;
                    widget.app.markTutorialSeen();
                    Navigator.pop(sheetContext);
                  },
                  child: const Text('تم'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!completed) {
      _tutorialShown = false;
    }
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

  List<Map<String, dynamic>> _mockBoard({int basePearls = 5}) => [
        {"displayName": "Nasser H.", "pearls": basePearls, "streak": 5},
        {"displayName": "Ahmad", "pearls": basePearls - 1, "streak": 2},
        {"displayName": "Saad", "pearls": basePearls - 2, "streak": 0},
        {"displayName": "Futun", "pearls": basePearls - 3, "streak": 0},
      ];

  List<Map<String, dynamic>> _normalizeBoardRows(
      List<Map<String, dynamic>> rows) {
    final myId = widget.app.userId;
    final myName = (widget.app.displayName ?? '').trim();
    return rows.map((r) {
      final row = Map<String, dynamic>.from(r);
      final uid = (row['userId'] ?? row['id'] ?? '').toString();
      if (myId != null && myId.isNotEmpty && uid == myId && myName.isNotEmpty) {
        row['displayName'] = myName;
        row['name'] = myName;
      }
      return row;
    }).toList();
  }

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

  void _showActiveRoomSnack(String code) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.black87,
        action: SnackBarAction(
          label: 'افتحه',
          textColor: const Color(0xFFE49A2C),
          onPressed: _openCurrentRoom,
        ),
        content: Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            children: [
              const Icon(Icons.meeting_room_outlined, color: Color(0xFFE49A2C)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  code.isEmpty
                      ? 'عندك قيم شغال حالياً. افتح الروم الحالي أو خلّصه قبل لا تبلش قيم ثاني.'
                      : 'عندك قيم شغال حالياً ($code). افتح الروم الحالي أو خلّصه قبل لا تبلش قيم ثاني.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openBoardPlayerProfile(
    Map<String, dynamic> row,
    _BoardSpec spec,
  ) async {
    final display =
        (row['displayName'] ?? row['name'] ?? row['playerName'] ?? '')
            .toString()
            .trim();
    if (display.isEmpty || display == '—') return;

    final uid = (row['userId'] ?? row['id'] ?? '').toString();
    widget.app.upsertUserProfile(display, {
      if (uid.isNotEmpty) 'id': uid,
      'publicId': row['publicId'],
      'displayName': display,
      'avatarUrl': row['avatarUrl'] ?? row['avatarPath'] ?? row['avatar'],
      'avatarBase64': row['avatarBase64'],
      'themeId': row['themeId'],
    });
    widget.app.upsertUserStats(display, {
      if (uid.isNotEmpty) 'id': uid,
      'publicId': row['publicId'],
      'wins': (row['wins'] as num?)?.toInt() ?? 0,
      'losses': (row['losses'] as num?)?.toInt() ?? 0,
      'gamePearls': {
        if (spec.gameId.trim().isNotEmpty && spec.gameId != '—')
          spec.gameId: (row['pearls'] as num?)?.toInt() ?? 0,
      },
    });

    if (uid.isNotEmpty) {
      try {
        final stats = await getUserStats(
          uid,
          token: widget.app.token,
          gameId: spec.gameId == '—' ? widget.app.selectedGame : spec.gameId,
        );
        if (stats != null) {
          widget.app.upsertUserStats(display, stats);
        }
      } catch (_) {
        // The row data is enough to open the profile if the stats lookup fails.
      }
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerProfilePage(app: widget.app, playerName: display),
      ),
    );
  }

  void _openDewanyahList({String? initialGameId}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DewanyahListPage(
          app: widget.app,
          initialGameId: initialGameId,
        ),
      ),
    );
  }

  Future<void> _openQuickGamePicker({required bool join}) async {
    final initialCategory = _homeSelectedCategoryId ??
        (_categories.isNotEmpty ? _categories.first : '');
    final initialGame = _homeSelectedGameId;
    final selection = await Navigator.push<_QuickGameSelection>(
      context,
      MaterialPageRoute(
        builder: (_) => _QuickGamePickerPage(
          app: widget.app,
          join: join,
          categories: _categories,
          gamesByCategory: _gameMap,
          initialCategoryId: initialCategory,
          initialGameId: initialGame,
        ),
      ),
    );
    if (!mounted || selection == null) return;

    setState(() {
      _homeSelectedCategoryId = selection.categoryId;
      _homeSelectedGameId = selection.gameId;
    });

    final hasMatchingDewanyahs = _dewanyahSpaces.any(
      (dew) => _isMyHubDewanyah(dew) && _dewMatchesGame(dew, selection.gameId),
    );
    final scope = await Navigator.push<_QuickScopeTarget>(
      context,
      MaterialPageRoute(
        builder: (_) => _QuickScopePickerPage(
          app: widget.app,
          gameId: selection.gameId,
          join: join,
          hasMatchingDewanyahs: hasMatchingDewanyahs,
        ),
      ),
    );
    if (!mounted || scope == null) return;

    switch (scope) {
      case _QuickScopeTarget.general:
        await _openGeneralRoomFlow(selection.gameId, join: join);
        break;
      case _QuickScopeTarget.sponsor:
        _msg('السبونسرات حالياً Coming soon');
        break;
      case _QuickScopeTarget.dewanyah:
        if (!hasMatchingDewanyahs) {
          _msg(
            'ما عندك دواوين للعبة ${widget.app.gameLabel(selection.gameId)} حالياً',
          );
          return;
        }
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DewanyahListPage(
              app: widget.app,
              initialGameId: selection.gameId,
            ),
          ),
        );
        break;
    }
  }

  Future<bool> _ensureRulesPrompt() async {
    if (widget.app.rulesPromptSeen == true) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تذكير سريع'),
        content: const Text(
          '• لكل لعبة ٥ لآلئ هذا الشهر.\n'
          '• الفوز ينقل لؤلؤة من الخاسر إذا كان عنده.\n'
          '• إذا عندك قيم شغال ما تقدر تدخل الثاني لين يخلص أو ينلغي.',
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
    if (ok == true) {
      widget.app.markRulesPromptSeen();
      return true;
    }
    return false;
  }

  Future<Position?> _getLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best);
    } catch (_) {
      return null;
    }
  }

  Future<void> _openGeneralRoomFlow(String gameId, {required bool join}) async {
    if (!widget.app.isSignedIn) {
      _msg('سجّل الدخول أولاً', error: true);
      return;
    }
    final proceed = await _ensureRulesPrompt();
    if (!proceed) return;
    final categoryId = _categoryForGame(gameId);
    widget.app.setSelectedGame(gameId, category: categoryId);

    try {
      if (join) {
        if (!mounted) return;
        final scanned = await Navigator.push<String>(
          context,
          MaterialPageRoute(builder: (_) => const ScanPage()),
        );
        final code = scanned?.trim() ?? '';
        if (code.isEmpty) return;

        final room = await ApiRoom.getRoomByCode(code, token: widget.app.token);
        final roomGame = (room['gameId'] ?? '').toString();
        if (roomGame.isNotEmpty && roomGame != gameId) {
          _msg('هذا القيم للعبة ${widget.app.gameLabel(roomGame)} مو ${widget.app.gameLabel(gameId)}',
              error: true);
          return;
        }
        final pos = await _getLocation();
        await ApiRoom.joinByCode(
          code: code,
          token: widget.app.token,
          lat: pos?.latitude,
          lng: pos?.longitude,
        );
        widget.app.setRoomCode(code);
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MatchPage(app: widget.app, room: room),
          ),
        );
        return;
      }

      final pos = await _getLocation();
      final room = await ApiRoom.createRoom(
        gameId: gameId,
        token: widget.app.token,
        lat: pos?.latitude,
        lng: pos?.longitude,
      );
      final roomGame = (room['gameId'] ?? '').toString().trim();
      if (roomGame.isNotEmpty && roomGame != gameId) {
        final roomCode = room['code']?.toString().trim();
        if (roomCode != null && roomCode.isNotEmpty) {
          widget.app.setRoomCode(roomCode);
        }
        _msg(
          'رجع السيرفر قيم ${widget.app.gameLabel(roomGame)} بدل ${widget.app.gameLabel(gameId)}. افتحي القيم الحالي أو حدّثي السيرفر.',
          error: true,
        );
        return;
      }
      final code = room['code']?.toString();
      widget.app.setRoomCode(code);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MatchPage(app: widget.app, room: room),
        ),
      );
    } catch (e) {
      final active =
          RegExp(r'PLAYER_ALREADY_IN_ACTIVE_ROOM:([A-Z0-9]+)').firstMatch(
        e.toString(),
      );
      if (active != null) {
        final activeCode = active.group(1) ?? '';
        if (activeCode.isNotEmpty) widget.app.setRoomCode(activeCode);
        _showActiveRoomSnack(activeCode);
        return;
      }
      _msg(ApiRoom.friendlyError(e), error: true);
    }
  }

  Future<void> _scanAndJoinFromHome() async {
    if (!widget.app.isSignedIn) {
      _msg('سجّل الدخول أولاً', error: true);
      return;
    }
    final proceed = await _ensureRulesPrompt();
    if (!proceed) return;
    if (!mounted) return;
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScanPage()),
    );
    final code = scanned?.trim() ?? '';
    if (code.isEmpty) return;
    try {
      final room = await ApiRoom.getRoomByCode(code, token: widget.app.token);
      final roomGame = (room['gameId'] ?? '').toString();
      if (roomGame.isNotEmpty) {
        final categoryId = _categoryForGame(roomGame);
        widget.app.setSelectedGame(roomGame, category: categoryId);
        setState(() {
          _homeSelectedCategoryId = categoryId;
          _homeSelectedGameId = roomGame;
        });
      }
      final pos = await _getLocation();
      await ApiRoom.joinByCode(
        code: code,
        token: widget.app.token,
        lat: pos?.latitude,
        lng: pos?.longitude,
      );
      widget.app.setRoomCode(code);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MatchPage(app: widget.app, room: room),
        ),
      );
    } catch (e) {
      final active =
          RegExp(r'PLAYER_ALREADY_IN_ACTIVE_ROOM:([A-Z0-9]+)').firstMatch(
        e.toString(),
      );
      if (active != null) {
        final activeCode = active.group(1) ?? '';
        if (activeCode.isNotEmpty) widget.app.setRoomCode(activeCode);
        _showActiveRoomSnack(activeCode);
        return;
      }
      _msg(ApiRoom.friendlyError(e), error: true);
    }
  }

  Widget _buildQuickHomeBar() {
    return Row(
      children: [
        Expanded(
          child: PrimaryPillButton(
            onPressed: () => _openQuickGamePicker(join: false),
            icon: Icons.add_box_outlined,
            label: widget.app.tr(ar: 'إنــــزّلــــي', en: 'Start'),
            maxWidth: double.infinity,
            minHeight: 76,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: PrimaryPillButton(
            onPressed: _scanAndJoinFromHome,
            icon: Icons.qr_code_scanner,
            label: widget.app.tr(ar: 'شرّف', en: 'Join'),
            maxWidth: double.infinity,
            minHeight: 76,
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentRoomSection() {
    final code = widget.app.roomCode;
    if (code == null || code.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RoomTimerBanner(
          code: code,
          token: widget.app.token,
          dense: false,
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _openCurrentRoom,
          icon: const Icon(Icons.meeting_room_outlined),
          label: Text('العودة للروم الحالي ($code)'),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Future<Position?> _getCurrentPositionForDewanyah() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best);
    } catch (_) {
      return null;
    }
  }

  Future<void> _submitDewanyahRequest({bool closeSheet = false}) async {
    final name = _dewNameCtrl.text.trim();
    final contact = _dewContactCtrl.text.trim();
    final prizeRaw = _dewPrizeCtrl.text.trim();
    if (name.isEmpty || contact.isEmpty) {
      _msg('عبئ اسم الديوانية ووسيلة التواصل', error: true);
      return;
    }
    int? prizeAmount;
    if (prizeRaw.isNotEmpty) {
      prizeAmount = int.tryParse(prizeRaw);
      if (prizeAmount == null || prizeAmount < 0) {
        _msg('حط سعر جائزة صحيح (رقم بدون كسور)', error: true);
        return;
      }
    }

    double? anchorLat;
    double? anchorLng;
    if (_dewLockLocation) {
      final pos = await _getCurrentPositionForDewanyah();
      if (pos == null) {
        _msg('فعّل الموقع وخل التطبيق يقدر يقرأه حتى نثبت موقع الديوانية',
            error: true);
        return;
      }
      anchorLat = pos.latitude;
      anchorLng = pos.longitude;
    }

    final note = _dewNoteCtrl.text.trim();
    await widget.app.addDewanyahRequest(
      name: name,
      contact: contact,
      gameId: _dewGame,
      note: note,
      locationLock: _dewLockLocation,
      radiusMeters: _dewLockLocation ? _dewRadiusMeters : null,
      anchorLat: anchorLat,
      anchorLng: anchorLng,
      prizeAmount: prizeAmount,
    );

    if (!mounted) return;
    setState(() {
      _dewanyahSpaces.insert(0, {
        'name': name,
        'owner': widget.app.displayName ?? 'أنت',
        'gameId': _dewGame,
        'prizeAmount': prizeAmount ?? 50,
        'status': 'pending',
        'locationLock': _dewLockLocation,
        'radiusMeters': _dewLockLocation ? _dewRadiusMeters : null,
        'anchorLat': anchorLat,
        'anchorLng': anchorLng,
        'startingPearls': 5,
        'players': [
          {
            'displayName': widget.app.displayName ?? 'أنت',
            'pearls': 5,
            'streak': 0
          },
        ],
      });
      _dewPage = 0;
      _dewPager.jumpToPage(0);
      _dewLockLocation = false;
      _showDewApplyForm = false;
      _dewRadiusMeters = 100;
    });

    _dewNameCtrl.clear();
    _dewContactCtrl.clear();
    _dewPrizeCtrl.text = '50';
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
        displayGameLabel: app.gameLabel(g),
        prize: null,
        showSponsorPearls: false,
        loader: (limit) async {
          final rows = await ApiLeaderboard.globalTop(
            token: app.token,
            gameId: g,
            limit: limit,
          );
          if (rows.isEmpty) return const <Map<String, dynamic>>[];
          return _normalizeBoardRows(rows
              .map((r) => {
                    'displayName':
                        (r['displayName'] ?? r['name'] ?? '').toString(),
                    'pearls': (r['pearls'] ?? r['permanentScore'] ?? 0),
                    'userId': (r['userId'] ?? '').toString(),
                    'streak': 0,
                  })
              .toList());
        },
        fallback: const <Map<String, dynamic>>[],
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
            displayGameLabel:
                gid.isEmpty ? '—' : widget.app.gameLabel(gid),
            prize: d['prizeAmount'] is int ? d['prizeAmount'] as int : null,
            showSponsorPearls: false,
            fallback: (d['players'] as List?)?.cast<Map<String, dynamic>>() ??
                const <Map<String, dynamic>>[],
            badge: d['status']?.toString(),
            owner: d['owner']?.toString(),
            fivePearlsNote: true,
            loader: dewId == null
                ? null
                : (limit) async {
                    final rows = await ApiDewanyah.leaderboard(
                      dewanyahId: dewId,
                      limit: limit,
                      gameId: gid,
                    );
                    return _normalizeBoardRows(rows);
                  },
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
          onOpenPlayer: _openBoardPlayerProfile,
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
    final currentGame = gameOptions.contains(_dewGame)
        ? _dewGame
        : (gameOptions.isNotEmpty ? gameOptions.first : null);

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
          controller: _dewPrizeCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'سعر الجائزة',
            hintText: 'مثال: 50',
          ),
        ),
        SizedBox(height: spacing),
        TextField(
          controller: _dewNoteCtrl,
          maxLines: compact ? 2 : 3,
          decoration: const InputDecoration(labelText: 'ملاحظات / قواعد خاصة'),
        ),
        SizedBox(height: spacing),
        SwitchListTile.adaptive(
          value: _dewLockLocation,
          onChanged: (v) => setState(() => _dewLockLocation = v),
          contentPadding: EdgeInsets.zero,
          title: const Text('تثبيت موقع الديوانية وقت الطلب'),
          subtitle: Text(
            'اختياري',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
          ),
        ),
        if (_dewLockLocation) ...[
          SizedBox(height: spacing),
          DropdownButtonFormField<int>(
            initialValue: _dewRadiusMeters,
            decoration: const InputDecoration(labelText: 'نطاق الموقع (متر)'),
            items: const [80, 100, 150, 200, 300]
                .map((v) => DropdownMenuItem<int>(
                      value: v,
                      child: Text('$v م'),
                    ))
                .toList(),
            onChanged: (v) =>
                setState(() => _dewRadiusMeters = v ?? _dewRadiusMeters),
          ),
        ],
      ],
    );
  }

  Widget _buildSponsorComingSoon() {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFE49A2C).withValues(alpha: 0.16),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFE49A2C).withValues(alpha: 0.34),
                ),
              ),
              child: const Icon(
                Icons.lock_clock_outlined,
                color: Color(0xFFE49A2C),
                size: 32,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              widget.app.tr(ar: 'قريباً', en: 'Coming soon'),
              style: TextStyle(
                color: onSurface,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.app.tr(
                ar: 'صفحة السبونسرات مقفلة مؤقتاً.',
                en: 'Sponsors are temporarily locked.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: onSurface.withValues(alpha: 0.72),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    final regularSpecs = _regularBoards(app);
    final dewSpecs = _dewBoards();
    final sponsorOnlyMode = widget.initialTab == 1;

    if (sponsorOnlyMode) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
        children: [
          _buildSponsorComingSoon(),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      children: [
        _buildCurrentRoomSection(),
        _buildQuickHomeBar(),
        const SizedBox(height: 10),
        if (tab == 0) ...[
          _LeaderboardPager(
            controller: _regularPager,
            current: _regularPage,
            specs: regularSpecs,
            onPageChanged: (i) => setState(() => _regularPage = i),
            onOpen: (i) => _openBoardDetail(regularSpecs, i),
            onOpenPlayer: _openBoardPlayerProfile,
          ),
        ] else if (tab == 1) ...[
          _buildSponsorComingSoon(),
        ] else ...[
          _buildHubDewanyahHome(dewSpecs, onSurface),
        ],
      ],
    );
  }

  Widget _buildHubDewanyahHome(List<_BoardSpec> dewSpecs, Color onSurface) {
    final mine = <Map<String, dynamic>>[];
    final discover = <Map<String, dynamic>>[];
    for (final dew in _dewanyahSpaces) {
      if (_homeSelectedGameId != null &&
          !_dewMatchesGame(dew, _homeSelectedGameId!)) {
        continue;
      }
      if (_isMyHubDewanyah(dew)) {
        mine.add(dew);
      } else {
        discover.add(dew);
      }
    }
    final filteredSpecs = _homeSelectedGameId == null
        ? dewSpecs
        : dewSpecs.where((spec) => spec.gameId == _homeSelectedGameId).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        Container(
          decoration: const BoxDecoration(
            color: Color(0xFF2A364D),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(34),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                decoration: const BoxDecoration(
                  color: Color(0xFF243149),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(34),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _homeSelectedGameId == null
                            ? 'الدواوين'
                            : 'دواوين ${widget.app.gameLabel(_homeSelectedGameId!)}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: onSurface,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _loadDewanyahs,
                      icon: const Icon(Icons.refresh),
                      color: onSurface,
                      tooltip: 'تحديث',
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                  Text(
                    'تعذّر تحميل الدواوين',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _dewError!,
                    style: TextStyle(color: onSurface.withValues(alpha: 0.7)),
                  ),
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
        const SizedBox(height: 10),
        _SectionTitle('دواويني', icon: Icons.home_work_outlined),
        const SizedBox(height: 10),
        if (mine.isEmpty)
          const _HubPanelMessage(
            icon: Icons.groups_2_outlined,
            title: 'ما عندك ديوانية مفعلة',
            text: 'انضم لديوانية أو ارسل طلب ديوانية من الزر تحت.',
          )
        else
          _buildHubDewanyahGrid(mine),
        if (discover.isNotEmpty) ...[
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => setState(
              () => _showMoreDewanyahs = !_showMoreDewanyahs,
            ),
            icon: Icon(
              _showMoreDewanyahs
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
            ),
            label: Text(
              _showMoreDewanyahs ? 'إخفاء الدواوين' : 'اكتشف دواوين أكثر',
            ),
          ),
          if (_showMoreDewanyahs) ...[
            const SizedBox(height: 10),
            _buildHubDewanyahGrid(discover),
          ],
        ],
        const SizedBox(height: 16),
        _SectionTitle('لوحة الديوانيات', icon: Icons.groups_3),
        const SizedBox(height: 8),
        if (filteredSpecs.isEmpty)
          const _HubPanelMessage(
            icon: Icons.home_work_outlined,
            title: 'ما عندك لوحات لهاللعبة',
            text: 'اختار لعبة ثانية أو ارجع للمراتب العامة.',
          )
        else
          _LeaderboardPager(
            controller: _dewPager,
            current: _dewPage,
            specs: filteredSpecs,
            onPageChanged: (i) => setState(() => _dewPage = i),
            onOpen: (i) => _openBoardDetail(filteredSpecs, i),
            onOpenPlayer: _openBoardPlayerProfile,
            showDots: false,
          ),
        const SizedBox(height: 14),
        _buildApplyCard(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHubDewanyahGrid(List<Map<String, dynamic>> dews) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width < 360 ? 2 : (width < 620 ? 3 : 4);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: dews.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.82,
          ),
          itemBuilder: (_, index) {
            final dew = dews[index];
            return _HubDewanyahTile(
              name: (dew['name'] ?? 'ديوانية').toString(),
              imageUrl: _hubDewanyahImageUrl(dew),
              isMine: _isMyHubDewanyah(dew),
              status: dew['status']?.toString(),
              onTap: () {
                final dewGames = _dewGameIds(dew);
                final initialGameId = _homeSelectedGameId != null &&
                        _dewMatchesGame(dew, _homeSelectedGameId!)
                    ? _homeSelectedGameId
                    : (dewGames.isNotEmpty ? dewGames.first : null);
                _openDewanyahList(initialGameId: initialGameId);
              },
            );
          },
        );
      },
    );
  }

  bool _isMyHubDewanyah(Map<String, dynamic> dew) {
    final id = (dew['id'] ?? '').toString();
    final ownerId = (dew['ownerUserId'] ?? dew['ownerId'])?.toString();
    if (ownerId != null &&
        widget.app.userId != null &&
        ownerId == widget.app.userId) {
      return true;
    }
    if (id.isNotEmpty && widget.app.joinedDewanyahIds.contains(id)) {
      return true;
    }
    return dew['status']?.toString() == 'pending';
  }

  String? _hubDewanyahImageUrl(Map<String, dynamic> dew) {
    final raw = (dew['imageUrl'] ??
            dew['logoUrl'] ??
            dew['coverUrl'] ??
            dew['avatarUrl'])
        ?.toString();
    if (raw == null || raw.trim().isEmpty) return null;
    return raw.trim();
  }

  Widget _buildApplyCard() {
    if (!_showDewApplyForm) {
      return SizedBox(
        width: double.infinity,
        child: PrimaryPillButton(
          onPressed: () => setState(() => _showDewApplyForm = true),
          icon: Icons.add_home_work_outlined,
          label: 'طلب ديوانية',
          maxWidth: 240,
          minHeight: 66,
          fontSize: 18,
        ),
      );
    }

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
                    'طلب ديوانية — نراجع الطلب ونتواصل معك للتفعيل',
                    style:
                        TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _showDewApplyForm = false),
                  icon: const Icon(Icons.close),
                  tooltip: 'إغلاق',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildApplyFields(),
            const SizedBox(height: 12),
            PrimaryPillButton(
              onPressed: _submitDewanyahRequest,
              icon: Icons.rocket_launch_outlined,
              label: 'إرسال الطلب وفتح لوحة الديوانية',
              maxWidth: 320,
              minHeight: 66,
              fontSize: 17,
            ),
            const SizedBox(height: 6),
            Text(
              'نرجع لك لنوضح القواعد ونفتح لك لوحة المراتب.',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
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
  final String displayGameLabel;
  final int? prize;
  final bool showSponsorPearls;
  final Future<List<Map<String, dynamic>>> Function(int limit)? loader;
  final List<Map<String, dynamic>> fallback;
  final String? badge;
  final String? owner;
  final bool fivePearlsNote;

  const _BoardSpec({
    required this.title,
    required this.gameId,
    required this.displayGameLabel,
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
  final void Function(Map<String, dynamic> row, _BoardSpec spec)? onOpenPlayer;
  final bool showDots;
  const _LeaderboardPager({
    required this.controller,
    required this.current,
    required this.specs,
    required this.onPageChanged,
    this.onOpen,
    this.onOpenPlayer,
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
          height: 440,
          child: PageView.builder(
            controller: controller,
            onPageChanged: onPageChanged,
            itemCount: specs.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: GestureDetector(
                onTap: onOpen != null ? () => onOpen!(i) : null,
                child: _LeaderboardPanel(
                  spec: specs[i],
                  onOpenPlayer: onOpenPlayer,
                ),
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
  final void Function(Map<String, dynamic> row, _BoardSpec spec)? onOpenPlayer;
  const _LeaderboardPanel({required this.spec, this.onOpenPlayer});

  @override
  Widget build(BuildContext context) {
    Widget buildCard(List<Map<String, dynamic>> list) {
      return _BoardCard(
        items: list,
        showSponsorPearls: spec.showSponsorPearls,
        onOpenPlayer:
            onOpenPlayer == null ? null : (row) => onOpenPlayer!(row, spec),
      );
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
                        'اللعبة الحالية: ${spec.displayGameLabel}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                      if (spec.owner != null)
                        Text(
                          'المالك: ${spec.owner}',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12),
                        ),
                    ],
                  ),
                ),
                if (spec.badge != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(spec.badge!,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                const SizedBox(width: 8),
                if (spec.prize != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF172133).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12)),
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
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 12),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: spec.loader?.call(30).catchError((_) => spec.fallback),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting &&
                      spec.loader != null) {
                    return const Card(
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final list = snap.data ?? spec.fallback;
                  if (list.isEmpty) {
                    return const Card(
                      child: Center(
                        child: Text('لا توجد نتائج بعد'),
                      ),
                    );
                  }
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

class _HubDewanyahTile extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final bool isMine;
  final String? status;
  final VoidCallback onTap;

  const _HubDewanyahTile({
    required this.name,
    required this.imageUrl,
    required this.isMine,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pending = status == 'pending';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageUrl != null)
                    Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const _HubDewFallback(),
                    )
                  else
                    const _HubDewFallback(),
                  PositionedDirectional(
                    top: 8,
                    end: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (pending || isMine)
                            ? const Color(0xFFE49A2C).withValues(alpha: 0.92)
                            : Colors.black.withValues(alpha: 0.48),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        pending
                            ? 'قيد المراجعة'
                            : (isMine ? 'دواويني' : 'اكتشاف'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 9, 8, 10),
              child: Text(
                name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HubDewFallback extends StatelessWidget {
  const _HubDewFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF304A5D),
      child: Center(
        child: Image.asset(
          'lib/assets/enzeli_logo.png',
          width: 52,
          height: 52,
          errorBuilder: (_, __, ___) => const Icon(Icons.groups_3, size: 44),
        ),
      ),
    );
  }
}

class _HubPanelMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  const _HubPanelMessage({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFE49A2C), size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    text,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
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

class _BoardCard extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final bool showSponsorPearls;
  final ValueChanged<Map<String, dynamic>>? onOpenPlayer;
  const _BoardCard({
    required this.items,
    required this.showSponsorPearls,
    this.onOpenPlayer,
  });

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
          final isTop = i == 0;

          return ListTile(
            onTap: onOpenPlayer == null ? null : () => onOpenPlayer!(it),
            leading: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  backgroundColor:
                      isTop ? const Color(0xFFFFC16B) : const Color(0xFF273347),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
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
                  child: Text(name,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
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

enum _QuickScopeTarget { general, dewanyah, sponsor }

class _QuickGameSelection {
  final String categoryId;
  final String gameId;

  const _QuickGameSelection({
    required this.categoryId,
    required this.gameId,
  });
}

class _QuickGamePickerPage extends StatefulWidget {
  final AppState app;
  final bool join;
  final List<String> categories;
  final Map<String, List<String>> gamesByCategory;
  final String initialCategoryId;
  final String? initialGameId;

  const _QuickGamePickerPage({
    required this.app,
    required this.join,
    required this.categories,
    required this.gamesByCategory,
    required this.initialCategoryId,
    required this.initialGameId,
  });

  @override
  State<_QuickGamePickerPage> createState() => _QuickGamePickerPageState();
}

class _QuickGamePickerPageState extends State<_QuickGamePickerPage> {
  late final PageController _categoryPager;
  late String _selectedCategoryId;
  String? _selectedGameId;

  @override
  void initState() {
    super.initState();
    _categoryPager = PageController(viewportFraction: 0.8);
    _selectedCategoryId = widget.categories.contains(widget.initialCategoryId)
        ? widget.initialCategoryId
        : (widget.categories.isNotEmpty ? widget.categories.first : '');
    final initialGames = _gamesForCurrentCategory;
    _selectedGameId =
        initialGames.contains(widget.initialGameId) ? widget.initialGameId : null;
    _selectedGameId ??= initialGames.isNotEmpty ? initialGames.first : null;
    final initialIndex = widget.categories.indexOf(_selectedCategoryId);
    if (initialIndex > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_categoryPager.hasClients) {
          _categoryPager.jumpToPage(initialIndex);
        }
      });
    }
  }

  @override
  void dispose() {
    _categoryPager.dispose();
    super.dispose();
  }

  List<String> get _gamesForCurrentCategory =>
      List<String>.from(widget.gamesByCategory[_selectedCategoryId] ?? const []);

  String _categoryLabel(String categoryId) {
    final base = widget.app.categoryLabel(categoryId);
    return _quickCategoryDisplayArabic[base] ??
        _quickCategoryDisplayArabic[categoryId] ??
        base;
  }

  void _selectCategory(String categoryId) {
    final nextGames =
        List<String>.from(widget.gamesByCategory[categoryId] ?? const []);
    setState(() {
      _selectedCategoryId = categoryId;
      if (!nextGames.contains(_selectedGameId)) {
        _selectedGameId = nextGames.isNotEmpty ? nextGames.first : null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final games = _gamesForCurrentCategory;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.join ? 'شرّف بأي لعبة' : 'إنزلي بأي لعبة'),
      ),
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Text(
                widget.join ? 'اختار اللعبة اللي بتشرّف عليها' : 'اختار اللعبة اللي بتنزل فيها',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 148,
                child: PageView.builder(
                  controller: _categoryPager,
                  itemCount: widget.categories.length,
                  onPageChanged: (index) =>
                      _selectCategory(widget.categories[index]),
                  itemBuilder: (_, index) {
                    final categoryId = widget.categories[index];
                    return GestureDetector(
                      onTap: () => _selectCategory(categoryId),
                      child: _QuickCategoryCard(
                        title: _categoryLabel(categoryId),
                        iconAsset: _quickCategoryIconPngById[categoryId],
                        isSelected: categoryId == _selectedCategoryId,
                      ),
                    );
                  },
                ),
              ),
              if (widget.categories.length > 1) ...[
                const SizedBox(height: 6),
                _Dots(
                  count: widget.categories.length,
                  current: widget.categories.indexOf(_selectedCategoryId),
                ),
              ],
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  children: [
                    Text(
                      'التصنيف: ${widget.app.categoryLabel(_selectedCategoryId)}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedGameId == null
                          ? 'ما فيه ألعاب بهذا التصنيف'
                          : widget.app.gameLabel(_selectedGameId!),
                      style: const TextStyle(
                        color: Color(0xFFE49A2C),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (games.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Text('ما فيه ألعاب بهالتصنيف حالياً'),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: games.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.92,
                  ),
                  itemBuilder: (_, index) {
                    final gameId = games[index];
                    return _QuickGameTile(
                      gameId: gameId,
                      label: widget.app.gameLabel(gameId),
                      pngAsset: _quickGamePngAssetById[gameId],
                      svgAsset: _quickGameSvgAssetById[gameId],
                      isSelected: gameId == _selectedGameId,
                      onTap: () => setState(() => _selectedGameId = gameId),
                    );
                  },
                ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: PrimaryPillButton(
                  onPressed: _selectedGameId == null
                      ? null
                      : () => Navigator.pop(
                            context,
                            _QuickGameSelection(
                              categoryId: _selectedCategoryId,
                              gameId: _selectedGameId!,
                            ),
                          ),
                  label: widget.join ? 'اختار النوع' : 'كمل واختار النوع',
                  maxWidth: 340,
                  minHeight: 76,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickScopePickerPage extends StatelessWidget {
  final AppState app;
  final String gameId;
  final bool join;
  final bool hasMatchingDewanyahs;

  const _QuickScopePickerPage({
    required this.app,
    required this.gameId,
    required this.join,
    required this.hasMatchingDewanyahs,
  });

  @override
  Widget build(BuildContext context) {
    final gameLabel = app.gameLabel(gameId);
    return Scaffold(
      appBar: AppBar(
        title: Text(join ? 'شرّف على $gameLabel' : 'إنزلي $gameLabel'),
      ),
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Text(
                'اختار نوع القيم',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                gameLabel,
                style: const TextStyle(
                  color: Color(0xFFE49A2C),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 18),
              _QuickScopeCard(
                title: 'عام',
                subtitle:
                    '${join ? 'شرّف' : 'إنزلي'} $gameLabel بالعام',
                icon: Icons.public,
                onTap: () => Navigator.pop(
                  context,
                  _QuickScopeTarget.general,
                ),
              ),
              const SizedBox(height: 12),
              _QuickScopeCard(
                title: 'دواوين',
                subtitle: hasMatchingDewanyahs
                    ? 'يعرض لك دواوين $gameLabel فقط'
                    : 'ما عندك دواوين للعبة $gameLabel',
                icon: Icons.home_work_outlined,
                enabled: hasMatchingDewanyahs,
                onTap: hasMatchingDewanyahs
                    ? () => Navigator.pop(
                          context,
                          _QuickScopeTarget.dewanyah,
                        )
                    : null,
              ),
              const SizedBox(height: 12),
              _QuickScopeCard(
                title: 'سبونسرات',
                subtitle: 'Coming soon',
                icon: Icons.tv_outlined,
                onTap: () => Navigator.pop(
                  context,
                  _QuickScopeTarget.sponsor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final bool compact;
  final VoidCallback onPressed;
  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.compact,
    required this.onPressed,
  });

  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final compact = widget.compact;
    final accent = const Color(0xFFF1A949);
    final pressedAccent = const Color(0xFFE39A34);
    final radius = compact ? 18.0 : 16.0;
    return AnimatedScale(
      scale: _pressed ? 0.985 : 1,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _pressed
                ? const [
                    Color(0xFFE2EAF2),
                    Color(0xFFCCDCE9),
                    Color(0xFFBDD0E2),
                  ]
                : const [
                    Color(0xFFEFF6FB),
                    Color(0xFFDCE9F4),
                    Color(0xFFCCDDED),
                  ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _pressed ? 0.08 : 0.12),
              blurRadius: _pressed ? 8 : 14,
              offset: Offset(0, _pressed ? 3 : 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: widget.onPressed,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: compact ? 72 : 66,
                minWidth: compact ? 92 : 0,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: compact ? 12 : 14,
                  horizontal: compact ? 12 : 16,
                ),
                child: compact
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(widget.icon,
                                size: 19, color: _pressed ? pressedAccent : accent),
                            const SizedBox(height: 4),
                          ],
                          Text(
                            widget.label,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13.5,
                              color: _pressed ? pressedAccent : accent,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.label,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                              color: _pressed ? pressedAccent : accent,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickCategoryCard extends StatelessWidget {
  final String title;
  final String? iconAsset;
  final bool isSelected;

  const _QuickCategoryCard({
    required this.title,
    required this.isSelected,
    this.iconAsset,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isSelected ? const Color(0xFFE49A2C) : Colors.white24,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2D6A7A), Color(0xFF23344A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (iconAsset != null) ...[
                  Image.asset(
                    iconAsset!,
                    width: 48,
                    height: 48,
                    filterQuality: FilterQuality.high,
                  ),
                  const SizedBox(height: 10),
                ],
                Text(
                  title,
                  style: TextStyle(
                    color: const Color(0xFFE49A2C)
                        .withValues(alpha: isSelected ? 1 : 0.92),
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickGameTile extends StatelessWidget {
  final String gameId;
  final String label;
  final String? pngAsset;
  final String? svgAsset;
  final bool isSelected;
  final VoidCallback onTap;

  const _QuickGameTile({
    required this.gameId,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.pngAsset,
    this.svgAsset,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Column(
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected ? const Color(0xFFE49A2C) : Colors.white24,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.22),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF2D6A7A), Color(0xFF23344A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Center(
                      child: _QuickGameIcon(
                        gameId: gameId,
                        pngAsset: pngAsset,
                        svgAsset: svgAsset,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isSelected ? const Color(0xFFE49A2C) : Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickGameIcon extends StatelessWidget {
  final String gameId;
  final String? pngAsset;
  final String? svgAsset;

  const _QuickGameIcon({
    required this.gameId,
    this.pngAsset,
    this.svgAsset,
  });

  @override
  Widget build(BuildContext context) {
    final hasPng = pngAsset != null && pngAsset!.trim().isNotEmpty;
    final hasSvg = svgAsset != null && svgAsset!.trim().isNotEmpty;
    if (hasPng) {
      return _iconCrop(
        child: Image.asset(
          pngAsset!,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => _fallback(hasSvg),
        ),
      );
    }
    return _fallback(hasSvg);
  }

  Widget _fallback(bool hasSvg) {
    if (hasSvg) {
      return _iconCrop(
        child: SvgPicture.asset(
          svgAsset!,
          fit: BoxFit.contain,
          alignment: Alignment.center,
          semanticsLabel: gameId,
          placeholderBuilder: (_) => _iconFallback(),
        ),
      );
    }
    return _iconFallback();
  }

  Widget _iconCrop({
    required Widget child,
    Alignment alignment = const Alignment(0, 0.2),
    double widthFactor = 0.9,
    double heightFactor = 0.8,
  }) {
    return ClipRect(
      child: Align(
        alignment: alignment,
        widthFactor: widthFactor,
        heightFactor: heightFactor,
        child: child,
      ),
    );
  }

  Widget _iconFallback() {
    return Icon(
      Icons.sports_esports_rounded,
      color: Colors.white.withValues(alpha: 0.92),
      size: 34,
    );
  }
}

class _QuickScopeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  const _QuickScopeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: enabled ? 1 : 0.48,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white24),
            gradient: const LinearGradient(
              colors: [Color(0xFF2D6A7A), Color(0xFF23344A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFFE49A2C), size: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white.withValues(alpha: 0.85),
                size: 18,
              ),
            ],
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
  final void Function(Map<String, dynamic> row, _BoardSpec spec)? onOpenPlayer;
  const _BoardDetailPage({
    required this.specs,
    required this.initialIndex,
    this.onOpenPlayer,
  });

  @override
  State<_BoardDetailPage> createState() => _BoardDetailPageState();
}

class _BoardDetailPageState extends State<_BoardDetailPage> {
  static const int _initialLimit = 30;
  static const int _stepLimit = 30;
  static const int _maxLimit = 300;

  late PageController _ctrl;
  late int _index;
  final Map<int, int> _limits = {};

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _ctrl = PageController(initialPage: _index);
    _limits[_index] = _initialLimit;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  int _limitFor(int pageIndex) => _limits[pageIndex] ?? _initialLimit;

  void _loadMore(int pageIndex) {
    final current = _limitFor(pageIndex);
    if (current >= _maxLimit) return;
    setState(() {
      _limits[pageIndex] =
          (current + _stepLimit).clamp(_initialLimit, _maxLimit);
    });
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
              child: Text('الجائزة: ${currentSpec.prize}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          Expanded(
            child: PageView.builder(
              controller: _ctrl,
              itemCount: specs.length,
              onPageChanged: (i) => setState(() {
                _index = i;
                _limits.putIfAbsent(i, () => _initialLimit);
              }),
              itemBuilder: (_, i) {
                final spec = specs[i];
                final limit = _limitFor(i);
                return Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: spec.loader
                        ?.call(limit)
                        .catchError((_) => spec.fallback),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting &&
                          spec.loader != null) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final list = snap.data ?? spec.fallback;
                      final hasMore = spec.loader != null &&
                          list.length >= limit &&
                          limit < _maxLimit;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            spec.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 18),
                          ),
                          Text(
                            'اللعبة: ${spec.gameId}',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7)),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: _BoardCard(
                              items: list,
                              showSponsorPearls: spec.showSponsorPearls,
                              onOpenPlayer: widget.onOpenPlayer == null
                                  ? null
                                  : (row) => widget.onOpenPlayer!(row, spec),
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (spec.loader != null)
                            Align(
                              alignment: Alignment.center,
                              child: OutlinedButton.icon(
                                onPressed: hasMore ? () => _loadMore(i) : null,
                                icon: const Icon(Icons.expand_more),
                                label: Text(
                                  hasMore ? 'عرض المزيد' : 'كل الأعضاء ظاهرين',
                                ),
                              ),
                            ),
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

// تم إلغاء بطاقة القواعد استجابة لطلب إزالة النص

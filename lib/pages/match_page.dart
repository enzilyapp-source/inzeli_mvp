// lib/pages/match_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:ui' show ImageFilter;

import '../state.dart';
import '../api_room.dart';
import '../sfx.dart';
import 'scan_page.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/primary_pill_button.dart';
import '../rules.dart';
import '../local_game_notifications.dart';
import '../scorekeeper/score_models.dart';
import 'scorekeeper/room_score_page.dart';

class MatchPage extends StatefulWidget {
  final AppState app;
  final Map<String, dynamic>? room;
  final String? sponsorCode;

  const MatchPage({
    super.key,
    required this.app,
    this.room,
    this.sponsorCode,
  });

  @override
  State<MatchPage> createState() => _MatchPageState();
}

class _MatchPageState extends State<MatchPage> with WidgetsBindingObserver {
  static const int _maxLocalNotificationsPerRoom = 2;
  static const Duration _timerEndNoticeCooldown = Duration(minutes: 10);
  static final Map<String, Set<String>> _localNotificationSlotsByRoom =
      <String, Set<String>>{};
  static final Map<String, DateTime> _timerEndNoticeTimes =
      <String, DateTime>{};

  Map<String, dynamic>? _room; // آخر نسخة من بيانات الروم
  Timer? _autoRefresh;

  List<Map<String, dynamic>> players = [];
  final Map<String, int> _pearlsByUser = {};
  final Map<String, String?> _teamOf = {};
  final Set<String> _knownPlayerIds = {};

  String? _winnerUserId;
  String? _winnerTeam; // A/B if team mode
  bool _teamMode = false; // default to فردي حتى يختار المضيف فرق

  Timer? _ticker;
  int _remaining = 0;
  DateTime? _startedAt;
  int? _timerSec;
  bool _timerEndNotified = false;
  String? _timerRoundKey;
  String? _timerNotificationKey;
  int? _scheduledTimerEndNotificationId;
  bool _closedNotified = false;
  bool _cancellingRoom = false;
  bool _allowPop = false;

  // حالة النتيجة والموافقات
  String? _resultStatus; // waiting | pending | approved | rejected
  Map<String, dynamic>? _resultPayload;
  List<Map<String, dynamic>> _resultVotes = const [];
  int _totalPlayers = 0;
  bool _approvalDialogOpen = false;
  bool _resultNotified = false;
  GameMode _currentGameMode = GameMode.both;
  int? _lastRemainingSoundTick;
  DateTime? _lastRefreshErrorAt;

  // RoomScorePage is an optional companion route; it never submits match results.
  late final ValueNotifier<ScoreRoomInfo> _scoreRoom;
  bool _openingScore = false;

  // قواعد أحجام الفرق لكل لعبة (عدد اللاعبين في كل فريق)
  static const Map<String, List<int>> _teamSizeRules = {
    'كوت': [2, 3], // 2 ضد 2 أو 3 ضد 3
    'بلوت': [2], // 2 ضد 2
    'تريكس': [2], // 2 ضد 2
    'هند': [2], // 2 ضد 2 في وضع الفرق
    'كيرم': [2], // 2 ضد 2 فقط
    'جاكارو': [2], // 2 ضد 2
    'سبيتة': [2], // 2 ضد 2 في وضع الفرق
    'دفان': [3], // 3 ضد 3 فقط
    'بيبيفوت': [2], // 2 ضد 2 في وضع الفرق
    'قدم': [9], // 9 ضد 9
    'سله': [5], // 5 ضد 5
    'طائره': [2, 3, 5, 6], // خيارات متعددة للفرق
    'بادل': [2], // 2 ضد 2
    'تنس طاولة': [2], // دبلز 2 ضد 2
    'تنس ارضي': [2], // دبلز 2 ضد 2
  };
  static const Set<int> _hindSoloSizes = {
    2,
    3,
    4,
    5
  }; // هند فردي = 2 أو 3 أو 4 أو 5 لاعبين
  static const int _spitaSoloSize = 5; // سبيتة فردي = 5 لاعبين
  bool get _iAmInRoom {
    final uid = widget.app.userId;
    if (uid == null || uid.isEmpty) return false;
    return _uniquePlayersList.any((p) => (p['userId'] ?? '') == uid);
  }

  bool _isCardGame(String game) => ScoreKind.supports(game);

  ScoreRoomInfo _scoreInfo() {
    final room = _room ?? widget.room;
    return ScoreRoomInfo(
      code: (room?['code'] ?? widget.app.roomCode ?? '').toString(),
      game: (room?['gameId'] ?? widget.app.selectedGame ?? '').toString(),
      hostId: (room?['hostUserId'] ?? '').toString(),
      players: _uniquePlayersList.map((p) {
        final person = ScorePerson.fromRoom(p);
        return ScorePerson(
            id: person.id,
            name: person.name,
            avatar: person.avatar,
            team: _teamOf[person.id] ?? person.team);
      }).toList(),
      teamMode: _teamMode,
      startedAt: _startedAt,
      timerSeconds: _timerSec,
      closed: _closedNotified,
    );
  }

  void _publishScoreRoom() {
    if (mounted) _scoreRoom.value = _scoreInfo();
  }

  Future<void> _openScore() async {
    if (_openingScore || _closedNotified || !_iAmInRoom) return;
    if (_startedAt == null) {
      _msg('القيد اختياري ومتاح بعد بدء القيم.');
      return;
    }
    _openingScore = true;
    _publishScoreRoom();
    try {
      await Navigator.push<void>(
          context,
          MaterialPageRoute(
              builder: (_) => RoomScorePage(
                  room: _scoreRoom,
                  userId: widget.app.userId ?? '',
                  token: widget.app.token)));
    } finally {
      _openingScore = false;
    }
  }

  Future<void> _showRoomQr(String code) => showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (ctx) => SingleChildScrollView(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('QR القيم',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SizedBox(
                      width: 220,
                      height: 220,
                      child: QrImageView(
                          data: 'https://inzeli.app/join/$code',
                          backgroundColor: Colors.white)),
                  const SizedBox(height: 12),
                  SelectableText(code),
                  const SizedBox(height: 8),
                  const Text('الانضمام يبقى مقفلًا أثناء العداد.'),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('رجوع')),
                ]))),
      );

  String _playerKey(Map<String, dynamic> p) {
    final uid = (p['userId'] ?? '').toString();
    if (uid.isNotEmpty) return uid;
    final user = p['user'] as Map<String, dynamic>? ?? const {};
    final name = (user['displayName'] ??
            user['name'] ??
            user['email'] ??
            user['phone'] ??
            '')
        .toString()
        .trim()
        .toLowerCase();
    if (name.isNotEmpty) return 'name:$name';
    return p.hashCode.toString();
  }

  List<Map<String, dynamic>> _dedupePlayers(List<Map<String, dynamic>> list) {
    final seen = <String>{};
    final result = <Map<String, dynamic>>[];
    for (final p in list) {
      final key = _playerKey(p);
      if (seen.add(key)) result.add(p);
    }
    return result;
  }

  List<Map<String, dynamic>> get _uniquePlayersList {
    // نحذف المكرر بحسب الـ id ثم الاسم لضمان عدم تكرار اللاعب.
    final base = _dedupePlayers(players);
    final seenIds = <String>{};
    final seenNames = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final p in base) {
      final uid = (p['userId'] ?? '').toString();
      if (uid.isNotEmpty && !seenIds.add(uid)) continue;
      final nameKey = _nameForMap(p).trim().toLowerCase();
      if (uid.isEmpty && !seenNames.add(nameKey)) continue;
      out.add(p);
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _room = widget.room;
    final initial = widget.room?['players'];
    if (initial is List) players = initial.cast<Map<String, dynamic>>();
    final code = (widget.room?['code'] ?? widget.app.roomCode ?? '').toString();
    final mode = widget.room?['mode']?.toString();
    final teamModeFlag = widget.room?['teamMode'];
    final initialGame =
        (widget.room?['gameId'] ?? widget.app.selectedGame ?? '').toString();
    _currentGameMode = widget.app.gameMode(initialGame);

    if (teamModeFlag is bool) {
      _teamMode = teamModeFlag;
    } else if (mode == 'team') {
      _teamMode = true;
    } else if (mode == 'solo') {
      _teamMode = false;
    }
    _enforceGameMode();
    _scoreRoom = ValueNotifier(_scoreInfo());
    if (code.isNotEmpty) _refresh(code);
    // تحديث تلقائي كل 10 ثوانٍ
    if (code.isNotEmpty) {
      _autoRefresh = Timer.periodic(const Duration(seconds: 3), (_) {
        if (mounted) _refresh(code);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _autoRefresh?.cancel();
    _scoreRoom.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final code =
          (_room?['code'] ?? widget.room?['code'] ?? widget.app.roomCode ?? '')
              .toString();
      if (code.isNotEmpty) {
        _refresh(code);
      }
    }
  }

  void _msg(String m,
      {Color? color, IconData? icon, bool animateIcon = false}) {
    final bool error = color == Colors.red || color == Colors.redAccent;
    final bool success = color == Colors.green || color == Colors.greenAccent;
    showAppSnack(context, m, error: error, success: success);
  }

  void _closeMatchPage() {
    if (!mounted) return;
    if (_allowPop) return;
    _allowPop = true;
    final route = ModalRoute.of(context);
    final navigator = Navigator.of(context);
    if (route != null) navigator.popUntil((candidate) => candidate == route);
    navigator.pop();
  }

  String _localNotificationRoomKey([String? code]) {
    final roomCode =
        (code ?? _room?['code'] ?? widget.room?['code'] ?? widget.app.roomCode)
            ?.toString()
            .trim();
    return roomCode == null || roomCode.isEmpty
        ? 'match:${identityHashCode(this)}'
        : roomCode;
  }

  bool _reserveLocalNotificationSlot(String slot, {String? code}) {
    final key = _localNotificationRoomKey(code);
    final slots =
        _localNotificationSlotsByRoom.putIfAbsent(key, () => <String>{});
    if (slots.contains(slot)) return false;
    if (slots.length >= _maxLocalNotificationsPerRoom) return false;
    slots.add(slot);
    return true;
  }

  void _cancelScheduledTimerEndNotification() {
    final id = _scheduledTimerEndNotificationId;
    if (id == null) return;
    _scheduledTimerEndNotificationId = null;
    unawaited(LocalGameNotifications.cancel(id));
  }

  void _exitMatchPageOnly() {
    if (!mounted) return;
    _msg('طلعت من الصفحة فقط. إذا رجعت للروم لاحقاً بتلقاه مثل ما هو.');
    _closeMatchPage();
  }

  Future<void> _confirmCancelRoom({String reason = 'player_cancelled'}) async {
    if (_cancellingRoom || _closedNotified) return;
    final code =
        (_room?['code'] ?? widget.room?['code'] ?? widget.app.roomCode ?? '')
            .toString();
    if (code.isEmpty) {
      _closeMatchPage();
      return;
    }
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إلغاء القيم؟'),
          content: const Text(
            'إذا لغيت القيم بيتكنسل عند الكل وترجع أي لآلئ محجوزة لأصحابها.\n'
            'إذا السيرفر ما يدعم الإلغاء حالياً، تقدر تطلع من الصفحة فقط بدون ما ينحشر التطبيق.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'back'),
              child: const Text('رجوع'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'exit_only'),
              child: const Text('خروج فقط'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'cancel_room'),
              child: const Text('إلغاء القيم'),
            ),
          ],
        ),
      ),
    );
    if (action == 'exit_only') {
      _exitMatchPageOnly();
      return;
    }
    if (action == 'cancel_room') {
      await _cancelCurrentRoom(reason: reason);
    }
  }

  Future<void> _cancelCurrentRoom({String reason = 'player_cancelled'}) async {
    if (_cancellingRoom || _closedNotified) return;
    final code =
        (_room?['code'] ?? widget.room?['code'] ?? widget.app.roomCode ?? '')
            .toString();
    if (code.isEmpty) {
      _closeMatchPage();
      return;
    }

    setState(() => _cancellingRoom = true);
    try {
      await ApiRoom.cancelRoom(
        code: code,
        token: widget.app.token,
        reason: reason,
      );
      _closedNotified = true;
      _ticker?.cancel();
      _autoRefresh?.cancel();
      _cancelScheduledTimerEndNotification();
      widget.app.setRoomCode(null);
      if (_reserveLocalNotificationSlot('room-cancelled', code: code)) {
        unawaited(LocalGameNotifications.show(
          id: LocalGameNotifications.idFor('room-cancelled:$code'),
          title: 'انلغى القيم',
          body: 'صار شي بالقيم، تكنسل ورجعت اللآلئ لأصحابها.',
        ));
      }
      if (mounted) {
        _msg('انلغى القيم ورجعت اللآلئ لأصحابها', color: Colors.green);
        setState(() => _cancellingRoom = false);
        _closeMatchPage();
      }
    } catch (e) {
      try {
        final room = await ApiRoom.getRoomByCode(code, token: widget.app.token);
        final status = (room['status'] ?? '').toString();
        if (status == 'cancelled' || status == 'finished') {
          _closedNotified = true;
          _ticker?.cancel();
          _autoRefresh?.cancel();
          widget.app.setRoomCode(null);
          if (!mounted) return;
          setState(() => _cancellingRoom = false);
          _closeMatchPage();
          return;
        }
      } catch (_) {
        // Keep the original cancellation error below.
      }
      if (!mounted) return;
      setState(() => _cancellingRoom = false);
      _msg('تعذر إلغاء القيم: ${ApiRoom.friendlyError(e)}',
          color: Colors.redAccent);
    }
  }

  void _syncTimerRound(String? startedAtIso) {
    final key = startedAtIso?.trim();
    if (key == null || key.isEmpty) {
      _timerRoundKey = null;
      _timerEndNotified = false;
      return;
    }
    if (_timerRoundKey != key) {
      _timerRoundKey = key;
      _timerEndNotified = false;
    }
  }

  void _notifyTimerEnded() {
    final code = (_room?['code'] ?? widget.app.roomCode ?? '').toString();
    final noticeKey = 'timer-end:$code:${_timerRoundKey ?? ''}:$_timerSec';
    final now = DateTime.now();
    final lastNoticeAt = _timerEndNoticeTimes[noticeKey];
    if (_timerEndNotified ||
        (lastNoticeAt != null &&
            now.difference(lastNoticeAt) < _timerEndNoticeCooldown)) {
      return;
    }
    _timerEndNotified = true;
    _timerEndNoticeTimes[noticeKey] = now;
    if (_reserveLocalNotificationSlot('timer-end', code: code)) {
      unawaited(
        LocalGameNotifications.show(
          id: LocalGameNotifications.idFor(noticeKey),
          title: 'انتهى عدّاد المباراة',
          body: 'الحين اختاروا الفائز واعتمدوا النتيجة.',
        ),
      );
    }
    Sfx.timerEnd(mute: widget.app.soundMuted == true);
    HapticFeedback.heavyImpact();
    if (!mounted) return;
    _msg('انتهى العدّاد، حدد الفائز', color: Colors.green);
    if (_approvalDialogOpen) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('انتهى الوقت'),
          content: const Text(
              'انتهى العدّاد. الحين اختاروا الفائز واعتمدوا النتيجة.'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('تم'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _syncTimerNotification({
    required String code,
    bool announceStart = false,
  }) async {
    if (code.isEmpty || _startedAt == null || _timerSec == null) return;
    final remaining = _calcRemainingFromClock();
    if (remaining <= 0) return;

    final key = '$code:${_startedAt!.toIso8601String()}:$_timerSec';
    if (!announceStart && _timerNotificationKey == key) return;
    _timerNotificationKey = key;

    final game =
        (_room?['gameId'] ?? widget.room?['gameId'] ?? widget.app.selectedGame)
            ?.toString();
    final gameLabel = widget.app.gameLabel(game ?? 'لعبة');
    final endAt = DateTime.now().add(Duration(seconds: remaining));
    final timerId = LocalGameNotifications.idFor('timer:$key');
    final endId = LocalGameNotifications.idFor('timer-end:$key');

    await LocalGameNotifications.requestPermission();
    if (announceStart &&
        _reserveLocalNotificationSlot('timer-start', code: code)) {
      await LocalGameNotifications.show(
        id: timerId,
        title: 'عداد $gameLabel شغال',
        body: 'باقي ${_fmt(remaining)} على نهاية الجولة.',
        endAt: endAt,
      );
    }
    if (_reserveLocalNotificationSlot('timer-end', code: code)) {
      _scheduledTimerEndNotificationId = endId;
      await LocalGameNotifications.schedule(
        id: endId,
        title: 'انتهى عدّاد $gameLabel',
        body: 'الحين اختاروا الفائز واعتمدوا النتيجة.',
        delay: Duration(seconds: remaining),
      );
    }
  }

  Future<Position?> _getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          return null;
        }
      }
      return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best);
    } catch (_) {
      return null;
    }
  }

  String _fmt(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$m:$ss';
  }

  int _calcRemainingFromClock() {
    if (_startedAt == null || _timerSec == null || _timerSec! <= 0) return 0;
    final elapsed = DateTime.now().difference(_startedAt!).inSeconds;
    final remain = _timerSec! - elapsed;
    return remain > 0 ? remain : 0;
  }

  bool get _countdownActive {
    // نعتمد الزمن الفعلي من startedAt/timerSec لتفادي أي تعليق لو قيمة _locked
    // أو _remaining وصلت بشكل متأخر من السيرفر.
    return _calcRemainingFromClock() > 0;
  }

  String _nameForUser(String uid) {
    final p = _uniquePlayersList.firstWhere(
      (e) => (e['userId'] ?? '').toString() == uid,
      orElse: () => const <String, dynamic>{},
    );
    final user = p['user'] as Map<String, dynamic>? ?? const {};
    return (user['displayName'] ??
            user['name'] ??
            user['email'] ??
            user['phone'] ??
            uid)
        .toString();
  }

  // نخلي الـ lock من الباكند فقط
  void _startTickerIfNeeded() {
    _ticker?.cancel();
    if (_startedAt == null || _timerSec == null) {
      setState(() => _remaining = 0);
      return;
    }

    void tick() {
      final elapsed = DateTime.now().difference(_startedAt!).inSeconds;
      final remain = _timerSec! - elapsed;
      final clamped = remain.clamp(0, 1 << 30);
      if (clamped != _remaining) {
        // أصوات آخر 3 ثواني
        if (clamped <= 3 && (_lastRemainingSoundTick ?? 4) > clamped) {
          Sfx.error(mute: widget.app.soundMuted == true);
          _lastRemainingSoundTick = clamped;
        }
        // عند انتهاء العداد
        if (clamped == 0 && _remaining > 0) {
          _notifyTimerEnded();
        }
      }
      setState(() => _remaining = clamped);
      _publishScoreRoom();
      if (_remaining <= 0) _ticker?.cancel();
    }

    tick();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  void _detectNewPlayers(List<Map<String, dynamic>> incoming) {
    final currentIds = incoming.map(_playerKey).toSet();
    if (currentIds.isEmpty) return;
    if (_knownPlayerIds.isEmpty) {
      _knownPlayerIds.addAll(currentIds);
      return;
    }
    final newIds = currentIds.difference(_knownPlayerIds);
    if (newIds.isNotEmpty) {
      for (final id in newIds) {
        final name = _nameForMap(incoming.firstWhere(
          (p) => (p['userId'] ?? '').toString() == id,
          orElse: () => const <String, dynamic>{},
        ));
        _msg('انضم $name');
      }
      Sfx.tap(mute: widget.app.soundMuted == true);
      HapticFeedback.lightImpact();
    }
    _knownPlayerIds.addAll(currentIds);
  }

  String _nameForMap(Map<String, dynamic> p) {
    final uid = (p['userId'] ?? '').toString();
    final user = p['user'] as Map<String, dynamic>? ?? const {};
    return (user['displayName'] ??
            user['name'] ??
            user['email'] ??
            user['phone'] ??
            uid)
        .toString();
  }

  void _enforceGameMode() {
    switch (_currentGameMode) {
      case GameMode.team:
        _teamMode = true;
        _winnerTeam ??= 'A';
        break;
      case GameMode.solo:
        _teamMode = false;
        _winnerTeam = null;
        _teamOf.clear();
        break;
      case GameMode.both:
        // لا تغيير
        break;
    }
  }

  bool _validateSetup(String game) {
    final count = _uniquePlayersList.length;

    if (_teamMode) {
      final sizeA = _teamOf.values.where((t) => t == 'A').length;
      final sizeB = _teamOf.values.where((t) => t == 'B').length;
      if (sizeA == 0 || sizeB == 0) {
        _msg('وزّع اللاعبين على الفريقين أولاً',
            icon: Icons.error, color: Colors.orange);
        return false;
      }
      if (sizeA != sizeB) {
        _msg('لازم عدد الفريقين يكون متساوي',
            icon: Icons.error, color: Colors.orange);
        return false;
      }
      final allowed = _teamSizeRules[game];
      if (allowed != null && !allowed.contains(sizeA)) {
        final txt = allowed.map((n) => '$n ضد $n').join(' أو ');
        _msg('لعبة $game تسمح بـ $txt فقط',
            icon: Icons.error, color: Colors.orange);
        return false;
      }
    } else {
      if (game == 'دفان') {
        _msg('دفان تُلعب فرق فقط 3 ضد 3',
            icon: Icons.error, color: Colors.orange);
        return false;
      }
      if (game == 'هند' && !_hindSoloSizes.contains(count)) {
        _msg('هند فردي يسمح بـ 2 أو 3 أو 4 أو 5 لاعبين',
            icon: Icons.error, color: Colors.orange);
        return false;
      }
      if (game == 'سبيتة' && count != _spitaSoloSize) {
        _msg('سبيتة فردي لازم يكونوا $_spitaSoloSize لاعبين',
            icon: Icons.error, color: Colors.orange);
        return false;
      }
      if (game == 'شطرنج' && count != 2) {
        _msg('شطرنج فردي فقط 1 ضد 1', icon: Icons.error, color: Colors.orange);
        return false;
      }
      if (game == 'دامه' && count != 2) {
        _msg('دامه فردي فقط 1 ضد 1', icon: Icons.error, color: Colors.orange);
        return false;
      }
      if (game == 'دومنه' && count != 2) {
        _msg('دومنه فردي فقط 1 ضد 1', icon: Icons.error, color: Colors.orange);
        return false;
      }
      if (game == 'طاوله' && count != 2) {
        _msg('طاوله فردي فقط 1 ضد 1', icon: Icons.error, color: Colors.orange);
        return false;
      }
      if (game == 'بلياردو' && count != 2) {
        _msg('بلياردو فردي فقط 1 ضد 1',
            icon: Icons.error, color: Colors.orange);
        return false;
      }
      if (game == 'بيبيفوت' && count != 2 && _teamMode == false) {
        _msg('بيبي فوت فردي فقط 1 ضد 1 أو فرق 2 ضد 2',
            icon: Icons.error, color: Colors.orange);
        return false;
      }
      if (game == 'تنس طاولة' && _teamMode == false && count != 2) {
        _msg('تنس طاولة فردي 1 ضد 1 أو فرق 2 ضد 2',
            icon: Icons.error, color: Colors.orange);
        return false;
      }
      if (game == 'تنس ارضي' && _teamMode == false && count != 2) {
        _msg('تنس فردي 1 ضد 1 أو فرق 2 ضد 2',
            icon: Icons.error, color: Colors.orange);
        return false;
      }
    }

    return true;
  }

  Future<void> _refreshResultState(String code) async {
    try {
      final state = await ApiRoom.getState(code: code, token: widget.app.token);
      final prevStatus = _resultStatus;
      _resultStatus = state['status']?.toString();
      _resultPayload = state['payload'] as Map<String, dynamic>?;
      _resultVotes =
          (state['votes'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      _totalPlayers = (state['totalPlayers'] as num?)?.toInt() ?? 0;
      if (prevStatus != _resultStatus) {
        _resultNotified = false;
      }
      if (!_approvalDialogOpen) _maybeShowApprovalDialog();
    } catch (_) {
      // ignore state fetch errors to avoid spamming UI
    }
  }

  void _maybeShowApprovalDialog() {
    if (_resultStatus == null) return;
    final myId = widget.app.userId ?? '';
    final isHost =
        (_room?['hostUserId'] ?? widget.room?['hostUserId'])?.toString() ==
            myId;

    if (_resultStatus == 'approved') {
      if (!_resultNotified) {
        _resultNotified = true;
        _msg('تم اعتماد النتيجة 🎉');
        Sfx.winner(mute: widget.app.soundMuted == true);
        widget.app.syncTimelineFromServer().catchError((_) {});
        widget.app.refreshSessionFromServer(force: true).catchError((_) {});
      }
      return;
    }

    if (_resultStatus == 'rejected' && isHost && !_resultNotified) {
      _resultNotified = true;
      _msg('رُفضت النتيجة. حدّد الفائز مرة أخرى.');
      Sfx.error(mute: widget.app.soundMuted == true);
      return;
    }

    if (_resultStatus == 'pending' && !isHost) {
      final alreadyVoted =
          _resultVotes.any((v) => (v['userId'] ?? '').toString() == myId);
      if (alreadyVoted) return;
      final payload = _resultPayload ?? const {};
      final winners = (payload['winners'] as List?)?.cast<String>() ?? const [];
      final losers = (payload['losers'] as List?)?.cast<String>() ?? const [];
      final winnerNames = winners.map(_nameForUser).join('، ');
      final loserNames = losers.map(_nameForUser).join('، ');

      _approvalDialogOpen = true;
      showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تأكيد النتيجة'),
            content: Text([
              if (winnerNames.isNotEmpty) 'الفائزون: $winnerNames',
              if (loserNames.isNotEmpty) 'الخاسرون: $loserNames',
              'وافق على النتيجة أو ارفض ليعيد المضيف اختيار الفائز.',
            ].join('\n')),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx, false);
                  try {
                    await ApiRoom.voteResult(
                        code: _room?['code'] ?? widget.room?['code'] ?? '',
                        approve: false,
                        token: widget.app.token);
                    _msg('تم الرفض، سيُعاد تحديد النتيجة');
                    Sfx.error(mute: widget.app.soundMuted == true);
                    _refreshResultState(
                        _room?['code'] ?? widget.room?['code'] ?? '');
                  } finally {
                    _approvalDialogOpen = false;
                    _resultNotified = false;
                  }
                },
                child: const Text('رفض'),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.pop(ctx, true);
                  try {
                    await ApiRoom.voteResult(
                        code: _room?['code'] ?? widget.room?['code'] ?? '',
                        approve: true,
                        token: widget.app.token);
                    _msg('تمت الموافقة على النتيجة');
                    Sfx.tap(mute: widget.app.soundMuted == true);
                    _refreshResultState(
                        _room?['code'] ?? widget.room?['code'] ?? '');
                    widget.app.syncTimelineFromServer().catchError((_) {});
                  } finally {
                    _approvalDialogOpen = false;
                  }
                },
                child: const Text('موافقة'),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _refresh(String code) async {
    try {
      final room = await ApiRoom.getRoomByCode(code, token: widget.app.token);
      _room = room;

      final remainingSec = (room['remainingSec'] as num?)?.toInt();
      if (remainingSec != null) {
        final prevRemaining = _remaining;
        _remaining = remainingSec;
        if (prevRemaining > 0 && _remaining <= 0) {
          _notifyTimerEnded();
        }
      }

      final status = room['status']?.toString();
      if (status != null && status != 'waiting' && status != 'running') {
        _timerSec = null;
        _startedAt = null;
        if (!_closedNotified) {
          _closedNotified = true;
          _ticker?.cancel();
          _autoRefresh?.cancel();
          _cancelScheduledTimerEndNotification();
          widget.app.setRoomCode(null);
          if (status == 'cancelled') {
            _msg('انلغى القيم ورجعت اللآلئ لأصحابها',
                color: Colors.greenAccent);
            if (_reserveLocalNotificationSlot('room-cancelled', code: code)) {
              unawaited(LocalGameNotifications.show(
                id: LocalGameNotifications.idFor('room-cancelled:$code'),
                title: 'انلغى القيم',
                body: 'صار شي بالقيم، تكنسل ورجعت اللآلئ لأصحابها.',
              ));
            }
          } else {
            _msg('الروم انتهى');
          }
        }
        _closeMatchPage();
        return;
      }

      final p = room['players'];
      if (p is List) {
        final incoming = _dedupePlayers(p.cast<Map<String, dynamic>>());
        _detectNewPlayers(incoming);
        players = incoming;
      }

      _pearlsByUser.clear();
      _teamOf.clear();

      final gameId =
          (room['gameId'] ?? widget.app.selectedGame ?? '').toString();
      _currentGameMode = widget.app.gameMode(gameId);

      for (final rp in _uniquePlayersList) {
        final uid = (rp['userId'] ?? '').toString();
        final user = rp['user'] as Map<String, dynamic>?;
        final gp = user?['gamePearls'];
        final gamePearls = gp is Map ? (gp[gameId] as num?)?.toInt() : null;
        final explicitPearls = gamePearls ??
            (rp['pearls'] as num?)?.toInt() ??
            (user?['pearls'] as num?)?.toInt();
        // نعرض رصيد اللعبة الفعلي من السيرفر، حتى لو كان 0.
        int pearls = explicitPearls ??
            (user?['creditBalance'] as num?)?.toInt() ??
            (user?['permanentScore'] as num?)?.toInt() ??
            0;

        // نستخدم التخزين المحلي فقط إذا السيرفر ما أعطانا رصيد صريح.
        if (uid == widget.app.userId &&
            gameId.isNotEmpty &&
            explicitPearls == null) {
          pearls = widget.app.pearlsForGame(gameId);
        }

        if (pearls < 0) pearls = 0;

        _pearlsByUser[uid] = pearls;

        final team = rp['team']?.toString();
        _teamOf[uid] = (team == 'A' || team == 'B') ? team : null;
      }

      final roomTeamMode = room['teamMode'];
      final roomMode = room['mode']?.toString();

      // Decide mode: prefer explicit backend flag. Otherwise, infer from teams or game mode.
      if (roomTeamMode is bool) {
        _teamMode = roomTeamMode;
      } else if (roomMode == 'solo') {
        _teamMode = false;
      } else if (roomMode == 'team') {
        _teamMode = true;
      } else if (_currentGameMode == GameMode.team) {
        _teamMode = true;
      } else if (_currentGameMode == GameMode.solo) {
        _teamMode = false;
      } else {
        final hasTeams = _teamOf.values.any((t) => t == 'A' || t == 'B');
        final bothTeams =
            _teamOf.values.contains('A') && _teamOf.values.contains('B');
        if (bothTeams) {
          _teamMode = true;
        } else if (!hasTeams) {
          _teamMode = false;
        }
      }

      _enforceGameMode();

      if (!_teamMode) {
        _winnerTeam = null;
      }

      _timerSec = (room['timerSec'] as num?)?.toInt();
      final s = room['startedAt'] as String?;
      _syncTimerRound(s);
      _startedAt = s != null ? DateTime.tryParse(s) : null;
      _startTickerIfNeeded();
      unawaited(_syncTimerNotification(code: code));

      await _refreshResultState(code);
      if (!mounted) return;
      _publishScoreRoom();
      setState(() {});
    } catch (e) {
      // لا نسبب سبام SnackBar كل 3 ثواني لأن هذا يعلق واجهة المباراة.
      final now = DateTime.now();
      final shouldToast = _lastRefreshErrorAt == null ||
          now.difference(_lastRefreshErrorAt!) > const Duration(seconds: 15);
      if (shouldToast && mounted) {
        _lastRefreshErrorAt = now;
        _msg('تعذر تحديث الروم الآن، جاري المحاولة...');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveRoom = _room ?? widget.room;
    final code =
        (effectiveRoom?['code'] ?? widget.app.roomCode ?? '').toString();
    final game = (effectiveRoom?['gameId'] ?? widget.app.selectedGame ?? 'لعبة')
        .toString();
    final sponsorCode = widget.sponsorCode;
    final timerMinutes = kGameRules[game]?.timerMinutes ?? 10;
    final timerSec = timerMinutes * 60;
    final countdownActive = _countdownActive;

    final hostId =
        (_room?['hostUserId'] ?? widget.room?['hostUserId'])?.toString();
    final isHost = widget.app.userId != null && hostId == widget.app.userId;
    final bool qaidGame = _isCardGame(game);
    final bool started = _startedAt != null;

    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_confirmCancelRoom(reason: 'player_left'));
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('مباراة $game — كود: ${code.isEmpty ? "—" : code}'),
          actions: [
            if (code.isNotEmpty && !_closedNotified)
              IconButton(
                tooltip: 'إلغاء القيم',
                icon: const Icon(Icons.close, color: Colors.redAccent),
                onPressed: _cancellingRoom
                    ? null
                    : () => _confirmCancelRoom(reason: 'manual_cancel'),
              ),
            if (sponsorCode != null && sponsorCode.isNotEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: Center(
                  child: Chip(
                    label: Text('Sponsor: $sponsorCode'),
                  ),
                ),
              ),
          ],
        ),
        body: Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async {
                if (code.isNotEmpty) await _refresh(code);
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (code.isNotEmpty) ...[
                    Center(
                      child: QrImageView(
                        data: 'https://inzeli.app/join/$code',
                        size: 220,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText('كود الروم: $code',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.center,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('تحديث'),
                        onPressed: () => _refresh(code),
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),
                  // تذكير توزيع الفرق أزيل بطلب المستخدم
                  const SizedBox(height: 12),
                  if (_timerSec != null && _startedAt != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.timer_outlined),
                        const SizedBox(width: 6),
                        Text(
                          _fmt(_remaining),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],

                  if (_resultStatus == 'pending')
                    Card(
                      color: Colors.orange.withValues(alpha: 0.12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.flag, color: Colors.orange),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'النتيجة قيد الموافقة (${_resultVotes.where((v) => v['approve'] == true).length}/$_totalPlayers وافقوا)',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_resultStatus == 'rejected' && isHost)
                    Card(
                      color: Colors.red.withValues(alpha: 0.12),
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                            'تم رفض النتيجة من أحد اللاعبين. حدّد الفائز من جديد.',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ),

                  if (isHost) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('وضع اللعب',
                                style: TextStyle(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 8),
                            if (_currentGameMode == GameMode.both)
                              SegmentedButton<bool>(
                                segments: const [
                                  ButtonSegment(
                                      value: true, label: Text('فرق')),
                                  ButtonSegment(
                                      value: false, label: Text('فردي')),
                                ],
                                selected: {_teamMode},
                                onSelectionChanged: _startedAt != null
                                    ? null
                                    : (s) => setState(() {
                                          _teamMode = s.first;
                                          _winnerTeam = null;
                                          _winnerUserId = null;
                                          if (!_teamMode) {
                                            _teamOf.clear();
                                          }
                                          _publishScoreRoom();
                                        }),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                        _currentGameMode == GameMode.team
                                            ? Icons.groups
                                            : Icons.person,
                                        size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      _currentGameMode == GameMode.team
                                          ? 'هذه اللعبة تُلعب كفرق فقط'
                                          : 'هذه اللعبة تُلعب كفردي فقط',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.center,
                    child: PrimaryPillButton(
                      icon: Icons.play_circle_outline,
                      label: 'بدء عدّاد ($timerMinutes دقيقة)',
                      maxWidth: 270,
                      minHeight: 74,
                      fontSize: 18,
                      onPressed: () async {
                        if (code.isEmpty) return;
                        if (_uniquePlayersList.length < 2) {
                          _msg('ما يصير تبلش بروحك',
                              icon: Icons.close,
                              color: Colors.red,
                              animateIcon: true);
                          return;
                        }
                        final gameName = (_room?['gameId'] ??
                                widget.room?['gameId'] ??
                                widget.app.selectedGame ??
                                '')
                            .toString();
                        if (!_validateSetup(gameName)) return;
                        try {
                          Sfx.primaryAction(
                              mute: widget.app.soundMuted == true);
                          final data = await ApiRoom.startRoom(
                            code: code,
                            token: widget.app.token,
                            targetWinPoints: null,
                            allowZeroCredit: true,
                            timerSec: timerSec,
                          );
                          _lastRemainingSoundTick = null;
                          _timerSec = (data['timerSec'] as num?)?.toInt();
                          final s = data['startedAt'] as String?;
                          _syncTimerRound(s);
                          _startedAt = s != null ? DateTime.tryParse(s) : null;
                          _startTickerIfNeeded();
                          unawaited(_syncTimerNotification(
                            code: code,
                            announceStart: true,
                          ));
                          Sfx.timerStart(mute: widget.app.soundMuted == true);
                          _msg('بدأت الجولة ⏱️');
                          _refresh(code);
                        } catch (e) {
                          Sfx.error(mute: widget.app.soundMuted == true);
                          _msg('خطأ البدء: ${ApiRoom.friendlyError(e)}');
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  // تم إخفاء حالة النصاب بناء على طلب المستخدم
                  if (isHost && _teamMode) ...[
                    _AssignTeamsCard(
                      app: widget.app,
                      code: code,
                      canAssign: _startedAt == null,
                      players: players,
                      teamOf: _teamOf,
                      pearlsByUser: _pearlsByUser,
                      onChanged: () => _refresh(code),
                    ),
                    const SizedBox(height: 16),
                  ],

                  const Text(
                    'اللاعبون',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Builder(builder: (context) {
                    final uniquePlayers = _uniquePlayersList;
                    if (uniquePlayers.isEmpty) {
                      return const Text(
                          'لاعب واحد (أنت). إن لم يظهر، حدّث/شّرف من جهاز آخر.');
                    }
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: uniquePlayers.map((p) {
                        final user = p['user'] as Map<String, dynamic>?;
                        final name = user?['displayName']?.toString() ??
                            user?['email']?.toString() ??
                            p['userId']?.toString() ??
                            '—';
                        final uid = p['userId']?.toString() ?? '';
                        final team = _teamOf[uid] ?? '';
                        final pearls = _pearlsByUser[uid] ?? 0;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              if (_teamMode && team.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                Text('($team)'),
                              ],
                              const SizedBox(width: 8),
                              _pearlPill(pearls),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  }),

                  if (isHost && _startedAt == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 6.0),
                      child: Text('اختر الفائز بعد بدء العداد.',
                          style: TextStyle(color: Colors.white70)),
                    )
                  else if (isHost && _teamMode)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ChoiceChip(
                          selected: _winnerTeam == 'A',
                          selectedColor: Colors.blue.withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                              color: _winnerTeam == 'A' ? Colors.blue : null),
                          label: const Text('الفريق A'),
                          onSelected: (_) => setState(() => _winnerTeam = 'A'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          selected: _winnerTeam == 'B',
                          selectedColor: Colors.red.withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                              color: _winnerTeam == 'B' ? Colors.red : null),
                          label: const Text('الفريق B'),
                          onSelected: (_) => setState(() => _winnerTeam = 'B'),
                        ),
                      ],
                    )
                  else if (isHost)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _uniquePlayersList.map((p) {
                        final user = p['user'] as Map<String, dynamic>?;
                        final name = user?['displayName']?.toString() ??
                            user?['email']?.toString() ??
                            p['userId']?.toString() ??
                            '—';
                        final uid = p['userId']?.toString() ?? '';
                        final selected = _winnerUserId == uid;
                        final team = _teamOf[uid] ?? '';
                        final pearls = _pearlsByUser[uid] ?? 0;
                        return ChoiceChip(
                          selected: selected,
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(name, overflow: TextOverflow.ellipsis),
                              if (_teamMode && team.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                Text('($team)'),
                              ],
                              const SizedBox(width: 6),
                              _pearlPill(pearls),
                            ],
                          ),
                          onSelected: (_) =>
                              setState(() => _winnerUserId = uid),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 12),

                  if (started &&
                      qaidGame &&
                      _iAmInRoom &&
                      !countdownActive) ...[
                    Card(
                        child: ListTile(
                      leading: const Icon(Icons.edit_note),
                      title: const Text('قيد المباراة — اختياري'),
                      subtitle: Text(isHost
                          ? 'اختَر قيد اللعبة أو القيد العام، وسجّل النقاط للجميع.'
                          : 'عرض القيد الذي فتحه الهوست.'),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: _openScore,
                    )),
                    const SizedBox(height: 12),
                  ],

                  if (isHost)
                    FilledButton.icon(
                      icon: const Icon(Icons.flag),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 18),
                        minimumSize: const Size.fromHeight(62),
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                      label: Text(_resultStatus == 'pending'
                          ? 'النتيجة قيد الموافقة'
                          : 'حسم النتيجة'),
                      onPressed: countdownActive
                          ? () => _msg('انتظر انتهاء العداد')
                          : () async {
                              final codeSafe = code;
                              if (_startedAt == null) {
                                Sfx.error(mute: widget.app.soundMuted == true);
                                _msg('ابدأ العداد أولاً');
                                return;
                              }
                              if (countdownActive) {
                                _msg('انتظر انتهاء العدّاد أولاً');
                                return;
                              }
                              if (_uniquePlayersList.length < 2) {
                                Sfx.error(mute: widget.app.soundMuted == true);
                                _msg('لا يمكن حسم النتيجة بلاعب واحد');
                                return;
                              }

                              try {
                                List<String> losers = [];
                                List<String> winners = [];
                                String winnerName;
                                if (_teamMode) {
                                  if (_winnerTeam == null) {
                                    _msg('اختر الفريق الفائز');
                                    return;
                                  }
                                  winners = _uniquePlayersList
                                      .map((p) => p['userId']?.toString() ?? '')
                                      .where((uid) =>
                                          uid.isNotEmpty &&
                                          (_teamOf[uid] ?? '') == _winnerTeam)
                                      .toList();
                                  losers = _uniquePlayersList
                                      .map((p) => p['userId']?.toString() ?? '')
                                      .where((uid) =>
                                          uid.isNotEmpty &&
                                          (_teamOf[uid] ?? '') != _winnerTeam)
                                      .toList();
                                  winnerName = 'الفريق ${_winnerTeam!}';
                                } else {
                                  if (_winnerUserId == null) {
                                    _msg('اختَر الفائز أولًا');
                                    return;
                                  }
                                  winners = [_winnerUserId!];
                                  losers = _uniquePlayersList
                                      .map((p) => p['userId']?.toString() ?? '')
                                      .where((uid) =>
                                          uid.isNotEmpty &&
                                          uid != _winnerUserId)
                                      .toList();
                                  winnerName = _nameForUser(_winnerUserId!);
                                }

                                final loserNames =
                                    losers.map(_nameForUser).join('، ');
                                winners = winners.toSet().toList();
                                losers = losers.toSet().toList();
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => Directionality(
                                    textDirection: TextDirection.rtl,
                                    child: AlertDialog(
                                      title: const Text('تأكيد النتيجة'),
                                      content: Text([
                                        'الفائز: $winnerName',
                                        if (loserNames.isNotEmpty)
                                          'الخاسرون: $loserNames',
                                        'سيتم انتظار موافقة كل اللاعبين.',
                                      ].join('\n')),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('إلغاء'),
                                        ),
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text('إرسال للموافقة'),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                                if (confirm != true) return;

                                await ApiRoom.submitResult(
                                  code: codeSafe,
                                  winners: winners,
                                  losers: losers,
                                  token: widget.app.token,
                                );

                                // حدّث اللآلئ محلياً مباشرةً (كل فائز +1، كل خاسر -1)
                                for (final w in winners.toSet()) {
                                  _pearlsByUser[w] =
                                      (_pearlsByUser[w] ?? 0) + 1;
                                }
                                for (final l in losers.toSet()) {
                                  _pearlsByUser[l] =
                                      (_pearlsByUser[l] ?? 0) - 1;
                                }

                                _msg('أُرسلت النتيجة — بانتظار موافقة الجميع');
                                // حدّث الخط الزمني / الإحصائيات عشان النتائج تظهر فوراً
                                await widget.app
                                    .syncTimelineFromServer()
                                    .catchError((_) {});
                                setState(() {
                                  _resultStatus = 'pending';
                                  _resultPayload = {
                                    'winners': winners,
                                    'losers': losers
                                  };
                                  _winnerUserId = null;
                                  _winnerTeam = null;
                                });
                                _refreshResultState(codeSafe);
                              } catch (e) {
                                _msg(e.toString());
                              }
                            },
                    ),

                  if (!_iAmInRoom) ...[
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.center,
                      child: FilledButton.icon(
                        onPressed: countdownActive
                            ? () => _msg('الشّرف مغلق أثناء العدّاد')
                            : () async {
                                final scanned = await Navigator.push<String>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ScanPage(),
                                  ),
                                );
                                final inputCode = scanned?.trim() ?? '';
                                if (inputCode.isEmpty) return;
                                if (!widget.app.isSignedIn) {
                                  _msg('سجّل دخول أول');
                                  return;
                                }
                                try {
                                  final pos = await _getLocation();
                                  await ApiRoom.joinByCode(
                                    code: inputCode,
                                    token: widget.app.token,
                                    lat: pos?.latitude,
                                    lng: pos?.longitude,
                                  );
                                  _msg('تم الانضمام ✅');
                                  _refresh(inputCode);
                                } catch (e) {
                                  _msg('خطأ: ${ApiRoom.friendlyError(e)}');
                                }
                              },
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('سكان للانضمام'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (countdownActive)
              Positioned.fill(
                child: AbsorbPointer(
                  absorbing: true,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.55),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock, color: Colors.white, size: 54),
                          const SizedBox(height: 16),
                          Text(
                            _fmt(_remaining),
                            style: const TextStyle(
                              fontSize: 56,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text('العدّاد شغّال، انتظر لين يخلص',
                              style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            // Opening a companion score route/QR never unlocks room actions.
            if (countdownActive && started && qaidGame && _iAmInRoom)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: SafeArea(
                    child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 10,
                        children: [
                      FilledButton.icon(
                          onPressed: _openScore,
                          icon: const Icon(Icons.edit_note),
                          label: const Text('قيد المباراة — اختياري')),
                      OutlinedButton.icon(
                          onPressed: () => _showRoomQr(code),
                          icon: const Icon(Icons.qr_code),
                          label: const Text('عرض QR')),
                    ])),
              ),
          ],
        ),
      ),
    );
  }
}

Widget _pearlPill(int pearls, {Color? color}) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Image.asset('lib/assets/pearl.png', width: 16, height: 16),
      const SizedBox(width: 4),
      Text(
        '$pearls',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    ],
  );
}

class _AssignTeamsCard extends StatelessWidget {
  final AppState app;
  final String code;
  final List<Map<String, dynamic>> players;
  final Map<String, String?> teamOf;
  final Map<String, int> pearlsByUser;
  final VoidCallback onChanged;
  final bool canAssign;

  const _AssignTeamsCard({
    required this.app,
    required this.code,
    required this.players,
    required this.teamOf,
    required this.pearlsByUser,
    required this.onChanged,
    required this.canAssign,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final teamA = players
        .where((p) => teamOf[(p['userId'] ?? '').toString()] == 'A')
        .toList();
    final teamB = players
        .where((p) => teamOf[(p['userId'] ?? '').toString()] == 'B')
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              canAssign
                  ? 'توزيع الفرق (للمضيف فقط)'
                  : 'توزيع الفرق ثابت بعد بدء القيم',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _TeamColumn(
                    title: 'الفريق A',
                    color: Colors.blue.shade600,
                    players: teamA,
                    pearlsByUser: pearlsByUser,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TeamColumn(
                    title: 'الفريق B',
                    color: Colors.red.shade600,
                    players: teamB,
                    pearlsByUser: pearlsByUser,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...players.map((p) {
              final uid = (p['userId'] ?? '').toString();
              final user = p['user'] as Map<String, dynamic>?;
              final name = user?['displayName']?.toString() ??
                  user?['email']?.toString() ??
                  uid;
              final pearls = pearlsByUser[uid] ?? 0;

              final sel = teamOf[uid];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(name,
                              maxLines: 1, overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 8),
                      _pearlPill(pearls),
                      const SizedBox(width: 8),
                    ]),
                    const SizedBox(height: 8),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: ToggleButtons(
                        isSelected: [
                          sel == 'A',
                          sel == 'B',
                        ],
                        borderRadius: BorderRadius.circular(12),
                        onPressed: !canAssign
                            ? null
                            : (index) async {
                                final value = index == 0 ? 'A' : 'B';
                                try {
                                  await ApiRoom.setPlayerTeam(
                                    code: code,
                                    playerUserId: uid,
                                    team: value,
                                    token: app.token,
                                  );
                                  onChanged();
                                } catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Team error: $e')),
                                  );
                                }
                              },
                        color: onSurface.withValues(alpha: 0.7),
                        selectedColor: Colors.white,
                        fillColor: sel == 'A'
                            ? Colors.blue.shade600
                            : Colors.red.shade600,
                        children: const [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('A',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('B',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _TeamColumn extends StatelessWidget {
  final String title;
  final Color color;
  final List<Map<String, dynamic>> players;
  final Map<String, int> pearlsByUser;

  const _TeamColumn({
    required this.title,
    required this.color,
    required this.players,
    required this.pearlsByUser,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          if (players.isEmpty)
            Text(
              'لا يوجد',
              style: TextStyle(color: color.withValues(alpha: 0.7)),
            )
          else
            ...players.map((p) {
              final uid = (p['userId'] ?? '').toString();
              final user = p['user'] as Map<String, dynamic>?;
              final name = user?['displayName']?.toString() ??
                  user?['email']?.toString() ??
                  uid;
              final pearls = pearlsByUser[uid] ?? 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(color: color),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _pearlPill(pearls, color: color),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

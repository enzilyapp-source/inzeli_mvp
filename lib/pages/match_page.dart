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

class _MatchPageState extends State<MatchPage> {
  Map<String, dynamic>? _room; // آخر نسخة من بيانات الروم
  final _codeCtrl = TextEditingController();
  Timer? _autoRefresh;

  List<Map<String, dynamic>> players = [];
  final Map<String, int> _pearlsByUser = {};
  final Map<String, String?> _teamOf = {};
  final Set<String> _knownPlayerIds = {};

  String? _winnerUserId;
  String? _winnerTeam; // A/B if team mode
  bool _teamMode = false; // default to فردي حتى يختار المضيف فرق
  bool _locked = false; // لا يسمح بالحسم/الشّرف أثناء العدّاد

  Timer? _ticker;
  int _remaining = 0;
  DateTime? _startedAt;
  int? _timerSec;
  bool _closedNotified = false;

  // حالة النتيجة والموافقات
  String? _resultStatus; // waiting | pending | approved | rejected
  Map<String, dynamic>? _resultPayload;
  List<Map<String, dynamic>> _resultVotes = const [];
  int _totalPlayers = 0;
  bool _approvalDialogOpen = false;
  bool _resultNotified = false;
  GameMode _currentGameMode = GameMode.both;
  int? _lastRemainingSoundTick;

  // -------- قيد (تسجيل نقاط الجنجفه) --------
  final int _qaidDefaultTarget = 100;
  int _qaidTarget = 100;
  int _qaidScoreA = 0;
  int _qaidScoreB = 0;
  final _qaidInputA = TextEditingController();
  final _qaidInputB = TextEditingController();
  List<Map<String, dynamic>> _qaidRounds = [];
  final Map<String, TextEditingController> _qaidPlayerInputs = {};
  final Map<String, int> _qaidPlayerScores = {};

  // قواعد أحجام الفرق لكل لعبة (عدد اللاعبين في كل فريق)
  static const Map<String, List<int>> _teamSizeRules = {
    'كوت': [2, 3],   // 2 ضد 2 أو 3 ضد 3
    'بلوت': [2],     // 2 ضد 2
    'تريكس': [2],    // 2 ضد 2
    'هند': [2],      // 2 ضد 2 في وضع الفرق
    'كيرم': [2],     // 2 ضد 2 فقط
    'سبيتة': [2],    // 2 ضد 2 في وضع الفرق
    'بيبيفوت': [2],  // 2 ضد 2 في وضع الفرق
    'قدم': [9],      // 9 ضد 9
    'سله': [5],      // 5 ضد 5
    'طائره': [2, 3, 5, 6], // خيارات متعددة للفرق
    'بادل': [2],     // 2 ضد 2
    'تنس طاولة': [2], // دبلز 2 ضد 2
    'تنس ارضي': [2], // دبلز 2 ضد 2
  };
  static const int _hindSoloSize = 5; // هند فردي = 5 لاعبين
  static const int _spitaSoloSize = 5; // سبيتة فردي = 5 لاعبين
  bool get _iAmInRoom {
    final uid = widget.app.userId;
    if (uid == null || uid.isEmpty) return false;
    return _uniquePlayersList.any((p) => (p['userId'] ?? '') == uid);
  }

  bool _isCardGame(String game) {
    final g = game.trim();
    const cardGames = [
      'كوت',
      'بلوت',
      'تريكس',
      'تريكس كمبليت',
      'هند',
      'hand',
      'trex',
      'baloot',
      'coup',
      'sbeeta',
      'سبيتة',
    ];
    return cardGames.any((c) => g.toLowerCase().contains(c.trim().toLowerCase())) && !g.toLowerCase().contains('uno');
  }

  void _resetQaid() {
    _qaidTarget = _qaidDefaultTarget;
    _qaidScoreA = 0;
    _qaidScoreB = 0;
    _qaidRounds = [];
    _qaidInputA.clear();
    _qaidInputB.clear();
    _qaidPlayerScores.clear();
    for (final c in _qaidPlayerInputs.values) {
      c.dispose();
    }
    _qaidPlayerInputs.clear();
    final players = _uniquePlayersList;
    for (final p in players) {
      final uid = (p['userId'] ?? '').toString();
      if (uid.isEmpty) continue;
      _qaidPlayerScores[uid] = 0;
      _qaidPlayerInputs[uid] = TextEditingController();
    }
  }

  void _ensureQaidPlayer(String uid) {
    if (!_qaidPlayerScores.containsKey(uid)) {
      _qaidPlayerScores[uid] = 0;
    }
    if (!_qaidPlayerInputs.containsKey(uid)) {
      _qaidPlayerInputs[uid] = TextEditingController();
    }
  }

  void _saveQaidRound(bool teamMode) {
    if (teamMode) {
      final a = int.tryParse(_qaidInputA.text.trim()) ?? 0;
      final b = int.tryParse(_qaidInputB.text.trim()) ?? 0;
      _qaidScoreA += a;
      _qaidScoreB += b;
      _qaidRounds.add({'a': a, 'b': b, 'ts': DateTime.now().toIso8601String()});
      _qaidInputA.clear();
      _qaidInputB.clear();
    } else {
      final map = <String, int>{};
      _qaidPlayerInputs.forEach((uid, ctrl) {
        final v = int.tryParse(ctrl.text.trim()) ?? 0;
        map[uid] = v;
        _qaidPlayerScores[uid] = (_qaidPlayerScores[uid] ?? 0) + v;
        ctrl.clear();
      });
      _qaidRounds.add({'scores': map, 'ts': DateTime.now().toIso8601String()});
    }
    setState(() {});
  }

  void _undoQaidRound(bool teamMode) {
    if (_qaidRounds.isEmpty) return;
    final last = _qaidRounds.removeLast();
    if (teamMode) {
      _qaidScoreA -= (last['a'] as int? ?? 0);
      _qaidScoreB -= (last['b'] as int? ?? 0);
    } else {
      final map = last['scores'] as Map<String, dynamic>? ?? {};
      map.forEach((uid, v) {
        _qaidPlayerScores[uid] = (_qaidPlayerScores[uid] ?? 0) - (v as int? ?? 0);
      });
    }
    setState(() {});
  }

  String _playerKey(Map<String, dynamic> p) {
    final uid = (p['userId'] ?? '').toString();
    if (uid.isNotEmpty) return uid;
    final user = p['user'] as Map<String, dynamic>? ?? const {};
    final name = (user['displayName'] ?? user['name'] ?? user['email'] ?? user['phone'] ?? '').toString().trim().toLowerCase();
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
      if (!seenNames.add(nameKey)) continue;
      out.add(p);
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    _room = widget.room;
    final initial = widget.room?['players'];
    if (initial is List) players = initial.cast<Map<String, dynamic>>();
    final code = (widget.room?['code'] ?? widget.app.roomCode ?? '').toString();
    final mode = widget.room?['mode']?.toString();
    final teamModeFlag = widget.room?['teamMode'];
    final initialGame = (widget.room?['gameId'] ?? widget.app.selectedGame ?? '').toString();
    _currentGameMode = widget.app.gameMode(initialGame);
    // حضّر القيد إذا اللعبة من ألعاب الجنجفه
    if (_isCardGame(initialGame)) {
      _resetQaid();
    }

    if (teamModeFlag is bool) {
      _teamMode = teamModeFlag;
    } else if (mode == 'team') {
      _teamMode = true;
    } else if (mode == 'solo') {
      _teamMode = false;
    }
    _enforceGameMode();
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
    _ticker?.cancel();
    _autoRefresh?.cancel();
    _codeCtrl.dispose();
    _qaidInputA.dispose();
    _qaidInputB.dispose();
    for (final c in _qaidPlayerInputs.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _msg(String m, {Color? color, IconData? icon, bool animateIcon = false}) {
    final bool error = color == Colors.red || color == Colors.redAccent;
    final bool success = color == Colors.green || color == Colors.greenAccent;
    showAppSnack(context, m, error: error, success: success);
  }

  Future<Position?> _getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          return null;
        }
      }
      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
    } catch (_) {
      return null;
    }
  }

  String _fmt(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$m:$ss';
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
        uid).toString();
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
          Sfx.success(mute: widget.app.soundMuted == true);
          HapticFeedback.heavyImpact();
          _msg('انتهى العدّاد، حدد الفائز', color: Colors.green);
          _locked = false;
        }
      }
      setState(() => _remaining = clamped);
      if (_remaining <= 0) _ticker?.cancel();
    }

    tick();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  void _detectNewPlayers(List<Map<String, dynamic>> incoming) {
    final currentIds = incoming.map(_playerKey).toSet();
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
    _knownPlayerIds
      ..clear()
      ..addAll(currentIds);
  }

  String _nameForMap(Map<String, dynamic> p) {
    final uid = (p['userId'] ?? '').toString();
    final user = p['user'] as Map<String, dynamic>? ?? const {};
    return (user['displayName'] ?? user['name'] ?? user['email'] ?? user['phone'] ?? uid).toString();
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
          _msg('وزّع اللاعبين على الفريقين أولاً', icon: Icons.error, color: Colors.orange);
          return false;
        }
        if (sizeA != sizeB) {
          _msg('لازم عدد الفريقين يكون متساوي', icon: Icons.error, color: Colors.orange);
          return false;
        }
        final allowed = _teamSizeRules[game];
        if (allowed != null && !allowed.contains(sizeA)) {
          final txt = allowed.map((n) => '$n ضد $n').join(' أو ');
          _msg('لعبة $game تسمح بـ $txt فقط', icon: Icons.error, color: Colors.orange);
          return false;
        }
      } else {
        if (game == 'هند' && count != _hindSoloSize) {
          _msg('هند فردي لازم يكونوا $_hindSoloSize لاعبين', icon: Icons.error, color: Colors.orange);
          return false;
        }
        if (game == 'سبيتة' && count != _spitaSoloSize) {
          _msg('سبيتة فردي لازم يكونوا $_spitaSoloSize لاعبين', icon: Icons.error, color: Colors.orange);
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
          _msg('بلياردو فردي فقط 1 ضد 1', icon: Icons.error, color: Colors.orange);
          return false;
        }
        if (game == 'بيبيفوت' && count != 2 && _teamMode == false) {
          _msg('بيبي فوت فردي فقط 1 ضد 1 أو فرق 2 ضد 2', icon: Icons.error, color: Colors.orange);
          return false;
        }
        if (game == 'تنس طاولة' && _teamMode == false && count != 2) {
          _msg('تنس طاولة فردي 1 ضد 1 أو فرق 2 ضد 2', icon: Icons.error, color: Colors.orange);
          return false;
        }
        if (game == 'تنس ارضي' && _teamMode == false && count != 2) {
          _msg('تنس فردي 1 ضد 1 أو فرق 2 ضد 2', icon: Icons.error, color: Colors.orange);
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
      _resultVotes = (state['votes'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
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
    final isHost = (_room?['hostUserId'] ?? widget.room?['hostUserId'])?.toString() == myId;

    if (_resultStatus == 'approved') {
      if (!_resultNotified) {
        _resultNotified = true;
        _msg('تم اعتماد النتيجة 🎉');
        Sfx.success(mute: widget.app.soundMuted == true);
        widget.app.syncTimelineFromServer().catchError((_) {});
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
      final alreadyVoted = _resultVotes.any((v) => (v['userId'] ?? '').toString() == myId);
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
                    await ApiRoom.voteResult(code: _room?['code'] ?? widget.room?['code'] ?? '', approve: false, token: widget.app.token);
                  _msg('تم الرفض، سيُعاد تحديد النتيجة');
                  Sfx.error(mute: widget.app.soundMuted == true);
                    _refreshResultState(_room?['code'] ?? widget.room?['code'] ?? '');
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
                    await ApiRoom.voteResult(code: _room?['code'] ?? widget.room?['code'] ?? '', approve: true, token: widget.app.token);
                    _msg('تمت الموافقة على النتيجة');
                    Sfx.tap(mute: widget.app.soundMuted == true);
                    _refreshResultState(_room?['code'] ?? widget.room?['code'] ?? '');
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

      _locked = room['locked'] == true;

      final remainingSec = (room['remainingSec'] as num?)?.toInt();
      if (remainingSec != null) _remaining = remainingSec;

      final status = room['status']?.toString();
      if (status != null && status != 'waiting' && status != 'running') {
        _timerSec = null;
        _startedAt = null;
        if (!_closedNotified) {
          _closedNotified = true;
          widget.app.setRoomCode(null);
          _msg('الروم انتهى');
        }
        if (mounted) Navigator.pop(context);
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

      final gameId = (room['gameId'] ?? widget.app.selectedGame ?? '').toString();
      _currentGameMode = widget.app.gameMode(gameId);

      for (final rp in _uniquePlayersList) {
        final uid = (rp['userId'] ?? '').toString();
        final user = rp['user'] as Map<String, dynamic>?;
        // حاول نقرأ أي قيمة لؤلؤ متاحة من السيرفر، وإلا 5 افتراضي
        int pearls =
            (user?['pearls'] as num?)?.toInt() ??
            (user?['creditBalance'] as num?)?.toInt() ??
            (user?['permanentScore'] as num?)?.toInt() ??
            5;

        // استخدم رصيد اللؤلؤ لكل لعبة للحساب الحالي (لصاحب الحساب فقط)
        if (uid == widget.app.userId && gameId.isNotEmpty) {
          pearls = widget.app.pearlsForGame(gameId);
        }

        // لو القيمة غير منطقية (<=0) نرجع للـ 5 الافتراضية
        if (pearls <= 0) pearls = 5;

        _pearlsByUser[uid] = pearls;

        final team = rp['team']?.toString();
        _teamOf[uid] = (team == 'A' || team == 'B') ? team : null;

      }

      final roomTeamMode = room['teamMode'];
      final roomMode = room['mode']?.toString();

      final prevTeamMode = _teamMode;
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
        final bothTeams = _teamOf.values.contains('A') && _teamOf.values.contains('B');
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

      // لو تغير نوع اللعب بين فردي/فرق أثناء الجولة للكوت/الجنجفة، صفّر القيد عشان يتوافق مع النمط
      if (_startedAt != null && _isCardGame(gameId) && prevTeamMode != _teamMode) {
        _resetQaid();
      }

      _timerSec = (room['timerSec'] as num?)?.toInt();
      final s = room['startedAt'] as String?;
      _startedAt = s != null ? DateTime.tryParse(s) : null;
      _startTickerIfNeeded();

      await _refreshResultState(code);

      setState(() {});
    } catch (e) {
      _msg('تحديث الروم فشل: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = (widget.room?['code'] ?? widget.app.roomCode ?? '').toString();
    final game =
    (widget.room?['gameId'] ?? widget.app.selectedGame ?? 'لعبة').toString();
    final sponsorCode = widget.sponsorCode;

    final hostId = (_room?['hostUserId'] ?? widget.room?['hostUserId'])?.toString();
    final isHost = widget.app.userId != null && hostId == widget.app.userId;
    final bool qaidGame = _isCardGame(game);
    final bool started = _startedAt != null;
    if (started && qaidGame && !_teamMode) {
      for (final p in _uniquePlayersList) {
        final uid = (p['userId'] ?? '').toString();
        if (uid.isNotEmpty) _ensureQaidPlayer(uid);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('مباراة $game — كود: ${code.isEmpty ? "—" : code}'),
        actions: [
          if (_startedAt == null && _timerSec == null)
            IconButton(
              tooltip: 'إغلاق الروم',
              icon: const Icon(Icons.close, color: Colors.redAccent),
              onPressed: () {
                widget.app.setRoomCode(null);
                Navigator.pop(context);
                _msg('تم إغلاق الروم', color: Colors.redAccent);
              },
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
                  SelectableText('كود الروم: $code', textAlign: TextAlign.center),
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
                              style: const TextStyle(fontWeight: FontWeight.w700),
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
                      child: Text('تم رفض النتيجة من أحد اللاعبين. حدّد الفائز من جديد.', style: TextStyle(color: Colors.red)),
                    ),
                  ),

                if (isHost) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('وضع اللعب', style: TextStyle(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 8),
                          if (_currentGameMode == GameMode.both)
                            SegmentedButton<bool>(
                              segments: const [
                                ButtonSegment(value: true, label: Text('فرق')),
                                ButtonSegment(value: false, label: Text('فردي')),
                              ],
                              selected: {_teamMode},
                            onSelectionChanged: (s) => setState(() {
                              _teamMode = s.first;
                              _winnerTeam = null;
                              _winnerUserId = null;
                              if (!_teamMode) {
                                _teamOf.clear();
                              }
                              final gameName = (widget.room?['gameId'] ?? widget.app.selectedGame ?? '').toString();
                              if (_isCardGame(gameName) && _startedAt != null) {
                                _resetQaid();
                              }
                            }),
                          )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(_currentGameMode == GameMode.team ? Icons.groups : Icons.person, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    _currentGameMode == GameMode.team
                                        ? 'هذه اللعبة تُلعب كفرق فقط'
                                        : 'هذه اللعبة تُلعب كفردي فقط',
                                    style: const TextStyle(fontWeight: FontWeight.w700),
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
                  child: FilledButton.icon(
                    icon: const Icon(Icons.play_circle_outline),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      minimumSize: const Size(240, 54),
                    ),
                    label: const Text('بدء عدّاد (10 دقائق)'),
                    onPressed: () async {
                      if (code.isEmpty) return;
                      if (_uniquePlayersList.length < 2) {
                        _msg('ما يصير تبلش بروحك', icon: Icons.close, color: Colors.red, animateIcon: true);
                        return;
                      }
                      final gameName = (widget.room?['gameId'] ?? widget.app.selectedGame ?? '').toString();
                      if (!_validateSetup(gameName)) return;
                      try {
                        final data = await ApiRoom.startRoom(
                          code: code,
                          token: widget.app.token,
                          targetWinPoints: null,
                          allowZeroCredit: true,
                          timerSec: 600,
                        );
                        _locked = data['locked'] == true;
                        _lastRemainingSoundTick = null;
                        _timerSec = (data['timerSec'] as num?)?.toInt();
                        final s = data['startedAt'] as String?;
                        _startedAt = s != null ? DateTime.tryParse(s) : null;
                        if (_isCardGame(gameName)) {
                          _resetQaid();
                        }
                        _startTickerIfNeeded();
                        Sfx.timerStart(mute: widget.app.soundMuted == true);
                        _msg('بدأت الجولة ⏱️');
                        _refresh(code);
                      } catch (e) {
                        Sfx.error(mute: widget.app.soundMuted == true);
                        _msg('خطأ البدء: $e');
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
                    return const Text('لاعب واحد (أنت). إن لم يظهر، حدّث/شّرف من جهاز آخر.');
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
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

                if (_startedAt == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 6.0),
                    child: Text('اختر الفائز بعد بدء العداد.', style: TextStyle(color: Colors.white70)),
                  )
                else if (_teamMode)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ChoiceChip(
                        selected: _winnerTeam == 'A',
                        selectedColor: Colors.blue.withValues(alpha: 0.2),
                        labelStyle: TextStyle(color: _winnerTeam == 'A' ? Colors.blue : null),
                        label: const Text('الفريق A'),
                        onSelected: (_) => setState(() => _winnerTeam = 'A'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        selected: _winnerTeam == 'B',
                        selectedColor: Colors.red.withValues(alpha: 0.2),
                        labelStyle: TextStyle(color: _winnerTeam == 'B' ? Colors.red : null),
                        label: const Text('الفريق B'),
                        onSelected: (_) => setState(() => _winnerTeam = 'B'),
                      ),
                    ],
                  )
                else
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
                        onSelected: (_) => setState(() => _winnerUserId = uid),
                      );
                    }).toList(),
                  ),

                const SizedBox(height: 12),

                if (started && qaidGame && !_locked) ...[
                  _QaidCard(
                    teamMode: _teamMode,
                    target: _qaidTarget,
                    scoreA: _qaidScoreA,
                    scoreB: _qaidScoreB,
                    players: _uniquePlayersList,
                    playerScores: _qaidPlayerScores,
                    inputA: _qaidInputA,
                    inputB: _qaidInputB,
                    playerInputs: _qaidPlayerInputs,
                    onSave: () => setState(() => _saveQaidRound(_teamMode)),
                    onUndo: () => setState(() => _undoQaidRound(_teamMode)),
                    onReset: () => setState(() => _resetQaid()),
                  ),
                  const SizedBox(height: 12),
                ],

                if (isHost)
                  FilledButton.icon(
                    icon: const Icon(Icons.flag),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                      minimumSize: const Size.fromHeight(62),
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    label: Text(_resultStatus == 'pending' ? 'النتيجة قيد الموافقة' : 'حسم النتيجة'),
                    onPressed: _locked
                        ? () => _msg('انتظر انتهاء العداد')
                        : () async {
                            final codeSafe = code;
                            if (_startedAt == null) {
                              Sfx.error(mute: widget.app.soundMuted == true);
                              _msg('ابدأ العداد أولاً');
                              return;
                            }
                            if (_remaining > 0) {
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
                                    .where((uid) => uid.isNotEmpty && (_teamOf[uid] ?? '') == _winnerTeam)
                                    .toList();
                                losers = _uniquePlayersList
                                    .map((p) => p['userId']?.toString() ?? '')
                                    .where((uid) => uid.isNotEmpty && (_teamOf[uid] ?? '') != _winnerTeam)
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
                                    .where((uid) => uid.isNotEmpty && uid != _winnerUserId)
                                    .toList();
                                winnerName = _nameForUser(_winnerUserId!);
                              }

                              final loserNames = losers.map(_nameForUser).join('، ');
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
                                      if (loserNames.isNotEmpty) 'الخاسرون: $loserNames',
                                      'سيتم انتظار موافقة كل اللاعبين.',
                                    ].join('\n')),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: const Text('إلغاء'),
                                      ),
                                      FilledButton(
                                        onPressed: () => Navigator.pop(ctx, true),
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
                            _pearlsByUser[w] = (_pearlsByUser[w] ?? 0) + 1;
                          }
                          for (final l in losers.toSet()) {
                            _pearlsByUser[l] = (_pearlsByUser[l] ?? 0) - 1;
                          }

                          _msg('أُرسلت النتيجة — بانتظار موافقة الجميع');
                          // حدّث الخط الزمني / الإحصائيات عشان النتائج تظهر فوراً
                          await widget.app.syncTimelineFromServer().catchError((_) {});
                          setState(() {
                            _resultStatus = 'pending';
                            _resultPayload = {'winners': winners, 'losers': losers};
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
                  const Text('انضم بالكود (اختبار سريع)'),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _codeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'اكتب كود الروم',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: 'مسح QR',
                        onPressed: () async {
                          final scanned = await Navigator.push<String>(
                            context,
                            MaterialPageRoute(builder: (_) => const ScanPage()),
                          );
                          if (scanned != null && scanned.isNotEmpty) {
                            setState(() => _codeCtrl.text = scanned);
                          }
                        },
                        icon: const Icon(Icons.qr_code_scanner),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _locked
                            ? () => _msg('الشّرف مغلق أثناء العدّاد')
                            : () async {
                          final inputCode = _codeCtrl.text.trim().isEmpty
                              ? code
                              : _codeCtrl.text.trim();
                          if (inputCode.isEmpty) {
                            _msg('اكتب الكود للانضمام');
                            return;
                          }
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
                            _msg('خطأ: $e');
                          }
                        },
                        child: const Text('انضم'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (_locked && _remaining > 0)
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
                        const Text('العدّاد شغّال، انتظر لين يخلص', style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // أثناء القفل: نسمح باستخدام القيد فقط
          if (_locked && _remaining > 0 && started && qaidGame)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: IgnorePointer(
                ignoring: false,
                child: _QaidCard(
                  teamMode: _teamMode,
                  target: _qaidTarget,
                  scoreA: _qaidScoreA,
                  scoreB: _qaidScoreB,
                  players: _uniquePlayersList,
                  playerScores: _qaidPlayerScores,
                  inputA: _qaidInputA,
                  inputB: _qaidInputB,
                  playerInputs: _qaidPlayerInputs,
                  onSave: () => setState(() => _saveQaidRound(_teamMode)),
                  onUndo: () => setState(() => _undoQaidRound(_teamMode)),
                  onReset: () => setState(() => _resetQaid()),
                ),
              ),
            ),
        ],
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

  const _AssignTeamsCard({
    required this.app,
    required this.code,
    required this.players,
    required this.teamOf,
    required this.pearlsByUser,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final teamA = players.where((p) => teamOf[(p['userId'] ?? '').toString()] == 'A').toList();
    final teamB = players.where((p) => teamOf[(p['userId'] ?? '').toString()] == 'B').toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'توزيع الفرق (للمضيف فقط)',
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
                child: Row(
                  children: [
                    Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    _pearlPill(pearls),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 160,
                      child: ToggleButtons(
                        isSelected: [
                          sel == 'A',
                          sel == 'B',
                        ],
                        borderRadius: BorderRadius.circular(12),
                        onPressed: (index) async {
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
                            child: Text('A', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('B', style: TextStyle(fontWeight: FontWeight.w700)),
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

// --- Qaid widgets (جنجفه) ---
class _QaidCard extends StatelessWidget {
  final bool teamMode;
  final int target;
  final int scoreA;
  final int scoreB;
  final List<Map<String, dynamic>> players;
  final Map<String, int> playerScores;
  final TextEditingController inputA;
  final TextEditingController inputB;
  final Map<String, TextEditingController> playerInputs;
  final VoidCallback onSave;
  final VoidCallback onUndo;
  final VoidCallback onReset;

  const _QaidCard({
    required this.teamMode,
    required this.target,
    required this.scoreA,
    required this.scoreB,
    required this.players,
    required this.playerScores,
    required this.inputA,
    required this.inputB,
    required this.playerInputs,
    required this.onSave,
    required this.onUndo,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final remainA = (target - scoreA);
    final remainB = (target - scoreB);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.calculate),
                SizedBox(width: 8),
                Text('قيد الجولة (الجنجفه)', style: TextStyle(fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 10),
            if (teamMode) ...[
              Row(
                children: [
                  Expanded(
                    child: _QaidTeamBox(
                      title: 'الفريق A',
                      score: scoreA,
                      remain: remainA,
                      input: inputA,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QaidTeamBox(
                      title: 'الفريق B',
                      score: scoreB,
                      remain: remainB,
                      input: inputB,
                    ),
                  ),
                ],
              ),
            ] else ...[
              const Text('قيد اللاعبين (فردي)', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: players.map((p) {
                  final uid = (p['userId'] ?? '').toString();
                  if (uid.isEmpty) return const SizedBox.shrink();
                  final user = p['user'] as Map<String, dynamic>?;
                  final name = user?['displayName']?.toString() ?? user?['email']?.toString() ?? uid;
                  final score = playerScores[uid] ?? 0;
                  final remain = (target - score).clamp(-999999, 999999);
                  final ctrl = playerInputs.putIfAbsent(uid, () => TextEditingController());
                  return SizedBox(
                    width: 170,
                    child: _QaidSoloBox(name: name, score: score, remain: remain, input: ctrl),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: onSave,
                  icon: const Icon(Icons.save),
                  label: const Text('تسجيل الجولة'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onUndo,
                  icon: const Icon(Icons.undo),
                  label: const Text('تراجع'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onReset,
                  child: const Text('تصفير القيد'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QaidTeamBox extends StatelessWidget {
  final String title;
  final int score;
  final int remain;
  final TextEditingController input;
  const _QaidTeamBox({
    required this.title,
    required this.score,
    required this.remain,
    required this.input,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('المجموع: $score', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  final v = int.tryParse(input.text.trim()) ?? 0;
                  input.text = (v - 1).toString();
                },
                icon: const Icon(Icons.remove),
              ),
              Expanded(
                child: TextField(
                  controller: input,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: 'نقاط الجولة'),
                ),
              ),
              IconButton(
                onPressed: () {
                  final v = int.tryParse(input.text.trim()) ?? 0;
                  input.text = (v + 1).toString();
                },
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QaidSoloBox extends StatelessWidget {
  final String name;
  final int score;
  final int remain;
  final TextEditingController input;
  const _QaidSoloBox({
    required this.name,
    required this.score,
    required this.remain,
    required this.input,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('المجموع: $score', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: input,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'نقاط الجولة'),
          ),
        ],
      ),
    );
  }
}

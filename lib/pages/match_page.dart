// lib/pages/match_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../state.dart';
import '../api_room.dart';
import '../sfx.dart';
import 'scan_page.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';

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
  final Map<String, bool> _isLeader = {};
  Map<String, dynamic>? _teamQuorum;
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

  @override
  void initState() {
    super.initState();
    _room = widget.room;
    final initial = widget.room?['players'];
    if (initial is List) players = initial.cast<Map<String, dynamic>>();
    final code = (widget.room?['code'] ?? widget.app.roomCode ?? '').toString();
    final mode = widget.room?['mode']?.toString();
    final teamModeFlag = widget.room?['teamMode'];
    if (teamModeFlag is bool) {
      _teamMode = teamModeFlag;
    } else if (mode == 'team') {
      _teamMode = true;
    } else if (mode == 'solo') {
      _teamMode = false;
    }
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
    super.dispose();
  }

  void _msg(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
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
    final p = players.firstWhere(
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
      setState(() => _remaining = remain.clamp(0, 1 << 30));
      if (_remaining <= 0) _ticker?.cancel();
    }

    tick();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  void _detectNewPlayers(List<Map<String, dynamic>> incoming) {
    final currentIds = incoming.map((e) => (e['userId'] ?? '').toString()).where((id) => id.isNotEmpty).toSet();
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
        builder: (ctx) => AlertDialog(
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
                } finally {
                  _approvalDialogOpen = false;
                }
              },
              child: const Text('موافقة'),
            ),
          ],
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
        final incoming = p.cast<Map<String, dynamic>>();
        _detectNewPlayers(incoming);
        players = incoming;
      }

      _pearlsByUser.clear();
      _teamOf.clear();
      _isLeader.clear();

      final gameId = (room['gameId'] ?? widget.app.selectedGame ?? '').toString();

      for (final rp in players) {
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

        final leader = (rp['isLeader'] == true);
        _isLeader[uid] = leader;
      }

      _teamQuorum = room['teamQuorum'] as Map<String, dynamic>?;
      final roomTeamMode = room['teamMode'];
      final roomMode = room['mode']?.toString();

      // Decide mode: prefer explicit backend flag. Otherwise, keep the host's toggle.
      if (roomTeamMode is bool) {
        _teamMode = roomTeamMode;
      } else if (roomMode == 'solo') {
        _teamMode = false;
      } else if (roomMode == 'team') {
        _teamMode = true;
      }

      if (!_teamMode) {
        _winnerTeam = null;
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

    return Scaffold(
      appBar: AppBar(
        title: Text('مباراة $game — كود: ${code.isEmpty ? "—" : code}'),
        actions: [
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
      body: RefreshIndicator(
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
            if (isHost && _teamMode)
              Card(
                color: Colors.orange.withValues(alpha: 0.15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'تذكير توزيع الفرق',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'خلك على توزيع زوجي (٢ ضد ٢، ٣ ضد ٣ ...). لو العدد ما يساوي، سوها فردي لاعب ضد لاعب عشان اللؤلؤ يتوزع بعدل.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                      ),
                    ],
                  ),
                ),
              ),
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
                        }),
                      ),
                    ],
                  ),
                ),
              ),
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
                    try {
                      final data = await ApiRoom.startRoom(
                        code: code,
                        token: widget.app.token,
                        targetWinPoints: null,
                        allowZeroCredit: true,
                        timerSec: 600,
                      );
                      _locked = data['locked'] == true;
                      _timerSec = (data['timerSec'] as num?)?.toInt();
                      final s = data['startedAt'] as String?;
                      _startedAt =
                      s != null ? DateTime.tryParse(s) : null;
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
            ],

            if (_teamMode && _teamQuorum != null) ...[
              _TeamQuorumCard(teamQuorum: _teamQuorum!),
              const SizedBox(height: 16),
            ],

            if (isHost && _teamMode) ...[
              _AssignTeamsCard(
                app: widget.app,
                code: code,
                players: players,
                teamOf: _teamOf,
                pearlsByUser: _pearlsByUser,
                isLeader: _isLeader,
                onChanged: () => _refresh(code),
              ),
              const SizedBox(height: 12),
              _SetLeaderCard(
                app: widget.app,
                code: code,
                players: players,
                teamOf: _teamOf,
                isLeader: _isLeader,
                onChanged: () => _refresh(code),
              ),
              const SizedBox(height: 16),
            ],

            const Text(
              'اللاعبون',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),

            if (players.isEmpty)
              const Text('لاعب واحد (أنت). إن لم يظهر، حدّث/شّرف من جهاز آخر.')
            else if (_startedAt == null)
              const Text('اختر الفائز بعد بدء العداد.', style: TextStyle(color: Colors.white70))
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
                children: players.map((p) {
                  final user = p['user'] as Map<String, dynamic>?;
                  final name = user?['displayName']?.toString() ??
                      user?['email']?.toString() ??
                      p['userId']?.toString() ??
                      '—';
                  final uid = p['userId']?.toString() ?? '';
                  final selected = _winnerUserId == uid;

                  final team = _teamOf[uid] ?? '';
                  final pearls = _pearlsByUser[uid] ?? 0;
                  final leader = _isLeader[uid] == true;

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
                        if (leader) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.star, size: 16, color: Colors.amber),
                        ],
                      ],
                    ),
                    onSelected: (_) =>
                        setState(() => _winnerUserId = uid),
                  );
                }).toList(),
              ),

            const SizedBox(height: 12),

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
                        if (players.length < 2) {
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
                            winners = players
                                .map((p) => p['userId']?.toString() ?? '')
                                .where((uid) => uid.isNotEmpty && (_teamOf[uid] ?? '') == _winnerTeam)
                                .toList();
                            losers = players
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
                            losers = players
                                .map((p) => p['userId']?.toString() ?? '')
                                .where((uid) => uid.isNotEmpty && uid != _winnerUserId)
                                .toList();
                            winnerName = _nameForUser(_winnerUserId!);
                          }

                          final loserNames = losers.map(_nameForUser).join('، ');
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
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
                          );
                          if (confirm != true) return;

                          await ApiRoom.submitResult(
                            code: codeSafe,
                            winners: winners,
                            losers: losers,
                            token: widget.app.token,
                          );

                          _msg('أُرسلت النتيجة — بانتظار موافقة الجميع');
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

/* -------------------------- Helper Widgets -------------------------- */

class _TeamQuorumCard extends StatelessWidget {
  final Map<String, dynamic> teamQuorum;
  const _TeamQuorumCard({required this.teamQuorum});

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? qa = teamQuorum['A'] as Map<String, dynamic>?;
    Map<String, dynamic>? qb = teamQuorum['B'] as Map<String, dynamic>?;
    qa ??= const {};
    qb ??= const {};
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'حالة النصاب (اللآلئ)',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            _row(
              'الفريق A',
              'مطلوب: ${qa['required'] ?? 0} — متاح: ${qa['available'] ?? 0} — ${_ok(qa['quorumMet'])}',
            ),
            const SizedBox(height: 4),
            _row(
              'الفريق B',
              'مطلوب: ${qb['required'] ?? 0} — متاح: ${qb['available'] ?? 0} — ${_ok(qb['quorumMet'])}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(title), Text(value)],
    );
  }

  String _ok(Object? b) => (b == true) ? 'مكتمل ✅' : 'غير مكتمل ❌';
}

class _AssignTeamsCard extends StatelessWidget {
  final AppState app;
  final String code;
  final List<Map<String, dynamic>> players;
  final Map<String, String?> teamOf;
  final Map<String, int> pearlsByUser;
  final Map<String, bool> isLeader;
  final VoidCallback onChanged;

  const _AssignTeamsCard({
    required this.app,
    required this.code,
    required this.players,
    required this.teamOf,
    required this.pearlsByUser,
    required this.isLeader,
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
              final leader = isLeader[uid] == true;

              final sel = teamOf[uid];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    _pearlPill(pearls),
                    if (leader) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.star, size: 16, color: Colors.amber),
                    ],
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

class _SetLeaderCard extends StatelessWidget {
  final AppState app;
  final String code;
  final List<Map<String, dynamic>> players;
  final Map<String, String?> teamOf;
  final Map<String, bool> isLeader;
  final VoidCallback onChanged;

  const _SetLeaderCard({
    required this.app,
    required this.code,
    required this.players,
    required this.teamOf,
    required this.isLeader,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final teamA = players
        .where((p) => teamOf[(p['userId'] ?? '').toString()] == 'A')
        .toList();
    final teamB = players
        .where((p) => teamOf[(p['userId'] ?? '').toString()] == 'B')
        .toList();

    final currentLeaderA = teamA.firstWhere(
          (p) => isLeader[(p['userId'] ?? '').toString()] == true,
      orElse: () => {},
    );
    final currentLeaderB = teamB.firstWhere(
          (p) => isLeader[(p['userId'] ?? '').toString()] == true,
      orElse: () => {},
    );

    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.all(12),
        title: const Text(
          'تعيين القادة (اضغط للفتح)',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        children: [
          _LeaderPickerRow(
            teamLabel: 'الفريق A',
            team: 'A',
            code: code,
            app: app,
            players: teamA,
            currentLeaderUserId:
                (currentLeaderA.isNotEmpty) ? currentLeaderA['userId']?.toString() : null,
            onChanged: onChanged,
          ),
          const SizedBox(height: 10),
          _LeaderPickerRow(
            teamLabel: 'الفريق B',
            team: 'B',
            code: code,
            app: app,
            players: teamB,
            currentLeaderUserId:
                (currentLeaderB.isNotEmpty) ? currentLeaderB['userId']?.toString() : null,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _LeaderPickerRow extends StatefulWidget {
  final String teamLabel;
  final String team;
  final String code;
  final AppState app;
  final List<Map<String, dynamic>> players;
  final String? currentLeaderUserId;
  final VoidCallback onChanged;

  const _LeaderPickerRow({
    required this.teamLabel,
    required this.team,
    required this.code,
    required this.app,
    required this.players,
    required this.currentLeaderUserId,
    required this.onChanged,
  });

  @override
  State<_LeaderPickerRow> createState() => _LeaderPickerRowState();
}

class _LeaderPickerRowState extends State<_LeaderPickerRow> {
  String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentLeaderUserId;
  }

  @override
  void didUpdateWidget(covariant _LeaderPickerRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentLeaderUserId != widget.currentLeaderUserId) {
      setState(() => _selected = widget.currentLeaderUserId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.players.map((p) {
      final user = p['user'] as Map<String, dynamic>?;
      final name = user?['displayName']?.toString() ??
          user?['email']?.toString() ??
          p['userId'].toString();
      final uid = (p['userId'] ?? '').toString();
      return DropdownMenuItem<String>(
        value: uid,
        child: Text(name, overflow: TextOverflow.ellipsis),
      );
    }).toList();

    return Row(
      children: [
        Expanded(
          child: Text(
            widget.teamLabel,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: widget.team == 'A' ? Colors.blue.shade700 : Colors.red.shade700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _selected,
            hint: const Text('اختر القائد'),
            items: items,
            onChanged: (val) async {
              if (val == null) return;
              try {
                await ApiRoom.setTeamLeader(
                  code: widget.code,
                  team: widget.team,
                  leaderUserId: val,
                  token: widget.app.token,
                );
                if (!mounted) return;
                setState(() => _selected = val);
                widget.onChanged();
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Leader error: $e')),
                );
              }
            },
          ),
        ),
      ],
    );
  }
}

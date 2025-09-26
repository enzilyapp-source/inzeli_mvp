import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../state.dart';
import '../api_room.dart';
import '../api_matches.dart';

class MatchPage extends StatefulWidget {
  final AppState app;
  final Map<String, dynamic>? room; // { code, gameId, players [{user:{id,displayName,email}, userId,..}], hostUserId, ... }
  const MatchPage({super.key, required this.app, this.room});

  @override
  State<MatchPage> createState() => _MatchPageState();
}

class _MatchPageState extends State<MatchPage> {
  final _codeCtrl = TextEditingController();
  List<Map<String, dynamic>> players = [];
  bool loading = false;

  // إعدادات قبل البدء
  int _target = 10;
  int _myPoints = 0;

  // اختيار فائز
  String? _winnerUserId;

  // مؤقّت
  Timer? _ticker;
  int _remaining = 0;
  DateTime? _startedAt;
  int? _timerSec;

  @override
  void initState() {
    super.initState();
    final initial = widget.room?['players'];
    if (initial is List) players = initial.cast<Map<String, dynamic>>();
    final code = (widget.room?['code'] ?? widget.app.roomCode ?? '').toString();
    if (code.isNotEmpty) _refresh(code);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh(String code) async {
    setState(() => loading = true);
    try {
      final room = await ApiRoom.getRoomByCode(code, token: widget.app.token);
      final p = room['players'];
      if (p is List) players = p.cast<Map<String, dynamic>>();
      _timerSec  = (room['timerSec'] as num?)?.toInt();
      final s    = room['startedAt'] as String?;
      _startedAt = s != null ? DateTime.tryParse(s) : null;
      _startTickerIfNeeded();
    } finally {
      setState(() => loading = false);
    }
  }

  void _startTickerIfNeeded() {
    _ticker?.cancel();
    if (_startedAt == null || _timerSec == null) { setState(() => _remaining = 0); return; }
    void _tick() {
      final elapsed = DateTime.now().difference(_startedAt!).inSeconds;
      final remain  = _timerSec! - elapsed;
      setState(() => _remaining = remain.clamp(0, 1 << 30));
      if (_remaining <= 0) _ticker?.cancel();
    }
    _tick();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _msg(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  String _fmt(int s) { final m = (s ~/ 60).toString().padLeft(2,'0'); final ss = (s % 60).toString().padLeft(2,'0'); return '$m:$ss'; }

  @override
  Widget build(BuildContext context) {
    final code = (widget.room?['code'] ?? widget.app.roomCode ?? '').toString();
    final game = (widget.room?['gameId'] ?? widget.app.selectedGame ?? 'لعبة').toString();
    final hostId = widget.room?['hostUserId']?.toString();
    final isHost = widget.app.userId != null && hostId == widget.app.userId;
    final httpsLink = code.isEmpty ? '' : 'https://inzeli.app/join/$code';
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(title: Text('مباراة $game — كود: ${code.isEmpty ? "—" : code}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (code.isNotEmpty) ...[
            Center(child: QrImageView(data: httpsLink, size: 220, backgroundColor: Colors.white)),
            const SizedBox(height: 8),
            SelectableText('كود الروم: $code', textAlign: TextAlign.center),
          ],

          const SizedBox(height: 16),
          if (_timerSec != null && _startedAt != null) ...[
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.timer_outlined), const SizedBox(width: 6),
              Text(_fmt(_remaining), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ]),
            const SizedBox(height: 8),
          ],

          // إعدادات قبل البدء + نقاط للعب
          if (code.isNotEmpty) Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('إعدادات قبل البدء', style: TextStyle(fontWeight: FontWeight.w900, color: onSurface)),
                const SizedBox(height: 8),
                Row(children: [
                  const Text('الهدف:'), const SizedBox(width: 8),
                  Expanded(child: Slider(value: _target.toDouble(), min: 1, max: 50, divisions: 49, label: '$_target',
                      onChanged: isHost ? (v) => setState(() => _target = v.toInt()) : null)),
                  Text('$_target'),
                ]),
                Row(children: [
                  const Text('نقاطي للعب:'), const SizedBox(width: 8),
                  SizedBox(width: 100, child: TextField(decoration: const InputDecoration(hintText: '0'),
                      keyboardType: TextInputType.number, onChanged: (v) => _myPoints = int.tryParse(v) ?? 0)),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () async {
                      if (code.isEmpty) return;
                      try {
                        await ApiRoom.setStake(code: code, amount: _myPoints, token: widget.app.token);
                        _msg('تم تأكيد النقاط');
                        _refresh(code);
                      } catch (e) { _msg('خطأ: $e'); }
                    },
                    child: const Text('تأكيد النقاط'),
                  ),
                  const Spacer(),
                  if (isHost) FilledButton(
                    onPressed: () async {
                      try {
                        final data = await ApiRoom.startRoom(
                          code: code, token: widget.app.token,
                          targetWinPoints: _target, allowZeroCredit: true, timerSec: 600,
                        );
                        _timerSec  = (data['timerSec'] as num?)?.toInt();
                        final s    = data['startedAt'] as String?;
                        _startedAt = s != null ? DateTime.tryParse(s) : null;
                        _startTickerIfNeeded();
                        _msg('انزلي — بدأنا!');
                        _refresh(code);
                      } catch (e) { _msg('خطأ البدء: $e'); }
                    },
                    child: const Text('انزلي'),
                  ),
                ]),
              ]),
            ),
          ),

          const SizedBox(height: 16),

          // اللاعبون (بالأسماء) + اختيار فائز
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('اللاعبون', style: TextStyle(fontWeight: FontWeight.w900)),
            Row(children: [
              if (loading) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 8), Chip(label: Text('${players.length} لاعب')),
            ]),
          ]),
          const SizedBox(height: 6),

          if (players.isEmpty)
            const Text('لاعب واحد (أنت). إن لم يظهر، حدّث/انضم من جهاز آخر.')
          else
            Wrap(spacing: 6, children: players.map((p) {
              final user = p['user'] as Map<String, dynamic>?;
              final name = user?['displayName']?.toString()
                  ?? user?['email']?.toString()
                  ?? p['userId']?.toString()
                  ?? '—';
              final uid  = p['userId']?.toString() ?? '';
              final selected = _winnerUserId == uid;
              return ChoiceChip(
                selected: selected,
                label: Text(name),
                onSelected: (_) => setState(() => _winnerUserId = uid),
              );
            }).toList()),

          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.flag),
            label: const Text('حسم النتيجة'),
            onPressed: () async {
              if (_winnerUserId == null) { _msg('اختاري الفائز أولًا'); return; }
              final losers = players.map((p) => p['userId']?.toString() ?? '')
                  .where((uid) => uid.isNotEmpty && uid != _winnerUserId).toList();
              try {
                await ApiMatches.createMatch(
                  roomCode: code.isEmpty ? null : code,
                  gameId: game,
                  winners: [_winnerUserId!],
                  losers: losers,
                  token: widget.app.token,
                );
                _msg('تم تسجيل النتيجة ✅');
                setState(() => _winnerUserId = null);
                if (code.isNotEmpty) _refresh(code);
              } catch (e) { _msg(e.toString()); }
            },
          ),

          const SizedBox(height: 16),
          const Text('انضم بالكود (اختبار سريع)'),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: TextField(controller: _codeCtrl, decoration: const InputDecoration(labelText: 'اكتب كود الروم'))),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () async {
                final inputCode = _codeCtrl.text.trim().isEmpty ? code : _codeCtrl.text.trim();
                if (inputCode.isEmpty) { _msg('اكتب الكود'); return; }
                if (!widget.app.isSignedIn) { _msg('سجّل دخول أول'); return; }
                try {
                  await ApiRoom.joinByCode(code: inputCode, userId: widget.app.userId!, token: widget.app.token);
                  _msg('Joined ✅'); _refresh(inputCode);
                } catch (e) { _msg('خطأ: $e'); }
              },
              child: const Text('انضم'),
            ),
          ]),
        ],
      ),
    );
  }
}

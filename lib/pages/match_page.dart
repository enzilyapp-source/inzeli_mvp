import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../state.dart';
import '../api_room.dart';
import '../api_matches.dart';

class MatchPage extends StatefulWidget {
  final AppState app;
  final Map<String, dynamic>? room;
  const MatchPage({super.key, required this.app, this.room});

  @override
  State<MatchPage> createState() => _MatchPageState();
}

class _MatchPageState extends State<MatchPage> {
  final _codeCtrl = TextEditingController();
  List<Map<String, dynamic>> players = [];
  String? _winnerUserId;

  Timer? _ticker;
  int _remaining = 0;
  DateTime? _startedAt;
  int? _timerSec;

  // NEW: per-round units 1/2/3
  int _units = 1;

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
    final room = await ApiRoom.getRoomByCode(code, token: widget.app.token);
    final p = room['players'];
    if (p is List) players = p.cast<Map<String, dynamic>>();
    _timerSec  = (room['timerSec'] as num?)?.toInt();
    final s    = room['startedAt'] as String?;
    _startedAt = s != null ? DateTime.tryParse(s) : null;
    _startTickerIfNeeded();
    setState(() {});
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

  bool get _locked => _startedAt != null && _timerSec != null && _remaining > 0;

  void _msg(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  String _fmt(int s) { final m = (s ~/ 60).toString().padLeft(2,'0'); final ss = (s % 60).toString().padLeft(2,'0'); return '$m:$ss'; }

  @override
  Widget build(BuildContext context) {
    final code = (widget.room?['code'] ?? widget.app.roomCode ?? '').toString();
    final game = (widget.room?['gameId'] ?? widget.app.selectedGame ?? 'لعبة').toString();
    final hostId = widget.room?['hostUserId']?.toString();
    final isHost = widget.app.userId != null && hostId == widget.app.userId;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(title: Text('مباراة $game — كود: ${code.isEmpty ? "—" : code}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (code.isNotEmpty) ...[
            Center(child: QrImageView(data: 'https://inzeli.app/join/$code', size: 220, backgroundColor: Colors.white)),
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

          // ===== NEW: per-round unit selection (1/2/3) =====
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('اختَر قيمة الجولة', style: TextStyle(fontWeight: FontWeight.w900, color: onSurface)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [1,2,3].map((n) {
                    final sel = _units == n;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: ChoiceChip(
                        selected: sel,
                        label: Text('$n', style: const TextStyle(fontWeight: FontWeight.bold)),
                        onSelected: (_) => setState(() => _units = n),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Text('الجولة الحالية = $_units نقطة', textAlign: TextAlign.center),
                if (_locked) ...[
                  const SizedBox(height: 6),
                  const Text('مقفلة حتى ينتهي العداد', textAlign: TextAlign.center, style: TextStyle(color: Colors.red)),
                ],
                if (isHost) ...[
                  const SizedBox(height: 10),
                  FilledButton(
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
                        _timerSec  = (data['timerSec'] as num?)?.toInt();
                        final s    = data['startedAt'] as String?;
                        _startedAt = s != null ? DateTime.tryParse(s) : null;
                        _startTickerIfNeeded();
                        _msg('بدأت الجولة ⏱️');
                        _refresh(code);
                      } catch (e) { _msg('خطأ البدء: $e'); }
                    },
                    child: const Text('بدء عدّاد'),
                  ),
                ],
              ]),
            ),
          ),

          const SizedBox(height: 16),

          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('اللاعبون', style: TextStyle(fontWeight: FontWeight.w900)),
            Chip(label: Text('${players.length} لاعب')),
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
            label: Text(_locked ? 'مقفلة حتى ينتهي العداد' : 'حسم النتيجة (+$_units/-$_units)'),
            onPressed: _locked ? null : () async {
              if (_winnerUserId == null) { _msg('اختار الفائز أولًا'); return; }
              final losers = players.map((p) => p['userId']?.toString() ?? '')
                  .where((uid) => uid.isNotEmpty && uid != _winnerUserId).toList();
              try {
                await ApiMatches.createMatch(
                  roomCode: code.isEmpty ? null : code,
                  gameId: game,
                  winners: [_winnerUserId!],
                  losers: losers,
                  stakeUnits: _units,
                  token: widget.app.token,
                );
                _msg('تم تسجيل الجولة ✅ (+$_units للفائز / -$_units للخاسر)');
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
//match_page.dart
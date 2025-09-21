import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../state.dart';
import '../api_room.dart';

class MatchPage extends StatefulWidget {
  final AppState app;
  final Map<String, dynamic>? room; // { code, gameId, players, hostUserId, ... }
  const MatchPage({super.key, required this.app, this.room});

  @override
  State<MatchPage> createState() => _MatchPageState();
}

class _MatchPageState extends State<MatchPage> {
  final _codeCtrl = TextEditingController();
  List<Map<String, dynamic>> players = [];
  bool loading = false;

  int _target = 10;
  int _myStake = 0;

  @override
  void initState() {
    super.initState();
    final initial = widget.room?['players'];
    if (initial is List) players = initial.cast<Map<String, dynamic>>();
    final code = (widget.room?['code'] ?? widget.app.roomCode ?? '').toString();
    if (code.isNotEmpty) _refresh(code);
  }

  @override
  void dispose() { _codeCtrl.dispose(); super.dispose(); }

  Future<void> _refresh(String code) async {
    setState(() => loading = true);
    try {
      final fresh = await ApiRoom.getPlayers(code, token: widget.app.token);
      setState(() => players = fresh);
    } finally {
      setState(() => loading = false);
    }
  }

  void _msg(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

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
          ] else
            const Text('لا يوجد كود — ارجع وأنشئ روم من “انزلي”.'),

          const SizedBox(height: 16),

          // إعدادات قبل البدء +
          if (code.isNotEmpty) Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('إعدادات قبل البدء', style: TextStyle(fontWeight: FontWeight.w900, color: onSurface)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('الهدف:'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Slider(
                          value: _target.toDouble(),
                          min: 1, max: 50, divisions: 49,
                          label: '$_target',
                          onChanged: isHost ? (v) => setState(() => _target = v.toInt()) : null,
                        ),
                      ),
                      Text('$_target'),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('نقاط اللعب:'),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          decoration: const InputDecoration(hintText: '0'),
                          keyboardType: TextInputType.number,
                          onChanged: (v) => _myStake = int.tryParse(v) ?? 0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () async {
                          if (code.isEmpty) return;
                          try {
                            await ApiRoom.setStake(code: code, amount: _myStake, token: widget.app.token);
                            _msg('تم حجز النقاط ');
                            _refresh(code);
                          } catch (e) { _msg('خطأ النقاط: $e'); }
                        },
                        child: const Text('حجز'),
                      ),
                      const Spacer(),
                      if (isHost) FilledButton(
                        onPressed: () async {
                          try {
                            await ApiRoom.startRoom(
                              code: code,
                              token: widget.app.token,
                              targetWinPoints: _target,
                              allowZeroCredit: true,
                            );
                            _msg('انزلي — بدأنا!');
                            _refresh(code);
                          } catch (e) { _msg('خطأ البدء: $e'); }
                        },
                        child: const Text('انزلي'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // عنوان وعدّاد اللاعبين
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('اللاعبون', style: TextStyle(fontWeight: FontWeight.w900)),
              Row(children: [
                if (loading) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 8),
                Chip(label: Text('${players.length} لاعب')),
              ]),
            ],
          ),
          const SizedBox(height: 6),

          if (players.isEmpty)
            const Text('لاعب واحد (أنت) — إن لم يظهر، حدّث/انضم من جهاز آخر.')
          else
            Wrap(
              spacing: 6,
              children: players.map((p) {
                final uid = p['userId']?.toString() ?? '—';
                return Chip(label: Text(uid));
              }).toList(),
            ),

          const SizedBox(height: 16),
          const Text('انضم بالكود (اختبار بدون سكان)'),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: TextField(controller: _codeCtrl, decoration: const InputDecoration(labelText: 'اكتب كود الروم'))),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () async {
                  final inputCode = _codeCtrl.text.trim().isEmpty ? code : _codeCtrl.text.trim();
                  if (inputCode.isEmpty) { _msg('اكتب الكود'); return; }
                  if (!widget.app.isSignedIn) { _msg('سجّل دخول أول'); return; }
                  try {
                    await ApiRoom.joinByCode(code: inputCode, userId: widget.app.userId!, token: widget.app.token);
                    _msg('Joined ✅');
                    _refresh(inputCode);
                  } catch (e) { _msg('خطأ: $e'); }
                },
                child: const Text('انضم'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

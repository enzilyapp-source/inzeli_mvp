import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../state.dart';
import '../api_room.dart';

class MatchPage extends StatefulWidget {
  final AppState app;
  final Map<String, dynamic>? room; // { code, gameId, players:[{userId, joinedAt}], ... }
  const MatchPage({super.key, required this.app, this.room});

  @override
  State<MatchPage> createState() => _MatchPageState();
}

class _MatchPageState extends State<MatchPage> {
  final _codeCtrl = TextEditingController();
  List<Map<String, dynamic>> players = [];
  bool loading = false;

  @override
  void initState() {
    super.initState();

    // 1) اعرض الـ host فورًا إن كان موجود في نتيجة الإنشاء
    final initial = widget.room?['players'];
    if (initial is List) {
      players = initial.cast<Map<String, dynamic>>();
    }

    // 2) انعش من السيرفر
    final code = (widget.room?['code'] ?? widget.app.roomCode ?? '').toString();
    if (code.isNotEmpty) {
      _refresh(code);
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh(String code) async {
    setState(() => loading = true);
    try {
      final fresh = await getPlayers(code, token: widget.app.token);
      setState(() => players = fresh);
    } catch (_) {
      // ممكن تعرضي رسالة خطأ هنا
    } finally {
      setState(() => loading = false);
    }
  }

  void _msg(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final code = (widget.room?['code'] ?? widget.app.roomCode ?? '').toString();
    final game = (widget.room?['gameId'] ?? widget.app.selectedGame ?? 'لعبة').toString();
    final httpsLink = code.isEmpty ? '' : 'https://inzeli.app/join/$code';

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

          // عنوان وعدّاد اللاعبين
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('اللاعبون', style: TextStyle(fontWeight: FontWeight.w900)),
              Row(children: [
                if (loading)
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 8),
                Chip(label: Text('${players.length} لاعب')),
              ]),
            ],
          ),
          const SizedBox(height: 6),

          // قائمة اللاعبين
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
                    await joinByCode(code: inputCode, userId: widget.app.userId!, token: widget.app.token);
                    _msg('Joined ✅');
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
    );
  }
}

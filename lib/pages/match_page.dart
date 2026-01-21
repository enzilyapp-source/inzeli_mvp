// lib/pages/match_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../state.dart';
import '../api_room.dart';
import '../api_matches.dart';

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
  final _codeCtrl = TextEditingController();

  List<Map<String, dynamic>> players = [];
  final Map<String, int> _pearlsByUser = {};
  final Map<String, String?> _teamOf = {};
  final Map<String, bool> _isLeader = {};
  Map<String, dynamic>? _teamQuorum;

  String? _winnerUserId;

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

  void _msg(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

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
  bool get _locked => false;

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

  Future<void> _refresh(String code) async {
    try {
      final room = await ApiRoom.getRoomByCode(code, token: widget.app.token);

      final p = room['players'];
      if (p is List) players = p.cast<Map<String, dynamic>>();

      _pearlsByUser.clear();
      _teamOf.clear();
      _isLeader.clear();

      final gameId = (room['gameId'] ?? widget.app.selectedGame ?? '').toString();

      for (final rp in players) {
        final uid = (rp['userId'] ?? '').toString();
        final user = rp['user'] as Map<String, dynamic>?;
        int pearls = (user?['permanentScore'] as num?)?.toInt() ?? 5; // fallback 5

        // استخدم رصيد اللؤلؤ لكل لعبة للحساب الحالي (لصاحب الحساب فقط)
        if (uid == widget.app.userId && gameId.isNotEmpty) {
          pearls = widget.app.pearlsForGame(gameId);
        }

        // لو ما في بيانات، اعتبر 5 لؤلؤ لكل لاعب جديد
        if (pearls <= 0) pearls = 5;

        _pearlsByUser[uid] = pearls;

        final team = rp['team']?.toString();
        _teamOf[uid] = (team == 'A' || team == 'B') ? team : null;

        final leader = (rp['isLeader'] == true);
        _isLeader[uid] = leader;
      }

      _teamQuorum = room['teamQuorum'] as Map<String, dynamic>?;

      _timerSec = (room['timerSec'] as num?)?.toInt();
      final s = room['startedAt'] as String?;
      _startedAt = s != null ? DateTime.tryParse(s) : null;
      _startTickerIfNeeded();

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

    final hostId = widget.room?['hostUserId']?.toString();
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

            if (isHost) ...[
              Align(
                alignment: Alignment.center,
                child: FilledButton.icon(
                  icon: const Icon(Icons.play_circle_outline),
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
                      _timerSec = (data['timerSec'] as num?)?.toInt();
                      final s = data['startedAt'] as String?;
                      _startedAt =
                      s != null ? DateTime.tryParse(s) : null;
                      _startTickerIfNeeded();
                      _msg('بدأت الجولة ⏱️');
                      _refresh(code);
                    } catch (e) {
                      _msg('خطأ البدء: $e');
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (_teamQuorum != null) ...[
              _TeamQuorumCard(teamQuorum: _teamQuorum!),
              const SizedBox(height: 16),
            ],

            if (isHost) ...[
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

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'اللاعبون',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                Chip(label: Text('${players.length} لاعب')),
              ],
            ),
            const SizedBox(height: 6),

            if (players.isEmpty)
              const Text('لاعب واحد (أنت). إن لم يظهر، حدّث/انضم من جهاز آخر.')
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

                  final team = (_teamOf[uid] ?? '') ?? '';
                  final pearls = _pearlsByUser[uid] ?? 0;
                  final leader = _isLeader[uid] == true;

                  final labelParts = <String>[
                    name,
                    if (team.isNotEmpty) '($team)',
                    '$pearls 💎',
                    if (leader) '⭐',
                  ];
                  final labelText = labelParts.join(' ');

                  return ChoiceChip(
                    selected: selected,
                    label: Text(labelText),
                    onSelected: (_) =>
                        setState(() => _winnerUserId = uid),
                  );
                }).toList(),
              ),

            const SizedBox(height: 12),

            FilledButton.icon(
              icon: const Icon(Icons.flag),
              label: const Text('حسم النتيجة (نقل لؤلؤة واحدة)'),
              onPressed: _locked || !isHost
                  ? () => _msg('الحسم للمضيف فقط')
                  : () async {
                    final codeSafe = code;
                    if (_winnerUserId == null) {
                      _msg('اختَر الفائز أولًا');
                      return;
                    }
                    if (players.length < 2) {
                      _msg('لا يمكن حسم النتيجة بلاعب واحد');
                      return;
                    }

                    final losers = players
                        .map((p) => p['userId']?.toString() ?? '')
                        .where((uid) => uid.isNotEmpty && uid != _winnerUserId)
                        .toList();

                    final zeroPearlPlayers = losers
                        .where((uid) => (_pearlsByUser[uid] ?? 0) <= 0)
                        .map(_nameForUser)
                        .toList();

                    final winnerName = _nameForUser(_winnerUserId!);
                    final loserNames = losers.map(_nameForUser).join('، ');

                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('تأكيد النتيجة'),
                        content: Text([
                          'الفائز: $winnerName',
                          'الخاسرون: $loserNames',
                          if (zeroPearlPlayers.isNotEmpty)
                            'تنبيه: ${zeroPearlPlayers.join("، ")} رصيده 0 لؤلؤة — لن يُخصم منه شيء إن خسر.'
                        ].join('\n')),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('إلغاء'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('تأكيد'),
                          ),
                        ],
                      ),
                    );
                    if (confirm != true) return;

                    try {
                      await ApiMatches.createMatch(
                        roomCode: codeSafe.isEmpty ? null : codeSafe,
                        gameId: game,
                        winners: [_winnerUserId!],
                        losers: losers,
                        token: widget.app.token,
                        sponsorCode: sponsorCode,
                      );

                      widget.app.addLocalMatch(
                        game: game,
                        roomCode: codeSafe,
                        winner: winnerName,
                        losers: loserNames.isEmpty ? const [] : loserNames.split('، ').where((e) => e.isNotEmpty).toList(),
                      );

                      // حدّث اللآلئ لجميع اللاعبين محليًا (عرض)
                      _pearlsByUser[_winnerUserId!] = (_pearlsByUser[_winnerUserId!] ?? 0) +
                          losers.where((uid) => (_pearlsByUser[uid] ?? 0) > 0).length;
                      for (final uid in losers) {
                        final cur = _pearlsByUser[uid] ?? 0;
                        if (cur > 0) _pearlsByUser[uid] = cur - 1;
                      }

                      // تحديث رصيد اللآلئ المحلي لصاحب الحساب فقط
                      final myId = widget.app.userId;
                      if (myId != null && myId.isNotEmpty) {
                        if (myId == _winnerUserId) {
                          // اربح لؤلؤة لكل خاسر يملك لؤلؤة > 0
                          final gain = losers.where((uid) => (_pearlsByUser[uid] ?? 0) > 0).length;
                          if (gain > 0) widget.app.grantPearlsForGame(game, gain);
                        } else if (losers.contains(myId)) {
                          if ((widget.app.pearlsForGame(game)) > 0) {
                            widget.app.spendPearlForGame(game);
                          }
                        }
                      }

                      _msg('تم النقل: كل خاسر -1 لؤلؤة، توزيعها على الفائز');
                      setState(() => _winnerUserId = null);
                      if (codeSafe.isNotEmpty) _refresh(codeSafe);

                      await Future.delayed(const Duration(milliseconds: 400));
                      if (mounted) Navigator.pop(context);
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
                FilledButton(
                  onPressed: () async {
                    final inputCode = _codeCtrl.text.trim().isEmpty
                        ? code
                        : _codeCtrl.text.trim();
                    if (inputCode.isEmpty) {
                      _msg('اكتب الكود');
                      return;
                    }
                    if (!widget.app.isSignedIn) {
                      _msg('سجّل دخول أول');
                      return;
                    }
                    try {
                      await ApiRoom.joinByCode(
                        code: inputCode,
                        token: widget.app.token,
                      );
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
      ),
    );
  }
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
                    Expanded(
                      child: Text(
                        '$name — $pearls 💎 ${leader ? "⭐" : ""}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'A', label: Text('A')),
                        ButtonSegment(value: 'B', label: Text('B')),
                        ButtonSegment(value: 'NONE', label: Text('—')),
                      ],
                      selected: {sel ?? 'NONE'},
                      onSelectionChanged: (set) async {
                        final value = set.first;
                        try {
                          if (value == 'NONE') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'حالياً يمكن التعيين إلى A أو B فقط'),
                              ),
                            );
                          } else {
                            await ApiRoom.setPlayerTeam(
                              code: code,
                              playerUserId: uid,
                              team: value,
                              token: app.token,
                            );
                            onChanged();
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Team error: $e')),
                          );
                        }
                      },
                    ),
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
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'تعيين القادة (للمضيف فقط)',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            _LeaderPickerRow(
              teamLabel: 'الفريق A',
              team: 'A',
              code: code,
              app: app,
              players: teamA,
              currentLeaderUserId:
              (currentLeaderA.isNotEmpty)
                  ? currentLeaderA['userId']?.toString()
                  : null,
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
              (currentLeaderB.isNotEmpty)
                  ? currentLeaderB['userId']?.toString()
                  : null,
              onChanged: onChanged,
            ),
          ],
        ),
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
            style: const TextStyle(fontWeight: FontWeight.w700),
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
                setState(() => _selected = val);
                widget.onChanged();
              } catch (e) {
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

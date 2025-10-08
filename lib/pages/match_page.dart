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

  // Room snapshot
  List<Map<String, dynamic>> players = [];
  Map<String, int> _pearlsByUser = {};        // uid -> permanentScore (pearls)
  Map<String, String?> _teamOf = {};          // uid -> 'A' | 'B' | null
  Map<String, bool> _isLeader = {};           // uid -> true/false
  Map<String, dynamic>? _teamQuorum;          // {A:{required,available,quorumMet}, B:{...}}

  // Winner selection
  String? _winnerUserId;

  // Timer lock
  Timer? _ticker;
  int _remaining = 0;
  DateTime? _startedAt;
  int? _timerSec;

  // Per-round stake units 1/2/3
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

  void _msg(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  String _fmt(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$m:$ss';
  }

  bool get _locked =>
      _startedAt != null && _timerSec != null && (_remaining > 0);

  void _startTickerIfNeeded() {
    _ticker?.cancel();
    if (_startedAt == null || _timerSec == null) {
      setState(() => _remaining = 0);
      return;
    }
    void _tick() {
      final elapsed = DateTime.now().difference(_startedAt!).inSeconds;
      final remain = _timerSec! - elapsed;
      setState(() => _remaining = remain.clamp(0, 1 << 30));
      if (_remaining <= 0) _ticker?.cancel();
    }
    _tick();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  Future<void> _refresh(String code) async {
    try {
      final room =
      await ApiRoom.getRoomByCode(code, token: widget.app.token);

      // core fields
      final p = room['players'];
      if (p is List) players = p.cast<Map<String, dynamic>>();

      // pearls = permanentScore from nested user
      _pearlsByUser.clear();
      _teamOf.clear();
      _isLeader.clear();

      for (final rp in players) {
        final uid = (rp['userId'] ?? '').toString();
        final user = rp['user'] as Map<String, dynamic>?;
        final pearls = (user?['permanentScore'] as num?)?.toInt() ?? 0;
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
    final code =
    (widget.room?['code'] ?? widget.app.roomCode ?? '').toString();
    final game =
    (widget.room?['gameId'] ?? widget.app.selectedGame ?? 'لعبة')
        .toString();
    final hostId = widget.room?['hostUserId']?.toString();
    final isHost =
        widget.app.userId != null && hostId == widget.app.userId;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar:
      AppBar(title: Text('مباراة $game — كود: ${code.isEmpty ? "—" : code}')),
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

            // Timer / lock
            const SizedBox(height: 12),
            if (_timerSec != null && _startedAt != null) ...[
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.timer_outlined),
                const SizedBox(width: 6),
                Text(_fmt(_remaining),
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 16)),
              ]),
              const SizedBox(height: 8),
            ],

            // Round stake units
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('اختَر قيمة الجولة',
                          style: TextStyle(
                              fontWeight: FontWeight.w900, color: onSurface)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [1, 2, 3].map((n) {
                          final sel = _units == n;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: ChoiceChip(
                              selected: sel,
                              label: Text('$n',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              onSelected: (_) =>
                                  setState(() => _units = n),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                      Text('الجولة الحالية = $_units نقطة',
                          textAlign: TextAlign.center),
                      if (_locked) ...[
                        const SizedBox(height: 6),
                        const Text('مقفلة حتى ينتهي العداد',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.red)),
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
                          child: const Text('بدء عدّاد'),
                        ),
                      ],
                    ]),
              ),
            ),

            // Team quorum snapshot
            if (_teamQuorum != null) ...[
              const SizedBox(height: 10),
              _TeamQuorumCard(teamQuorum: _teamQuorum!),
            ],

            const SizedBox(height: 16),

            // Host-only: assign teams
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

            // Players list & winner selection
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('اللاعبون',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                  Chip(label: Text('${players.length} لاعب')),
                ]),
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
              label: Text(_locked
                  ? 'مقفلة حتى ينتهي العداد'
                  : 'حسم النتيجة (+$_units/-$_units)'),
              onPressed: _locked
                  ? null
                  : () async {
                final codeSafe = code;
                if (_winnerUserId == null) {
                  _msg('اختار الفائز أولًا');
                  return;
                }
                final losers = players
                    .map((p) => p['userId']?.toString() ?? '')
                    .where((uid) =>
                uid.isNotEmpty && uid != _winnerUserId)
                    .toList();
                try {
                  await ApiMatches.createMatch(
                    roomCode: codeSafe.isEmpty ? null : codeSafe,
                    gameId: game,
                    winners: [_winnerUserId!],
                    losers: losers,
                    stakeUnits: _units,
                    token: widget.app.token,
                  );
                  _msg('تم تسجيل الجولة ✅ (+$_units للفائز / -$_units للخاسر)');
                  setState(() => _winnerUserId = null);
                  if (codeSafe.isNotEmpty) _refresh(codeSafe);
                } catch (e) {
                  _msg(e.toString());
                }
              },
            ),

            const SizedBox(height: 16),
            const Text('انضم بالكود (اختبار سريع)'),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                  child: TextField(
                    controller: _codeCtrl,
                    decoration:
                    const InputDecoration(labelText: 'اكتب كود الروم'),
                  )),
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
                        userId: widget.app.userId!,
                        token: widget.app.token);
                    _msg('Joined ✅');
                    _refresh(inputCode);
                  } catch (e) {
                    _msg('خطأ: $e');
                  }
                },
                child: const Text('انضم'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

/* -------------------------- UI helper widgets -------------------------- */

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
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('حالة النصاب (اللآلئ)',
              style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          _row('الفريق A',
              'مطلوب: ${qa['required'] ?? 0} — متاح: ${qa['available'] ?? 0} — ${_ok(qa['quorumMet'])}'),
          const SizedBox(height: 4),
          _row('الفريق B',
              'مطلوب: ${qb['required'] ?? 0} — متاح: ${qb['available'] ?? 0} — ${_ok(qb['quorumMet'])}'),
        ]),
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('توزيع الفرق (للمضيف فقط)',
              style: TextStyle(fontWeight: FontWeight.w900, color: onSurface)),
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
                          // set to no team? we’ll map to A/B null by setting neither:
                          // simple approach: set to A then immediately undo? Better:
                          // provide backend with 'A'|'B' only; to clear, assign B then A?
                          // Simpler UX: keep only A/B; NONE just shows not assigned.
                          // We’ll treat NONE as "A" toggled off -> send team A then ask user to move.
                          // If you want true unassign, add an endpoint to clear team.
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('حالياً يمكن التعيين إلى A أو B فقط'),
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
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text('Team error: $e')));
                      }
                    },
                  ),
                ],
              ),
            );
          }),
        ]),
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('تعيين القادة (للمضيف فقط)',
              style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),

          // Team A leader
          _LeaderPickerRow(
            teamLabel: 'الفريق A',
            team: 'A',
            code: code,
            app: app,
            players: teamA,
            currentLeaderUserId:
            (currentLeaderA is Map && currentLeaderA.isNotEmpty)
                ? currentLeaderA['userId']?.toString()
                : null,
            onChanged: onChanged,
          ),
          const SizedBox(height: 10),

          // Team B leader
          _LeaderPickerRow(
            teamLabel: 'الفريق B',
            team: 'B',
            code: code,
            app: app,
            players: teamB,
            currentLeaderUserId:
            (currentLeaderB is Map && currentLeaderB.isNotEmpty)
                ? currentLeaderB['userId']?.toString()
                : null,
            onChanged: onChanged,
          ),
        ]),
      ),
    );
  }
}

class _LeaderPickerRow extends StatefulWidget {
  final String teamLabel;
  final String team; // 'A' or 'B'
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
      final name =
          user?['displayName']?.toString() ?? user?['email']?.toString() ?? p['userId'].toString();
      final uid = (p['userId'] ?? '').toString();
      return DropdownMenuItem<String>(
        value: uid,
        child: Text(name, overflow: TextOverflow.ellipsis),
      );
    }).toList();

    return Row(
      children: [
        Expanded(
          child: Text(widget.teamLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            value: _selected,
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
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('Leader error: $e')));
              }
            },
          ),
        ),
      ],
    );
  }
}

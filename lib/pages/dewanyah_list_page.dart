import 'package:flutter/material.dart';
import '../api_dewanyah.dart';
import '../api_room.dart';
import '../state.dart';
import 'match_page.dart';
import '../sfx.dart';
import 'package:geolocator/geolocator.dart';

class DewanyahListPage extends StatefulWidget {
  final AppState app;
  const DewanyahListPage({super.key, required this.app});

  @override
  State<DewanyahListPage> createState() => _DewanyahListPageState();
}

class _DewanyahListPageState extends State<DewanyahListPage> {
  late Future<List<Map<String, dynamic>>> _future;
  final Map<String, bool> _membershipCache = {};
  final Map<String, String> _selectedGameByDew = {};

  @override
  void initState() {
    super.initState();
    _future = ApiDewanyah.listAll();
  }

  Future<void> _refresh() async {
    setState(() {
      _membershipCache.clear();
      _future = ApiDewanyah.listAll();
    });
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

  Future<void> _join(Map<String, dynamic> dew) async {
    if (!widget.app.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('سجّل الدخول أولاً')));
      return;
    }
    final id = dew['id']?.toString();
    if (id == null || id.isEmpty) return;
    try {
      await ApiDewanyah.requestJoin(dewanyahId: id, token: widget.app.token);
      if (!mounted) return;
      Sfx.tap(mute: widget.app.soundMuted == true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال طلب انضمام')),
      );
    } catch (e) {
      Sfx.error(mute: widget.app.soundMuted == true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل طلب الانضمام: $e')));
    }
  }

  Future<void> _startGame(Map<String, dynamic> dew, String gameId) async {
    final app = widget.app;
    if (!app.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('سجّل الدخول أولاً')));
      return;
    }
    final ownerUserId = dew['ownerUserId']?.toString();
    final id = dew['id']?.toString() ?? '';
    final isOwner = ownerUserId != null && ownerUserId == app.userId;
    final isMember = isOwner || app.joinedDewanyahIds.contains(id);
    // allow approved members (and owner) only
    if (!isMember) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('الانضمام مطلوب قبل إنشاء مباراة الديوانية')));
      return;
    }
    if (gameId.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('اختر لعبة الديوانية أولاً')));
      return;
    }
    try {
      final pos = await _getLocation();
      final room = await ApiRoom.createRoom(
        gameId: gameId,
        sponsorCode: null,
        token: app.token,
        lat: pos?.latitude,
        lng: pos?.longitude,
      );
      if (!mounted) return;
      Sfx.tap(mute: widget.app.soundMuted == true);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MatchPage(app: app, room: room, sponsorCode: null),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Sfx.error(mute: widget.app.soundMuted == true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إنشاء مباراة: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    return Scaffold(
      appBar: AppBar(
        title: const Text('الدواوين'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('فشل تحميل الدواوين: ${snap.error}'));
          }
          final list = snap.data ?? const [];
          if (list.isEmpty) return const Center(child: Text('لا توجد دواوين حالياً'));
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final d = list[i];
              final name = (d['name'] ?? 'ديوانية').toString();
              final owner = (d['ownerName'] ?? '').toString();
              final game = ((d['games'] as List?)?.isNotEmpty ?? false)
                  ? (d['games'][0]['gameId']?.toString() ?? 'لعبة')
                  : (d['gameId'] ?? 'لعبة').toString();
              final ownerUserId = d['ownerUserId']?.toString();
              final isOwner = ownerUserId != null && ownerUserId == app.userId;
              final requireApproval = d['requireApproval'] == true;
              final locationLock = d['locationLock'] == true;
              final id = d['id']?.toString() ?? '';
              bool isJoined = isOwner || app.joinedDewanyahIds.contains(id);
              // Lazy membership check via leaderboard (approved members only)
              if (!isJoined && !_membershipCache.containsKey(id) && app.userId != null) {
                _membershipCache[id] = false; // mark as loading
                ApiDewanyah.leaderboard(dewanyahId: id).then((rows) {
                  final found = rows.any((r) => (r['userId'] ?? '').toString() == app.userId);
                  if (mounted) {
                    setState(() {
                      _membershipCache[id] = found;
                      if (found) app.addJoinedDewanyah(id);
                    });
                  }
                }).catchError((_) {
                  // ignore errors, keep existing state
                });
              } else if (_membershipCache[id] == true) {
                isJoined = true;
              }
              final games = ((d['games'] as List?) ?? const [])
                  .map((g) => g is Map ? (g['gameId']?.toString() ?? '') : '')
                  .where((g) => g.isNotEmpty)
                  .toList();
              final currentGame = _selectedGameByDew[id] ??
                  (games.isNotEmpty ? games.first : (d['gameId']?.toString() ?? ''));
              if (_selectedGameByDew[id] == null && currentGame.isNotEmpty) {
                _selectedGameByDew[id] = currentGame;
              }
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('$name — $game', style: const TextStyle(fontWeight: FontWeight.w900)),
                          ),
                      if (isOwner)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: const Chip(
                            label: Text('مالك'),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      if (locationLock)
                        const SizedBox(width: 6),
                      if (locationLock)
                        const Chip(
                          label: Text('قفل موقع'),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                      if (owner.isNotEmpty) Text('المالك: $owner'),
                      const SizedBox(height: 8),
                      if (games.isNotEmpty)
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: games
                              .map(
                                (g) => ChoiceChip(
                                  label: Text(g),
                                  selected: currentGame == g,
                                  onSelected: (_) => setState(() => _selectedGameByDew[id] = g),
                                ),
                              )
                              .toList(),
                        ),
                      if (games.isNotEmpty) const SizedBox(height: 8),
                      if (isOwner)
                        TextButton.icon(
                          onPressed: () async {
                            try {
                              final members = await ApiDewanyah.members(
                                  dewanyahId: d['id']?.toString() ?? '', token: app.token);
                              if (!context.mounted) return;
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('الطلبات والأعضاء'),
                                  content: SizedBox(
                                    width: 350,
                                    child: ListView.separated(
                                      shrinkWrap: true,
                                      itemCount: members.length,
                                      separatorBuilder: (_, __) => const Divider(height: 8),
                                      itemBuilder: (_, i) {
                                        final m = members[i];
                                        final status = (m['status'] ?? '').toString();
                                        final mid = (m['userId'] ?? '').toString();
                                        return ListTile(
                                          leading: CircleAvatar(child: Text('${i + 1}')),
                                          title: Text(m['user']?['displayName']?.toString() ?? 'لاعب'),
                                          subtitle: Text('حالة: $status'),
                                          trailing: status == 'pending'
                                              ? Wrap(
                                                  spacing: 6,
                                                  children: [
                                                    TextButton(
                                                      onPressed: () async {
                                                    await ApiDewanyah.setMemberStatus(
                                                        dewanyahId: d['id']?.toString() ?? '',
                                                        memberUserId: mid,
                                                        status: 'approved',
                                                        token: app.token);
                                                        if (!mounted || !context.mounted) return;
                                                        Navigator.pop(context);
                                                        await _refresh();
                                                        if (!mounted || !context.mounted) return;
                                                        ScaffoldMessenger.of(context)
                                                            .showSnackBar(const SnackBar(content: Text('تمت الموافقة')));
                                                      },
                                                      child: const Text('قبول'),
                                                    ),
                                                    TextButton(
                                                      onPressed: () async {
                                                        await ApiDewanyah.setMemberStatus(
                                                            dewanyahId: d['id']?.toString() ?? '',
                                                            memberUserId: mid,
                                                            status: 'rejected',
                                                            token: app.token);
                                                        if (!mounted || !context.mounted) return;
                                                        Navigator.pop(context);
                                                        await _refresh();
                                                        if (!mounted || !context.mounted) return;
                                                        ScaffoldMessenger.of(context)
                                                            .showSnackBar(const SnackBar(content: Text('تم الرفض')));
                                                      },
                                                      child: const Text('رفض'),
                                                    ),
                                                  ],
                                                )
                                              : null,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(content: Text('فشل تحميل الطلبات: $e')));
                          }
                        },
                          icon: const Icon(Icons.notifications_active_outlined),
                          label: const Text('الطلبات/الأعضاء'),
                        )
                      else if (!isJoined)
                        ElevatedButton.icon(
                          onPressed: () => _join(d),
                          icon: const Icon(Icons.group_add_outlined),
                          label: Text(requireApproval ? 'طلب انضمام' : 'انضمام مباشر'),
                        ),
                      if (isJoined && !isOwner)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4.0),
                          child: Text('أنت عضو في هذه الديوانية', style: TextStyle(color: Colors.greenAccent)),
                        ),
                      if (games.isNotEmpty && (isJoined || isOwner))
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => _startGame(d, currentGame),
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('ابدأ مباراة'),
                              ),
                            ),
                          ],
                        ),
                      TextButton(
                        onPressed: () async {
                          try {
                            final list = await ApiDewanyah.leaderboard(dewanyahId: d['id']?.toString() ?? '');
                            if (!context.mounted) return;
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('لوحة الديوانية'),
                                content: SizedBox(
                                  width: 320,
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    itemCount: list.length,
                                    separatorBuilder: (_, __) => const Divider(height: 8),
                                    itemBuilder: (_, i) {
                                      final p = list[i];
                                      return ListTile(
                                        leading: CircleAvatar(child: Text('${i + 1}')),
                                        title: Text(p['displayName']?.toString() ?? 'لاعب'),
                                        trailing: Text('${p['pearls'] ?? 0}'),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(content: Text('فشل تحميل اللوحة: $e')));
                          }
                        },
                        child: const Text('عرض اللوحة'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.close),
        label: const Text('عودة'),
      ),
    );
  }
}

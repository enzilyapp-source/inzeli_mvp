import 'dart:async';
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
  final Map<String, int> _pendingByDew = {};
  Timer? _pendingPollTimer;
  int _lastPendingTotal = -1;

  @override
  void initState() {
    super.initState();
    _future = ApiDewanyah.listAll();
    _refreshOwnerPending(showToastOnIncrease: false);
    _startPendingPoll();
  }

  Future<void> _refresh() async {
    setState(() {
      _membershipCache.clear();
      _future = ApiDewanyah.listAll();
    });
    await _refreshOwnerPending(showToastOnIncrease: false);
  }

  @override
  void dispose() {
    _pendingPollTimer?.cancel();
    super.dispose();
  }

  void _startPendingPoll() {
    _pendingPollTimer?.cancel();
    if (!widget.app.isSignedIn) return;
    _pendingPollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _refreshOwnerPending();
    });
  }

  Future<void> _refreshOwnerPending({bool showToastOnIncrease = true}) async {
    if (!widget.app.isSignedIn) return;
    try {
      final list = await ApiDewanyah.ownerPendingJoins(token: widget.app.token);
      final next = <String, int>{};
      var total = 0;
      for (final row in list) {
        final dewId = (row['dewanyahId'] ?? '').toString();
        final pending = (row['pendingCount'] as num?)?.toInt() ?? 0;
        if (dewId.isEmpty || pending <= 0) continue;
        next[dewId] = pending;
        total += pending;
      }
      final previousTotal = _lastPendingTotal;
      _lastPendingTotal = total;

      if (mounted) {
        setState(() {
          _pendingByDew
            ..clear()
            ..addAll(next);
        });
      }

      if (!showToastOnIncrease) return;
      if (previousTotal < 0) return;
      if (total <= previousTotal) return;
      if (!mounted) return;
      final diff = total - previousTotal;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('وصل $diff طلب جديد للديوانية')),
      );
    } catch (_) {
      // ignore polling errors to avoid noisy UX
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

  Future<void> _join(Map<String, dynamic> dew) async {
    if (!widget.app.isSignedIn) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('سجّل الدخول أولاً')));
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('فشل طلب الانضمام: $e')));
    }
  }

  Future<void> _startGame(Map<String, dynamic> dew, String gameId) async {
    final app = widget.app;
    if (!app.isSignedIn) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('سجّل الدخول أولاً')));
      return;
    }
    final ownerUserId = dew['ownerUserId']?.toString();
    final id = dew['id']?.toString() ?? '';
    final isOwner = ownerUserId != null && ownerUserId == app.userId;
    final isMember = isOwner || app.joinedDewanyahIds.contains(id);
    // allow approved members (and owner) only
    if (!isMember) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('الانضمام مطلوب قبل إنشاء مباراة الديوانية')));
      return;
    }
    if (gameId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('اختر لعبة الديوانية أولاً')));
      return;
    }
    try {
      final locationLock = dew['locationLock'] == true;
      final lockLat = (dew['anchorLat'] as num?)?.toDouble();
      final lockLng = (dew['anchorLng'] as num?)?.toDouble();
      final radius =
          ((dew['radiusMeters'] as num?)?.toInt() ?? 100).clamp(50, 1000);

      double? roomLat;
      double? roomLng;
      int? roomRadius;

      if (locationLock) {
        if (lockLat == null || lockLng == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'موقع الديوانية غير مثبت بعد. راجعي إعدادات الديوانية من الأدمن.')),
          );
          return;
        }
        final pos = await _getLocation();
        if (pos == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('فعّلي الموقع حتى نتحقق أنك داخل نطاق الديوانية')),
          );
          return;
        }
        final dist = Geolocator.distanceBetween(
          pos.latitude,
          pos.longitude,
          lockLat,
          lockLng,
        );
        if (dist > radius) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'أنت خارج نطاق الديوانية (${dist.toStringAsFixed(0)}م من المركز)')),
          );
          return;
        }
        roomLat = lockLat;
        roomLng = lockLng;
        roomRadius = radius;
      } else {
        final pos = await _getLocation();
        roomLat = pos?.latitude;
        roomLng = pos?.longitude;
      }

      final room = await ApiRoom.createRoom(
        gameId: gameId,
        sponsorCode: null,
        dewanyahId: id,
        token: app.token,
        lat: roomLat,
        lng: roomLng,
        radiusMeters: roomRadius,
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تعذر إنشاء مباراة: $e')));
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
          if (list.isEmpty) {
            return const Center(child: Text('لا توجد دواوين حالياً'));
          }
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
              final pendingCount = _pendingByDew[id] ?? 0;
              bool isJoined = isOwner || app.joinedDewanyahIds.contains(id);
              // Lazy membership check via leaderboard (approved members only)
              if (!isJoined &&
                  !_membershipCache.containsKey(id) &&
                  app.userId != null) {
                _membershipCache[id] = false; // mark as loading
                ApiDewanyah.leaderboard(dewanyahId: id).then((rows) {
                  final found = rows
                      .any((r) => (r['userId'] ?? '').toString() == app.userId);
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
                  (games.isNotEmpty
                      ? games.first
                      : (d['gameId']?.toString() ?? ''));
              if (_selectedGameByDew[id] == null && currentGame.isNotEmpty) {
                _selectedGameByDew[id] = currentGame;
              }
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(
                            avatar: const Icon(Icons.sports_esports_outlined,
                                size: 16),
                            label: Text(game),
                            visualDensity: VisualDensity.compact,
                          ),
                          if (isOwner)
                            const Chip(
                              avatar:
                                  Icon(Icons.verified_user_outlined, size: 16),
                              label: Text('مالك'),
                              visualDensity: VisualDensity.compact,
                            ),
                          if (locationLock)
                            const Chip(
                              avatar:
                                  Icon(Icons.location_on_outlined, size: 16),
                              label: Text('قفل موقع'),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                      if (owner.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.person_outline, size: 16),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'المالك: $owner',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: .82),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      if (games.isNotEmpty)
                        Center(
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 6,
                            runSpacing: 6,
                            children: games
                                .map(
                                  (g) => ChoiceChip(
                                    label: Text(g),
                                    selected: currentGame == g,
                                    onSelected: (_) => setState(
                                        () => _selectedGameByDew[id] = g),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      if (games.isNotEmpty) const SizedBox(height: 8),
                      if (isOwner)
                        Center(
                          child: TextButton.icon(
                            onPressed: () async {
                              try {
                                final members = await ApiDewanyah.members(
                                    dewanyahId: d['id']?.toString() ?? '',
                                    token: app.token);
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
                                        separatorBuilder: (_, __) =>
                                            const Divider(height: 8),
                                        itemBuilder: (_, i) {
                                          final m = members[i];
                                          final status =
                                              (m['status'] ?? '').toString();
                                          final mid =
                                              (m['userId'] ?? '').toString();
                                          return ListTile(
                                            leading: CircleAvatar(
                                                child: Text('${i + 1}')),
                                            title: Text(m['user']
                                                        ?['displayName']
                                                    ?.toString() ??
                                                'لاعب'),
                                            subtitle: Text('حالة: $status'),
                                            trailing: status == 'pending'
                                                ? Wrap(
                                                    spacing: 6,
                                                    children: [
                                                      TextButton(
                                                        onPressed: () async {
                                                          await ApiDewanyah
                                                              .setMemberStatus(
                                                                  dewanyahId:
                                                                      d['id']?.toString() ??
                                                                          '',
                                                                  memberUserId:
                                                                      mid,
                                                                  status:
                                                                      'approved',
                                                                  token: app
                                                                      .token);
                                                          if (!mounted ||
                                                              !context
                                                                  .mounted) {
                                                            return;
                                                          }
                                                          Navigator.pop(
                                                              context);
                                                          await _refresh();
                                                          if (!mounted ||
                                                              !context
                                                                  .mounted) {
                                                            return;
                                                          }
                                                          ScaffoldMessenger.of(
                                                                  context)
                                                              .showSnackBar(
                                                                  const SnackBar(
                                                                      content: Text(
                                                                          'تمت الموافقة')));
                                                          await _refreshOwnerPending(
                                                              showToastOnIncrease:
                                                                  false);
                                                        },
                                                        child:
                                                            const Text('قبول'),
                                                      ),
                                                      TextButton(
                                                        onPressed: () async {
                                                          await ApiDewanyah
                                                              .setMemberStatus(
                                                                  dewanyahId:
                                                                      d['id']?.toString() ??
                                                                          '',
                                                                  memberUserId:
                                                                      mid,
                                                                  status:
                                                                      'rejected',
                                                                  token: app
                                                                      .token);
                                                          if (!mounted ||
                                                              !context
                                                                  .mounted) {
                                                            return;
                                                          }
                                                          Navigator.pop(
                                                              context);
                                                          await _refresh();
                                                          if (!mounted ||
                                                              !context
                                                                  .mounted) {
                                                            return;
                                                          }
                                                          ScaffoldMessenger.of(
                                                                  context)
                                                              .showSnackBar(
                                                                  const SnackBar(
                                                                      content: Text(
                                                                          'تم الرفض')));
                                                          await _refreshOwnerPending(
                                                              showToastOnIncrease:
                                                                  false);
                                                        },
                                                        child:
                                                            const Text('رفض'),
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
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content:
                                            Text('فشل تحميل الطلبات: $e')));
                              }
                            },
                            icon: _OwnerPendingBadge(count: pendingCount),
                            label: Text(
                              pendingCount > 0
                                  ? 'الطلبات/الأعضاء ($pendingCount)'
                                  : 'الطلبات/الأعضاء',
                            ),
                          ),
                        )
                      else if (!isJoined)
                        Align(
                          alignment: Alignment.center,
                          child: ElevatedButton.icon(
                            onPressed: () => _join(d),
                            icon: const Icon(Icons.group_add_outlined),
                            label: Text(requireApproval
                                ? 'طلب انضمام'
                                : 'انضمام مباشر'),
                          ),
                        ),
                      if (isJoined && !isOwner)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4.0),
                          child: Text(
                            'أنت عضو في هذه الديوانية',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.greenAccent),
                          ),
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
                      Center(
                        child: TextButton.icon(
                          onPressed: () async {
                            try {
                              final list = await ApiDewanyah.leaderboard(
                                dewanyahId: d['id']?.toString() ?? '',
                                gameId:
                                    currentGame.isNotEmpty ? currentGame : null,
                              );
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
                                      separatorBuilder: (_, __) =>
                                          const Divider(height: 8),
                                      itemBuilder: (_, i) {
                                        final p = list[i];
                                        return ListTile(
                                          leading: CircleAvatar(
                                              child: Text('${i + 1}')),
                                          title: Text(
                                              p['displayName']?.toString() ??
                                                  'لاعب'),
                                          trailing: Text('${p['pearls'] ?? 0}'),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('فشل تحميل اللوحة: $e')));
                            }
                          },
                          icon:
                              const Icon(Icons.leaderboard_outlined, size: 18),
                          label: const Text('عرض اللوحة'),
                        ),
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

class _OwnerPendingBadge extends StatelessWidget {
  final int count;
  const _OwnerPendingBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final baseIcon = Icon(
      count > 0
          ? Icons.notifications_active
          : Icons.notifications_active_outlined,
      color: count > 0 ? Colors.amberAccent : null,
    );
    if (count <= 0) return baseIcon;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        baseIcon,
        Positioned(
          right: -6,
          top: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white, width: 0.8),
            ),
            constraints: const BoxConstraints(minWidth: 16),
            child: Text(
              count > 99 ? '99+' : '$count',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

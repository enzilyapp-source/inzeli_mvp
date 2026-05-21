import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../api_dewanyah.dart';
import '../api_room.dart';
import '../api_user.dart';
import '../sfx.dart';
import '../state.dart';
import '../widgets/primary_pill_button.dart';
import 'match_page.dart';
import 'player_profile_page.dart';

class DewanyahListPage extends StatefulWidget {
  final AppState app;
  final String? initialGameId;
  const DewanyahListPage({
    super.key,
    required this.app,
    this.initialGameId,
  });

  @override
  State<DewanyahListPage> createState() => _DewanyahListPageState();
}

class _DewanyahListPageState extends State<DewanyahListPage> {
  late Future<List<Map<String, dynamic>>> _future;
  final Map<String, bool> _membershipCache = {};
  final Map<String, String> _selectedGameByDew = {};
  final Map<String, int> _pendingByDew = {};
  final PageController _boardPager = PageController();
  final _requestNameCtrl = TextEditingController();
  final _requestContactCtrl = TextEditingController();
  final _requestNoteCtrl = TextEditingController();
  Timer? _pendingPollTimer;
  int _lastPendingTotal = -1;
  bool _showMoreDewanyahs = false;
  bool _showRequestForm = false;
  bool _requestLockLocation = false;
  bool _submittingRequest = false;
  int _requestRadiusMeters = 100;
  int _boardPage = 0;
  String? _filterGameId;
  String? _requestGameId;
  String? _boardDewanyahId;

  @override
  void initState() {
    super.initState();
    _future = _loadDewanyahs();
    final games = _gameOptions();
    _filterGameId = games.contains(widget.initialGameId)
        ? widget.initialGameId
        : null;
    _requestGameId = _filterGameId ?? (games.isNotEmpty ? games.first : null);
    _refreshOwnerPending(showToastOnIncrease: false);
    _startPendingPoll();
  }

  @override
  void dispose() {
    _pendingPollTimer?.cancel();
    _boardPager.dispose();
    _requestNameCtrl.dispose();
    _requestContactCtrl.dispose();
    _requestNoteCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _membershipCache.clear();
      _future = _loadDewanyahs();
    });
    await _refreshOwnerPending(showToastOnIncrease: false);
  }

  Future<List<Map<String, dynamic>>> _loadDewanyahs() async {
    final list = await ApiDewanyah.listAll();
    await widget.app.pruneResolvedOwnedDewanyahRequests(list);
    return list;
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

      if (!showToastOnIncrease || previousTotal < 0 || total <= previousTotal) {
        return;
      }
      if (!mounted) return;
      final diff = total - previousTotal;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('وصل $diff طلب جديد للديوانية')),
      );
    } catch (_) {
      // Polling is best-effort; errors should not interrupt the page.
    }
  }

  Future<Position?> _getLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
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
    final id = _dewId(dew);
    if (id.isEmpty) return;
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
    final id = _dewId(dew);
    final isMember = _isMineOrJoined(dew);
    if (!isMember) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الانضمام مطلوب قبل إنشاء مباراة الديوانية'),
        ),
      );
      return;
    }
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الديوانية لم تتفعل بعد')),
      );
      return;
    }
    final resolvedGameId = _resolvedGameForStart(dew, gameId);
    if (resolvedGameId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر لعبة الديوانية أولاً')),
      );
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
                'موقع الديوانية غير مثبت بعد. راجعي إعدادات الديوانية من الأدمن.',
              ),
            ),
          );
          return;
        }
        final pos = await _getLocation();
        if (pos == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('فعّلي الموقع حتى نتحقق أنك داخل نطاق الديوانية'),
            ),
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
                'أنت خارج نطاق الديوانية (${dist.toStringAsFixed(0)}م من المركز)',
              ),
            ),
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

      widget.app.setSelectedGame(
        resolvedGameId,
        category: _categoryForGame(resolvedGameId),
      );
      final room = await ApiRoom.createRoom(
        gameId: resolvedGameId,
        sponsorCode: null,
        dewanyahId: id,
        token: app.token,
        lat: roomLat,
        lng: roomLng,
        radiusMeters: roomRadius,
      );
      final roomGame = (room['gameId'] ?? '').toString().trim();
      if (roomGame.isNotEmpty && roomGame != resolvedGameId) {
        if (!mounted) return;
        Sfx.error(mute: widget.app.soundMuted == true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'رجع السيرفر لعبة ${widget.app.gameLabel(roomGame)} بدل ${widget.app.gameLabel(resolvedGameId)}. افتحي القيم الحالي أو حدّثي السيرفر.',
            ),
          ),
        );
        return;
      }
      if (!mounted) return;
      Sfx.tap(mute: widget.app.soundMuted == true);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MatchPage(app: app, room: room, sponsorCode: null),
        ),
      );
    } catch (e) {
      final active =
          RegExp(r'PLAYER_ALREADY_IN_ACTIVE_ROOM:([A-Z0-9]+)').firstMatch(
        e.toString(),
      );
      if (active != null) {
        final activeCode = active.group(1) ?? '';
        if (activeCode.isNotEmpty) {
          app.setRoomCode(activeCode);
          await _resumeActiveRoom(
            activeCode,
            expectedGameId: resolvedGameId,
            expectedDewanyahId: id,
          );
          return;
        }
      }
      if (!mounted) return;
      Sfx.error(mute: widget.app.soundMuted == true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('تعذر إنشاء مباراة: ${ApiRoom.friendlyError(e)}')));
    }
  }

  Future<void> _resumeActiveRoom(
    String code, {
    String? expectedGameId,
    String? expectedDewanyahId,
  }) async {
    if (code.trim().isEmpty) return;
    try {
      final room = await ApiRoom.getRoomByCode(code, token: widget.app.token);
      final status = room['status']?.toString();
      if (status != null && status != 'waiting' && status != 'running') {
        widget.app.setRoomCode(null);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('القيم السابق انتهى')),
        );
        return;
      }
      final roomGame = (room['gameId'] ?? '').toString().trim();
      final roomDewanyahId = (room['dewanyahId'] ?? '').toString().trim();
      final wantedGame = expectedGameId?.trim() ?? '';
      final wantedDewanyah = expectedDewanyahId?.trim() ?? '';
      if (wantedGame.isNotEmpty &&
          roomGame.isNotEmpty &&
          roomGame != wantedGame) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'عندك قيم شغال للعبة ${widget.app.gameLabel(roomGame)}. لغيه أول قبل ما تبدين ${widget.app.gameLabel(wantedGame)}.',
            ),
          ),
        );
        return;
      }
      if (wantedDewanyah.isNotEmpty &&
          roomDewanyahId.isNotEmpty &&
          roomDewanyahId != wantedDewanyah) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'عندك قيم شغال في ديوانية ثانية. لغيه أول قبل ما تبدين قيم جديد.',
            ),
          ),
        );
        return;
      }
      if (roomGame.isNotEmpty) {
        widget.app.setSelectedGame(
          roomGame,
          category: _categoryForGame(roomGame),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('رجعناك للقيم الحالي ($code)')),
      );
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              MatchPage(app: widget.app, room: room, sponsorCode: null),
        ),
      );
    } catch (e) {
      if (e.toString().contains('ROOM_NOT_FOUND') ||
          e.toString().contains('HTTP 404')) {
        widget.app.setRoomCode(null);
      }
      if (!mounted) return;
      Sfx.error(mute: widget.app.soundMuted == true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('عندك قيم شغال، بس تعذر فتحه: ${ApiRoom.friendlyError(e)}'),
        ),
      );
    }
  }

  Future<void> _submitDewanyahRequest() async {
    if (_submittingRequest) return;
    final name = _requestNameCtrl.text.trim();
    final contact = _requestContactCtrl.text.trim();
    final note = _requestNoteCtrl.text.trim();
    if (name.isEmpty || contact.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('عبّئ اسم الديوانية ووسيلة التواصل')),
      );
      return;
    }

    double? anchorLat;
    double? anchorLng;
    if (_requestLockLocation) {
      final pos = await _getLocation();
      if (pos == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فعّل الموقع حتى نثبت مكان الديوانية'),
          ),
        );
        return;
      }
      anchorLat = pos.latitude;
      anchorLng = pos.longitude;
    }

    setState(() => _submittingRequest = true);
    try {
      await widget.app.addDewanyahRequest(
        name: name,
        contact: contact,
        gameId: _requestGameId,
        note: note.isEmpty ? null : note,
        locationLock: _requestLockLocation,
        radiusMeters: _requestLockLocation ? _requestRadiusMeters : null,
        anchorLat: anchorLat,
        anchorLng: anchorLng,
      );
      if (!mounted) return;
      _requestNameCtrl.clear();
      _requestContactCtrl.clear();
      _requestNoteCtrl.clear();
      setState(() {
        _showRequestForm = false;
        _submittingRequest = false;
        _requestLockLocation = false;
        _requestRadiusMeters = 100;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('استلمنا طلب الديوانية')),
      );
      unawaited(_refresh());
    } catch (e) {
      if (!mounted) return;
      setState(() => _submittingRequest = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تعذر إرسال الطلب: $e')));
    }
  }

  String _dewId(Map<String, dynamic> dew) => (dew['id'] ?? '').toString();

  String _dewName(Map<String, dynamic> dew) =>
      (dew['name'] ?? dew['title'] ?? 'ديوانية').toString();

  String _ownerName(Map<String, dynamic> dew) =>
      (dew['ownerName'] ?? dew['owner'] ?? '').toString();

  bool _isOwner(Map<String, dynamic> dew) {
    final app = widget.app;
    final ownerId = (dew['ownerUserId'] ?? dew['ownerId'])?.toString();
    return ownerId != null && app.userId != null && ownerId == app.userId;
  }

  bool _isMineOrJoined(Map<String, dynamic> dew) {
    final app = widget.app;
    final id = _dewId(dew);
    if (_isOwner(dew)) return true;
    if (id.isEmpty) return dew['status']?.toString() == 'pending';
    final cached = _membershipCache[id];
    if (cached != null) return cached;
    if (app.joinedDewanyahIds.contains(id)) {
      _queueMembershipCheck(id, optimistic: true);
      return true;
    }
    _queueMembershipCheck(id);
    return false;
  }

  void _queueMembershipCheck(String id, {bool optimistic = false}) {
    final app = widget.app;
    if (id.isEmpty || app.userId == null || _membershipCache.containsKey(id)) {
      return;
    }
    _membershipCache[id] = optimistic;
    unawaited(
      ApiDewanyah.leaderboard(dewanyahId: id).then((rows) {
        final found =
            rows.any((r) => (r['userId'] ?? '').toString() == app.userId);
        if (!mounted) return;
        setState(() {
          _membershipCache[id] = found;
          if (found) {
            app.addJoinedDewanyah(id);
          } else {
            app.removeJoinedDewanyah(id);
          }
        });
      }).catchError((_) {
        // Keep the current UI if membership lookup fails.
      }),
    );
  }

  List<String> _dewGames(Map<String, dynamic> dew) {
    final games = <String>[];
    final raw = dew['games'];
    if (raw is List) {
      for (final item in raw) {
        final value = item is Map
            ? (item['gameId'] ?? item['id'] ?? item['name'])?.toString()
            : item?.toString();
        if (value != null && value.trim().isNotEmpty) {
          games.add(value.trim());
        }
      }
    }
    final fallback = (dew['gameId'] ?? '').toString().trim();
    if (fallback.isNotEmpty) games.add(fallback);
    return games.toSet().toList();
  }

  bool _matchesFilter(Map<String, dynamic> dew) {
    final filter = _filterGameId?.trim() ?? '';
    if (filter.isEmpty) return true;
    return _dewGames(dew).contains(filter);
  }

  List<String> _visibleGames(Map<String, dynamic> dew) {
    final games = _dewGames(dew);
    final initialGame = widget.initialGameId?.trim() ?? '';
    if (initialGame.isNotEmpty && games.contains(initialGame)) {
      return [initialGame];
    }
    final filteredGame = _filterGameId?.trim() ?? '';
    if (filteredGame.isNotEmpty && games.contains(filteredGame)) {
      return [filteredGame];
    }
    return games;
  }

  String _currentGame(Map<String, dynamic> dew) {
    final id = _dewId(dew);
    final games = _visibleGames(dew);
    final initialGame = widget.initialGameId?.trim() ?? '';
    if (initialGame.isNotEmpty && games.contains(initialGame)) {
      if (id.isNotEmpty) _selectedGameByDew[id] = initialGame;
      return initialGame;
    }
    final filteredGame = _filterGameId?.trim() ?? '';
    if (filteredGame.isNotEmpty && games.contains(filteredGame)) {
      if (id.isNotEmpty) _selectedGameByDew[id] = filteredGame;
      return filteredGame;
    }
    final selected = id.isEmpty ? null : _selectedGameByDew[id];
    if (selected != null && games.contains(selected)) return selected;
    final fallback = games.isNotEmpty ? games.first : '';
    if (id.isNotEmpty && fallback.isNotEmpty) {
      _selectedGameByDew[id] = fallback;
    }
    return fallback;
  }

  String _resolvedGameForStart(Map<String, dynamic> dew, String requestedGameId) {
    final visibleGames = _visibleGames(dew);
    final requested = requestedGameId.trim();
    if (requested.isNotEmpty && visibleGames.contains(requested)) {
      return requested;
    }
    final current = _currentGame(dew).trim();
    if (current.isNotEmpty && visibleGames.contains(current)) {
      return current;
    }
    return visibleGames.isNotEmpty ? visibleGames.first : requested;
  }

  String? _categoryForGame(String gameId) {
    final normalized = gameId.trim();
    if (normalized.isEmpty) return null;
    for (final entry in widget.app.games.entries) {
      if (entry.value.contains(normalized)) return entry.key;
    }
    return null;
  }

  List<String> _gameOptions() {
    final set = <String>{};
    for (final list in widget.app.games.values) {
      for (final game in list) {
        if (game.trim().isNotEmpty) set.add(game.trim());
      }
    }
    final selected = widget.app.selectedGame;
    if (selected != null && selected.trim().isNotEmpty) set.add(selected);
    return set.toList();
  }

  String? _imageUrl(Map<String, dynamic> dew) {
    final raw = (dew['imageUrl'] ??
            dew['logoUrl'] ??
            dew['coverUrl'] ??
            dew['avatarUrl'])
        ?.toString();
    if (raw == null || raw.trim().isEmpty) return null;
    return raw.trim();
  }

  List<Map<String, dynamic>> _mergeLocalOwned(
    List<Map<String, dynamic>> serverList,
  ) {
    final merged = List<Map<String, dynamic>>.from(serverList);
    final serverIds = merged.map(_dewId).where((id) => id.isNotEmpty).toSet();
    for (final owned in widget.app.ownedDewanyahs.reversed) {
      final map = Map<String, dynamic>.from(owned);
      final id = _dewId(map);
      if (id.isNotEmpty && serverIds.contains(id)) continue;
      if (_hasMatchingApprovedDewanyah(map, serverList)) continue;
      map['ownerId'] ??= widget.app.userId;
      map['ownerName'] ??= widget.app.displayName ?? widget.app.name;
      map['status'] ??= 'pending';
      merged.insert(0, map);
    }
    return merged;
  }

  bool _hasMatchingApprovedDewanyah(
    Map<String, dynamic> localOwned,
    List<Map<String, dynamic>> serverList,
  ) {
    final localStatus = (localOwned['status'] ?? '').toString().trim();
    if (localStatus != 'pending') return false;

    final localName = _normalizeDewanyahName(_dewName(localOwned));
    if (localName.isEmpty) return false;

    final myUserId = widget.app.userId?.trim() ?? '';
    final myDisplay =
        _normalizeDewanyahName(widget.app.displayName ?? widget.app.name ?? '');

    return serverList.any((server) {
      final serverId = _dewId(server).trim();
      if (serverId.isEmpty) return false;

      final serverName = _normalizeDewanyahName(_dewName(server));
      if (serverName != localName) return false;

      final serverOwnerId =
          ((server['ownerUserId'] ?? server['ownerId']) ?? '').toString().trim();
      if (myUserId.isNotEmpty && serverOwnerId.isNotEmpty) {
        return serverOwnerId == myUserId;
      }

      final serverOwnerName =
          _normalizeDewanyahName(_ownerName(server));
      return myDisplay.isNotEmpty &&
          serverOwnerName.isNotEmpty &&
          serverOwnerName == myDisplay;
    });
  }

  String _normalizeDewanyahName(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .toLowerCase();
  }

  Future<void> _showMembers(Map<String, dynamic> dew) async {
    final id = _dewId(dew);
    if (id.isEmpty) return;
    try {
      final members =
          await ApiDewanyah.members(dewanyahId: id, token: widget.app.token);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('الطلبات والأعضاء'),
          content: SizedBox(
            width: 350,
            child: members.isEmpty
                ? const Text('لا توجد طلبات حالياً')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: members.length,
                    separatorBuilder: (_, __) => const Divider(height: 8),
                    itemBuilder: (_, i) {
                      final m = members[i];
                      final status = (m['status'] ?? '').toString();
                      final mid = (m['userId'] ?? '').toString();
                      final canRemove =
                          mid.isNotEmpty && mid != widget.app.userId;
                      return ListTile(
                        leading: CircleAvatar(child: Text('${i + 1}')),
                        title: Text(
                          m['user']?['displayName']?.toString() ?? 'لاعب',
                        ),
                        subtitle: Text('حالة: $status'),
                        trailing: status == 'pending' || canRemove
                            ? Wrap(
                                spacing: 6,
                                children: [
                                  if (status == 'pending') ...[
                                    TextButton(
                                      onPressed: () async {
                                        await ApiDewanyah.setMemberStatus(
                                          dewanyahId: id,
                                          memberUserId: mid,
                                          status: 'approved',
                                          token: widget.app.token,
                                        );
                                        if (!mounted ||
                                            !dialogContext.mounted) {
                                          return;
                                        }
                                        Navigator.pop(dialogContext);
                                        await _refresh();
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text('تمت الموافقة'),
                                          ),
                                        );
                                      },
                                      child: const Text('قبول'),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        await ApiDewanyah.setMemberStatus(
                                          dewanyahId: id,
                                          memberUserId: mid,
                                          status: 'rejected',
                                          token: widget.app.token,
                                        );
                                        if (!mounted ||
                                            !dialogContext.mounted) {
                                          return;
                                        }
                                        Navigator.pop(dialogContext);
                                        await _refresh();
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text('تم الرفض')),
                                        );
                                      },
                                      child: const Text('رفض'),
                                    ),
                                  ],
                                  if (canRemove)
                                    TextButton(
                                      onPressed: () => _removeMember(
                                        id,
                                        mid,
                                        dialogContext,
                                      ),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.redAccent,
                                      ),
                                      child: const Text('حذف'),
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
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('فشل تحميل الطلبات: $e')));
    }
  }

  Future<void> _removeMember(
    String dewanyahId,
    String memberUserId,
    BuildContext dialogContext,
  ) async {
    try {
      await ApiDewanyah.removeMember(
        dewanyahId: dewanyahId,
        memberUserId: memberUserId,
        token: widget.app.token,
      );
      if (!mounted || !dialogContext.mounted) return;
      Navigator.pop(dialogContext);
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف اللاعب من الديوانية')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('فشل حذف اللاعب: $e')));
    }
  }

  Future<void> _leaveDewanyah(
    Map<String, dynamic> dew,
    BuildContext sheetContext,
  ) async {
    final id = _dewId(dew);
    if (id.isEmpty) return;
    try {
      await ApiDewanyah.leave(dewanyahId: id, token: widget.app.token);
      if (!mounted) return;
      widget.app.removeJoinedDewanyah(id);
      Sfx.tap(mute: widget.app.soundMuted == true);
      if (sheetContext.mounted) Navigator.pop(sheetContext);
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('طلعت من الديوانية')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('فشل الخروج من الديوانية: $e')));
    }
  }

  Future<void> _showLeaderboard(Map<String, dynamic> dew, String gameId) async {
    final id = _dewId(dew);
    if (id.isEmpty) return;
    try {
      final rows = await ApiDewanyah.leaderboard(
        dewanyahId: id,
        gameId: gameId.isNotEmpty ? gameId : null,
      );
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('لوحة الديوانية'),
          content: SizedBox(
            width: 320,
            child: rows.isEmpty
                ? const Text('لا توجد نتائج بعد')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const Divider(height: 8),
                    itemBuilder: (_, i) {
                      final p = rows[i];
                      return ListTile(
                        onTap: () => _openPlayerProfileFromRow(p, gameId),
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
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('فشل تحميل اللوحة: $e')));
    }
  }

  Future<void> _openPlayerProfileFromRow(
    Map<String, dynamic> row,
    String gameId,
  ) async {
    final display =
        (row['displayName'] ?? row['name'] ?? row['playerName'] ?? '')
            .toString()
            .trim();
    if (display.isEmpty || display == '—') return;

    final uid = (row['userId'] ?? row['id'] ?? '').toString();
    widget.app.upsertUserProfile(display, {
      if (uid.isNotEmpty) 'id': uid,
      'publicId': row['publicId'],
      'displayName': display,
      'avatarUrl': row['avatarUrl'] ?? row['avatarPath'] ?? row['avatar'],
      'avatarBase64': row['avatarBase64'],
      'themeId': row['themeId'],
    });
    widget.app.upsertUserStats(display, {
      if (uid.isNotEmpty) 'id': uid,
      'publicId': row['publicId'],
      'wins': (row['wins'] as num?)?.toInt() ?? 0,
      'losses': (row['losses'] as num?)?.toInt() ?? 0,
      'gamePearls': {
        if (gameId.trim().isNotEmpty)
          gameId: (row['pearls'] as num?)?.toInt() ?? 0,
      },
    });

    if (uid.isNotEmpty) {
      try {
        final stats = await getUserStats(
          uid,
          token: widget.app.token,
          gameId: gameId.isEmpty ? widget.app.selectedGame : gameId,
        );
        if (stats != null) widget.app.upsertUserStats(display, stats);
      } catch (_) {
        // The leaderboard row still gives enough context to open the profile.
      }
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerProfilePage(app: widget.app, playerName: display),
      ),
    );
  }

  void _openDewanyahSheet(Map<String, dynamic> dew) {
    final id = _dewId(dew);
    final isOwner = _isOwner(dew);
    final isJoined = _isMineOrJoined(dew);
    final owner = _ownerName(dew);
    final pendingCount = _pendingByDew[id] ?? 0;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (sheetContext, sheetSetState) {
          final games = _visibleGames(dew);
          final pickedGame = _currentGame(dew);
          final currentGame = games.contains(pickedGame)
              ? pickedGame
              : (games.isNotEmpty ? games.first : '');
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                6,
                16,
                MediaQuery.of(sheetContext).viewInsets.bottom + 18,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _dewName(dew),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (owner.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'المالك: $owner',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (games.isNotEmpty)
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: games
                          .map(
                            (g) => ChoiceChip(
                              label: Text(widget.app.gameLabel(g)),
                              selected: currentGame == g,
                              onSelected: (_) {
                                if (id.isNotEmpty) _selectedGameByDew[id] = g;
                                sheetSetState(() {});
                                setState(() {});
                              },
                            ),
                          )
                          .toList(),
                    ),
                  const SizedBox(height: 14),
                  if (id.isEmpty)
                    const _InfoStrip(
                      icon: Icons.hourglass_empty,
                      text: 'طلب الديوانية قيد المراجعة',
                    )
                  else if (isOwner)
                    OutlinedButton.icon(
                      onPressed: () => _showMembers(dew),
                      icon: _OwnerPendingBadge(count: pendingCount),
                      label: Text(
                        pendingCount > 0
                            ? 'الطلبات/الأعضاء ($pendingCount)'
                            : 'الطلبات/الأعضاء',
                      ),
                    )
                  else if (!isJoined)
                    PrimaryPillButton(
                      onPressed: () => _join(dew),
                      icon: Icons.group_add_outlined,
                      label: dew['requireApproval'] == true
                          ? 'طلب انضمام'
                          : 'انضمام مباشر',
                      maxWidth: 240,
                      minHeight: 62,
                      fontSize: 18,
                    )
                  else ...[
                    const _InfoStrip(
                      icon: Icons.verified_user_outlined,
                      text: 'أنت عضو في هذه الديوانية',
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => _leaveDewanyah(dew, sheetContext),
                      icon: const Icon(Icons.logout),
                      label: const Text('الخروج من الديوانية'),
                    ),
                  ],
                  if (games.isNotEmpty && (isJoined || isOwner)) ...[
                    const SizedBox(height: 10),
                    PrimaryPillButton(
                      onPressed: () => _startGame(dew, currentGame),
                      icon: Icons.play_arrow,
                      label: 'ابدأ مباراة',
                      maxWidth: 240,
                      minHeight: 64,
                      fontSize: 18,
                    ),
                  ],
                  if (id.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => _showLeaderboard(dew, currentGame),
                      icon: const Icon(Icons.leaderboard_outlined),
                      label: const Text('عرض اللوحة'),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDewanyahGrid(List<Map<String, dynamic>> dews) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width < 360 ? 2 : (width < 620 ? 3 : 4);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: dews.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.82,
          ),
          itemBuilder: (_, index) {
            final dew = dews[index];
            final id = _dewId(dew);
            final pendingCount = _pendingByDew[id] ?? 0;
            return _DewanyahTile(
              name: _dewName(dew),
              imageUrl: _imageUrl(dew),
              isMine: _isMineOrJoined(dew),
              pendingCount: pendingCount,
              status: dew['status']?.toString(),
              onTap: () => _openDewanyahSheet(dew),
            );
          },
        );
      },
    );
  }

  Widget _buildBoardCarouselSection(List<Map<String, dynamic>> list) {
    final specs = _dewBoardSpecs(list);
    if (specs.isEmpty) {
      return const _PanelMessage(
        icon: Icons.leaderboard_outlined,
        title: 'لوحة الديوانيات',
        text: 'بتظهر اللوحات لما تتفعل أول ديوانية.',
      );
    }
    final safePage = _boardPage >= specs.length ? 0 : _boardPage;
    if (safePage != _boardPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _boardPage = safePage);
        if (_boardPager.hasClients) _boardPager.jumpToPage(safePage);
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle(
          title: 'لوحة الديوانيات',
          icon: Icons.groups_3_outlined,
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 380,
          child: PageView.builder(
            controller: _boardPager,
            itemCount: specs.length,
            onPageChanged: (i) => setState(() => _boardPage = i),
            itemBuilder: (_, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _buildDewBoardPanel(specs[index]),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _BoardDots(count: specs.length, current: safePage),
      ],
    );
  }

  List<_DewBoardSpec> _dewBoardSpecs(List<Map<String, dynamic>> list) {
    final specs = <_DewBoardSpec>[];
    for (final dew in list) {
      final id = _dewId(dew);
      if (id.isEmpty) continue;
      final games = _dewGames(dew);
      final gameIds = games.isEmpty ? [''] : games;
      for (final game in gameIds) {
        final filter = _filterGameId?.trim() ?? '';
        if (filter.isNotEmpty && game != filter) continue;
        specs.add(
          _DewBoardSpec(
            dewanyahId: id,
            title: _dewName(dew),
            gameId: game,
            owner: _ownerName(dew),
          ),
        );
      }
    }
    return specs;
  }

  Widget _buildDewBoardPanel(_DewBoardSpec spec) {
    final gameLabel =
        spec.gameId.isEmpty ? 'كل الألعاب' : widget.app.gameLabel(spec.gameId);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spec.title,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        'اللعبة الحالية: $gameLabel',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.62),
                          fontSize: 12,
                        ),
                      ),
                      if (spec.owner.isNotEmpty)
                        Text(
                          'المالك: ${spec.owner}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.62),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'ديوانية',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: ApiDewanyah.leaderboard(
                  dewanyahId: spec.dewanyahId,
                  gameId: spec.gameId.isNotEmpty ? spec.gameId : null,
                  limit: 30,
                ),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Card(
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snap.hasError) {
                    return Center(
                      child: Text('تعذر تحميل اللوحة: ${snap.error}'),
                    );
                  }
                  final rows = snap.data ?? const [];
                  if (rows.isEmpty) {
                    return const Center(child: Text('لا توجد نتائج بعد'));
                  }
                  return Card(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => const Divider(height: 0),
                      itemBuilder: (_, index) {
                        final row = rows[index];
                        final isTop = index == 0;
                        return ListTile(
                          onTap: () =>
                              _openPlayerProfileFromRow(row, spec.gameId),
                          leading: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                backgroundColor: isTop
                                    ? const Color(0xFFFFC16B)
                                    : const Color(0xFF273347),
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: isTop ? Colors.black : Colors.white,
                                  ),
                                ),
                              ),
                              if (isTop)
                                Positioned(
                                  top: -6,
                                  right: -10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFA53A),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'الأول',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          title: Text(
                            row['displayName']?.toString() ??
                                row['name']?.toString() ??
                                'لاعب',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          subtitle: const Text('اللآلئ العامة'),
                          trailing: _MiniPearlPill(value: row['pearls'] ?? 0),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildBoardSection(List<Map<String, dynamic>> list) {
    final boards = list.where((d) => _dewId(d).isNotEmpty).toList();
    if (boards.isEmpty) {
      return const _PanelMessage(
        icon: Icons.leaderboard_outlined,
        title: 'لوحة الديوانيات',
        text: 'بتظهر اللوحات لما تتفعل أول ديوانية.',
      );
    }
    final ids = boards.map(_dewId).toSet();
    if (_boardDewanyahId == null || !ids.contains(_boardDewanyahId)) {
      _boardDewanyahId = _dewId(boards.first);
    }
    final selected = boards.firstWhere(
      (d) => _dewId(d) == _boardDewanyahId,
      orElse: () => boards.first,
    );
    final selectedId = _dewId(selected);
    final game = _currentGame(selected);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionTitle(
              title: 'لوحة الديوانيات',
              icon: Icons.groups_3_outlined,
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: boards.map((dew) {
                  final id = _dewId(dew);
                  return Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      label: Text(_dewName(dew)),
                      selected: id == selectedId,
                      onSelected: (_) => setState(() => _boardDewanyahId = id),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            if (_dewGames(selected).length > 1)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _dewGames(selected)
                    .map(
                      (g) => FilterChip(
                        label: Text(widget.app.gameLabel(g)),
                        selected: game == g,
                        onSelected: (_) =>
                            setState(() => _selectedGameByDew[selectedId] = g),
                      ),
                    )
                    .toList(),
              ),
            if (_dewGames(selected).length > 1) const SizedBox(height: 8),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: ApiDewanyah.leaderboard(
                dewanyahId: selectedId,
                gameId: game.isNotEmpty ? game : null,
                limit: 5,
              ),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snap.hasError) {
                  return Text('تعذر تحميل اللوحة: ${snap.error}');
                }
                final rows = snap.data ?? const [];
                if (rows.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('لا توجد نتائج بعد'),
                  );
                }
                return Column(
                  children: rows.take(5).toList().asMap().entries.map((entry) {
                    final index = entry.key;
                    final row = entry.value;
                    return ListTile(
                      onTap: () => _openPlayerProfileFromRow(row, game),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(child: Text('${index + 1}')),
                      title: Text(row['displayName']?.toString() ?? 'لاعب'),
                      trailing: Text(
                        '${row['pearls'] ?? 0}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestSection() {
    final gameOptions = _gameOptions();
    final currentGame = gameOptions.contains(_requestGameId)
        ? _requestGameId
        : (gameOptions.isNotEmpty ? gameOptions.first : null);
    _requestGameId = currentGame;

    if (!_showRequestForm) {
      return SizedBox(
        width: double.infinity,
        child: PrimaryPillButton(
          onPressed: () => setState(() => _showRequestForm = true),
          icon: Icons.add_home_work_outlined,
          label: 'طلب ديوانية',
          maxWidth: 240,
          minHeight: 66,
          fontSize: 18,
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.add_home_work_outlined),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'طلب ديوانية',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  onPressed: _submittingRequest
                      ? null
                      : () => setState(() => _showRequestForm = false),
                  icon: const Icon(Icons.close),
                  tooltip: 'إغلاق',
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _requestNameCtrl,
              decoration: const InputDecoration(labelText: 'اسم الديوانية'),
            ),
            const SizedBox(height: 10),
            if (gameOptions.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: currentGame,
                decoration: const InputDecoration(labelText: 'اللعبة الأساسية'),
                items: gameOptions
                    .map(
                      (g) => DropdownMenuItem(
                        value: g,
                        child: Text(widget.app.gameLabel(g)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _requestGameId = v),
              ),
            if (gameOptions.isNotEmpty) const SizedBox(height: 10),
            TextField(
              controller: _requestContactCtrl,
              decoration: const InputDecoration(labelText: 'رقم/إيميل للتواصل'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _requestNoteCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'ملاحظات'),
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _requestLockLocation,
              onChanged: _submittingRequest
                  ? null
                  : (v) => setState(() => _requestLockLocation = v),
              title: const Text('تثبيت موقع الديوانية'),
              subtitle: Text(
                'اختياري',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
            ),
            if (_requestLockLocation)
              DropdownButtonFormField<int>(
                initialValue: _requestRadiusMeters,
                decoration: const InputDecoration(labelText: 'نطاق الموقع'),
                items: const [80, 100, 150, 200, 300]
                    .map(
                      (v) => DropdownMenuItem(
                        value: v,
                        child: Text('$v م'),
                      ),
                    )
                    .toList(),
                onChanged: (v) =>
                    setState(() => _requestRadiusMeters = v ?? 100),
              ),
            const SizedBox(height: 12),
            PrimaryPillButton(
              onPressed: _submittingRequest ? null : _submitDewanyahRequest,
              icon: Icons.send_outlined,
              loading: _submittingRequest,
              label: 'إرسال الطلب',
              maxWidth: 220,
              minHeight: 64,
              fontSize: 18,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final filterLabel = (_filterGameId?.trim().isNotEmpty ?? false)
        ? widget.app.gameLabel(_filterGameId!)
        : null;
    final pageSurface = Theme.of(context).scaffoldBackgroundColor;
    return Scaffold(
      backgroundColor: const Color(0xFF1F2B40),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F2B40),
        surfaceTintColor: Colors.transparent,
        title: Text(filterLabel == null ? 'الدواوين' : 'دواوين $filterLabel'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Container(
        color: pageSurface,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('فشل تحميل الدواوين: ${snap.error}'));
            }

            final list = _mergeLocalOwned(snap.data ?? const []);
            final myDewanyahs = <Map<String, dynamic>>[];
            final discoverDewanyahs = <Map<String, dynamic>>[];
            for (final dew in list) {
              if (!_matchesFilter(dew)) continue;
              if (_isMineOrJoined(dew)) {
                myDewanyahs.add(dew);
              } else {
                discoverDewanyahs.add(dew);
              }
            }

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                    if (filterLabel != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'يعرض لك الدواوين المرتبطة بلعبة $filterLabel',
                        style: TextStyle(
                          color: onSurface.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (filterLabel == null) const SizedBox(height: 6),
                    const _SectionTitle(
                      title: 'دواويني',
                      icon: Icons.home_work_outlined,
                    ),
                    const SizedBox(height: 10),
                    if (myDewanyahs.isEmpty)
                      const _PanelMessage(
                        icon: Icons.groups_2_outlined,
                        title: 'ما عندك ديوانية مفعلة',
                        text: 'انضم لديوانية أو ارسل طلب ديوانية من الزر تحت.',
                      )
                    else
                      _buildDewanyahGrid(myDewanyahs),
                    if (discoverDewanyahs.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => setState(
                          () => _showMoreDewanyahs = !_showMoreDewanyahs,
                        ),
                        icon: Icon(
                          _showMoreDewanyahs
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                        ),
                        label: Text(
                          _showMoreDewanyahs
                              ? 'إخفاء الدواوين'
                              : 'اكتشف دواوين أكثر',
                        ),
                      ),
                      if (_showMoreDewanyahs) ...[
                        const SizedBox(height: 10),
                        _buildDewanyahGrid(discoverDewanyahs),
                      ],
                    ],
                    const SizedBox(height: 16),
                    _buildBoardCarouselSection(list),
                    const SizedBox(height: 14),
                    _buildRequestSection(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DewBoardSpec {
  final String dewanyahId;
  final String title;
  final String gameId;
  final String owner;

  const _DewBoardSpec({
    required this.dewanyahId,
    required this.title,
    required this.gameId,
    required this.owner,
  });
}

class _BoardDots extends StatelessWidget {
  final int count;
  final int current;
  const _BoardDots({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return Container(
          width: active ? 12 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: active ? 0.9 : 0.4),
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }
}

class _MiniPearlPill extends StatelessWidget {
  final dynamic value;
  const _MiniPearlPill({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF232E4A),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('lib/assets/pearl.png', width: 18, height: 18),
          const SizedBox(width: 6),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _DewanyahTile extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final bool isMine;
  final int pendingCount;
  final String? status;
  final VoidCallback onTap;

  const _DewanyahTile({
    required this.name,
    required this.imageUrl,
    required this.isMine,
    required this.pendingCount,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pending = status == 'pending';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageUrl != null)
                    Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const _DewanyahFallback(),
                    )
                  else
                    const _DewanyahFallback(),
                  PositionedDirectional(
                    top: 8,
                    end: 8,
                    child: _TileBadge(
                      label: pending
                          ? 'قيد المراجعة'
                          : (isMine ? 'دواويني' : 'اكتشاف'),
                      highlighted: isMine || pending,
                    ),
                  ),
                  if (pendingCount > 0)
                    PositionedDirectional(
                      top: 8,
                      start: 8,
                      child: _OwnerPendingPill(count: pendingCount),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 9, 8, 10),
              child: Text(
                name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DewanyahFallback extends StatelessWidget {
  const _DewanyahFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF304A5D),
      child: Center(
        child: Image.asset(
          'lib/assets/enzeli_logo.png',
          width: 52,
          height: 52,
          errorBuilder: (_, __, ___) => const Icon(Icons.groups_3, size: 44),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFFE49A2C)),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
          ),
        ),
      ],
    );
  }
}

class _PanelMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  const _PanelMessage({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFE49A2C), size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    text,
                    style: TextStyle(color: Colors.white.withValues(alpha: .7)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoStrip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoStrip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: const Color(0xFFE49A2C)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _TileBadge extends StatelessWidget {
  final String label;
  final bool highlighted;
  const _TileBadge({required this.label, required this.highlighted});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: highlighted
            ? const Color(0xFFE49A2C).withValues(alpha: 0.92)
            : Colors.black.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
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

class _OwnerPendingPill extends StatelessWidget {
  final int count;
  const _OwnerPendingPill({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }
}

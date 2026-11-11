import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../scorekeeper/score_api.dart';
import '../../scorekeeper/score_appearance.dart';
import '../../scorekeeper/score_document.dart';
import '../../scorekeeper/score_models.dart';
import '../../widgets/adaptive_game_frame.dart';

class RoomScorePage extends StatefulWidget {
  const RoomScorePage(
      {super.key,
      required this.room,
      required this.userId,
      required this.token});
  final ValueListenable<ScoreRoomInfo> room;
  final String userId;
  final String? token;
  @override
  State<RoomScorePage> createState() => _RoomScorePageState();
}

class _RoomScorePageState extends State<RoomScorePage>
    with WidgetsBindingObserver {
  late final ScoreApi _api;
  WebViewController? _web;
  Timer? _poller, _debounce;
  ScoreEnvelope? _remote;
  ScoreSnapshot? _pending, _context, _recoverySnapshot;
  List<ScorePerson> _people = [];
  String? _error;
  bool _loading = true,
      _writing = false,
      _reading = false,
      _conflict = false,
      _ready = false,
      _allowPop = false;
  int _documentGeneration = 0;
  DateTime? _lastWriteAt;
  Future<void> _recovery = Future<void>.value();
  final GlobalKey _webViewKey = GlobalKey();
  num _restoreScroll = 0;
  bool get _host => widget.room.value.hostId == widget.userId;
  bool get _editable =>
      _host && (_remote?.canEdit ?? false) && !widget.room.value.closed;
  String get _backupKey =>
      'score-sheet.draft.${widget.room.value.code}.${widget.userId}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _api = ScoreApi(code: widget.room.value.code, token: widget.token);
    unawaited(_start());
  }

  Future<void> _start() async {
    try {
      _people = await _api.roster();
      await _read(initial: true);
      if (!mounted) return;
      _poller = Timer.periodic(const Duration(seconds: 4), (_) {
        unawaited(_poll());
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _poll() async {
    if (_pending != null) {
      await _flush();
      return;
    }
    if (_people.isEmpty) {
      await _start();
    } else {
      await _read();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_poll());
      _poller ??= Timer.periodic(const Duration(seconds: 4), (_) {
        unawaited(_poll());
      });
    } else {
      _poller?.cancel();
      _poller = null;
      unawaited(_flush());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poller?.cancel();
    _debounce?.cancel();
    _api.dispose();
    super.dispose();
  }

  Future<void> _read({bool initial = false}) async {
    if (_reading || _writing || !mounted) return;
    _reading = true;
    try {
      final result = await _api.read();
      if (!mounted) return;
      final changed = _remote?.revision != result.revision;
      _remote = result;
      if (initial && _host) {
        final saved =
            (await SharedPreferences.getInstance()).getString(_backupKey);
        if (saved != null) {
          try {
            final backup = jsonDecode(saved) as Map<String, dynamic>;
            if (backup['dirty'] == true) {
              final draft = ScoreSnapshot.fromJson(
                  Map<String, dynamic>.from(backup['snapshot'] as Map));
              if (backup['revision'] == result.revision) {
                _pending = draft;
              } else {
                _recoverySnapshot = draft;
                _conflict = true;
                _error =
                    'توجد تغييرات غير متزامنة من هذا الجهاز. تقدر تعرض نسختك أو تحمّل القيد المشترك؛ نسختك محفوظة.';
              }
            }
          } catch (_) {
            /* Preserve an unreadable backup; never replace it automatically. */
          }
        }
      }
      if (_pending != null && !_conflict) {
        if (initial) await _show(_pending!);
        unawaited(_flush());
      } else if ((changed || initial) && result.snapshot != null) {
        await _show(result.snapshot!);
      }
      if (mounted) {
        setState(() {
          _loading = false;
          if (!_conflict) _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    } finally {
      _reading = false;
      if (_pending != null && !_conflict && mounted) unawaited(_flush());
    }
  }

  Future<void> _show(ScoreSnapshot snapshot) async {
    _restoreScroll = 0;
    if (_web != null && _context?.kind == snapshot.kind) {
      try {
        _restoreScroll = num.tryParse(
                (await _web!.runJavaScriptReturningResult('window.scrollY'))
                    .toString()) ??
            0;
      } catch (_) {}
    }
    _context = snapshot;
    _ready = false;
    final generation = ++_documentGeneration;
    final ordered = snapshot.rosterIds
        .map((id) => _people.firstWhere((p) => p.id == id,
            orElse: () => ScorePerson(id: id, name: 'لاعب')))
        .map((p) => ScorePerson(
            id: p.id,
            name: p.name,
            avatar: p.avatar,
            team: snapshot.teams[p.id]))
        .toList();
    if (ordered.length < 2) {
      throw const FormatException('لا يوجد لاعبون كفاية لفتح القيد');
    }
    final html = await ScoreDocument.build(
        kind: snapshot.kind,
        people: ordered,
        teamMode: snapshot.teamMode,
        editable: _editable && !_conflict,
        storage: snapshot.storage);
    if (!mounted || generation != _documentGeneration) return;
    final controller = WebViewController();
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.setBackgroundColor(ScoreAppearance.background);
    await controller.addJavaScriptChannel('InzeliBridge',
        onMessageReceived: (message) {
      if (generation == _documentGeneration) {
        unawaited(_message(message.message));
      }
    });
    await controller.setNavigationDelegate(NavigationDelegate(
      onNavigationRequest: (request) => request.url == 'about:blank' ||
              request.url.startsWith('https://score.inzeli.local/')
          ? NavigationDecision.navigate
          : NavigationDecision.prevent,
      onWebResourceError: (error) {
        if (error.isForMainFrame == true && mounted) {
          setState(() => _error = 'تعذر عرض القيد. أعد تحميله.');
        }
      },
    ));
    await controller.loadHtmlString(html,
        baseUrl: 'https://score.inzeli.local/');
    if (mounted && generation == _documentGeneration) {
      setState(() => _web = controller);
    }
  }

  Future<void> _message(String text) async {
    if (!mounted || text.length > 260000) return;
    final data = jsonDecode(text) as Map<String, dynamic>;
    if (data['type'] == 'ready') {
      setState(() => _ready = true);
      await _web?.runJavaScript('window.scrollTo(0, $_restoreScroll);');
      return;
    }
    if (!_editable || _conflict) return;
    if (data['type'] == 'confirm') {
      final action = data['action']?.toString() ?? '';
      final confirmedGeneration = _documentGeneration;
      if (action.isEmpty) return;
      final yes = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
                  title: const Text('تأكيد'),
                  content: Text(data['message'].toString()),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('إلغاء')),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('تأكيد')),
                  ]));
      if (yes == true &&
          mounted &&
          confirmedGeneration == _documentGeneration) {
        await _web?.runJavaScript(
            'window.InzeliConfirm(${ScoreDocument.scriptJson(action)});');
      }
      return;
    }
    if (data['type'] != 'snapshot' || _context == null) return;
    final s = _context!;
    final snapshot = ScoreSnapshot(
        kind: s.kind,
        rosterIds: s.rosterIds,
        teamMode: s.teamMode,
        teams: s.teams,
        storage: Map<String, String>.from(data['storage'] as Map));
    if (snapshot.signature == _remote?.snapshot?.signature &&
        _pending == null) {
      return;
    }
    _pending = snapshot;
    await _saveRecovery();
    if (!mounted) return;
    setState(() {});
    _debounce?.cancel();
    _debounce =
        Timer(const Duration(milliseconds: 750), () => unawaited(_flush()));
  }

  Future<void> _saveRecovery() {
    // Serialize disk writes too: an acknowledged round cannot delete a newer draft.
    _recovery = _recovery.catchError((_) {}).then((_) async {
      final snapshot = _pending ?? _remote?.snapshot;
      if (snapshot == null) return;
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
          _backupKey,
          jsonEncode({
            'revision': _remote?.revision ?? 0,
            'dirty': _pending != null,
            'snapshot': snapshot.toJson(),
          }));
    });
    return _recovery;
  }

  Future<void> _flush() async {
    if (_reading ||
        _writing ||
        _pending == null ||
        !_editable ||
        _conflict ||
        !mounted) {
      return;
    }
    final since = _lastWriteAt == null
        ? 2000
        : DateTime.now().difference(_lastWriteAt!).inMilliseconds;
    if (since < 2000) {
      _debounce?.cancel();
      _debounce = Timer(
          Duration(milliseconds: 2000 - since), () => unawaited(_flush()));
      return;
    }
    _lastWriteAt = DateTime.now();
    _writing = true;
    final snapshot = _pending!;
    try {
      final result = await _api.write(_remote!.revision, snapshot);
      if (!mounted) return;
      _remote = result;
      if (_pending?.signature == snapshot.signature) {
        _pending = null;
      }
      await _saveRecovery();
      if (mounted) setState(() => _error = null);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          if (e is ScoreApiError && (e.status == 409 || e.status == 403)) {
            _conflict = true;
            _recoverySnapshot = _pending;
          }
        });
      }
      if (_conflict) await _web?.runJavaScript('window.InzeliSetReadOnly?.();');
    } finally {
      _writing = false;
      if (_pending != null && !_conflict && mounted) {
        _debounce?.cancel();
        _debounce =
            Timer(const Duration(seconds: 3), () => unawaited(_flush()));
      }
    }
  }

  Future<void> _reload() async {
    // Keep the recovery copy on conflict, but stop this device overwriting another host device.
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_backupKey);
    if (saved != null) {
      await preferences.setString(
          '$_backupKey.recovery.${DateTime.now().millisecondsSinceEpoch}',
          saved);
    }
    _pending = null;
    _conflict = false;
    _remote = null;
    _recoverySnapshot = null;
    await _read(initial: false);
    if (_error == null) await _saveRecovery();
  }

  Future<void> _choose() async {
    if (!_editable) return;
    final own = ScoreKind.forGame(widget.room.value.game);
    final kind = await showModalBottomSheet<ScoreKind>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (ctx) => SingleChildScrollView(
            child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('اختَر القيد — اختياري',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text(
                          'الهوست يسجّل، والكل يشوف النقاط. تقدر تكمل القيم بدون قيد.'),
                      if (own != null)
                        ListTile(
                            leading: const Icon(Icons.style_outlined),
                            title: Text(own.label),
                            onTap: () => Navigator.pop(ctx, own)),
                      ListTile(
                          leading: const Icon(Icons.edit_note),
                          title: const Text('القيد العام'),
                          subtitle: const Text('نقاط موجبة وسالبة'),
                          onTap: () => Navigator.pop(ctx, ScoreKind.general)),
                    ]))));
    if (kind == null || !mounted) return;
    if (_remote?.snapshot != null) {
      final yes = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
                  title: const Text('تغيير نوع القيد؟'),
                  content: const Text(
                      'بيبدأ سجل نقاط جديد للجميع. نتيجة المباراة ما تتغير.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('إلغاء')),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('بدء قيد جديد'))
                  ]));
      if (yes != true || !mounted) return;
    }
    final room = widget.room.value;
    if (room.players.length < 2 ||
        (kind == ScoreKind.trix && room.players.length != 4)) {
      setState(() => _error =
          'قيد التركس يحتاج أربعة لاعبين، وبقية القيود تحتاج لاعبين على الأقل.');
      return;
    }
    if (room.teamMode &&
        (!room.players.any((p) => p.team == 'A') ||
            !room.players.any((p) => p.team == 'B'))) {
      setState(
          () => _error = 'وزّع اللاعبين على الفريقين من صفحة المباراة أولًا.');
      return;
    }
    await _show(ScoreSnapshot(
        kind: kind,
        rosterIds: room.players.map((p) => p.id).toList(),
        teamMode: room.teamMode,
        teams: {
          for (final p in room.players) p.id: room.teamMode ? p.team : null
        },
        storage: {}));
  }

  Future<void> _back() async {
    await _flush();
    if (!mounted) return;
    if (_pending != null) {
      final yes = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
                  title: const Text('النقاط لم تتزامن بعد'),
                  content: const Text(
                      'محفوظة على هذا الجهاز. جرّب المزامنة أو ارجع للمباراة وكمّلها لاحقًا.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('انتظار')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('رجوع للمباراة'))
                  ]));
      if (yes != true || !mounted) return;
    }
    setState(() => _allowPop = true);
    await Future<void>.delayed(Duration.zero);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _qr() => showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) => SingleChildScrollView(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('QR القيم',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                SizedBox(
                    width: 220,
                    height: 220,
                    child: QrImageView(
                        data:
                            'https://inzeli.app/join/${widget.room.value.code}',
                        backgroundColor: Colors.white)),
                const SizedBox(height: 12),
                SelectableText(widget.room.value.code),
                const SizedBox(height: 10),
                const Text('الانضمام يبقى حسب حالة الغرفة والعداد.'),
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('الرجوع للقيد')),
              ]))));
  Widget _panel(ScoreRoomInfo room) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 4,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.timer_outlined, size: 20),
                const SizedBox(width: 6),
                Text(
                    room.startedAt == null
                        ? 'العداد ما بدأ'
                        : '${(room.remaining() ~/ 60).toString().padLeft(2, '0')}:${(room.remaining() % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold))
              ]),
              Text(
                  _conflict
                      ? 'تعارض في المزامنة'
                      : _pending != null
                          ? 'بانتظار المزامنة'
                          : _host
                              ? 'أنت الهوست · تقدر تعدّل'
                              : 'عرض مباشر · الهوست يعدّل',
                  style: const TextStyle(fontSize: 12)),
            ]),
        ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('اللاعبون (${_people.length})'),
            children: [
              if (_context?.teamMode ?? room.teamMode) ...[
                for (final team in ['A', 'B'])
                  _peopleGroup(
                      'الفريق $team',
                      _people
                          .where(
                              (p) => (_context?.teams[p.id] ?? p.team) == team)
                          .toList()),
              ] else
                _peopleGroup('', _people),
            ]),
      ]);
  Widget _peopleGroup(String label, List<ScorePerson> people) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (label.isNotEmpty)
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            children: people
                .map((p) => Chip(
                    avatar: _avatar(p),
                    label: Text(p.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis)))
                .toList()),
      ]));
  Widget _avatar(ScorePerson p) {
    ImageProvider? image;
    try {
      if (p.avatar?.startsWith('data:') ?? false) {
        image = MemoryImage(base64Decode(p.avatar!.split(',').last));
      } else if (p.avatar != null) {
        image = NetworkImage(p.avatar!);
      }
    } catch (_) {/* An invalid photo must never block entering a score. */}
    return CircleAvatar(
        backgroundImage: image,
        onBackgroundImageError: image == null ? null : (_, __) {},
        child: image == null
            ? Text(p.name.isEmpty ? '؟' : p.name.characters.first)
            : null);
  }

  @override
  Widget build(BuildContext context) {
    final content = _loading
        ? const Center(child: CircularProgressIndicator())
        : _web != null
            ? Stack(children: [
                Positioned.fill(
                    child: WebViewWidget(key: _webViewKey, controller: _web!)),
                if (!_ready) const Center(child: CircularProgressIndicator()),
              ])
            : Center(
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.edit_note, size: 54),
                      const SizedBox(height: 12),
                      Text(_host ? 'القيد اختياري' : 'الهوست ما فتح قيد للحين'),
                      const SizedBox(height: 12),
                      if (_editable)
                        FilledButton(
                            onPressed: _choose,
                            child: const Text('اختيار القيد')),
                      TextButton(
                          onPressed: _back,
                          child: const Text('الرجوع للمباراة')),
                    ])));
    return Theme(
        data: ScoreAppearance.theme,
        child: Directionality(
            textDirection: TextDirection.rtl,
            child: PopScope(
              canPop: _allowPop,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop) unawaited(_back());
              },
              child: Scaffold(
                backgroundColor: ScoreAppearance.background,
                appBar: AppBar(
                    leading: IconButton(
                        onPressed: _back,
                        icon: const Icon(Icons.arrow_back),
                        tooltip: 'الرجوع للمباراة'),
                    title: Text(_context?.kind.label ?? 'قيد المباراة',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    actions: [
                      IconButton(
                          onPressed: _qr,
                          icon: const Icon(Icons.qr_code),
                          tooltip: 'عرض QR'),
                      if (_editable)
                        IconButton(
                            onPressed:
                                _writing || _pending != null ? null : _choose,
                            icon: const Icon(Icons.style_outlined),
                            tooltip: 'اختيار نوع القيد'),
                    ]),
                body: SafeArea(
                    child: Column(children: [
                  if (_error != null)
                    MaterialBanner(
                        overflowAlignment: OverflowBarAlignment.end,
                        content:
                            Text(_error!, style: const TextStyle(fontSize: 12)),
                        actions: [
                          if (_recoverySnapshot != null)
                            TextButton(
                                onPressed: () => _show(_recoverySnapshot!),
                                child: const Text('عرض نسخة الجهاز')),
                          TextButton(
                              onPressed: _conflict ? _reload : _poll,
                              child: Text(_conflict
                                  ? 'تحميل القيد المشترك'
                                  : 'إعادة المحاولة')),
                        ]),
                  Expanded(
                      child: ValueListenableBuilder<ScoreRoomInfo>(
                          valueListenable: widget.room,
                          builder: (context, room, _) => AdaptiveGameFrame(
                              panel: _panel(room), content: content))),
                ])),
              ),
            )));
  }
}

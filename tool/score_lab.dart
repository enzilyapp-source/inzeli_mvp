// Development entrypoint only. It refuses production URLs and is not imported by main.dart.
// Uses the real API, real PostgreSQL and the real in-app score screen on two simulators.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:inzeli/api_base.dart';
import 'package:inzeli/api_room.dart';
import 'package:inzeli/pages/match_page.dart';
import 'package:inzeli/pages/scorekeeper/room_score_page.dart';
import 'package:inzeli/scorekeeper/score_models.dart';
import 'package:inzeli/state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final uri = Uri.parse(apiBase);
  if (!['localhost', '127.0.0.1'].contains(uri.host) || uri.port != 48189) {
    runApp(const MaterialApp(
        home: Scaffold(body: Center(child: Text('المختبر يشتغل محليًا فقط')))));
    return;
  }
  runApp(const ScoreLab());
}

class ScoreLab extends StatelessWidget {
  const ScoreLab({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate
        ],
        supportedLocales: const [Locale('ar')],
        theme: ThemeData(
            useMaterial3: true,
            fontFamily: 'Tajawal',
            colorScheme:
                ColorScheme.fromSeed(seedColor: const Color(0xFF16383D))),
        home: const _LabHome(),
      );
}

class _LabHome extends StatefulWidget {
  const _LabHome();
  @override
  State<_LabHome> createState() => _LabHomeState();
}

class _LabHomeState extends State<_LabHome> {
  final app = AppState();
  ValueNotifier<ScoreRoomInfo>? info;
  Timer? ticker;
  Map<String, dynamic>? room;
  String? error;
  bool get guest =>
      const String.fromEnvironment('SCORE_LAB_ROLE', defaultValue: 'host') ==
      'guest';
  static const code = String.fromEnvironment('SCORE_LAB_ROOM');
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    ticker?.cancel();
    info?.dispose();
    app.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final response = await http.post(Uri.parse('$apiBase/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email':
                guest ? 'guest@score-lab.invalid' : 'host@score-lab.invalid',
            'password': 'ScoreLab-Local-Only-2026'
          }));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['ok'] != true) throw StateError('Local login failed');
      final auth = Map<String, dynamic>.from(body['data'] as Map),
          user = Map<String, dynamic>.from(auth['user'] as Map);
      app.token = auth['token'] as String;
      app.userId = user['id'] as String;
      app.displayName = user['displayName'] as String;
      app.email = user['email'] as String;
      app.creditPoints = 5;
      app.selectedGame = 'هند';
      app.selectedCategory = 'جنجفة';
      app.roomCode = code;
      app.soundMuted = true;
      room = await ApiRoom.getRoomByCode(code, token: app.token);
      final players = (room!['players'] as List)
          .map((p) => ScorePerson.fromRoom(Map<String, dynamic>.from(p as Map)))
          .toList();
      final initial = ScoreRoomInfo(
          code: code,
          game: 'هند',
          hostId: room!['hostUserId'].toString(),
          players: players,
          teamMode: false,
          startedAt: DateTime.parse(room!['startedAt'].toString()),
          timerSeconds: (room!['timerSec'] as num).toInt());
      info = ValueNotifier(initial);
      ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        info!.value = ScoreRoomInfo(
            code: initial.code,
            game: initial.game,
            hostId: initial.hostId,
            players: initial.players,
            teamMode: false,
            startedAt: initial.startedAt,
            timerSeconds: initial.timerSeconds);
      });
      if (!mounted) return;
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scores();
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  void _scores() => Navigator.push(
      context,
      MaterialPageRoute<void>(
          builder: (_) => RoomScorePage(
              room: info!, userId: app.userId!, token: app.token)));
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: Text(
              guest ? 'مختبر القيد · اللاعب الثاني' : 'مختبر القيد · الهوست')),
      body: SafeArea(
          child: Center(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.science_outlined, size: 50),
                    const SizedBox(height: 16),
                    const Text('بيئة محلية — حسابات وهمية وبيانات منفصلة',
                        textAlign: TextAlign.center),
                    if (error != null) Text(error!),
                    if (info == null && error == null)
                      const Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator()),
                    if (info != null) ...[
                      const SizedBox(height: 12),
                      Text('غرفة الهند: $code'),
                      Text('أنت: ${app.displayName}'),
                      const SizedBox(height: 16),
                      FilledButton(
                          onPressed: _scores, child: const Text('فتح القيد')),
                      TextButton(
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                  builder: (_) =>
                                      MatchPage(app: app, room: room))),
                          child: const Text('صفحة المباراة والـQR')),
                    ],
                  ])))));
}

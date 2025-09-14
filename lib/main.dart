// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';

// App state & pages
import 'state.dart';
import 'pages/games_page.dart';
import 'pages/leaderboard_page.dart';
import 'pages/timeline_page.dart';
import 'pages/sponsor_page.dart';
import 'pages/profile_page.dart';
import 'pages/signin_page.dart';

// Your HTTP API (custom backend)
import 'api_room.dart'; // <- must expose joinByCode({code,userId}) and optionally getRoomByCode(code)

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final app = AppState();
  await app.load();

  runApp(InzeliApp(app: app));
}

class InzeliApp extends StatelessWidget {
  final AppState app;
  const InzeliApp({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFFC5533C));
    return Directionality(
      textDirection: TextDirection.rtl,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'انزلي',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: scheme,
          scaffoldBackgroundColor: const Color(0xFFF7F0E3),
          appBarTheme: const AppBarTheme(
            elevation: 0,
            centerTitle: true,
            backgroundColor: Color(0xFFF7F0E3),
            foregroundColor: Colors.black,
            titleTextStyle: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black),
          ),
          // Your SDK expects CardThemeData (not CardTheme)
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 2,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
              side: BorderSide(color: Color(0xFFEADFCC)),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.transparent),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Color(0xFFC5533C), width: 1.4),
            ),
            labelStyle: const TextStyle(color: Colors.black87),
            hintStyle: const TextStyle(color: Colors.black54),
          ),
        ),
        home: HomeShell(app: app),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  final AppState app;
  const HomeShell({super.key, required this.app});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  AppLinks? _appLinks;
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  // Handle both HTTPS URLs (e.g., https://inzeli.app/join/CODE) and custom scheme (inzeli://join?code=CODE)
  Future<void> _initDeepLinks() async {
    try {
      _appLinks = AppLinks();

      // Get initial link (handle both new & old API names to avoid version issues)
      Uri? initialUri;
      try {
        initialUri = await _appLinks!.getInitialLink(); // app_links >= 6.x
      } catch (_) {
        final dyn = _appLinks as dynamic;
        try {
          final res = await dyn.getInitialLink(); // older versions
          if (res is Uri) initialUri = res;
        } catch (_) {}
      }
      if (initialUri != null) await _handleUri(initialUri);

      // Stream deep links while app is running
      _linkSub = _appLinks!.uriLinkStream.listen(
            (uri) => _handleUri(uri),
        onError: (err) => debugPrint('Deep link stream error: $err'),
      );
    } catch (e) {
      debugPrint('AppLinks init error: $e');
    }
  }

  Future<void> _handleUri(Uri uri) async {
    if (!mounted) return;

    // 1) HTTPS path: https://inzeli.app/join/<CODE>
    if (uri.scheme == 'https' && uri.host == 'inzeli.app') {
      if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'join') {
        if (uri.pathSegments.length >= 2) {
          final code = uri.pathSegments[1];
          await _joinRoom(code);
          return;
        }
      }
    }

    // 2) Fallback custom scheme: inzeli://join?code=<CODE>
    if (uri.scheme == 'inzeli' && uri.host == 'join') {
      final code = uri.queryParameters['code'] ?? '';
      if (code.isNotEmpty) {
        await _joinRoom(code);
        return;
      }
    }
  }

  Future<void> _joinRoom(String code) async {
    try {
      // TODO: replace this with your real current user ID (or JWT in headers)
      const guestUserId = 'GUEST_USER_ID_FROM_DB';
      await joinByCode(code: code, userId: guestUserId);
      // Optional: fetch room info
      // final room = await getRoomByCode(code);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('انضمّيت للروم $code ✅')),
      );

      // (Optional) navigate to a match screen with that room data
      // Navigator.push(context, MaterialPageRoute(builder: (_) => MatchPage(app: widget.app, supaRoom: room)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر الانضمام: $e')),
      );
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;

    // Keep pages and bottom destinations in sync (exactly 5)
    final pages = <Widget>[
      GamesPage(app: app),       // 0
      LeaderboardPage(app: app), // 1
      SponsorPage(app: app),     // 2
      TimelinePage(app: app),    // 3
      ProfilePage(app: app),     // 4
    ];
    final titles = <String>[
      'انزلي','المراتب','سبونسر','السالفة؟','حسابي'
    ];

    // Guard index in case of hot-reload mismatches
    if (_tab < 0 || _tab >= pages.length) {
      _tab = 0;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_tab]),
        actions: [
          IconButton(
            tooltip: 'تسجيل',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SignInPage(state: app)),
              );
            },
            icon: const Icon(Icons.person_add_alt_1),
          ),

          // Optional: a quick debug button to test API ping without touching main structure
          // IconButton(
          //   tooltip: 'Ping API',
          //   onPressed: () async {
          //     // Example: call http.get('$apiBase/ping') and show result
          //   },
          //   icon: const Icon(Icons.bug_report_outlined),
          // ),
        ],
      ),
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.play_circle_outline), label: 'انزلي'),
          NavigationDestination(icon: Icon(Icons.emoji_events_outlined), label: 'المراتب'),
          NavigationDestination(icon: Icon(Icons.star_border), label: 'سبونسر'),
          NavigationDestination(icon: Icon(Icons.history), label: 'سالفة؟'),
          NavigationDestination(icon: Icon(Icons.account_circle_outlined), label: 'حسابي'),
        ],
      ),
    );
  }
}

// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'state.dart';

// pages
import 'pages/games_page.dart';
import 'pages/leaderboard_hub_page.dart'; // ✅ NEW (leaderboards first)
import 'pages/timeline_page.dart';
import 'pages/profile_page.dart';
import 'pages/signin_page.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() => runApp(const InzeliApp());

class InzeliApp extends StatelessWidget {
  const InzeliApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inzeli',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ar'), Locale('en')],
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        fontFamily: 'Tajawal',
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFFE49A2C), // البرتقالي للأكشن
          secondary: const Color(0xFF5E9EB4), // أزرق فاتح للأيقونات
          surface: const Color(0xFF1C273B),
          onSurface: Colors.white,
          outline: Colors.white.withValues(alpha: 0.12),
        ),
        scaffoldBackgroundColor: const Color(0xFF223448),
        textButtonTheme: TextButtonThemeData(
          style: ButtonStyle(
            foregroundColor: const WidgetStatePropertyAll(Color(0xFFE49A2C)),
            textStyle: const WidgetStatePropertyAll(
              TextStyle(
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: ButtonStyle(
            foregroundColor: const WidgetStatePropertyAll(Color(0xFFE49A2C)),
            side: WidgetStatePropertyAll(
              BorderSide(color: Colors.white.withValues(alpha: 0.35)),
            ),
            textStyle: const WidgetStatePropertyAll(
              TextStyle(
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: ButtonStyle(
            backgroundColor: const WidgetStatePropertyAll(Color(0xFFE9F2FB)),
            foregroundColor: const WidgetStatePropertyAll(Color(0xFFE49A2C)),
            textStyle: const WidgetStatePropertyAll(
              TextStyle(
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: const WidgetStatePropertyAll(Color(0xFFE9F2FB)),
            foregroundColor: const WidgetStatePropertyAll(Color(0xFFE49A2C)),
            textStyle: const WidgetStatePropertyAll(
              TextStyle(
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Color(0xFF1C273B),
          indicatorColor: Color(0xFF3F6F82),
          surfaceTintColor: Colors.transparent,
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(
              fontFamily: 'Tajawal',
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AppState app = AppState();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await app.load(); // SharedPreferences (auth)
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return app.isSignedIn ? HomePage(app: app) : SignInPage(app: app);
  }
}

class HomePage extends StatefulWidget {
  final AppState app;
  const HomePage({super.key, required this.app});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    widget.app.addListener(_onAppChange);
  }

  @override
  void dispose() {
    widget.app.removeListener(_onAppChange);
    super.dispose();
  }

  void _onAppChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;

    // ✅ New order: Leaderboards first
    final pages = [
      LeaderboardHubPage(key: const ValueKey('lb-regular'), app: app),
      GamesPage(app: app),
      TimelinePage(app: app),
      LeaderboardHubPage(key: const ValueKey('lb-sponsor'), app: app, initialTab: 1), // الراعي جنب شسالفه؟
      ProfilePage(app: app), // الملف آخر أيقونة (يمين)
    ];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF34677A), // lighter top
              Color(0xFF232E4A), // darker bottom
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 8),
              Text(
                '',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _TopProfileCard(app: app),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: pages[_index],
                ),
              ),
            ],
          ),
        ),
      ),

      // ✅ Bottom Nav updated labels/icons order
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.emoji_events_outlined),
            selectedIcon: const Icon(Icons.emoji_events),
            label: app.tr(ar: 'المراتب', en: 'Leaders'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.sports_esports_outlined),
            selectedIcon: const Icon(Icons.sports_esports),
            label: app.tr(ar: 'الألعاب', en: 'Games'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.help_outline),
            selectedIcon: const Icon(Icons.help),
            label: app.tr(ar: 'شسالفة؟', en: 'Timeline'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.tv_outlined),
            selectedIcon: const Icon(Icons.tv),
            label: app.tr(ar: 'سبونسرات', en: 'Sponsors'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: app.tr(ar: 'ملفي', en: 'Profile'),
          ),
        ],
      ),
    );
  }
}

/// top profile card
class _TopProfileCard extends StatelessWidget {
  final AppState app;
  const _TopProfileCard({required this.app});

  @override
  Widget build(BuildContext context) {
    final pearls = app.creditPoints ?? 0; // (or app.pearls if you renamed)
    final name = app.displayName ?? app.name ?? '—';
    final email = app.email ?? app.phone ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF172133).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFF273347),
            child: Text(
              name.isNotEmpty ? name.characters.first : '؟',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF232E4A),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Image.asset(
                  'lib/assets/pearl.png',
                  width: 18,
                  height: 18,
                ),
                const SizedBox(width: 4),
                Text(
                  '$pearls',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

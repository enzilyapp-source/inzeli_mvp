// lib/main.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'state.dart';
import 'widgets/avatar_effects.dart';

// pages
import 'pages/games_page.dart';
import 'pages/leaderboard_hub_page.dart'; // ✅ NEW (leaderboards first)
import 'pages/timeline_page.dart';
import 'pages/profile_page.dart';
import 'pages/signin_page.dart';

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
              if (_index != 4) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _TopProfileCard(
                    app: app,
                    onTap: () => setState(() => _index = 4),
                  ),
                ),
                const SizedBox(height: 12),
              ],
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
  final VoidCallback? onTap;
  const _TopProfileCard({required this.app, this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = app.displayName ?? app.name ?? '—';
    final id = app.publicId ?? app.userId ?? '';
    final cardColor = _cardColor(app.cardId);
    final effect = _effectFromId(app.themeId);
    ImageProvider? avatarImage;
    if (app.avatarBase64 != null && app.avatarBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(app.avatarBase64!);
        avatarImage = MemoryImage(bytes);
      } catch (_) {}
    }

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (effect != null)
                  AvatarEffect(
                    effect: effect,
                    size: 82,
                    animate: true,
                    child: CircleAvatar(
                      radius: 28,
                      backgroundImage: avatarImage,
                      backgroundColor: const Color(0xFF273347),
                      child: avatarImage == null
                          ? Text(
                              name.isNotEmpty ? name.characters.first : '؟',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                  )
                else
                  CircleAvatar(
                    radius: 28,
                    backgroundImage: avatarImage,
                    backgroundColor: const Color(0xFF273347),
                    child: avatarImage == null
                        ? Text(
                            name.isNotEmpty ? name.characters.first : '؟',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                const SizedBox(height: 8),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (id.isNotEmpty)
                  Text(
                    _shortId(id),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                      letterSpacing: 0.2,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _shortId(String raw) {
    final clean = raw.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (clean.isEmpty) return '';
    final short = clean.length > 6 ? clean.substring(clean.length - 6) : clean.padLeft(6, '0');
    return '#$short';
  }

  Color _cardColor(String? id) {
    switch (id) {
      case 'navy':
        return const Color(0xFF0F1D32);
      case 'violet':
        return const Color(0xFF2D1B46);
      case 'blue':
      default:
        return const Color(0xFF1E2F4D);
    }
  }

  AvatarEffectType? _effectFromId(String? id) {
    switch (id) {
      case 'blueThunder':
        return AvatarEffectType.blueThunder;
      case 'goldLightning':
        return AvatarEffectType.goldLightning;
      case 'kuwait':
        return AvatarEffectType.kuwaitSparkles;
      case 'greenLeaf':
        return AvatarEffectType.greenLeaf;
      case 'flameBlue':
        return AvatarEffectType.flameBlue;
      default:
        return null;
    }
  }
}

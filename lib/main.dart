// lib/main.dart
import 'dart:async';
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

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  final AppState app = AppState();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    app.addListener(_onAppChanged);
    _boot();
  }

  @override
  void dispose() {
    app.removeListener(_onAppChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && app.isSignedIn) {
      unawaited(app.refreshSessionFromServer());
    }
  }

  void _onAppChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _boot() async {
    await app.load(); // SharedPreferences (auth)
    if (app.isSignedIn) {
      unawaited(app.refreshSessionFromServer(force: true));
    }
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
      GamesPage(app: app, embedded: true),
      TimelinePage(app: app),
      LeaderboardHubPage(
          key: const ValueKey('lb-sponsor'),
          app: app,
          initialTab: 1), // الراعي جنب شسالفه؟
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
              const SizedBox(height: 6),
              if (_index != 4) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _TopProfileCard(
                    app: app,
                    onTap: () => setState(() => _index = 4),
                  ),
                ),
                const SizedBox(height: 4),
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
    final (topGame, topPearls) = _topPearlGame(app);
    final savedRank = app.bestBadgeLabel();
    final rank = savedRank == null
        ? _rankLabelForPearls(topPearls)
        : _rankLabelForBadge(savedRank);
    final recentWins = _recentWins(name);
    final screenWidth = MediaQuery.of(context).size.width;
    final compact = screenWidth < 430;
    final cardHeight = compact ? 156.0 : 164.0;
    final avatarEffectSize = compact ? 98.0 : 102.0;
    final avatarRadius = compact ? 37.0 : 39.0;
    final badgeLift = compact ? -22.0 : -20.0;
    final pearlSize = compact ? 58.0 : 62.0;
    final trophySize = compact ? 38.0 : 40.0;
    final badgeRowSlotHeight = compact ? 32.0 : 34.0;
    final badgeRowMaxHeight = compact ? 90.0 : 96.0;
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
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: cardHeight,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              children: [
                PositionedDirectional(
                  top: 8,
                  start: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white24, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.workspace_premium,
                            size: 16, color: Color(0xFFF1A949)),
                        const SizedBox(width: 6),
                        Text(
                          rank,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (effect != null)
                        AvatarEffect(
                          effect: effect,
                          size: avatarEffectSize,
                          animate: true,
                          child: CircleAvatar(
                            radius: avatarRadius,
                            backgroundImage: avatarImage,
                            backgroundColor: const Color(0xFF273347),
                            child: avatarImage == null
                                ? Text(
                                    name.isNotEmpty
                                        ? name.characters.first
                                        : '؟',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 24,
                                      color: Colors.white,
                                    ),
                                  )
                                : null,
                          ),
                        )
                      else
                        CircleAvatar(
                          radius: avatarRadius,
                          backgroundImage: avatarImage,
                          backgroundColor: const Color(0xFF273347),
                          child: avatarImage == null
                              ? Text(
                                  name.isNotEmpty ? name.characters.first : '؟',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 24,
                                    color: Colors.white,
                                  ),
                                )
                              : null,
                        ),
                      const SizedBox(height: 6),
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
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
                ),
              ],
            ),
          ),
          SizedBox(
            height: badgeRowSlotHeight,
            child: OverflowBox(
              minHeight: 0,
              maxHeight: badgeRowMaxHeight,
              alignment: Alignment.topCenter,
              child: Transform.translate(
                offset: Offset(0, badgeLift),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _MainPearlBadge(
                      game: topGame,
                      pearls: topPearls,
                      size: pearlSize,
                    ),
                    _MainTrophyStrip(recentWins: recentWins, size: trophySize),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 0),
        ],
      ),
    );
  }

  (String, int) _topPearlGame(AppState app) {
    if (app.gamePearls.isNotEmpty) {
      final top =
          app.gamePearls.entries.reduce((a, b) => a.value >= b.value ? a : b);
      return (app.gameLabel(top.key), top.value);
    }
    if (app.selectedGame != null && app.selectedGame!.isNotEmpty) {
      return (
        app.gameLabel(app.selectedGame!),
        app.pearlsForGame(app.selectedGame!)
      );
    }
    return (app.tr(ar: 'بدون لعبة', en: 'No game'), 0);
  }

  List<(String, DateTime)> _recentWins(String player) {
    final wins = app.timeline.where((t) => t.winner == player).toList()
      ..sort((a, b) => b.ts.compareTo(a.ts));
    return wins.take(3).map((t) => (app.gameLabel(t.game), t.ts)).toList();
  }

  String _rankLabelForPearls(int pearls) {
    if (pearls >= 30) return app.tr(ar: 'فلتة', en: 'GOAT');
    if (pearls >= 20) return app.tr(ar: 'فنان', en: 'Legend');
    if (pearls >= 15) return app.tr(ar: 'زين', en: 'Professional');
    if (pearls >= 10) return app.tr(ar: 'يمشي حاله', en: 'Advance');
    if (pearls >= 5) return app.tr(ar: 'عليمي', en: 'Beginner');
    return app.tr(ar: 'بدايات', en: 'New');
  }

  String _rankLabelForBadge(String label) {
    return app.tr(
      ar: label,
      en: switch (label) {
        'عليمي' => 'Beginner',
        'يمشي حاله' => 'Advance',
        'زين' => 'Professional',
        'فنان' => 'Legend',
        'فلتة' => 'GOAT',
        _ => label,
      },
    );
  }

  String _shortId(String raw) {
    final clean = raw.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (clean.isEmpty) return '';
    final short = clean.length > 6
        ? clean.substring(clean.length - 6)
        : clean.padLeft(6, '0');
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
      case 'whiteSparkle':
        return AvatarEffectType.whiteSparkle;
      default:
        return null;
    }
  }
}

class _MainPearlBadge extends StatelessWidget {
  final String game;
  final int pearls;
  final double size;
  const _MainPearlBadge({
    required this.game,
    required this.pearls,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    final valueFont = size * 0.28;
    final labelFont = size * 0.17;
    final topOffset = size * 0.2;
    final bottomOffset = size * 0.18;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: topOffset,
            left: 0,
            right: 0,
            child: Text(
              '$pearls',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF1E2F4D),
                fontWeight: FontWeight.w900,
                fontSize: valueFont,
              ),
            ),
          ),
          Positioned(
            bottom: bottomOffset,
            left: 8,
            right: 8,
            child: Text(
              game,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w700,
                fontSize: labelFont,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MainTrophyStrip extends StatelessWidget {
  final List<(String, DateTime)> recentWins;
  final double size;
  const _MainTrophyStrip({
    required this.recentWins,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final filled = i < recentWins.length;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: _MainTrophyCircle(
            filled: filled,
            size: size,
          ),
        );
      }),
    );
  }
}

class _MainTrophyCircle extends StatelessWidget {
  final bool filled;
  final double size;
  const _MainTrophyCircle({
    required this.filled,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        Icons.emoji_events_rounded,
        size: size * 0.5,
        color: filled ? Colors.amber : Colors.grey.shade400,
      ),
    );
  }
}

// lib/main.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'biometric_auth.dart';
import 'state.dart';
import 'widgets/challenge_rank_visuals.dart';
import 'widgets/primary_pill_button.dart';

// pages
import 'pages/games_page.dart';
import 'pages/leaderboard_hub_page.dart'; // ✅ NEW (leaderboards first)
import 'pages/dewanyah_list_page.dart';
import 'pages/profile_page.dart';
import 'pages/signin_page.dart';
import 'pages/sponsor_page.dart';
import 'push/one_signal_bridge.dart';

const String _oneSignalPromptSeenKey = 'onesignal_permission_prompt_seen';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OneSignalBridge.initialize();
  runApp(const InzeliApp());
}

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
  bool _biometricUnlocked = false;
  bool _biometricPrompting = false;
  bool _notificationPromptQueued = false;

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
    if (!app.isSignedIn || !app.biometricEnabled) {
      _biometricUnlocked = true;
    }
    if (!app.isSignedIn) {
      _notificationPromptQueued = false;
    }
    if (mounted) setState(() {});
    _scheduleNotificationPrompt();
  }

  Future<void> _boot() async {
    await app.load(); // SharedPreferences (auth)
    if (app.isSignedIn) {
      unawaited(app.refreshSessionFromServer(force: true));
    }
    _biometricUnlocked = !app.isSignedIn || !app.biometricEnabled;
    if (mounted) {
      setState(() => _loading = false);
      if (!_biometricUnlocked) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_unlockWithBiometrics());
        });
      } else {
        _scheduleNotificationPrompt();
      }
    }
  }

  Future<void> _unlockWithBiometrics() async {
    if (_biometricPrompting || !app.isSignedIn) return;
    _biometricPrompting = true;
    if (mounted) setState(() {});
    try {
      final available = await BiometricAuthService.isAvailable();
      if (!available) {
        app.setBiometricEnabled(false);
        _biometricUnlocked = true;
        return;
      }

      final ok = await BiometricAuthService.authenticate(
        reason: 'استخدم Face ID لفتح إنزلي',
      );
      if (ok) _biometricUnlocked = true;
    } finally {
      _biometricPrompting = false;
      if (mounted) setState(() {});
      if (_biometricUnlocked) _scheduleNotificationPrompt();
    }
  }

  void _scheduleNotificationPrompt() {
    if (_notificationPromptQueued) return;
    if (!mounted || !app.isSignedIn) return;
    if (app.biometricEnabled && !_biometricUnlocked) return;
    if (!OneSignalBridge.isSupported) return;

    _notificationPromptQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_maybeAskForNotificationPermission());
    });
  }

  Future<void> _maybeAskForNotificationPermission() async {
    if (!mounted || !app.isSignedIn) return;
    if (app.biometricEnabled && !_biometricUnlocked) return;
    if (!OneSignalBridge.isSupported) return;

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    if (prefs.getBool(_oneSignalPromptSeenKey) ?? false) return;

    final enable = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1C273B),
          title: const Text(
            'فعّل إشعارات إنزلي',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'بنطرش لك تنبيهات النتائج، تغييرات الليدر بورد، وانتهاء السيزن.',
            style: TextStyle(color: Color(0xFFE5ECF7)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('لاحقاً'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('فعّل الإشعار'),
            ),
          ],
        ),
      ),
    );

    await prefs.setBool(_oneSignalPromptSeenKey, true);
    if (enable == true) {
      await OneSignalBridge.requestPermission();
    }
  }

  Future<void> _logoutFromLock() async {
    await app.clearAuth();
    _biometricUnlocked = true;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const _LaunchSplashScreen();
    }

    if (app.isSignedIn && app.biometricEnabled && !_biometricUnlocked) {
      return _BiometricUnlockPage(
        busy: _biometricPrompting,
        onUnlock: _unlockWithBiometrics,
        onLogout: _logoutFromLock,
      );
    }

    return app.isSignedIn ? HomePage(app: app) : SignInPage(app: app);
  }
}

class _LaunchSplashScreen extends StatefulWidget {
  const _LaunchSplashScreen();

  @override
  State<_LaunchSplashScreen> createState() => _LaunchSplashScreenState();
}

class _LaunchSplashScreenState extends State<_LaunchSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF609EB3),
              Color(0xFF5792A6),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: Tween<double>(begin: 0.82, end: 1).animate(curved),
              child: AnimatedBuilder(
                animation: curved,
                builder: (context, child) {
                  final pulse = 1 + math.sin(curved.value * math.pi) * 0.035;
                  return Transform.scale(scale: pulse, child: child);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 148,
                      height: 148,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFB8DFFF).withValues(
                              alpha: 0.22,
                            ),
                            blurRadius: 34,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'lib/assets/enzeli_logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'إنزلي',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'نجتمع، نلعب، ونحسبها صح',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BiometricUnlockPage extends StatelessWidget {
  final bool busy;
  final VoidCallback onUnlock;
  final VoidCallback onLogout;

  const _BiometricUnlockPage({
    required this.busy,
    required this.onUnlock,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF34677A), Color(0xFF232E4A)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'lib/assets/enzeli_logo.png',
                      width: 96,
                      height: 96,
                    ),
                    const SizedBox(height: 18),
                    const Icon(Icons.face, size: 56, color: Colors.white),
                    const SizedBox(height: 12),
                    const Text(
                      'فتح إنزلي',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'استخدم Face ID للدخول إلى حسابك المحفوظ على هذا الجهاز',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 20),
                    PrimaryPillButton(
                      label: 'فتح بـ Face ID',
                      onPressed: busy ? null : onUnlock,
                      icon: Icons.face,
                      loading: busy,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: busy ? null : onLogout,
                      child: const Text('تسجيل خروج'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
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

    // ترتيب التبّات من اليمين لليسار: الرئيسية، الألعاب، دواوين، سبونسرات، ملفي.
    final pages = [
      LeaderboardHubPage(key: const ValueKey('lb-regular'), app: app),
      GamesPage(app: app, embedded: true),
      DewanyahListPage(app: app),
      SponsorPage(app: app, embedded: true),
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
      bottomNavigationBar: Directionality(
        textDirection: TextDirection.rtl,
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: app.tr(ar: 'الرئيسية', en: 'Home'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.sports_esports_outlined),
              selectedIcon: const Icon(Icons.sports_esports),
              label: app.tr(ar: 'الألعاب', en: 'Games'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.groups_3_outlined),
              selectedIcon: const Icon(Icons.groups_3),
              label: app.tr(ar: 'دواوين', en: 'Dewanyahs'),
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
    final rank = _bestRankLabel(topPearls);
    final recentWins = _recentWins(name);
    final screenWidth = MediaQuery.of(context).size.width;
    final compact = screenWidth < 430;
    final cardHeight = compact ? 156.0 : 164.0;
    final avatarRadius = compact ? 37.0 : 39.0;
    final badgeLift = compact ? -22.0 : -20.0;
    final pearlSize = compact ? 58.0 : 62.0;
    final trophySize = compact ? 38.0 : 40.0;
    final badgeRowSlotHeight = compact ? 32.0 : 34.0;
    final badgeRowMaxHeight = compact ? 90.0 : 96.0;
    final cardColor = _cardColor(app.cardId);
    final rankVisual = playerRankForLabel(rank);
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
                  child: RankBadge(rank: rankVisual, compact: true),
                ),
                PositionedDirectional(
                  top: 8,
                  end: 10,
                  child: _NotificationBell(
                    count: app.unreadNotificationCount,
                    onTap: () => _openNotifications(context, app),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      buildAvatarThemeWidget(
                        themeId: app.themeId,
                        size: compact ? 98.0 : 102.0,
                        animate: true,
                        child: CircleAvatar(
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

  void _openNotifications(BuildContext context, AppState app) {
    app.markNotificationsRead();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFF1C273B),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.notifications_rounded,
                        color: Color(0xFFE49A2C)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'الإشعارات',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (app.notifications.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          app.clearNotifications();
                          Navigator.pop(ctx);
                        },
                        child: const Text('مسح'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (app.notifications.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: Text(
                      'ما عندك إشعارات حالياً',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: math.min(app.notifications.length, 30),
                      separatorBuilder: (_, __) => Divider(
                        color: Colors.white.withValues(alpha: 0.08),
                        height: 1,
                      ),
                      itemBuilder: (_, index) {
                        final entry = app.notifications[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor:
                                _notificationColor(entry.type).withValues(
                              alpha: 0.18,
                            ),
                            child: Icon(
                              _notificationIcon(entry.type),
                              color: _notificationColor(entry.type),
                              size: 20,
                            ),
                          ),
                          title: Text(
                            entry.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          subtitle: Text(
                            '${entry.body}\n${_notificationTime(entry.createdAt)}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.68),
                              height: 1.35,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _notificationIcon(String type) {
    return switch (type) {
      'badge' => Icons.workspace_premium_rounded,
      'win' => Icons.emoji_events_rounded,
      'loss' => Icons.sports_score_rounded,
      _ => Icons.notifications_rounded,
    };
  }

  Color _notificationColor(String type) {
    return switch (type) {
      'badge' => Colors.amber,
      'win' => Colors.greenAccent,
      'loss' => Colors.redAccent,
      _ => const Color(0xFFE49A2C),
    };
  }

  String _notificationTime(DateTime value) {
    final now = DateTime.now();
    final diff = now.difference(value);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inHours < 1) return 'قبل ${diff.inMinutes} د';
    if (diff.inDays < 1) return 'قبل ${diff.inHours} س';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
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

  String _bestRankLabel(int pearls) {
    final savedRank = app.bestBadgeLabel();
    final savedThreshold = app.bestBadgeThreshold();
    final currentThreshold = AppState.badgeThresholdForPearls(pearls);
    if (savedRank != null && savedThreshold > currentThreshold) {
      return _rankLabelForBadge(savedRank);
    }
    return _rankLabelForPearls(pearls);
  }

  String _rankLabelForBadge(String label) {
    final arLabel = switch (label) {
      'Beginner' => 'عليمي',
      'Advance' => 'يمشي حاله',
      'Professional' => 'زين',
      'Legend' => 'فنان',
      'GOAT' || 'فلته' => 'فلتة',
      _ => label,
    };
    return app.tr(
      ar: arLabel,
      en: switch (arLabel) {
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
}

class _NotificationBell extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _NotificationBell({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final visibleCount = count.clamp(0, 99);
    return Material(
      color: Colors.black.withValues(alpha: 0.22),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              const Icon(Icons.notifications_rounded,
                  color: Colors.white, size: 24),
              if (visibleCount > 0)
                PositionedDirectional(
                  top: 4,
                  end: 3,
                  child: Container(
                    constraints:
                        const BoxConstraints(minWidth: 18, minHeight: 18),
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4EA5FF),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xFF1E2F4D),
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$visibleCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
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

// lib/main.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'biometric_auth.dart';
import 'state.dart';
import 'operations_gate.dart';
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

const Map<String, String> _mainGameSvgAssetById = <String, String>{
  'قدم': 'lib/assets/games_svg/games-01.svg',
  'طائره': 'lib/assets/games_svg/games-02.svg',
  'سله': 'lib/assets/games_svg/games-03.svg',
  'دفان': 'lib/assets/games_svg/games-26.svg',
  'تنس ارضي': 'lib/assets/games_svg/games-05.svg',
  'بيبيفوت': 'lib/assets/games_svg/games-06.svg',
  'بادل': 'lib/assets/games_svg/games-07.svg',
  'بلوت': 'lib/assets/games_svg/games-24.svg',
  'هند': 'lib/assets/games_svg/games-09.svg',
  'كوت': 'lib/assets/games_svg/games-08.svg',
  'سبيتة': 'lib/assets/games_svg/games-25.svg',
  'بولنج': 'lib/assets/games_svg/games-16.svg',
  'بلياردو': 'lib/assets/games_svg/games-15.svg',
  'تنس طاولة': 'lib/assets/games_svg/games-17.svg',
  'شطرنج': 'lib/assets/games_svg/games-18.svg',
  'تريكس': 'lib/assets/games_svg/games-11.svg',
  'دامه': 'lib/assets/games_svg/games-19.svg',
  'كيرم': 'lib/assets/games_svg/games-20.svg',
  'دومنه': 'lib/assets/games_svg/games-21.svg',
  'طاوله': 'lib/assets/games_svg/games-22.svg',
  'اونو': 'lib/assets/games_svg/games-13.svg',
  'جاكارو': 'lib/assets/games_svg/games-23.svg',
};

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OneSignalBridge.initialize();
  runApp(const InzeliApp());
}

class InzeliApp extends StatelessWidget {
  const InzeliApp({super.key});

  @override
  Widget build(BuildContext context) {
    final androidArabicOnly =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    return MaterialApp(
      title: 'Inzeli',
      debugShowCheckedModeBanner: false,
      locale: androidArabicOnly ? const Locale('ar') : null,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: androidArabicOnly
          ? const [Locale('ar')]
          : const [Locale('ar'), Locale('en')],
      builder: (context, child) {
        if (defaultTargetPlatform != TargetPlatform.android) {
          return OperationsGate(child: child ?? const SizedBox.shrink());
        }
        final media = MediaQuery.of(context);
        final scale = media.textScaler.scale(1);
        final clampedScale = scale.clamp(1.0, 1.12).toDouble();
        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(clampedScale)),
          child: OperationsGate(child: child ?? const SizedBox.shrink()),
        );
      },
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
  Timer? _inboxTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    app.addListener(_onAppChanged);
    OneSignalBridge.onNotification = (item) {
      if (app.isSignedIn) {
        app.receivePush(item);
      } else {
        OneSignalBridge.deferNotification(item);
      }
    };
    OperationsGate.onHiddenGames = app.applyHiddenGames;
    app.applyHiddenGames(OperationsGate.hiddenGameIds);
    _inboxTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (app.isSignedIn) unawaited(app.refreshServerNotifications());
    });
    _boot();
  }

  @override
  void dispose() {
    _inboxTimer?.cancel();
    OneSignalBridge.onNotification = null;
    OperationsGate.onHiddenGames = null;
    app.removeListener(_onAppChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && app.isSignedIn) {
      unawaited(app.refreshSessionFromServer());
      unawaited(app.refreshServerNotifications());
    }
  }

  void _onAppChanged() {
    if (app.isSignedIn) {
      for (final item in OneSignalBridge.takePendingNotifications()) {
        app.receivePush(item);
      }
    }
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
      for (final item in OneSignalBridge.takePendingNotifications()) {
        app.receivePush(item);
      }
    }
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
    final isAndroid = Theme.of(context).platform == TargetPlatform.android;
    final width = MediaQuery.sizeOf(context).width;
    final headerPadding = isAndroid && width < 360 ? 10.0 : 16.0;
    final pagePadding = isAndroid && width < 360 ? 4.0 : 8.0;

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
          bottom: !isAndroid,
          child: Column(
            children: [
              const SizedBox(height: 6),
              if (_index != 4) ...[
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: headerPadding),
                  child: _TopProfileCard(
                    app: app,
                    onTap: () => setState(() => _index = 4),
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: pagePadding),
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
          height: isAndroid ? (width < 360 ? 70 : 74) : null,
          labelBehavior:
              isAndroid ? NavigationDestinationLabelBehavior.alwaysShow : null,
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
    final favoriteGame = _favoriteGame(app, name);
    final topGame = favoriteGame.label;
    final topPearls = favoriteGame.pearls;
    final rankThreshold = AppState.badgeThresholdForPearls(
      app.badgeProgressForGame(favoriteGame.gameId),
    );
    final earnedBadges = _earnedBadgeEntries(name);
    final isAndroid = Theme.of(context).platform == TargetPlatform.android;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final veryCompact = isAndroid && screenWidth < 360;
    final compact = screenWidth < 430;
    final cardHeight = isAndroid
        ? (veryCompact ? 144.0 : (compact ? 152.0 : 164.0))
        : (compact ? 156.0 : 164.0);
    final avatarRadius = isAndroid
        ? (veryCompact ? 33.0 : (compact ? 36.0 : 39.0))
        : (compact ? 37.0 : 39.0);
    final avatarFrameSize = isAndroid
        ? (veryCompact ? 86.0 : (compact ? 94.0 : 102.0))
        : (compact ? 98.0 : 102.0);
    final badgeLift = isAndroid
        ? (veryCompact ? -18.0 : (compact ? -20.0 : -20.0))
        : (compact ? -22.0 : -20.0);
    final pearlSize = isAndroid
        ? (veryCompact ? 50.0 : (compact ? 56.0 : 62.0))
        : (compact ? 58.0 : 62.0);
    final trophySize = isAndroid
        ? (veryCompact ? 32.0 : (compact ? 36.0 : 40.0))
        : (compact ? 38.0 : 40.0);
    final badgeRowSlotHeight = isAndroid
        ? (veryCompact ? 28.0 : (compact ? 31.0 : 34.0))
        : (compact ? 32.0 : 34.0);
    final badgeRowMaxHeight = isAndroid
        ? (veryCompact ? 72.0 : (compact ? 86.0 : 96.0))
        : (compact ? 90.0 : 96.0);
    final cardColor = _cardColor(app.cardId);
    final rankVisual = playerRankForThreshold(rankThreshold);
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
                  child: _MainGameRankBadge(
                    rank: rankVisual,
                    gameId: favoriteGame.gameId,
                    gameLabel: favoriteGame.label,
                  ),
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
                        size: avatarFrameSize,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (id.isNotEmpty)
                        Text(
                          _shortId(id),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                    _MainEarnedBadgeStack(
                      badges: earnedBadges,
                      size: trophySize,
                    ),
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
    unawaited(app.refreshServerNotifications().whenComplete(() {
      app.markNotificationsRead();
    }));
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
      'monthly_leaderboard_award' => Icons.emoji_events_rounded,
      'win' => Icons.emoji_events_rounded,
      'loss' => Icons.sports_score_rounded,
      _ => Icons.notifications_rounded,
    };
  }

  Color _notificationColor(String type) {
    return switch (type) {
      'badge' => Colors.amber,
      'monthly_leaderboard_award' => Colors.amber,
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

  Set<String> _playedGameIds(String player) {
    final played = <String>{...app.playedGameIds};
    for (final cat in app.mainGames.values) {
      for (final gameId in cat) {
        if (app.winsOf(player, gameId) + app.lossesOf(player, gameId) > 0) {
          played.add(gameId);
        }
      }
    }
    for (final entry in app.timeline) {
      final gameId = entry.game.trim();
      if (gameId.isEmpty) continue;
      if (_isMatchEvent(entry) && _entryInvolvesPlayer(entry, player)) {
        played.add(gameId);
      }
    }
    return played;
  }

  bool _isMatchEvent(TimelineEntry entry) {
    final kind = entry.kind.trim().toUpperCase();
    return kind.isEmpty ||
        kind == 'MATCH' ||
        kind == 'MATCH_WIN' ||
        kind == 'MATCH_LOSS' ||
        kind == 'MATCH_FINISHED';
  }

  bool _entryInvolvesPlayer(TimelineEntry entry, String player) {
    return entry.winner == player ||
        entry.winners.contains(player) ||
        entry.losers.contains(player);
  }

  int _timelinePlayedCount(String player, String gameId) {
    return app.timeline
        .where((entry) =>
            entry.game.trim() == gameId &&
            _isMatchEvent(entry) &&
            _entryInvolvesPlayer(entry, player))
        .length;
  }

  _MainGameSummary _favoriteGame(AppState app, String player) {
    final played = _playedGameIds(player);
    final gameIds = <String>{
      ...played,
      ...app.gamePearls.keys,
      ...app.gameBadgeProgress.keys,
      if (app.selectedGame != null && app.selectedGame!.isNotEmpty)
        app.selectedGame!,
    };
    for (final cat in app.mainGames.values) {
      gameIds.addAll(cat);
    }

    final summaries = <_MainGameSummary>[];
    for (final raw in gameIds) {
      final gameId = raw.trim();
      if (gameId.isEmpty) continue;
      final statsPlayed =
          app.winsOf(player, gameId) + app.lossesOf(player, gameId);
      final timelinePlayed = _timelinePlayedCount(player, gameId);
      final active =
          played.contains(gameId) || statsPlayed > 0 || timelinePlayed > 0;
      if (!active) continue;
      summaries.add(_MainGameSummary(
        gameId: gameId,
        label: app.gameLabel(gameId),
        pearls: app.pearlsForGame(gameId),
        badgeProgress: app.badgeProgressForGame(gameId),
        playedCount: math.max(statsPlayed, timelinePlayed),
      ));
    }

    if (summaries.isEmpty) {
      return _MainGameSummary(
        gameId: '',
        label: app.tr(ar: 'بدون لعبة', en: 'No game'),
        pearls: 0,
        badgeProgress: 0,
        playedCount: 0,
      );
    }

    summaries.sort((a, b) {
      if (a.playedCount != b.playedCount) {
        return b.playedCount.compareTo(a.playedCount);
      }
      if (a.badgeProgress != b.badgeProgress) {
        return b.badgeProgress.compareTo(a.badgeProgress);
      }
      if (a.pearls != b.pearls) return b.pearls.compareTo(a.pearls);
      return a.label.compareTo(b.label);
    });
    return summaries.first;
  }

  Map<String, dynamic>? _bestBadgeForGame(String gameId, String player) {
    if (!_playedGameIds(player).contains(gameId)) return null;
    final candidates = app.badges
        .where((b) => (b['gameId'] ?? '').toString().trim() == gameId)
        .toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) {
      final thresholdA = (a['threshold'] as num?)?.toInt() ?? 0;
      final thresholdB = (b['threshold'] as num?)?.toInt() ?? 0;
      if (thresholdA != thresholdB) return thresholdB.compareTo(thresholdA);
      final dateA = DateTime.tryParse((a['lastEarnedAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final dateB = DateTime.tryParse((b['lastEarnedAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return dateB.compareTo(dateA);
    });
    return candidates.first;
  }

  int _badgeThresholdForGame(String gameId, int pearls, String player) {
    final saved =
        (_bestBadgeForGame(gameId, player)?['threshold'] as num?)?.toInt() ?? 0;
    final current = AppState.badgeThresholdForPearls(pearls);
    return math.max(saved, current);
  }

  List<_MainEarnedBadgeEntry> _earnedBadgeEntries(String player) {
    final played = _playedGameIds(player);
    final byGame = <String, _MainEarnedBadgeEntry>{};
    for (final badge in app.badges) {
      final gameId = (badge['gameId'] ?? '').toString().trim();
      if (gameId.isEmpty || !played.contains(gameId)) continue;
      final label = (badge['label'] ?? '').toString().trim();
      final threshold = (badge['threshold'] as num?)?.toInt() ??
          AppState.badgeThresholdForLabel(label);
      if (threshold <= 5) continue;
      final earnedAt =
          DateTime.tryParse((badge['lastEarnedAt'] ?? '').toString()) ??
              DateTime.fromMillisecondsSinceEpoch(0);
      final entry = _MainEarnedBadgeEntry(
        gameId: gameId,
        gameLabel: app.gameLabel(gameId),
        threshold: threshold,
        earnedAt: earnedAt,
      );
      final existing = byGame[gameId];
      if (existing == null ||
          entry.threshold > existing.threshold ||
          (entry.threshold == existing.threshold &&
              entry.earnedAt.isAfter(existing.earnedAt))) {
        byGame[gameId] = entry;
      }
    }

    for (final gameId in played) {
      final threshold = _badgeThresholdForGame(
        gameId,
        app.badgeProgressForGame(gameId),
        player,
      );
      if (threshold <= 5) continue;
      byGame.putIfAbsent(
        gameId,
        () => _MainEarnedBadgeEntry(
          gameId: gameId,
          gameLabel: app.gameLabel(gameId),
          threshold: threshold,
          earnedAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      );
    }

    return byGame.values.toList()
      ..sort((a, b) {
        if (a.threshold != b.threshold) {
          return b.threshold.compareTo(a.threshold);
        }
        return b.earnedAt.compareTo(a.earnedAt);
      });
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

class _MainGameSummary {
  final String gameId;
  final String label;
  final int pearls;
  final int badgeProgress;
  final int playedCount;

  const _MainGameSummary({
    required this.gameId,
    required this.label,
    required this.pearls,
    required this.badgeProgress,
    required this.playedCount,
  });
}

class _MainEarnedBadgeEntry {
  final String gameId;
  final String gameLabel;
  final int threshold;
  final DateTime earnedAt;

  const _MainEarnedBadgeEntry({
    required this.gameId,
    required this.gameLabel,
    required this.threshold,
    required this.earnedAt,
  });
}

class _MainGameIconBadge extends StatelessWidget {
  final String gameId;
  final double size;
  final Color? iconColor;
  final Color backgroundColor;

  const _MainGameIconBadge({
    required this.gameId,
    this.size = 22,
    this.iconColor,
    this.backgroundColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final asset = _mainGameSvgAssetById[gameId];
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.16),
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: asset == null
          ? Icon(
              Icons.sports_esports_rounded,
              size: size * 0.62,
              color: iconColor ?? const Color(0xFF1E2F4D),
            )
          : SvgPicture.asset(
              asset,
              fit: BoxFit.contain,
              colorFilter: iconColor == null
                  ? null
                  : ColorFilter.mode(iconColor!, BlendMode.srcIn),
            ),
    );
  }
}

class _MainGameRankBadge extends StatelessWidget {
  final PlayerRank rank;
  final String gameId;
  final String gameLabel;

  const _MainGameRankBadge({
    required this.rank,
    required this.gameId,
    required this.gameLabel,
  });

  @override
  Widget build(BuildContext context) {
    final data = getRankData(rank);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 150),
        padding: const EdgeInsetsDirectional.fromSTEB(8, 5, 9, 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
          boxShadow: [
            BoxShadow(
              color: data.colors.last.withValues(alpha: 0.12),
              blurRadius: 14,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MainGameIconBadge(
              gameId: gameId,
              size: 24,
              iconColor: const Color(0xFF1E2F4D),
              backgroundColor: Colors.white.withValues(alpha: 0.92),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                gameId.isEmpty ? data.arabic : '${data.arabic} • $gameLabel',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MainEarnedBadgeStack extends StatelessWidget {
  final List<_MainEarnedBadgeEntry> badges;
  final double size;
  const _MainEarnedBadgeStack({required this.badges, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final visible = badges.take(3).toList();
    if (visible.isEmpty) return SizedBox(width: size, height: size);
    final overlap = size * 0.52;
    final width = size + (visible.length - 1) * overlap;
    return Tooltip(
      message: visible
          .map((badge) => '${badge.gameLabel} • ${badge.threshold}')
          .join('\n'),
      child: SizedBox(
        width: width,
        height: size + 8,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < visible.length; i++)
              PositionedDirectional(
                end: i * overlap,
                top: 0,
                child: _MainEarnedBadgeCircle(
                  badge: visible[i],
                  size: size,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MainEarnedBadgeCircle extends StatelessWidget {
  final _MainEarnedBadgeEntry badge;
  final double size;
  const _MainEarnedBadgeCircle({required this.badge, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final rank = playerRankForThreshold(badge.threshold);
    final rankData = getRankData(rank);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: rankData.colors,
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: rankData.colors.last.withValues(alpha: 0.32),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            rankData.icon,
            size: size * 0.48,
            color: Colors.white.withValues(alpha: 0.92),
          ),
          PositionedDirectional(
            end: size * 0.05,
            bottom: size * 0.05,
            child: _MainGameIconBadge(
              gameId: badge.gameId,
              size: size * 0.42,
              iconColor: const Color(0xFF1E2F4D),
            ),
          ),
        ],
      ),
    );
  }
}

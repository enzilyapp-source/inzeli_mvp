import 'package:flutter/material.dart';
import 'state.dart';
import 'pages/games_page.dart';
import 'pages/leaderboard_page.dart';
import 'pages/timeline_page.dart';
import 'pages/profile_page.dart';
import 'pages/signin_page.dart'; // صفحة التسجيل/الدخول

void main() => runApp(const InzeliApp());

class InzeliApp extends StatelessWidget {
  const InzeliApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inzeli',
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: const Color(0xFF3D5AFE),
        textTheme: const TextTheme(),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF3D5AFE),
        textTheme: const TextTheme(),
      ),
      home: const AuthGate(),
    );
  }
}

/// يشيّك لو عندك توكن محفوظ → يدخل الهوم، وإلا يفتح سيجن إن
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final app = AppState();
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await app.load(); // يحمل SharedPreferences + الأوث (من state.dart)
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
  int index = 0;
  late final pages = <Widget>[
    GamesPage(app: widget.app),
    LeaderboardPage(app: widget.app),
    TimelinePage(app: widget.app),
    ProfilePage(app: widget.app),
  ];

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: Text('أهلًا ${app.displayName ?? app.name ?? ""}'),
        actions: [
          IconButton(
            tooltip: 'خروج',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await app.clearAuth();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const AuthGate()),
                    (_) => false,
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // بطاقة الحساب
          Card(
            child: ListTile(
              leading: const Icon(Icons.person, size: 28),
              title: Text(
                app.displayName ?? app.name ?? '—',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                app.email ?? app.phone ?? '—',
                style: TextStyle(color: onSurface.withOpacity(0.7)),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('الرصيد: ${app.creditPoints ?? 0}'),
                  Text('النقاط: ${app.permanentScore ?? 0}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // الصفحة الحالية (Games / Leaderboard / Timeline / Profile)
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.75,
            child: pages[index],
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.videogame_asset),
            label: 'الألعاب',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events),
            label: 'المراتب',
          ),
          // ✅ تغيّر الاسم إلى "شسالفة؟"
          NavigationDestination(
            icon: Icon(Icons.timeline),
            label: 'شسالفة؟',
          ),
          NavigationDestination(
            icon: Icon(Icons.person),
            label: 'ملفي',
          ),
        ],
      ),
    );
  }
}

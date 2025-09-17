import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_auth.dart';
import 'state.dart';
import 'pages/games_page.dart';
import 'pages/leaderboard_page.dart';
import 'pages/timeline_page.dart';
import 'pages/profile_page.dart';

void main() => runApp(const InzeliApp());

class InzeliApp extends StatelessWidget {
  const InzeliApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inzeli',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
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
  final app = AppState();
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await app.load(); // يحمل بياناتك + الأوث الجديدة
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return app.isSignedIn ? HomePage(app: app) : SignInPage(app: app);
  }
}

class SignInPage extends StatelessWidget {
  final AppState app;
  const SignInPage({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    void msg(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sports_esports, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.login),
              label: const Text('تسجيل دخول سريع'),
              onPressed: () async {
                final r = await login(email: 'birdy@example.com', password: '12345678');
                if (!r.ok) { msg(r.message); return; }
                final token = r.data!['token'] as String;
                final user  = r.data!['user']  as Map<String, dynamic>;
                await app.setAuthFromBackend(token: token, user: user);
                if (!context.mounted) return;
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomePage(app: app)));
              },
            ),
            TextButton(
              onPressed: () { /* TODO: افتحي صفحة تسجيل */ },
              child: const Text('إنشاء حساب جديد'),
            ),
          ],
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
  int index = 0;
  late final pages = <Widget>[
    GamesPage(app: widget.app),
    LeaderboardPage(app: widget.app),
    TimelinePage(app: widget.app),
    ProfilePage(app: widget.app),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('أهلاً ${widget.app.displayName ?? ""}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await widget.app.clearAuth();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const AuthGate()),
                    (_) => false,
              );
            },
          )
        ],
      ),
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.videogame_asset), label: 'الألعاب'),
          NavigationDestination(icon: Icon(Icons.emoji_events), label: 'المراتب'),
          NavigationDestination(icon: Icon(Icons.timeline), label: 'التايملاين'),
          NavigationDestination(icon: Icon(Icons.person), label: 'ملفي'),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'state.dart';
import 'api_auth.dart';
import 'pages/games_page.dart';
import 'pages/leaderboard_page.dart';
import 'pages/timeline_page.dart';
import 'pages/profile_page.dart';
import 'pages/signin_page.dart'; // صفحة التسجيل/الدخول اللي عطيتك

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

/// يشيك إذا فيه توكن محفوظ -> يدخل على الصفحة الرئيسية، وإلا يفتح شاشة الدخول
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
    await app.load(); // يحمل بياناتك + الأوث من SharedPreferences
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return app.isSignedIn
        ? HomePage(app: app)
        : SignInPage(app: app); // ← شاشة الدخول الكاملة اللي عطيتك
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

  void _msg(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    return Scaffold(
      appBar: AppBar(
        title: Text('أهلًا ${app.displayName ?? app.name ?? ""}'),
        actions: [
          IconButton(
            tooltip: 'تحديث الحساب',
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              // لو حابة تتحققين من التوكن وتجيبين /auth/me
              if (!app.isSignedIn) { _msg('سجّلي دخول أول'); return; }
              try {
                // مثال بسيط: نخزن نفس القيم الحالية (أو تستدعين /auth/me من api_auth وتحدّثين)
                _msg('تم التحديث');
                setState(() {});
              } catch (e) { _msg(e.toString()); }
            },
          ),
          IconButton(
            tooltip: 'تسجيل خروج',
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
          // بطاقة الحساب في الصفحة الرئيسية
          Card(
            child: ListTile(
              leading: const Icon(Icons.person, size: 28),
              title: Text(app.displayName ?? app.name ?? '—',
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text(app.email ?? app.phone ?? '—'),
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
          // الصفحة الحالية من شريط التنقل
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
          NavigationDestination(icon: Icon(Icons.videogame_asset), label: 'الألعاب'),
          NavigationDestination(icon: Icon(Icons.emoji_events), label: 'المراتب'),
          NavigationDestination(icon: Icon(Icons.timeline), label: 'التايملاين'),
          NavigationDestination(icon: Icon(Icons.person), label: 'ملفي'),
        ],
      ),
    );
  }
}

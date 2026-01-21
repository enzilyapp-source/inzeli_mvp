import 'package:flutter/material.dart';
import '../state.dart';
import '../widgets/primary_pill_button.dart';

class WelcomeBouncer extends StatelessWidget {
  final AppState app;
  final VoidCallback onEnter;

  const WelcomeBouncer({
    super.key,
    required this.app,
    required this.onEnter,
  });

  @override
  Widget build(BuildContext context) {
    final name = app.displayName ?? app.name ?? '';

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF232E4A),
              Color(0xFF34677A),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(),

              // Logo
              SizedBox(
                width: 120,
                height: 120,
                child: Image.asset('lib/assets/logo.png', fit: BoxFit.contain),
              ),

              const SizedBox(height: 18),

              // optional greeting
              if (name.isNotEmpty)
                Text(
                  name,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),

              const SizedBox(height: 22),

              // Button: انزلي
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: PrimaryPillButton(
                  label: app.tr(ar: 'انزلي', en: 'Start'),
                  onPressed: onEnter,
                  icon: Icons.arrow_forward,
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
//pages/welcome_bouncer.dart

// lib/pages/sponsor_page.dart
import 'package:flutter/material.dart';

import '../state.dart';

class SponsorPage extends StatelessWidget {
  final AppState app;
  final bool embedded;
  const SponsorPage({super.key, required this.app, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final body = Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE49A2C).withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFE49A2C).withValues(alpha: 0.36),
                      ),
                    ),
                    child: const Icon(
                      Icons.lock_clock_outlined,
                      color: Color(0xFFE49A2C),
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    app.tr(ar: 'قريباً', en: 'Coming soon'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: onSurface,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    app.tr(
                      ar: 'صفحة السبونسرات مقفلة مؤقتاً.',
                      en: 'Sponsors are temporarily locked.',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: onSurface.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (embedded) return body;

    return Scaffold(
      appBar: AppBar(
        title: Text(app.tr(ar: 'سبونسرات', en: 'Sponsors')),
      ),
      body: body,
    );
  }
}

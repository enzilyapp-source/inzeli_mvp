// lib/pages/timeline_page.dart
import 'package:flutter/material.dart';
import '../state.dart';

class TimelinePage extends StatelessWidget {
  final AppState app;
  const TimelinePage({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: app.timeline.length,
      separatorBuilder: (_, __)=> const Divider(height: 0),
      itemBuilder: (_, i) {
        final t = app.timeline[app.timeline.length - 1 - i];
        return ListTile(
          leading: const Icon(Icons.sports_esports_outlined),
          title: Text('${t.game} — ${t.roomCode}'),
          subtitle: Text('فائز: ${t.winner} • خاسرون: ${t.losers.join("، ")}\n${t.ts}'),
        );
      },
    );
  }
}

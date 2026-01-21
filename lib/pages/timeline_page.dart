import 'package:flutter/material.dart';
import '../state.dart';

class TimelinePage extends StatelessWidget {
  final AppState app;
  const TimelinePage({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    final on = Theme.of(context).colorScheme.onSurface;

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: app.timeline.length + 1, // +1 للهيدر
      separatorBuilder: (_, __) => const Divider(height: 0),
      itemBuilder: (_, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Text(
              'شسالفه ؟',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: on),
            ),
          );
        }
        final t = app.timeline[app.timeline.length - i]; // الأحدث فوق
        return ListTile(
          leading: const Icon(Icons.sports_esports_outlined),
          title: Text('${t.game} — ${t.roomCode}'),
          subtitle: Text('فائز: ${t.winner} • خاسرون: ${t.losers.join("، ")}\n${t.ts}'),
        );
      },
    );
  }
}
//timeline_page.dart
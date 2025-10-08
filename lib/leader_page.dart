import 'package:flutter/material.dart';
import 'state.dart';

class LeaderPage extends StatelessWidget {
  final AppState state;
  const LeaderPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    // ديمو ثابت
    final rows = [
      {'name': 'سارة', 'pts': 13, 'w': 8, 'l': 2},
      {'name': 'علي', 'pts': 11, 'w': 7, 'l': 3},
      {'name': 'ريم', 'pts': 9,  'w': 6, 'l': 4},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('المراتب')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (ctx, i) {
          final r = rows[i];
          return Card(
            child: ListTile(
              title: Text('${i + 1}. ${r['name']}'),
              subtitle: Text('نقاط: ${r['pts']} • ف:${r['w']} / خ:${r['l']}'),
            ),
          );
        },
      ),
    );
  }
}
//leader_page.dart
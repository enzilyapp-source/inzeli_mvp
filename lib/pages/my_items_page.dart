// lib/pages/my_items_page.dart
import 'package:flutter/material.dart';
import '../api_store.dart';
import '../state.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/challenge_rank_visuals.dart';

class MyItemsPage extends StatefulWidget {
  final AppState app;
  const MyItemsPage({super.key, required this.app});

  @override
  State<MyItemsPage> createState() => _MyItemsPageState();
}

class _MyItemsPageState extends State<MyItemsPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiStore.myItems(token: widget.app.token ?? '');
  }

  Future<void> _apply(String id, String kind) async {
    try {
      await ApiStore.applySelection(
        token: widget.app.token ?? '',
        themeId: kind == 'theme' ? id : null,
        frameId: kind == 'frame' ? id : null,
        cardId: kind == 'card' ? id : null,
      );
      if (kind == 'theme') widget.app.themeId = id;
      if (kind == 'frame') widget.app.frameId = id;
      if (kind == 'card') widget.app.cardId = id;
      await widget.app.saveState();
      setState(() {});
      _msg('تم التطبيق');
    } catch (e) {
      _msg('فشل التطبيق: $e');
    }
  }

  void _msg(String text) {
    showAppSnack(context, text);
  }

  @override
  Widget build(BuildContext context) {
    final topPearls = widget.app.gamePearls.isEmpty
        ? 0
        : widget.app.gamePearls.values.reduce((a, b) => a >= b ? a : b);
    final currentThreshold = AppState.badgeThresholdForPearls(topPearls);
    final unlockedRankThreshold = currentThreshold > widget.app.bestBadgeThreshold()
        ? currentThreshold
        : widget.app.bestBadgeThreshold();
    return Scaffold(
      appBar: AppBar(title: const Text('ممتلكاتي')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text('خطأ: ${snap.error}'));
          var items = snap.data ?? const [];
          final existingIds = items
              .map((e) => ((e['item'] as Map?)?['id'] ?? '').toString())
              .toSet();
          for (final t in kThemeVisualOptions) {
            final unlocked = t.unlockThreshold != null
                ? unlockedRankThreshold >= t.unlockThreshold!
                : t.vipOnly
                    ? widget.app.hasActiveVip
                    : widget.app.freeThemesOwned.contains(t.id);
            if (unlocked && !existingIds.contains(t.id)) {
              items = List<Map<String, dynamic>>.from(items)
                ..add({
                  'item': {
                    'id': t.id,
                    'name': t.label,
                    'kind': 'theme',
                  }
                });
              existingIds.add(t.id);
            }
          }
          if (items.isEmpty) return const Center(child: Text('لا تملك عناصر بعد'));

          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final it = items[i];
              final item = (it['item'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
              final id = item['id']?.toString() ?? '';
              final name = item['name']?.toString() ?? '';
              final kind = item['kind']?.toString() ?? '';
              final applied = (kind == 'theme' && widget.app.themeId == id) ||
                  (kind == 'frame' && widget.app.frameId == id) ||
                  (kind == 'card' && widget.app.cardId == id);

              return ListTile(
                title: Text(name),
                subtitle: Text('النوع: $kind'),
                trailing: TextButton(
                  onPressed: () => _apply(id, kind),
                  child: Text(applied ? 'مُطبَّق' : 'تطبيق'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

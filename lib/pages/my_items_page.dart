// lib/pages/my_items_page.dart
import 'package:flutter/material.dart';
import '../api_store.dart';
import '../state.dart';

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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ممتلكاتي')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text('خطأ: ${snap.error}'));
          final items = snap.data ?? const [];
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

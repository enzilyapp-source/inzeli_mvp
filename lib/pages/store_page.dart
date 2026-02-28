// lib/pages/store_page.dart
import 'package:flutter/material.dart';
import '../api_store.dart';
import '../state.dart';
import '../widgets/app_snackbar.dart';

class StorePage extends StatefulWidget {
  final AppState app;
  const StorePage({super.key, required this.app});

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  late Future<List<Map<String, dynamic>>> _future;
  Set<String> ownedIds = {};
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final items = await ApiStore.listItems();
    // إدراج الثيمات المجانية في حال لم تُرجعها الـ API
    const freeThemes = [
      {'id': 'blueThunder', 'name': 'برق أزرق', 'kind': 'theme', 'price': 0, 'preview': 'هالة برق أزرق'},
      {'id': 'goldLightning', 'name': 'برق ذهبي', 'kind': 'theme', 'price': 0, 'preview': 'هالة برق ذهبي'},
      {'id': 'kuwait', 'name': 'ألوان العلم', 'kind': 'theme', 'price': 0, 'preview': 'هالة العلم'},
      {'id': 'greenLeaf', 'name': 'أوراق خضراء', 'kind': 'theme', 'price': 0, 'preview': 'أوراق متحركة'},
      {'id': 'flameBlue', 'name': 'لهب أزرق', 'kind': 'theme', 'price': 0, 'preview': 'هالة لهب أزرق'},
      {'id': 'whiteSparkle', 'name': 'سباركل أبيض', 'kind': 'theme', 'price': 0, 'preview': 'هالة بريق أبيض'},
    ];
    final existingIds = items.map((e) => e['id'].toString()).toSet();
    for (final t in freeThemes) {
      if (!existingIds.contains(t['id'])) {
        items.add(Map<String, dynamic>.from(t));
      }
    }
    if (widget.app.token != null && widget.app.token!.isNotEmpty) {
      try {
        final mine = await ApiStore.myItems(token: widget.app.token!);
        ownedIds = mine.map((e) => e['itemId'].toString()).toSet();
      } catch (_) {}
    }
    ownedIds.addAll(widget.app.freeThemesOwned);
    // اعتبر الثيم الحالي مملوكاً دائماً
    if (widget.app.themeId != null) ownedIds.add(widget.app.themeId!);
    return items;
  }

  Future<void> _buy(String itemId) async {
    if (!widget.app.isSignedIn) {
      _msg('سجّل الدخول أولاً');
      return;
    }
    setState(() => loading = true);
    try {
      final item = (await _future).firstWhere((e) => e['id'].toString() == itemId, orElse: () => {});
      final price = (item['price'] ?? 0) as num;
      if (price == 0) {
        ownedIds.add(itemId);
        widget.app.freeThemesOwned.add(itemId);
        await widget.app.saveState();
        _msg('تمت الإضافة إلى ثيماتي', success: true);
      } else {
        final res = await ApiStore.buyItem(token: widget.app.token!, itemId: itemId);
        ownedIds.add(itemId);
        widget.app.creditBalance = (res['balance'] as num?)?.toInt() ?? widget.app.creditBalance;
        await widget.app.saveState();
        _msg('تم الشراء');
      }
    } catch (e) {
      _msg('فشل الشراء: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _apply({String? themeId, String? frameId, String? cardId}) async {
    if (!widget.app.isSignedIn) {
      _msg('سجّل الدخول أولاً');
      return;
    }
    try {
      final res = await ApiStore.applySelection(
        token: widget.app.token!,
        themeId: themeId,
        frameId: frameId,
        cardId: cardId,
      );
      widget.app.themeId = res['themeId']?.toString() ?? widget.app.themeId;
      widget.app.frameId = res['frameId']?.toString() ?? widget.app.frameId;
      widget.app.cardId = res['cardId']?.toString() ?? widget.app.cardId;
      await widget.app.saveState();
      _msg('تم التطبيق', success: true);
      setState(() {});
    } catch (e) {
      _msg('فشل التطبيق: $e', error: true);
    }
  }

  void _msg(String text, {bool error = false, bool success = false}) {
    showAppSnack(context, text, error: error, success: success);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('متجر الثيمات'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: Text(
                'رصيدك: ${widget.app.storeCredit}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('خطأ: ${snap.error}'));
          }
          final items = snap.data ?? const [];
          if (items.isEmpty) return const Center(child: Text('لا توجد عناصر حالياً'));

          return LayoutBuilder(
            builder: (context, cons) {
              final isNarrow = cons.maxWidth < 380;
              final crossAxisCount = isNarrow ? 1 : 2;
              // give taller tiles on wider screens to avoid flex overflow
              final aspect = isNarrow ? 0.9 : 0.65;
              return GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: aspect,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final it = items[i];
                  final id = it['id'].toString();
                  final owned = ownedIds.contains(id);
                  final name = it['name']?.toString() ?? '';
                  final price = (it['price'] ?? 0) as int;
                  final kind = it['kind']?.toString() ?? '';
                  final desc = it['description']?.toString() ?? '';
                  final preview = it['preview']?.toString() ?? '';
                  final isApplied = (kind == 'theme' && widget.app.themeId == id) ||
                      (kind == 'frame' && widget.app.frameId == id) ||
                      (kind == 'card' && widget.app.cardId == id);

                  return Card(
                    elevation: isApplied ? 6 : 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text('النوع: $kind', maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text('السعر: $price', maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.grey.shade200,
                              ),
                              child: Center(
                                child: Text(
                                  preview.isNotEmpty ? preview : desc,
                                  textAlign: TextAlign.center,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (owned)
                            FilledButton(
                              onPressed: () {
                                if (kind == 'theme') _apply(themeId: id);
                                if (kind == 'frame') _apply(frameId: id);
                                if (kind == 'card') _apply(cardId: id);
                              },
                              child: Text(isApplied ? 'مُطبَّق' : 'تطبيق'),
                            )
                          else
                            FilledButton(
                              onPressed: loading ? null : () => _buy(id),
                              child: const Text('شراء'),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

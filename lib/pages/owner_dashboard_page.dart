// lib/pages/owner_dashboard_page.dart
import 'package:flutter/material.dart';
import '../state.dart';

class OwnerDashboardPage extends StatefulWidget {
  final AppState app;
  const OwnerDashboardPage({super.key, required this.app});

  @override
  State<OwnerDashboardPage> createState() => _OwnerDashboardPageState();
}

class _OwnerDashboardPageState extends State<OwnerDashboardPage> {
  final _titleCtrl = TextEditingController();
  final _sponsorCtrl = TextEditingController();
  final _dewNameCtrl = TextEditingController();
  final _imageCtrl = TextEditingController();
  String _type = 'sponsor';
  Color _primary = const Color(0xFF233C56);
  Color _accent = const Color(0xFF46C2D8);

  @override
  void dispose() {
    _titleCtrl.dispose();
    _sponsorCtrl.dispose();
    _dewNameCtrl.dispose();
    _imageCtrl.dispose();
    super.dispose();
  }

  void _msg(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _createBoard() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      _msg('اكتب اسم اللوحة');
      return;
    }
    await widget.app.addManagedBoard(
      title: title,
      type: _type,
      sponsorCode: _type == 'sponsor' ? _sponsorCtrl.text.trim() : null,
      dewanyahName: _type == 'dewanyah' ? _dewNameCtrl.text.trim() : null,
      primaryColor: _primary.value.toRadixString(16),
      accentColor: _accent.value.toRadixString(16),
      imageUrl: _imageCtrl.text.trim().isEmpty ? null : _imageCtrl.text.trim(),
    );
    _titleCtrl.clear();
    _sponsorCtrl.clear();
    _dewNameCtrl.clear();
    _imageCtrl.clear();
    _msg('تم إنشاء لوحة مخصصة');
    setState(() {});
  }

  List<Map<String, dynamic>> _allBoards() {
    final dewOwned = widget.app.ownedDewanyahs.map((d) => {
          'id': d['id'] ?? d['name'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
          'title': d['name'] ?? 'ديوانية',
          'type': 'dewanyah',
          'dewanyahName': d['name'],
          'primaryColor': d['primaryColor'],
          'accentColor': d['accentColor'],
          'imageUrl': d['imageUrl'],
          'ownerName': d['ownerName'] ?? widget.app.displayName ?? 'أنت',
        });
    return [
      ...widget.app.managedBoards,
      ...dewOwned,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final boards = _allBoards();
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة المالك'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeaderCard(app: widget.app),
            const SizedBox(height: 12),
            _BuildForm(
              titleCtrl: _titleCtrl,
              sponsorCtrl: _sponsorCtrl,
              dewNameCtrl: _dewNameCtrl,
              imageCtrl: _imageCtrl,
              type: _type,
              primary: _primary,
              accent: _accent,
              onTypeChange: (v) => setState(() => _type = v),
              onPrimaryChange: (c) => setState(() => _primary = c),
              onAccentChange: (c) => setState(() => _accent = c),
              onCreate: _createBoard,
            ),
            const SizedBox(height: 16),
            const Text(
              'لوحاتك',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 8),
            if (boards.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('لا يوجد لوحات بعد'),
                ),
              )
            else
              ...boards.map((b) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _BoardPreviewCard(board: b),
                  )),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final AppState app;
  const _HeaderCard({required this.app});

  @override
  Widget build(BuildContext context) {
    final name = app.displayName ?? app.name ?? 'أنت';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              child: Text(name.characters.isNotEmpty ? name.characters.first : '؟'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(app.email ?? app.phone ?? '—'),
                  const SizedBox(height: 6),
                  Text('تحكم بالرعاة والديوانيات: ألوان، صور، لوحات'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BuildForm extends StatelessWidget {
  final TextEditingController titleCtrl;
  final TextEditingController sponsorCtrl;
  final TextEditingController dewNameCtrl;
  final TextEditingController imageCtrl;
  final String type;
  final Color primary;
  final Color accent;
  final ValueChanged<String> onTypeChange;
  final ValueChanged<Color> onPrimaryChange;
  final ValueChanged<Color> onAccentChange;
  final VoidCallback onCreate;

  const _BuildForm({
    required this.titleCtrl,
    required this.sponsorCtrl,
    required this.dewNameCtrl,
    required this.imageCtrl,
    required this.type,
    required this.primary,
    required this.accent,
    required this.onTypeChange,
    required this.onPrimaryChange,
    required this.onAccentChange,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final swatches = [
      const Color(0xFF233C56),
      const Color(0xFF20334F),
      const Color(0xFF1E2D3F),
      const Color(0xFF3B4D61),
      const Color(0xFF8BC6EC),
      const Color(0xFF5C6BC0),
      const Color(0xFFF06292),
      const Color(0xFFFFA726),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('إنشاء لوحة مخصصة', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            const SizedBox(height: 10),
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'اسم اللوحة'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: const InputDecoration(labelText: 'النوع'),
              items: const [
                DropdownMenuItem(value: 'sponsor', child: Text('سبونسر')),
                DropdownMenuItem(value: 'dewanyah', child: Text('ديوانية')),
              ],
              onChanged: (v) => onTypeChange(v ?? 'sponsor'),
            ),
            const SizedBox(height: 8),
            if (type == 'sponsor')
              TextField(
                controller: sponsorCtrl,
                decoration: const InputDecoration(labelText: 'كود الراعي'),
              )
            else
              TextField(
                controller: dewNameCtrl,
                decoration: const InputDecoration(labelText: 'اسم الديوانية (اختياري لو غير موجود)'),
              ),
            const SizedBox(height: 10),
            TextField(
              controller: imageCtrl,
              decoration: const InputDecoration(labelText: 'رابط صورة/شعار (اختياري)'),
            ),
            const SizedBox(height: 10),
            const Text('الألوان'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: swatches.map((c) => _ColorDot(
                color: c,
                selected: c.value == primary.value,
                onTap: () => onPrimaryChange(c),
              )).toList(),
            ),
            const SizedBox(height: 8),
            const Text('لون التمييز'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: swatches.map((c) => _ColorDot(
                color: c,
                selected: c.value == accent.value,
                onTap: () => onAccentChange(c),
              )).toList(),
            ),
            const SizedBox(height: 12),
            Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [primary, accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Center(
                child: Text('معاينة اللوحة', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.dashboard_customize_outlined),
              label: const Text('حفظ وإنشاء اللوحة'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _ColorDot({required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: selected ? Colors.white : Colors.white24, width: selected ? 3 : 1),
        ),
      ),
    );
  }
}

class _BoardPreviewCard extends StatelessWidget {
  final Map<String, dynamic> board;
  const _BoardPreviewCard({required this.board});

  Color _parse(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    try {
      final v = int.parse(hex, radix: 16);
      // ensure ARGB
      final argb = hex.length <= 6 ? 0xFF000000 | v : v;
      return Color(argb);
    } catch (_) {
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = board['title']?.toString() ?? 'لوحة';
    final type = board['type']?.toString() ?? 'sponsor';
    final primary = _parse(board['primaryColor']?.toString(), const Color(0xFF233C56));
    final accent = _parse(board['accentColor']?.toString(), const Color(0xFF46C2D8));
    final image = board['imageUrl']?.toString();
    final owner = board['ownerName']?.toString() ?? '';
    final sponsor = board['sponsorCode']?.toString();
    final dewName = board['dewanyahName']?.toString();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [primary, accent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 50,
                  height: 50,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: image != null && image.isNotEmpty
                        ? Image.network(
                            image,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_outlined),
                          )
                        : Container(
                            color: Colors.white.withOpacity(0.18),
                            child: const Icon(Icons.image_outlined),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(type == 'sponsor' ? 'لوحة راعي' : 'لوحة ديوانية'),
                      if (sponsor != null && sponsor.isNotEmpty)
                        Text('الكود: $sponsor', style: const TextStyle(fontSize: 12)),
                      if (dewName != null && dewName.isNotEmpty)
                        Text('الديوانية: $dewName', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _ColorBadge(color: primary, label: '#${primary.value.toRadixString(16).padLeft(8, '0')}'),
                const SizedBox(width: 8),
                _ColorBadge(color: accent, label: '#${accent.value.toRadixString(16).padLeft(8, '0')}'),
                const Spacer(),
                if (owner.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.verified_user_outlined, size: 16),
                      const SizedBox(width: 4),
                      Text(owner, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('معاينة لوحة المراتب', style: TextStyle(fontWeight: FontWeight.w800)),
                  SizedBox(height: 6),
                  _MockLeaderboard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorBadge extends StatelessWidget {
  final Color color;
  final String label;
  const _ColorBadge({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white, width: 0.5),
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }
}

class _MockLeaderboard extends StatelessWidget {
  const _MockLeaderboard();

  @override
  Widget build(BuildContext context) {
    final rows = const [
      {'name': 'Nasser', 'pts': 120},
      {'name': 'Ahmad', 'pts': 110},
      {'name': 'Saad', 'pts': 90},
    ];
    return Column(
      children: rows.map((r) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              CircleAvatar(radius: 10, child: Text(r['name']!.toString()[0])),
              const SizedBox(width: 6),
              Expanded(child: Text(r['name']!.toString(), style: const TextStyle(fontWeight: FontWeight.w800))),
              Text('${r['pts']} pts'),
            ],
          ),
        );
      }).toList(),
    );
  }
}

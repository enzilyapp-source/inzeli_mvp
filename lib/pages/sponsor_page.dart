// lib/pages/sponsor_page.dart
import 'package:flutter/material.dart';

import '../api_sponsor.dart';
import '../state.dart';
import 'sponsor_game_page.dart';

class SponsorPage extends StatefulWidget {
  final AppState app;
  final bool embedded;
  const SponsorPage({super.key, required this.app, this.embedded = false});

  @override
  State<SponsorPage> createState() => _SponsorPageState();
}

class _SponsorPageState extends State<SponsorPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiSponsors.listSponsors();
  }

  Future<void> _refresh() async {
    setState(() => _future = ApiSponsors.listSponsors());
    await _future;
  }

  void _openSponsor(Map<String, dynamic> sponsor) {
    final code = (sponsor['code'] ?? '').toString().trim();
    if (code.isEmpty) return;
    widget.app.setSponsorCode(code);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SponsorGameScreen(
          app: widget.app,
          sponsorCode: code,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _PanelMessage(
                  icon: Icons.error_outline,
                  title: 'تعذر تحميل السبونسرات',
                  text: '${snap.error}',
                ),
              ],
            );
          }
          final sponsors = snap.data ?? const [];
          if (sponsors.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: const [
                _PanelMessage(
                  icon: Icons.workspace_premium_outlined,
                  title: 'لا توجد سبونسرات حالياً',
                  text: 'بتظهر هنا أول ما نضيف راعي من الأدمن.',
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            children: [
              Row(
                children: [
                  const Icon(Icons.workspace_premium_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.app.tr(ar: 'سبونسرات إنزلي', en: 'Sponsors'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Tajawal',
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final columns = width < 360 ? 2 : (width < 620 ? 3 : 4);
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sponsors.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.82,
                    ),
                    itemBuilder: (_, index) {
                      final sponsor = sponsors[index];
                      return _SponsorTile(
                        name: _sponsorName(sponsor),
                        imageUrl: _imageUrl(sponsor),
                        color: _parseHexColor(
                          sponsor['themePrimary']?.toString(),
                          fallback: const Color(0xFFE49A2C),
                        ),
                        onTap: () => _openSponsor(sponsor),
                      );
                    },
                  );
                },
              ),
            ],
          );
        },
      ),
    );

    if (widget.embedded) return body;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.app.tr(ar: 'سبونسرات', en: 'Sponsors')),
      ),
      body: body,
    );
  }

  String _sponsorName(Map<String, dynamic> sponsor) {
    return (sponsor['name'] ?? sponsor['code'] ?? 'سبونسر').toString();
  }

  String? _imageUrl(Map<String, dynamic> sponsor) {
    final raw = (sponsor['imageUrl'] ??
            sponsor['logoUrl'] ??
            sponsor['coverUrl'] ??
            sponsor['avatarUrl'])
        ?.toString();
    if (raw == null || raw.trim().isEmpty) return null;
    return raw.trim();
  }
}

class _SponsorTile extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final Color color;
  final VoidCallback onTap;

  const _SponsorTile({
    required this.name,
    required this.imageUrl,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageUrl != null)
                    Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _SponsorFallback(color: color),
                    )
                  else
                    _SponsorFallback(color: color),
                  PositionedDirectional(
                    top: 8,
                    end: 8,
                    child: _TileBadge(color: color),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 9, 8, 10),
              child: Text(
                name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                  fontFamily: 'Tajawal',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SponsorFallback extends StatelessWidget {
  final Color color;
  const _SponsorFallback({required this.color});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            color.withValues(alpha: 0.95),
            const Color(0xFF1F2B40),
          ],
        ),
      ),
      child: Center(
        child: Image.asset(
          'lib/assets/enzeli_logo.png',
          width: 54,
          height: 54,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.workspace_premium_outlined, size: 44),
        ),
      ),
    );
  }
}

class _TileBadge extends StatelessWidget {
  final Color color;
  const _TileBadge({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.8)),
      ),
      child: const Text(
        'راعي',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 12,
          fontFamily: 'Tajawal',
        ),
      ),
    );
  }
}

class _PanelMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _PanelMessage({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFE49A2C), size: 32),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                fontFamily: 'Tajawal',
              ),
            ),
            const SizedBox(height: 6),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

Color _parseHexColor(String? input, {required Color fallback}) {
  final text = (input ?? '').trim().replaceAll('#', '');
  if (text.length == 6 || text.length == 8) {
    try {
      final withAlpha = text.length == 8 ? text : 'FF$text';
      return Color(int.parse(withAlpha, radix: 16));
    } catch (_) {}
  }
  return fallback;
}

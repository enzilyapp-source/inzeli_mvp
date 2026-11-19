import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../state.dart';
import '../api_store.dart';
import '../widgets/challenge_rank_visuals.dart';
import '../widgets/rank_identity.dart';
import '../widgets/app_snackbar.dart';

/// Draft selections stay local to this sheet. Saving changes the frame/banner
/// together after server ownership validation; dismissing discards the draft.
class ProfileAppearanceEditor extends StatefulWidget {
  const ProfileAppearanceEditor(
      {super.key,
      required this.app,
      required this.onPickPhoto,
      required this.onRemovePhoto});
  final AppState app;
  final Future<void> Function() onPickPhoto, onRemovePhoto;
  @override
  State<ProfileAppearanceEditor> createState() =>
      _ProfileAppearanceEditorState();
}

class _ProfileAppearanceEditorState extends State<ProfileAppearanceEditor> {
  late String? _frame, _card;
  bool _loading = true, _refreshFailed = false, _saving = false;
  final Set<String> _storeOwned = {};
  @override
  void initState() {
    super.initState();
    _frame = widget.app.themeId;
    _card = widget.app.cardId ?? 'navy';
    _load();
  }

  Future<void> _load() async {
    final account = widget.app.userId;
    final auth = widget.app.token;
    final refreshed = await widget.app.refreshChallengeRewards();
    try {
      if (auth != null) {
        final items = await ApiStore.myItems(token: auth);
        if (!mounted ||
            widget.app.userId != account ||
            widget.app.token != auth) {
          return;
        }
        _storeOwned.addAll(items
            .map((row) => ((row['item'] as Map?)?['id'] ?? '').toString()));
        await widget.app.applyRewardSnapshot({
          'ownedRewardIds':
              _storeOwned.where((id) => id.startsWith('reward_')).toList()
        });
      }
    } catch (_) {/* Previously cached ownership remains usable for preview. */}
    if (mounted) {
      setState(() {
        _loading = false;
        _refreshFailed = !refreshed;
      });
    }
  }

  List<ThemeVisualOption> get _frames {
    final app = widget.app;
    final top = app.gameBadgeProgress.values
        .fold<int>(app.bestBadgeThreshold(), math.max);
    final options = kThemeVisualOptions.where((option) {
      if (option.rewardSlot != null) {
        return app.earnedRewardIds.contains(option.id);
      }
      return _storeOwned.contains(option.id) ||
          app.freeThemesOwned.contains(option.id) ||
          option.id == app.themeId ||
          (option.vipOnly && app.hasActiveVip) ||
          (option.unlockThreshold != null && top >= option.unlockThreshold!);
    }).toList();
    return [
      ...options.where((option) => option.id.startsWith('reward_tier_')),
      ...options.where((option) => !option.id.startsWith('reward_tier_')),
    ];
  }

  ImageProvider? get _photo {
    try {
      final source = widget.app.avatarBase64;
      if (source != null && source.isNotEmpty) {
        return MemoryImage(base64Decode(source));
      }
    } catch (_) {}
    return null;
  }

  Widget _portrait({double radius = 26}) {
    final name = (widget.app.displayName ?? widget.app.name ?? '').trim();
    return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFF26374B),
        backgroundImage: _photo,
        child: _photo == null
            ? Text(name.isEmpty ? '؟' : name.characters.first,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800))
            : null);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await widget.app
        .applyProfileAppearance(selectedThemeId: _frame, selectedCardId: _card);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.pop(context, true);
    } else {
      showAppSnack(context,
          'تعذّر حفظ المظهر. تأكد من الاتصال وفتح الإطار والبنر بحسابك.',
          error: true);
    }
  }

  Widget _heading(String text, IconData icon) => Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 12),
      child: Row(children: [
        Icon(icon, color: Colors.white, size: 23),
        const SizedBox(width: 9),
        Expanded(
            child: Text(text,
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)))
      ]));
  Widget _tile(
          {required Widget child,
          required bool selected,
          required VoidCallback tap,
          required String label}) =>
      Semantics(
        selected: selected,
        button: true,
        label: label,
        child: Material(
            color: selected ? const Color(0xFF34445A) : const Color(0xFF203248),
            borderRadius: BorderRadius.circular(19),
            child: InkWell(
              onTap: _saving ? null : tap,
              borderRadius: BorderRadius.circular(19),
              child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(19),
                      border: Border.all(
                          color: selected
                              ? const Color(0xFFFFC25C)
                              : Colors.white12,
                          width: selected ? 2 : 1)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    child,
                    const SizedBox(height: 7),
                    Text(label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 11)),
                    if (selected)
                      const Icon(Icons.check_circle,
                          color: Color(0xFFFFC25C), size: 18),
                  ])),
            )),
      );
  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final banner = rankIdentityForBanner(_card);
    final frames = _frames;
    final banners = rankIdentities
        .where((rank) => app.earnedRewardIds.contains(rank.bannerId))
        .toList();
    return Directionality(
      textDirection: app.isEnglish ? TextDirection.ltr : TextDirection.rtl,
      child: SafeArea(
          child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: .88,
        minChildSize: .4,
        maxChildSize: .96,
        builder: (context, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            children: [
              Row(children: [
                const Expanded(
                    child: Text('تعديل الصورة والإطار',
                        style: TextStyle(
                            fontSize: 23, fontWeight: FontWeight.w800))),
                IconButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    tooltip: 'إغلاق المحرر',
                    icon: const Icon(Icons.close))
              ]),
              const Text('اعرض الجوائز المفتوحة لك، عاين المظهر ثم احفظه.',
                  style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                      color: profileBaseColor(_card),
                      height: 210,
                      child: CustomPaint(
                          painter:
                              banner == null ? null : RankBannerPainter(banner),
                          child: Center(
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                buildAvatarThemeWidget(
                                    themeId: _frame,
                                    size: 112,
                                    animate: false,
                                    child: _portrait(radius: 40)),
                                const SizedBox(height: 8),
                                Text(app.displayName ?? app.name ?? 'لاعب',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 21)),
                              ]))))),
              if (_loading)
                const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: LinearProgressIndicator(color: Color(0xFFFFC25C))),
              if (_refreshFailed)
                TextButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('تعذّر تحديث الجوائز — إعادة المحاولة')),
              _heading('تغيير الصورة', Icons.photo_outlined),
              Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                        onPressed: _saving
                            ? null
                            : () async {
                                await widget.onPickPhoto();
                                if (mounted) setState(() {});
                              },
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white38)),
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: const Text('رفع صورة')),
                    if ((app.avatarBase64?.isNotEmpty ?? false) ||
                        (app.avatarPath?.isNotEmpty ?? false))
                      TextButton(
                          onPressed: _saving
                              ? null
                              : () async {
                                  await widget.onRemovePhoto();
                                  if (mounted) setState(() {});
                                },
                          child: const Text('إزالة الصورة')),
                  ]),
              _heading('اختر إطار الصورة — المفتوح لك',
                  Icons.filter_frames_outlined),
              LayoutBuilder(builder: (context, constraints) {
                final cols = constraints.maxWidth < 350 ? 3 : 4;
                final width = (constraints.maxWidth - (cols - 1) * 10) / cols;
                return Wrap(spacing: 10, runSpacing: 10, children: [
                  SizedBox(
                      width: width,
                      child: _tile(
                          selected: _frame == null,
                          tap: () => setState(() => _frame = null),
                          label: 'بدون إطار',
                          child: SizedBox(
                              height: 76, child: Center(child: _portrait())))),
                  for (final option in frames)
                    SizedBox(
                        width: width,
                        child: _tile(
                            selected: _frame == option.id,
                            tap: () => setState(() => _frame = option.id),
                            label: option.label,
                            child: buildAvatarThemeWidget(
                                themeId: option.id,
                                size: math.min(82, width - 20),
                                animate: false,
                                child: _portrait()))),
                ]);
              }),
              _heading('بنرات المستويات — المفتوح لك', Icons.panorama_outlined),
              if (banners.isEmpty)
                const Text('تظهر بنرات مستوياتك هنا بعد تحديث الجوائز.',
                    style: TextStyle(color: Colors.white70)),
              Wrap(spacing: 10, runSpacing: 10, children: [
                for (final rank in banners)
                  SizedBox(
                      width: 150,
                      child: _tile(
                          selected: _card == rank.bannerId,
                          tap: () => setState(() => _card = rank.bannerId),
                          label: 'بنر ${rank.arabic} • ${rank.metalAr}',
                          child: RankBannerPreview(rank: rank))),
              ]),
              _heading('لون الملف', Icons.palette_outlined),
              Wrap(spacing: 10, runSpacing: 8, children: [
                for (final color in [
                  ('navy', 'كحلي'),
                  ('blue', 'أزرق'),
                  ('violet', 'بنفسجي')
                ])
                  ChoiceChip(
                      label: Text(color.$2),
                      selected: _card == color.$1,
                      onSelected: _saving
                          ? null
                          : (_) => setState(() => _card = color.$1)),
              ]),
              const SizedBox(height: 20),
              FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFFC25C),
                      foregroundColor: const Color(0xFF172C41)),
                  onPressed: _saving || _loading ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check),
                  label: const Text('حفظ المظهر')),
            ]),
      )),
    );
  }
}

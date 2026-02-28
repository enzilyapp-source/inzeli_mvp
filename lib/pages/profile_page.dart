// lib/pages/profile_page.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/app_snackbar.dart';

import '../state.dart';
import '../widgets/streak_flame.dart'; // uses: StreakFlame(streak: ...)
import '../widgets/avatar_effects.dart';
import 'store_page.dart';
import 'my_items_page.dart';
import '../sfx.dart';
import 'signin_page.dart';
import '../api_user.dart';

class ProfilePage extends StatefulWidget {
  final AppState app;
  const ProfilePage({super.key, required this.app});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const _deleteUrl = 'https://web.enzily.app/delete-account.html';
  // thresholds and labels for “الأنواط”
  static const List<int> _milestones = [5, 10, 15, 20, 30];
  AvatarEffectType? _avatarEffect; // default: no theme until user picks
  int _cardThemeIndex = 0; // 0: blue, 1: navy, 2: violet
  List<String> _labels(AppState app) => [
    app.tr(ar: 'عليمي', en: 'Beginner'),
    app.tr(ar: 'يمشي حاله', en: 'Advance'),
    app.tr(ar: 'زين', en: 'Professional'),
    app.tr(ar: 'فنان', en: 'Legend'),
    app.tr(ar: 'فلتة', en: 'GOAT'),
  ];

  final ImagePicker _picker = ImagePicker();
  int _wins = 0;
  int _losses = 0;
  int _games = 0;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  @override
  void initState() {
    super.initState();
    _avatarEffect = _effectFromId(widget.app.themeId);
    _cardThemeIndex = _cardIndexFromId(widget.app.cardId);
    _nameCtrl = TextEditingController(text: _meName());
    _emailCtrl = TextEditingController(text: widget.app.email ?? '');
    _phoneCtrl = TextEditingController(text: widget.app.phone ?? '');
    _wins = widget.app.winsOf(_meName(), _currentGame());
    _losses = widget.app.lossesOf(_meName(), _currentGame());
    _games = widget.app.totalGamesPlayed(_meName());
    _loadStats();
  }

  String _meName() => widget.app.displayName ?? widget.app.name ?? 'لاعب';
  String _currentGame() {
    String game = widget.app.selectedGame ?? '—';
    if (widget.app.gamePearls.isNotEmpty) {
      final top = widget.app.gamePearls.entries.reduce((a, b) => a.value >= b.value ? a : b);
      game = top.key;
    }
    return game;
  }

  (String, int) _topPearlGame(AppState app) {
    if (app.gamePearls.isNotEmpty) {
      final top = app.gamePearls.entries.reduce((a, b) => a.value >= b.value ? a : b);
      return (app.gameLabel(top.key), top.value);
    }
    if (app.selectedGame != null && app.selectedGame!.isNotEmpty) {
      return (app.gameLabel(app.selectedGame!), app.pearlsForGame(app.selectedGame!));
    }
    return (app.tr(ar: 'بدون لعبة', en: 'No game'), 0);
  }

  List<(String, DateTime)> _recentWins(String player) {
    final wins = widget.app.timeline
        .where((t) => t.winner == player)
        .toList()
      ..sort((a, b) => b.ts.compareTo(a.ts));

    return wins.take(3).map((t) => (widget.app.gameLabel(t.game), t.ts)).toList();
  }

  String _shortId(String id) {
    final clean = id.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (clean.isEmpty) return '';
    final short = clean.length > 6 ? clean.substring(clean.length - 6) : clean.padLeft(6, '0');
    return '#$short';
  }

  AvatarEffectType? _effectFromId(String? id) {
    switch (id) {
      case 'blueThunder':
        return AvatarEffectType.blueThunder;
      case 'goldLightning':
        return AvatarEffectType.goldLightning;
      case 'kuwait':
        return AvatarEffectType.kuwaitSparkles;
      case 'greenLeaf':
        return AvatarEffectType.greenLeaf;
      case 'flameBlue':
        return AvatarEffectType.flameBlue;
      default:
        return null;
    }
  }

  String? _effectId(AvatarEffectType? effect) {
    switch (effect) {
      case AvatarEffectType.blueThunder:
        return 'blueThunder';
      case AvatarEffectType.goldLightning:
        return 'goldLightning';
      case AvatarEffectType.kuwaitSparkles:
        return 'kuwait';
      case AvatarEffectType.greenLeaf:
        return 'greenLeaf';
      case AvatarEffectType.flameBlue:
        return 'flameBlue';
      default:
        return null;
    }
  }

  int _cardIndexFromId(String? id) {
    switch (id) {
      case 'navy':
        return 1;
      case 'violet':
        return 2;
      case 'blue':
      default:
        return 0;
    }
  }

  String _cardId(int idx) {
    switch (idx) {
      case 1:
        return 'navy';
      case 2:
        return 'violet';
      default:
        return 'blue';
    }
  }

  Future<void> _loadStats() async {
    final uid = widget.app.userId;
    if (uid == null || uid.isEmpty) return;
    try {
      final stats = await getUserStats(uid, token: widget.app.token);
      if (stats == null) return;
      setState(() {
        _wins = (stats['wins'] as num?)?.toInt() ?? _wins;
        _losses = (stats['losses'] as num?)?.toInt() ?? _losses;
        _games = _wins + _losses;
      });
      final gp = stats['gamePearls'];
      if (gp is Map) {
        widget.app.gamePearls = gp.map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0));
        await widget.app.saveState();
        if (mounted) setState(() {});
      }
    } catch (_) {}
  }

  Future<void> _pickAvatar() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (kIsWeb) {
        await widget.app.setAvatarBytes(bytes, fallbackPath: null);
      } else {
        await widget.app.setAvatarBytes(bytes, fallbackPath: picked.path);
      }
      if (mounted) {
        Sfx.tap(mute: widget.app.soundMuted == true);
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;
      Sfx.error(mute: widget.app.soundMuted == true);
      _msg('فشل اختيار الصورة: $e');
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _msg(String text, {bool error = false, bool success = false}) {
    showAppSnack(context, text, error: error, success: success);
  }

  Future<void> _openDeleteWeb() async {
    final app = widget.app;
    final uri = Uri.parse(_deleteUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) _msg(app.tr(ar: 'تعذّر فتح رابط الحذف', en: 'Could not open delete link'));
  }

  Future<void> _confirmDelete(AppState app) async {
    if (app.token == null || app.token!.isEmpty) {
      _msg('سجّل الدخول أولاً');
      return;
    }

    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        bool confirmed = false;
        return StatefulBuilder(
          builder: (ctx, setDialog) => AlertDialog(
            title: Text(app.tr(ar: 'تأكيد حذف الحساب', en: 'Confirm account deletion')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(app.tr(
                  ar: 'سيتم حذف حسابك وجميع بياناتك نهائياً ولا يمكن التراجع.',
                  en: 'Your account and data will be permanently deleted and cannot be restored.',
                )),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: confirmed,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(app.tr(
                    ar: 'أوافق على حذف الحساب نهائياً',
                    en: 'I understand and agree to delete my account',
                  )),
                  onChanged: (v) => setDialog(() => confirmed = v ?? false),
                ),
                const SizedBox(height: 6),
                TextButton(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
                  onPressed: () => _openDeleteWeb(),
                  child: Text(
                    app.tr(
                      ar: 'بدلاً من ذلك، احذف الحساب عبر الويب',
                      en: 'Alternatively, delete your account on the web',
                    ),
                    style: TextStyle(color: Theme.of(context).colorScheme.primary),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(app.tr(ar: 'إلغاء', en: 'Cancel')),
              ),
              TextButton(
                onPressed: confirmed ? () => Navigator.of(ctx).pop(true) : null,
                child: Text(
                  app.tr(ar: 'حذف نهائياً', en: 'Delete'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (sure != true) return;
    if (!mounted) return;

    // show quick loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final res = await deleteAccount(token: app.token!);

    if (mounted) Navigator.of(context).pop(); // close loader

    if (res['ok'] == true) {
      await app.clearAuth();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => SignInPage(app: app)),
        (route) => false,
      );
      if (!mounted) return;
      _msg(app.tr(ar: 'تم حذف الحساب', en: 'Account deleted'));
    } else {
      if (!mounted) return;
      _msg(res['message']?.toString() ?? app.tr(ar: 'فشل الحذف', en: 'Deletion failed'));
    }
  }

  Future<void> _openStore(AppState app) async {
    if (!app.isSignedIn) {
      _msg('سجّل الدخول أولاً');
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StorePage(app: app)),
    );
    setState(() {});
  }

  Future<void> _openItems(AppState app) async {
    if (!app.isSignedIn) {
      _msg('سجّل الدخول أولاً');
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MyItemsPage(app: app)),
    );
    setState(() {});
  }

  void _openSettings(AppState app) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        String selected = app.isEnglish ? 'en' : 'ar';
        bool muted = app.soundMuted ?? false;
        bool privateProfile = app.profilePrivate ?? false;
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('إعدادات الحساب', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 10),

                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'الاسم'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(labelText: 'الإيميل'),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(labelText: 'رقم الجوال'),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('تغيير الصورة'),
                      onPressed: _pickAvatar,
                    ),

                    const SizedBox(height: 16),
                    const Text('إعدادات التطبيق', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                    const SizedBox(height: 10),
                    const Text('اللغة', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'ar', label: Text('العربية')),
                        ButtonSegment(value: 'en', label: Text('English')),
                      ],
                      selected: {selected},
                      onSelectionChanged: (s) {
                        selected = s.first;
                        app.setLanguage(selected);
                        setState(() {});
                        setSheet(() {});
                      },
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: muted,
                      onChanged: (v) {
                        muted = v;
                        app.setSoundMuted(v);
                        setState(() {});
                        setSheet(() {});
                      },
                      title: const Text('كتم الصوت'),
                      subtitle: const Text('إيقاف المؤثرات الصوتية'),
                    ),
                    SwitchListTile(
                      value: privateProfile,
                      onChanged: (v) {
                        privateProfile = v;
                        app.setProfilePrivate(v);
                        setState(() {});
                        setSheet(() {});
                      },
                      title: const Text('إخفاء الملف الشخصي'),
                      subtitle: const Text('عند الإخفاء يظهر في البحث الثيم + أفضل لعبة + فوز/خسارة فقط'),
                    ),

                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.close),
                          label: const Text('إغلاق'),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                        FilledButton.icon(
                          icon: const Icon(Icons.save),
                          label: const Text('حفظ التغييرات'),
                          onPressed: () async {
                            app.displayName = _nameCtrl.text.trim().isEmpty ? app.displayName : _nameCtrl.text.trim();
                            app.email = _emailCtrl.text.trim().isEmpty ? app.email : _emailCtrl.text.trim();
                            app.phone = _phoneCtrl.text.trim().isEmpty ? app.phone : _phoneCtrl.text.trim();
                            await app.saveState();
                            if (mounted) setState(() {});
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                        ),
                      ],
                    ),

                    if (app.isSignedIn) ...[
                      const SizedBox(height: 12),
                      const Divider(),
                      TextButton.icon(
                        icon: const Icon(Icons.logout, color: Colors.red),
                        label: Text(
                          app.tr(ar: 'تسجيل خروج', en: 'Log out'),
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
                        ),
                        onPressed: () async {
                          await app.clearAuth();
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          if (!mounted) return;
                          setState(() {});
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => SignInPage(app: app)),
                            (route) => false,
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      TextButton.icon(
                        icon: const Icon(Icons.delete_forever, color: Colors.red),
                        label: Text(
                          app.tr(ar: 'حذف الحساب', en: 'Delete account'),
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w800),
                        ),
                        onPressed: () => _confirmDelete(app),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openAvatarThemePicker() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final effects = <(AvatarEffectType?, String)>[
          (null, 'بدون ثيم'),
          (AvatarEffectType.blueThunder, 'برق أزرق'),
          (AvatarEffectType.goldLightning, 'برق ذهبي'),
          (AvatarEffectType.kuwaitSparkles, 'ألوان العلم'),
          (AvatarEffectType.greenLeaf, 'أوراق خضراء'),
        ];
        final cardThemes = [
          ('أزرق', 0),
          ('كحلي', 1),
          ('بنفسجي', 2),
        ];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('تعديل الصورة والثيم', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _pickAvatar,
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('تغيير الصورة'),
                ),
                const SizedBox(height: 12),
                const Text('ثيم الهالة حول الصورة', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: effects.map((e) {
                      final selected = _avatarEffect == e.$1;
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: GestureDetector(
                          onTap: () => setState(() => _avatarEffect = e.$1),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AvatarEffect(
                                effect: e.$1 ?? AvatarEffectType.blueThunder,
                                size: 74,
                                animate: e.$1 != null,
                                child: CircleAvatar(
                                  radius: 26,
                                  backgroundColor: Colors.white24,
                                  child: Text(e.$2.characters.first, style: const TextStyle(color: Colors.white)),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                e.$2,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: selected ? Theme.of(context).colorScheme.primary : Colors.white70,
                                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('ثيم كرت الملف', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: cardThemes.map((c) {
                    final selected = _cardThemeIndex == c.$2;
                    return ChoiceChip(
                      label: Text(c.$1),
                      selected: selected,
                      onSelected: (_) => setState(() => _cardThemeIndex = c.$2),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () async {
                      widget.app.themeId = _effectId(_avatarEffect);
                      widget.app.cardId = _cardId(_cardThemeIndex);
                      await widget.app.saveState();
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      setState(() {});
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('حفظ'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    // أفضل لعبة = أعلى رصيد لآلئ، وإلا المختارة/أول لعبة
    String game = app.selectedGame ?? '—';
    if (app.gamePearls.isNotEmpty) {
      final top = app.gamePearls.entries.reduce((a, b) => a.value >= b.value ? a : b);
      game = top.key;
    }
    final gameLabel = app.gameLabel(game);
    final meName = app.displayName ?? app.name ?? 'لاعب';
    final displayUserId = app.publicId ?? app.userId ?? '';
    final (topGameName, topPearls) = _topPearlGame(app);
    // النوطة الحالية بناءً على أعلى لؤلؤة
    String currentRankLabelForPearls(int pearls) {
      int milestone = _milestones.first;
      for (final m in _milestones) {
        if (pearls >= m) milestone = m;
      }
      return _rankName(_labelFor(milestone));
    }
    final currentRank = currentRankLabelForPearls(topPearls);
    final recentWins = _recentWins(meName);
    final headerBg = _cardThemeIndex == 0
        ? const Color(0xFF1E2F4D)
        : _cardThemeIndex == 1
            ? const Color(0xFF0F1D32)
            : const Color(0xFF2D1B46); // violet theme option

    // level ring uses wins/losses for the currently selected game
    final lvl = app.levelForGame(meName, game);
    ImageProvider? avatarImage;
    if (app.avatarBase64 != null && app.avatarBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(app.avatarBase64!);
        avatarImage = MemoryImage(bytes);
      } catch (_) {}
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header (hero with avatar, top game pearls, and recent trophies)
          Card(
            elevation: 6,
            clipBehavior: Clip.none,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: SizedBox(
              height: 176,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: headerBg,
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white24, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.workspace_premium, size: 16, color: Color(0xFFF1A949)),
                          const SizedBox(width: 6),
                          Text(
                            currentRank,
                            style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    bottom: -12,
                    child: _PearlBadge(
                      game: topGameName,
                      pearls: topPearls,
                      size: 60,
                    ),
                  ),
                  Positioned(
                    right: 12,
                    bottom: -12,
                    child: _TrophyStrip(
                      recentWins: recentWins,
                      size: 42,
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            if (_avatarEffect != null)
                              AvatarEffect(
                                effect: _avatarEffect!,
                                size: 108,
                                animate: true,
                                child: CircleAvatar(
                                  radius: 42,
                                  backgroundImage: avatarImage,
                                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                                  child: avatarImage == null
                                      ? Text(
                                          meName.isNotEmpty ? meName.characters.first : '؟',
                                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                                        )
                                      : null,
                                ),
                              )
                            else
                              CircleAvatar(
                                radius: 42,
                                backgroundImage: avatarImage,
                                backgroundColor: Colors.white.withValues(alpha: 0.12),
                                child: avatarImage == null
                                    ? Text(
                                        meName.isNotEmpty ? meName.characters.first : '؟',
                                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                                      )
                                    : null,
                              ),
                            Positioned(
                              bottom: 2,
                              right: 4,
                              child: InkWell(
                                onTap: _openAvatarThemePicker,
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.edit, size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          meName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                        if (displayUserId.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            _shortId(displayUserId),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .72),
                              fontSize: 12,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 10),

        // Stats row (icons فقط)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _IconStat(icon: Icons.emoji_events_outlined, value: _wins, sparkleColor: Colors.greenAccent),
            _IconStat(icon: Icons.cancel_outlined, value: _losses, sparkleColor: Colors.redAccent),
            _IconStat(icon: Icons.sports_esports_outlined, value: _games),
          ],
        ),

        const SizedBox(height: 12),

        // Pearls per game (دائرة تعبئة لكل لعبة)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _PearlCircleGrid(
              entries: _gamePearlEntries(app),
              maxValue: _milestones.last,
              milestones: _milestones,
              rankLabel: _labelFor,
              rankName: _rankName,
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Quick actions row moved to bottom
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _QuickActionChip(
              icon: Icons.settings_outlined,
              label: app.tr(ar: 'الإعدادات', en: 'Settings'),
              onTap: () => _openSettings(app),
            ),
            _QuickActionChip(
              icon: Icons.shopping_bag_outlined,
              label: app.tr(ar: 'المتجر', en: 'Market'),
              onTap: () => _openStore(app),
            ),
            _QuickActionChip(
              icon: Icons.style_outlined,
              label: app.tr(ar: 'ثيماتي', en: 'My Themes'),
              onTap: () => _openItems(app),
            ),
          ],
        ),

      if (app.ownedDewanyahs.isNotEmpty) ...[
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app.tr(ar: 'ديوانياتي', en: 'My Dewanyahs'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                ...app.ownedDewanyahs.map<Widget>((d) {
                  final name = (d['name'] ?? 'ديوانية').toString();
                  final gameId = (d['gameId'] ?? '—').toString();
                  final status = (d['status'] ?? 'pending').toString();
                  final pearls = (d['startingPearls'] ?? 5).toString();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.groups_3_outlined),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(app.tr(
                        ar: 'اللعبة: $gameId • يبدأ بـ $pearls لؤلؤة',
                        en: 'Game: $gameId • Starts with $pearls pearls',
                      )),
                      trailing: _StatusBadge(label: status),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],

      const SizedBox(height: 12),

      // Milestones (الأنواط) row as animated orbs
      Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app.tr(ar: 'الأنواط', en: 'Ranks'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _milestones.map((m) {
                    final got = app.winsOf(meName, game);
                    final achieved = got >= m;
                    return _RankOrb(
                      label: _labelFor(m),
                      count: m,
                      achieved: achieved,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Current game “level” ring + streak
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  height: 110,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        painter: _RingPainter(fill01: lvl.fill01),
                      ),
                      Text(
                        _rankName(lvl.name),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.tr(ar: 'اللعبة الحالية: $gameLabel', en: 'Current game: $gameLabel'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          StreakFlame(
                            streak: _winStreak(meName, game),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            app.tr(ar: 'سلسلة الانتصارات', en: 'Win streak'),
                            style: TextStyle(
                              color: onSurface.withValues(alpha: .75),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

      ],
    );
  }

  // ---------- helpers ----------

  String _labelFor(int milestone) {
    final labels = _labels(widget.app);
    final idx = _milestones.indexOf(milestone);
    return (idx >= 0 && idx < labels.length) ? labels[idx] : '';
    // 5: عليمي, 10: يمشي حاله, 15: زين, 20: فنان, 30: فلتة
  }

  String _rankName(String name) {
    return widget.app.tr(
      ar: name,
      en: switch (name) {
        'عليمي' => 'Beginner',
        'يمشي حاله' => 'Advance',
        'زين' => 'Professional',
        'فنان' => 'Legend',
        'فلتة' => 'GOAT',
        'بدايات' => 'Newbie',
        _ => name,
      },
    );
  }

  List<(String, int)> _gamePearlEntries(AppState app) {
    final entries = <(String, int)>[];
    for (final cat in app.games.values) {
      for (final g in cat) {
        entries.add((app.gameLabel(g), app.pearlsForGame(g)));
      }
    }
    final seen = <String>{};
    final uniq = <(String, int)>[];
    for (final e in entries) {
      if (seen.add(e.$1)) uniq.add(e);
    }
    uniq.sort((a, b) => a.$1.compareTo(b.$1));
    return uniq;
  }

  int _winStreak(String user, String game) {
    // simple local streak using timeline (latest-first)
    final list = widget.app
        .userMatches(user)
        .where((t) => t.game == game)
        .toList()
      ..sort((a, b) => b.ts.compareTo(a.ts));

    int streak = 0;
    for (final t in list) {
      if (t.winner == user) {
        streak += 1;
      } else {
        break;
      }
    }
    return streak;
  }

}

/* ---------------- painters / small widgets ---------------- */

class _RingPainter extends CustomPainter {
  final double fill01; // 0..1
  _RingPainter({required this.fill01});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2 - 3;

    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = const Color(0xFF90CAF9).withValues(alpha: .25);

    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 8
      ..color = const Color(0xFF29B6F6);

    canvas.drawCircle(c, r, bg);
    final sweep =
        (fill01.clamp(0, 1) as double) * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      sweep,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.fill01 != fill01;
}

class _PearlBadge extends StatelessWidget {
  final String game;
  final int pearls;
  final double size;
  const _PearlBadge({required this.game, required this.pearls, this.size = 72});

  @override
  Widget build(BuildContext context) {
    final double topOffset = size * 0.2;
    final double bottomOffset = size * 0.18;
    return Stack(
      alignment: Alignment.center,
      children: [
        _SparkleOnce(
          color: const Color(0xFFF1A949),
          size: size + 16,
        ),
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: topOffset,
                left: 0,
                right: 0,
                child: Text(
                  '$pearls',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF1E2F4D),
                    fontWeight: FontWeight.w900,
                    fontSize: size * 0.28,
                  ),
                ),
              ),
              Positioned(
                bottom: bottomOffset,
                left: 8,
                right: 8,
                child: Text(
                  game,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w700,
                    fontSize: size * 0.17,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrophyStrip extends StatelessWidget {
  final List<(String, DateTime)> recentWins;
  final double size;
  const _TrophyStrip({required this.recentWins, this.size = 46});

  @override
  Widget build(BuildContext context) {
    final trophies = recentWins.take(3).toList();
    const trophyFill = Color(0xFFE3E6EF);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        if (i >= trophies.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: _TrophyCircle(
              label: '—',
              date: null,
              filled: false,
              color: Colors.white.withValues(alpha: .4),
              size: size,
            ),
          );
        }
        final t = trophies[i];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: _TrophyCircle(
            label: t.$1,
            date: t.$2,
            filled: true,
            color: trophyFill,
            size: size,
          ),
        );
      }),
    );
  }
}

class _TrophyCircle extends StatelessWidget {
  final String label;
  final DateTime? date;
  final bool filled;
  final Color color;
  final double size;
  const _TrophyCircle({required this.label, required this.date, required this.filled, required this.color, this.size = 46});

  @override
  Widget build(BuildContext context) {
    final textColor = filled ? Colors.black : Colors.white;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: filled ? color : Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events_rounded, size: size * 0.35, color: Colors.amber),
            if (filled) ...[
              SizedBox(height: size * 0.05),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w800,
                  fontSize: size * 0.22,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RankOrb extends StatelessWidget {
  final String label;
  final int count;
  final bool achieved;
  const _RankOrb({required this.label, required this.count, required this.achieved});

  @override
  Widget build(BuildContext context) {
    final style = _rankStyle(label);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            if (achieved && style.sparkle != null)
              _SparkleOnce(
                color: style.sparkle!,
                size: 78,
                duration: const Duration(milliseconds: 2200),
              ),
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: style.gradient,
                boxShadow: [
                  BoxShadow(
                    color: (style.shadow ?? Colors.black26).withValues(alpha: achieved ? 0.35 : 0.2),
                    blurRadius: achieved ? 14 : 8,
                    offset: const Offset(0, 6),
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withValues(alpha: achieved ? 0.22 : 0.12),
                  width: 1.4,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // metallic sheen
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white24,
                            Colors.transparent,
                            Colors.white10,
                          ],
                          stops: [0.0, 0.45, 0.9],
                        ),
                      ),
                    ),
                  ),
                  // inner highlight ring
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.24),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                        stops: const [0.0, 1.0],
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontVariations: const [FontVariation('wght', 800)],
                        fontSize: 18,
                        letterSpacing: 0.2,
                        color: style.text ?? Colors.white,
                        shadows: [
                          Shadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 6),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: .75),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  _RankStyle _rankStyle(String label) {
    switch (label) {
      case 'عليمي':
      case 'Beginner':
        return _RankStyle(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFE082), Color(0xFFF6C453), Color(0xFFCE9E2B)],
            stops: [0.0, 0.55, 1.0],
          ),
          sparkle: const Color(0xFFFFE082),
        );
      case 'يمشي حاله':
      case 'Advance':
        return _RankStyle(
          gradient: const LinearGradient(
            colors: [Color(0xFFD7A15F), Color(0xFFB87733), Color(0xFF8A4B2E)],
            stops: [0.0, 0.45, 1.0],
          ),
          sparkle: const Color(0xFFD7A15F),
        );
      case 'زين':
      case 'Professional':
        return _RankStyle(
          gradient: const LinearGradient(
            colors: [Color(0xFFEFF3F8), Color(0xFFC9D0D9), Color(0xFF9FA9B5)],
            stops: [0.0, 0.55, 1.0],
          ),
          sparkle: const Color(0xFFFFFFFF),
          text: Colors.black87,
          shadow: const Color(0xFF90A4AE),
        );
      case 'فنان':
      case 'Legend':
        return _RankStyle(
          gradient: const LinearGradient(
            colors: [Color(0xFFE0FEFF), Color(0xFFA0F3FF), Color(0xFF5CD7F7)],
            stops: [0.0, 0.55, 1.0],
          ),
          sparkle: const Color(0xFFA5F2FF),
          text: const Color(0xFF0A2C35),
          shadow: const Color(0xFF4DD0E1),
        );
      case 'فلتة':
      case 'GOAT':
        return _RankStyle(
          gradient: const LinearGradient(
            colors: [Color(0xFFB388FF), Color(0xFF8E24AA), Color(0xFF512DA8)],
            stops: [0.0, 0.5, 1.0],
          ),
          sparkle: const Color(0xFFE0E0FF),
          text: const Color(0xFFF5F5F5),
          shadow: const Color(0xFF7E57C2),
        );
      default:
        return _RankStyle(
          gradient: const LinearGradient(colors: [Color(0xFF607D8B), Color(0xFF455A64)]),
          sparkle: const Color(0xFF90A4AE),
        );
    }
  }
}

class _RankStyle {
  final Gradient gradient;
  final Color? sparkle;
  final Color? text;
  final Color? shadow;
  _RankStyle({required this.gradient, this.sparkle, this.text, this.shadow});
}
class _SparkleOnce extends StatefulWidget {
  final Color color;
  final double size;
  final Duration duration;
  const _SparkleOnce({
    required this.color,
    this.size = 60,
    this.duration = const Duration(milliseconds: 1800),
  });

  @override
  State<_SparkleOnce> createState() => _SparkleOnceState();
}

class _SparkleOnceState extends State<_SparkleOnce> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _SparklePainter(
            color: widget.color,
            progress: Curves.easeOut.transform(_ctrl.value),
          ),
        ),
      ),
    );
  }
}

class _SparklePainter extends CustomPainter {
  final Color color;
  final double progress; // 0..1
  _SparklePainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseR = size.shortestSide / 2.8;
    final sparkles = 16;
    final maxBurst = size.shortestSide * 0.45;
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < sparkles; i++) {
      final angle = (2 * math.pi / sparkles) * i;
      final burst = baseR + progress * maxBurst;
      final pos = center + Offset(math.cos(angle), math.sin(angle)) * burst;
      final fade = (1 - progress).clamp(0.0, 1.0);
      final alpha = (fade * 0.7).clamp(0.0, 0.7);
      paint.color = color.withValues(alpha: alpha);
      final radius = (1.2 + (i % 3) * 0.4) * fade * 1.8;
      canvas.drawCircle(pos, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  const _StatusBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final lc = label.toLowerCase();
    Color color;
    String text;
    if (lc.contains('pending') || lc.contains('قيد')) {
      color = Colors.amber;
      text = 'قيد التفعيل';
    } else if (lc.contains('live') || lc.contains('open')) {
      color = Colors.greenAccent;
      text = 'مفتوحة';
    } else {
      color = Colors.blueGrey.shade200;
      text = label;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _IconStat extends StatefulWidget {
  final IconData icon;
  final int value;
  final Color? sparkleColor;
  const _IconStat({required this.icon, required this.value, this.sparkleColor});

  @override
  State<_IconStat> createState() => _IconStatState();
}

class _IconStatState extends State<_IconStat> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _scale = Tween<double>(begin: 1, end: 0.9).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _ctrl.forward();
  void _onTapCancel() => _ctrl.reverse();
  void _onTapUp(TapUpDetails _) => _ctrl.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapCancel: _onTapCancel,
      onTapUp: _onTapUp,
      child: ScaleTransition(
        scale: _scale,
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                if (widget.sparkleColor != null)
                  _SparkleOnce(
                    color: widget.sparkleColor!,
                    size: 54,
                  ),
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  child: Icon(widget.icon, color: Colors.white, size: 22),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('${widget.value}', style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickActionChip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFF1A949);
    return ActionChip(
      onPressed: onTap,
      avatar: Icon(icon, size: 18, color: accent),
      label: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: accent,
        ),
      ),
      shape: StadiumBorder(side: BorderSide(color: accent.withValues(alpha: 0.35))),
      backgroundColor: Colors.white,
      elevation: 2,
      shadowColor: Colors.black12,
    );
  }
}

class _PearlCircleGrid extends StatelessWidget {
  final List<(String, int)> entries;
  final int maxValue;
  final List<int> milestones;
  final String Function(int) rankLabel;
  final String Function(String) rankName;
  const _PearlCircleGrid({required this.entries, required this.maxValue, required this.milestones, required this.rankLabel, required this.rankName});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const Text('لا توجد بيانات');
    final color = Theme.of(context).colorScheme.primary;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: entries.map((e) {
        final game = e.$1;
        final value = e.$2.clamp(0, maxValue);
        final pct = value / maxValue;
        return SizedBox(
          width: 88,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: pct),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) => SizedBox(
                      width: 74,
                      height: 74,
                      child: CustomPaint(
                        painter: _ArcPainter(
                          progress: v,
                          color: color,
                          bgColor: Colors.grey.shade800,
                          strokeWidth: 7,
                        ),
                      ),
                    ),
                  ),
                  Text('$value', style: const TextStyle(fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 6),
              Text(game, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(rankLabel(_nearestRank(value)), style: TextStyle(fontSize: 11, color: Colors.white70)),
            ],
          ),
        );
      }).toList(),
    );
  }

  int _nearestRank(int value) {
    for (final m in milestones) {
      if (value <= m) return m;
    }
    return milestones.last;
  }
}

class _ArcPainter extends CustomPainter {
  final double progress; // 0..1
  final Color color;
  final Color bgColor;
  final double strokeWidth;

  _ArcPainter({required this.progress, required this.color, required this.bgColor, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final start = -math.pi / 2;
    final sweep = 2 * math.pi * progress;

    // background
    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, bgPaint);

    // progress
    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, start, sweep, false, fgPaint);
  }

  @override
  bool shouldRepaint(covariant _ArcPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color || oldDelegate.bgColor != bgColor || oldDelegate.strokeWidth != strokeWidth;
  }
}
//profile_page.dart

// lib/pages/games_page.dart
import 'package:flutter/material.dart';

import '../state.dart';
import '../api_room.dart';
// لو حبيتي تستخدمين القواعد لاحقًا
import '../widgets/room_timer_banner.dart';
import 'match_page.dart';
import 'scan_page.dart';

class GamesPage extends StatefulWidget {
  final AppState app;
  const GamesPage({super.key, required this.app});

  @override
  State<GamesPage> createState() => _GamesPageState();
}

class _GamesPageState extends State<GamesPage> {
  final TextEditingController _joinCtrl = TextEditingController();
  late final PageController _catPage;

  AppState get app => widget.app;

  @override
  void initState() {
    super.initState();
    _catPage = PageController(viewportFraction: 0.8);
    // إذا ما في اختيار سابق، نختار أول كاتيجوري
    if (app.selectedCategory == null && app.categories.isNotEmpty) {
      app.setSelectedGame(null, category: app.categories.first);
    }
    // لو في Game محفوظة، نخليه، وإلا نختار أول لعبة في الكاتيجوري
    if (app.selectedGame == null &&
        app.selectedCategory != null &&
        app.games[app.selectedCategory] != null &&
        app.games[app.selectedCategory]!.isNotEmpty) {
      final g = app.games[app.selectedCategory]!.first;
      app.setSelectedGame(g, category: app.selectedCategory);
    }
  }

  @override
  void dispose() {
    _joinCtrl.dispose();
    _catPage.dispose();
    super.dispose();
  }

  void _msg(String text) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  String? get _selectedCategory => app.selectedCategory;
  String? get _selectedGame => app.selectedGame;

  // ------------ Actions: Create / Join ------------

  Future<void> _createRoomForSelectedGame() async {
    if (!app.isSignedIn) {
      _msg('سجّل الدخول أولًا');
      return;
    }
    final game = _selectedGame;
    if (game == null || game.isEmpty) {
      _msg('اختَر اللعبة أولًا');
      return;
    }
    if (!app.spendPearlForGame(game)) {
      _msg('رصيد لآلئ هذه اللعبة انتهى لهذا الشهر');
      return;
    }
    if (app.token == null || app.token!.isEmpty) {
      _msg('التوكن غير موجود — سجّل دخول مرة ثانية');
      return;
    }

    try {
      final room = await ApiRoom.createRoom(
        gameId: game,
        token: app.token,
      );
      final code = room['code']?.toString();
      app.setRoomCode(code);

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MatchPage(
            app: app,
            room: room,
          ),
        ),
      );
      setState(() {});
    } catch (e) {
      _msg('فشل إنشاء الروم: $e');
    }
  }

  Future<void> _joinRoomByCode() async {
    if (!app.isSignedIn) {
      _msg('سجّل الدخول أولًا');
      return;
    }
    final code = _joinCtrl.text.trim();
    if (code.isEmpty) {
      _msg('اكتب كود الروم');
      return;
    }
    final game = _selectedGame;
    if (game == null || game.isEmpty) {
      _msg('اختَر اللعبة أولًا');
      return;
    }
    if (!app.spendPearlForGame(game)) {
      _msg('رصيد لآلئ هذه اللعبة انتهى لهذا الشهر');
      return;
    }
    if (app.token == null || app.token!.isEmpty) {
      _msg('التوكن غير موجود — سجّل دخول مرة ثانية');
      return;
    }

    try {
      await ApiRoom.joinByCode(
        code: code,
        token: app.token,
      );
      final room = await ApiRoom.getRoomByCode(
        code,
        token: app.token,
      );
      app.setRoomCode(code);

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MatchPage(
            app: app,
            room: room,
          ),
        ),
      );
      setState(() {});
    } catch (e) {
      _msg('تعذّر الانضمام: $e');
    }
  }

  Future<void> _scanAndJoin() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScanPage()),
    );
    if (code == null || code.isEmpty) return;
    _joinCtrl.text = code;
    await _joinRoomByCode();
  }

  Future<void> _openCurrentRoom() async {
    final code = app.roomCode;
    if (code == null || code.isEmpty) {
      _msg('ما عندك روم شغّال حاليًا');
      return;
    }
    try {
      final room = await ApiRoom.getRoomByCode(
        code,
        token: app.token,
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MatchPage(
            app: app,
            room: room,
          ),
        ),
      );
      setState(() {});
    } catch (e) {
      _msg('فشل فتح الروم الحالي: $e');
    }
  }

  // ------------ UI builders ------------

  Widget _buildUserCard() {
    final name = app.displayName ?? app.name ?? 'لاعب';
    final email = app.email ?? '';
    final pearls = app.pearls;
    final permanent = app.permanentScore ?? 0;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              child: Text(
                name.isNotEmpty ? name.characters.first : '؟',
                style:
                const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  if (email.isNotEmpty)
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.circle, size: 12),
                      const SizedBox(width: 4),
                      Text('لآلئك: $pearls'),
                      const SizedBox(width: 12),
                      const Icon(Icons.stacked_line_chart, size: 12),
                      const SizedBox(width: 4),
                      Text('نقاط اللعبة: $permanent'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPager() {
    final categories = app.categories;
    if (categories.isEmpty) {
      return const Text('لا توجد تصنيفات متاحة حاليًا');
    }
    final selected = _selectedCategory ?? categories.first;
    final currentIndex = categories.indexOf(selected).clamp(0, categories.length - 1);

    return Column(
      children: [
        SizedBox(
          height: 150,
          child: PageView.builder(
            controller: _catPage,
            itemCount: categories.length,
            onPageChanged: (idx) {
              final cat = categories[idx];
              app.setSelectedGame(null, category: cat);
              final list = app.games[cat] ?? const <String>[];
              if (list.isNotEmpty) app.setSelectedGame(list.first, category: cat);
              setState(() {});
            },
            itemBuilder: (_, idx) {
              final cat = categories[idx];
              final isSelected = idx == currentIndex;
              return _CategoryCard(
                title: app.categoryLabel(cat),
                isSelected: isSelected,
              );
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(categories.length, (i) {
            final active = i == currentIndex;
            return Container(
              width: active ? 12 : 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(active ? 0.9 : 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildGamesGrid() {
    final cat = _selectedCategory;
    final games = (cat != null) ? (app.games[cat] ?? const <String>[]) : const <String>[];

    if (games.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 24.0),
        child: Center(child: Text('لا توجد ألعاب لهذا التصنيف حاليًا')),
      );
    }

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.0,
      children: games.map((g) {
        final bool isSelected = g == _selectedGame;
        return GestureDetector(
          onTap: () {
            app.setSelectedGame(g, category: cat);
            setState(() {});
          },
          child: _GameCardImage(
            title: app.gameLabel(g),
            isSelected: isSelected,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCreateJoinRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: _createRoomForSelectedGame,
          icon: const Icon(Icons.add_box_outlined),
          label: const Text('انزلي'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _joinCtrl,
                decoration: const InputDecoration(
                  labelText: 'ادخل كود الروم',
                  hintText: 'مثال: ABC123',
                  filled: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _scanAndJoin,
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: 'مسح QR',
            ),
            const SizedBox(width: 4),
            FilledButton(
              onPressed: _joinRoomByCode,
              child: const Text('شرّف'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCurrentRoomSection() {
    final code = app.roomCode;
    if (code == null || code.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        RoomTimerBanner(
          code: code,
          token: app.token,
          dense: false,
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _openCurrentRoom,
          icon: const Icon(Icons.meeting_room_outlined),
          label: Text('العودة للروم الحالي ($code)'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cat = _selectedCategory ?? '—';
    final game = _selectedGame ?? 'اختر لعبة';

    return Scaffold(
      appBar: AppBar(
        title: const Text('ألعاب إنزلي'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF34677A), // lighter top
              Color(0xFF232E4A), // darker bottom
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 12,
              bottom: 12 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildUserCard(),
                const SizedBox(height: 12),
                if (app.roomCode != null) _buildCurrentRoomSection(),
                const SizedBox(height: 8),

                // عنوان صغير
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'اختر اللعبة والتصنيف:',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                _buildCategoryPager(),
                const SizedBox(height: 16),
                Text('التصنيف: ${app.categoryLabel(cat)} — اللعبة: ${app.gameLabel(game)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 12),

                _buildGamesGrid(),
                const SizedBox(height: 24),
                _buildCreateJoinRow(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GameCardImage extends StatelessWidget {
  final String title;
  final bool isSelected;
  const _GameCardImage({required this.title, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected ? const Color(0xFFE49A2C) : Colors.white24;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                )
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2D6A7A), Color(0xFF23344A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String title;
  final bool isSelected;
  const _CategoryCard({required this.title, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? const Color(0xFFE49A2C) : Colors.white24,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      height: 120,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2D6A7A), Color(0xFF23344A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.white.withOpacity(isSelected ? 1 : 0.8),
                shadows: const [Shadow(color: Colors.black45, blurRadius: 4)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SideFade extends StatelessWidget {
  final bool isLeft;
  const _SideFade({required this.isLeft});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: isLeft ? Alignment.centerLeft : Alignment.centerRight,
          end: isLeft ? Alignment.centerRight : Alignment.centerLeft,
          colors: [
            Colors.black.withOpacity(0.25),
            Colors.black.withOpacity(0.0),
          ],
        ),
      ),
    );
  }
}

class _ArrowHint extends StatelessWidget {
  final bool isLeft;
  const _ArrowHint({required this.isLeft});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: FractionallySizedBox(
        widthFactor: 1,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: isLeft ? 8 : 8),
          child: Row(
            mainAxisAlignment: isLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
            children: [
              Icon(
                isLeft ? Icons.arrow_back_ios_new : Icons.arrow_forward_ios,
                size: 16,
                color: Colors.white.withOpacity(0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

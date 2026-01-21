// lib/state.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ------------------------------
/// AppState (single source of truth)
/// ------------------------------
class AppState extends ChangeNotifier {
  // ---- Auth / user (from backend) ----
  String? token;
  String? userId;

  String? displayName;
  String? email;

  /// "لآلئ" used in UI (monthly/general wallet on the user model)
  int? creditPoints;
  /// رصيد الشراء (عملة المتجر) - يظهر لصاحب الحساب فقط
  int? creditBalance;

  /// Permanent score / lifetime score (if you use it elsewhere)
  int? permanentScore;

  // ---- Legacy / optional fields (some UI references them) ----
  String? name; // fallback name for older UI
  String? phone;

  // ---- App selections (used in leaderboard/profile pages) ----
  String? selectedCategory;
  String? selectedGame;

  // ---- Room ----
  String? roomCode;

  // ---- Profile extras ----
  String? bio50;
  String? activeSponsorCode;
  // اختيارات الثيم/الإطار/الكارت
  String? themeId;
  String? frameId;
  String? cardId;
  // إعدادات محلية
  String? language; // e.g. 'ar' / 'en'
  bool? soundMuted;
  bool? profilePrivate;
  // لآلئ شهرية لكل لعبة (تُعاد شهرياً إلى 5 لكل لعبة)
  Map<String, int> gamePearls = <String, int>{};
  String? pearlsResetMonth; // YYYY-MM
  List<Map<String, dynamic>> ownedDewanyahs = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> managedBoards = <Map<String, dynamic>>[];

  // ---- Local demo data (used by old leaderboard/player profile/timeline) ----
  final List<TimelineEntry> timeline = <TimelineEntry>[];

  /// Categories used by LeaderboardPage (old “filters” UI)
  final List<String> categories = const <String>[
    'جنجفة',
    'ألعاب شعبية',
    'رياضة',
  ];

  /// Games per category used by LeaderboardPage
  final Map<String, List<String>> games = const <String, List<String>>{
    'جنجفة': ['كوت', 'بلوت', 'تريكس', 'هند', 'سبيتة'],
    'ألعاب شعبية': ['شطرنج', 'دامه', 'كيرم', 'دومنه', 'طاوله', 'بلياردو'],
    'رياضة': ['بيبيفوت', 'قدم', 'سله', 'طائره', 'بولنج', 'بادل', 'تنس طاولة', 'تنس ارضي'],
  };

  /// Optional local profiles (used by PlayerProfilePage.profile())
  final Map<String, PlayerProfile> _profiles = <String, PlayerProfile>{};

  /// Local per-game stats (used by pointsOf / winsOf / lossesOf)
  /// key format: "$playerName|$game"
  final Map<String, _LocalStats> _stats = <String, _LocalStats>{};

  bool get isSignedIn => (token != null && token!.isNotEmpty && userId != null && userId!.isNotEmpty);
  bool get isEnglish => (language ?? 'ar') == 'en';

  /// Helper to pick localized strings without a full i18n system.
  String tr({required String ar, required String en}) => isEnglish ? en : ar;
  String gameLabel(String name) {
    final n = name.trim();
    if (!isEnglish) return n;
    const map = {
      'بلوت': 'Baloot',
      'كوت': 'Kout',
      'تريكس': 'Trex',
      'هند': 'Hind',
      'سبيتة': 'Spita',
      'شطرنج': 'Chess',
      'دامه': 'Checkers',
      'كيرم': 'Carrom',
      'دومنه': 'Domino',
      'طاوله': 'Backgammon',
      'بلياردو': 'Billiards',
      'بيبيفوت': 'Baby Foot',
      'قدم': 'Football',
      'سله': 'Basketball',
      'طائره': 'Volleyball',
      'بولنج': 'Bowling',
      'بادل': 'Padel',
      'تنس طاولة': 'Table Tennis',
      'تنس ارضي': 'Tennis',
      'كونكان': 'Conkan',
    };
    return map[n] ?? n;
  }

  String categoryLabel(String name) {
    final n = name.trim();
    if (!isEnglish) return n;
    const map = {
      'جنجفة': 'Card Games',
      'ألعاب شعبية': 'Popular Games',
      'رياضة': 'Sports',
    };
    return map[n] ?? n;
  }

  /// Convenience alias if you ever used "pearls" in older code.
  int get pearls => creditPoints ?? 0;
  int get storeCredit => creditBalance ?? 0;

  /// ------------------------------
  /// Persistence (SharedPreferences)
  /// ------------------------------
  static const _kAuthKey = 'inzeli_auth_v1';

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kAuthKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;

      token = (m['token'] as String?)?.trim();
      userId = (m['userId'] as String?)?.trim();

      displayName = m['displayName'] as String?;
      email = m['email'] as String?;

      creditPoints = (m['creditPoints'] as num?)?.toInt();
      creditBalance = (m['creditBalance'] as num?)?.toInt();
      permanentScore = (m['permanentScore'] as num?)?.toInt();

      name = m['name'] as String?;
      phone = m['phone'] as String?;

      selectedCategory = m['selectedCategory'] as String?;
      selectedGame = m['selectedGame'] as String?;
      roomCode = m['roomCode'] as String?;

      bio50 = m['bio50'] as String?;
      activeSponsorCode = m['activeSponsorCode'] as String?;
      themeId = m['themeId'] as String?;
      frameId = m['frameId'] as String?;
      cardId = m['cardId'] as String?;
      language = m['language'] as String?;
      soundMuted = m['soundMuted'] as bool?;
      profilePrivate = m['profilePrivate'] as bool?;
      final rawGamePearls = m['gamePearls'];
      if (rawGamePearls is Map) {
        gamePearls = rawGamePearls.map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0));
      }
      pearlsResetMonth = m['pearlsResetMonth'] as String?;
      final rawDew = m['ownedDewanyahs'];
      if (rawDew is List) {
        ownedDewanyahs =
            rawDew.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      final rawBoards = m['managedBoards'];
      if (rawBoards is List) {
        managedBoards =
            rawBoards.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {
      // ignore bad local cache
    }

    await _resetPearlsIfNeeded();
  }

  Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    final data = <String, dynamic>{
      'token': token,
      'userId': userId,
      'displayName': displayName,
      'email': email,
      'creditPoints': creditPoints,
      'creditBalance': creditBalance,
      'permanentScore': permanentScore,
      'name': name,
      'phone': phone,
      'selectedCategory': selectedCategory,
      'selectedGame': selectedGame,
      'roomCode': roomCode,
      'bio50': bio50,
      'activeSponsorCode': activeSponsorCode,
      'themeId': themeId,
      'frameId': frameId,
      'cardId': cardId,
      'language': language,
      'soundMuted': soundMuted,
      'profilePrivate': profilePrivate,
      'gamePearls': gamePearls,
      'pearlsResetMonth': pearlsResetMonth,
      'ownedDewanyahs': ownedDewanyahs,
      'managedBoards': managedBoards,
    };
    await sp.setString(_kAuthKey, jsonEncode(data));
  }

  // جعل الحفظ متاحاً للصفحات الأخرى بشكل آمن
  Future<void> saveState() => _save();

  /// Called after login/register:
  /// expects response shape:
  /// { token: "...", user: { id, displayName, email, creditPoints, permanentScore } }
  Future<void> setAuthFromBackend({
    required String token,
    required Map<String, dynamic> user,
  }) async {
    this.token = token;

    // support both `id` and `userId` keys
    userId = (user['id'] ?? user['userId'] ?? '').toString();

    displayName = (user['displayName'] ?? user['name'])?.toString();
    email = (user['email'])?.toString();

    creditPoints = (user['creditPoints'] as num?)?.toInt();
    permanentScore = (user['permanentScore'] as num?)?.toInt();

    // optional fallbacks
    name = displayName ?? name;
    phone = user['phone']?.toString() ?? phone;

    await _save();
    notifyListeners();
  }

  Future<void> clearAuth() async {
    token = null;
    userId = null;
    displayName = null;
    email = null;
    creditPoints = null;
    permanentScore = null;

    roomCode = null;
    selectedCategory = null;
    selectedGame = null;
    ownedDewanyahs = <Map<String, dynamic>>[];
    managedBoards = <Map<String, dynamic>>[];

    await _save();
    notifyListeners();
  }

  /// ------------------------------
  /// Small setters used by ProfilePage
  /// ------------------------------
  void setBio(String v) {
    bio50 = v.trim();
    _save();
    notifyListeners();
  }

  void setSponsorCode(String? code) {
    activeSponsorCode = (code == null || code.trim().isEmpty) ? null : code.trim();
    _save();
    notifyListeners();
  }

  void setLanguage(String langCode) {
    language = langCode;
    _save();
    notifyListeners();
  }

  void setSoundMuted(bool muted) {
    soundMuted = muted;
    _save();
    notifyListeners();
  }

  void setProfilePrivate(bool v) {
    profilePrivate = v;
    _save();
    notifyListeners();
  }

  void setSelectedGame(String? game, {String? category}) {
    if (category != null) selectedCategory = category;
    selectedGame = game;
    _save();
    notifyListeners();
  }

  void setRoomCode(String? code) {
    roomCode = (code == null || code.trim().isEmpty) ? null : code.trim();
    _save();
    notifyListeners();
  }

  /// ------------------------------
  /// Monthly pearls per game (reset to 5 each month)
  /// ------------------------------
  Future<void> _resetPearlsIfNeeded() async {
    final now = DateTime.now();
    final ym = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    if (pearlsResetMonth != ym || gamePearls.isEmpty) {
      _seedMonthlyPearls();
      pearlsResetMonth = ym;
      await _save();
      return;
    }
    if (_seedMissingGamePearls()) {
      await _save();
    }
  }

  void _ensurePearlsCurrent() {
    final now = DateTime.now();
    final ym = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    if (pearlsResetMonth != ym || gamePearls.isEmpty) {
      _seedMonthlyPearls();
      pearlsResetMonth = ym;
      // ignore: discarded_futures
      _save();
    } else if (_seedMissingGamePearls()) {
      // ignore: discarded_futures
      _save();
    }
  }

  void _seedMonthlyPearls() {
    gamePearls = {
      for (final g in _allKnownGames()) g: 5,
    };
  }

  bool _seedMissingGamePearls() {
    bool changed = false;
    for (final g in _allKnownGames()) {
      if (!gamePearls.containsKey(g)) {
        gamePearls[g] = 5;
        changed = true;
      }
    }
    return changed;
  }

  Iterable<String> _allKnownGames() {
    final set = <String>{};
    for (final entry in games.entries) {
      set.addAll(entry.value);
    }
    if (selectedGame != null && selectedGame!.isNotEmpty) {
      set.add(selectedGame!);
    }
    return set.where((g) => g.trim().isNotEmpty);
  }

  int pearlsForGame(String gameId) {
    _ensurePearlsCurrent();
    return gamePearls[gameId] ?? 5;
  }

  bool spendPearlForGame(String gameId) {
    _ensurePearlsCurrent();
    final current = gamePearls[gameId] ?? 0;
    if (current <= 0) return false;
    gamePearls[gameId] = current - 1;
    // ignore: discarded_futures
    _save();
    notifyListeners();
    return true;
  }

  void grantPearlsForGame(String gameId, int amount) {
    _ensurePearlsCurrent();
    final cur = gamePearls[gameId] ?? 0;
    gamePearls[gameId] = (cur + amount).clamp(0, 9999);
    // ignore: discarded_futures
    _save();
    notifyListeners();
  }

  /// Called when a user applies to open a new dewanyah leaderboard.
  Future<void> addDewanyahRequest({
    required String name,
    required String contact,
    String? gameId,
    String? note,
  }) async {
    ownedDewanyahs.add({
      'name': name,
      'contact': contact,
      'gameId': gameId,
      'note': note,
      'status': 'pending',
      'createdAt': DateTime.now().toIso8601String(),
      'ownerId': userId,
      'ownerName': displayName ?? name,
      'startingPearls': 5,
    });
    await _save();
    notifyListeners();
  }

  Future<void> addManagedBoard({
    required String title,
    required String type, // sponsor or dewanyah
    String? sponsorCode,
    String? dewanyahName,
    String? primaryColor,
    String? accentColor,
    String? imageUrl,
  }) async {
    managedBoards.add({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'title': title,
      'type': type,
      'sponsorCode': sponsorCode,
      'dewanyahName': dewanyahName,
      'primaryColor': primaryColor,
      'accentColor': accentColor,
      'imageUrl': imageUrl,
      'ownerId': userId,
      'ownerName': displayName ?? name,
    });
    await _save();
    notifyListeners();
  }

  Future<void> updateManagedBoardTheme({
    required String id,
    String? primaryColor,
    String? accentColor,
    String? imageUrl,
  }) async {
    for (final b in managedBoards) {
      if (b['id'] == id) {
        if (primaryColor != null) b['primaryColor'] = primaryColor;
        if (accentColor != null) b['accentColor'] = accentColor;
        if (imageUrl != null) b['imageUrl'] = imageUrl;
        break;
      }
    }
    await _save();
    notifyListeners();
  }

  /// ------------------------------
  /// LeaderboardPage + PlayerProfilePage helpers (local)
  /// ------------------------------
  PlayerProfile? profile(String playerName) => _profiles[playerName];

  int pointsOf(String playerName, String game) => _stats[_key(playerName, game)]?.points ?? 0;
  int winsOf(String playerName, String game) => _stats[_key(playerName, game)]?.wins ?? 0;
  int lossesOf(String playerName, String game) => _stats[_key(playerName, game)]?.losses ?? 0;

  List<TimelineEntry> userMatches(String playerName) =>
      timeline.where((t) => t.winner == playerName || t.losers.contains(playerName)).toList();

  /// This is used by your old LeaderboardPage:
  /// `FutureBuilder(future: app.getLeaderboard(selectedGame))`
  Future<List<LBRow>> getLeaderboard(String? game) async {
    final g = (game ?? '').trim();
    if (g.isEmpty) return const <LBRow>[];

    final rows = <LBRow>[];
    final seen = <String>{};

    // collect anyone who appeared in timeline for this game
    for (final t in timeline.where((e) => e.game == g)) {
      seen.add(t.winner);
      for (final l in t.losers) {
        seen.add(l);
      }
    }

    for (final name in seen) {
      final s = _stats[_key(name, g)] ?? _LocalStats();
      rows.add(LBRow(name: name, pts: s.points, w: s.wins, l: s.losses));
    }

    // sort: points desc, wins desc
    rows.sort((a, b) {
      final p = b.pts.compareTo(a.pts);
      if (p != 0) return p;
      return b.w.compareTo(a.w);
    });

    return rows;
  }

  /// Call this if you want to record a match locally (optional).
  void addLocalMatch({
    required String game,
    required String roomCode,
    required String winner,
    required List<String> losers,
    DateTime? ts,
  }) {
    final when = ts ?? DateTime.now();
    timeline.add(TimelineEntry(
      game: game,
      roomCode: roomCode,
      winner: winner,
      losers: losers,
      ts: when,
    ));

    // update stats: winner +1 point, losers -1 (simple)
    final wKey = _key(winner, game);
    _stats[wKey] = (_stats[wKey] ?? _LocalStats())
      ..wins += 1
      ..points += 1;

    for (final lo in losers) {
      final lKey = _key(lo, game);
      _stats[lKey] = (_stats[lKey] ?? _LocalStats())
        ..losses += 1
        ..points -= 1;
    }

    notifyListeners();
  }

  /// Used by ProfilePage for ring label
  GameLevel levelForGame(String playerName, String game) {
    final w = winsOf(playerName, game);
    // simple tier names to match your vibe
    if (w >= 30) return const GameLevel(name: 'فلتة', fill01: 1.0);
    if (w >= 20) return const GameLevel(name: 'فنان', fill01: 0.82);
    if (w >= 15) return const GameLevel(name: 'زين', fill01: 0.65);
    if (w >= 10) return const GameLevel(name: 'يمشي حاله', fill01: 0.45);
    if (w >= 5) return const GameLevel(name: 'عليمي', fill01: 0.28);
    return const GameLevel(name: 'بدايات', fill01: 0.12);
  }

  String _key(String playerName, String game) => '$playerName|$game';
}

/// ------------------------------
/// Data models used by your pages
/// ------------------------------

class LBRow {
  final String name;
  final int pts;
  final int w;
  final int l;
  const LBRow({
    required this.name,
    required this.pts,
    required this.w,
    required this.l,
  });
}

class TimelineEntry {
  final String game;
  final String roomCode;
  final String winner;
  final List<String> losers;
  final DateTime ts;

  const TimelineEntry({
    required this.game,
    required this.roomCode,
    required this.winner,
    required this.losers,
    required this.ts,
  });
}

class PlayerProfile {
  final String? phone;
  const PlayerProfile({this.phone});
}

class GameLevel {
  final String name;
  final double fill01;
  const GameLevel({required this.name, required this.fill01});
}

class _LocalStats {
  int points = 0;
  int wins = 0;
  int losses = 0;
}

/// Optional helper for quick debugging prints without breaking lints.
void debugLog(Object? o) {
  // ignore: avoid_print
  if (kDebugMode) print(o);
}

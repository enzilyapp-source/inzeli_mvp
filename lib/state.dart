// lib/state.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_dewanyah.dart';
import 'api_timeline.dart';
import 'api_user.dart';
import 'api_users.dart';

enum GameMode { solo, team, both }

/// ------------------------------
/// AppState (single source of truth)
/// ------------------------------
class AppState extends ChangeNotifier {
  // ---- Auth / user (from backend) ----
  String? token;
  String? userId;
  String? publicId;

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
  int? age;
  String? avatarPath;
  String? avatarBase64;
  Map<String, Map<String, dynamic>> userStats = {};
  Map<String, Map<String, dynamic>> userProfiles = {};

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
  Set<String> freeThemesOwned = {};
  // إعدادات محلية
  String? language; // e.g. 'ar' / 'en'
  bool? soundMuted;
  bool? profilePrivate;
  bool? rulesPromptSeen;
  bool? tutorialSeen;
  // لآلئ شهرية لكل لعبة (تُعاد شهرياً إلى 5 لكل لعبة)
  Map<String, int> gamePearls = <String, int>{};
  String? pearlsResetMonth; // YYYY-MM
  List<Map<String, dynamic>> ownedDewanyahs = <Map<String, dynamic>>[];
  Set<String> joinedDewanyahIds = <String>{};
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
    'جنجفة': ['كوت', 'بلوت', 'تريكس', 'هند', 'سبيتة', 'اونو'],
    'ألعاب شعبية': ['شطرنج', 'دامه', 'كيرم', 'دومنه', 'طاوله', 'بلياردو'],
    'رياضة': ['بيبيفوت', 'قدم', 'سله', 'طائره', 'بولنج', 'بادل', 'تنس طاولة', 'تنس ارضي'],
  };

  /// تحديد وضع اللعب لكل لعبة (solo / team / both)
  static const Map<String, GameMode> _gameModes = {
    'كوت': GameMode.team,
    'بلوت': GameMode.team,
    'تريكس': GameMode.solo,
    'هند': GameMode.both,
    'سبيتة': GameMode.both,
    'اونو': GameMode.solo,
    'شطرنج': GameMode.solo,
    'دامه': GameMode.solo,
    'كيرم': GameMode.team,
    'دومنه': GameMode.solo,
    'طاوله': GameMode.solo,
    'بلياردو': GameMode.solo,
    'بيبيفوت': GameMode.both,
    'قدم': GameMode.team,
    'سله': GameMode.team,
    'طائره': GameMode.team,
    'بولنج': GameMode.both,
    'بادل': GameMode.team,
    'تنس طاولة': GameMode.both,
    'تنس ارضي': GameMode.both,
    'كونكان': GameMode.team,
  };

  GameMode gameMode(String game) {
    final key = game.trim();
    return _gameModes[key] ?? GameMode.both;
  }

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
      'اونو': 'Uno',
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
      publicId = (m['publicId'] as String?)?.trim();

      displayName = m['displayName'] as String?;
      email = m['email'] as String?;

      creditPoints = (m['creditPoints'] as num?)?.toInt();
      creditBalance = (m['creditBalance'] as num?)?.toInt();
      permanentScore = (m['permanentScore'] as num?)?.toInt();

      name = m['name'] as String?;
      phone = m['phone'] as String?;
      final rawAge = m['age'];
      if (rawAge is num) age = rawAge.toInt();
      avatarPath = m['avatarPath'] as String?;
      avatarBase64 = m['avatarBase64'] as String?;

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
      tutorialSeen = m['tutorialSeen'] as bool?;
      final rawFreeThemes = m['freeThemesOwned'];
      if (rawFreeThemes is List) {
        freeThemesOwned = rawFreeThemes.map((e) => e.toString()).toSet();
      }
      final rawGamePearls = m['gamePearls'];
    if (rawGamePearls is Map) {
      gamePearls = rawGamePearls.map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0));
    }
    rulesPromptSeen = m['rulesPromptSeen'] as bool?;
      pearlsResetMonth = m['pearlsResetMonth'] as String?;
      final rawDew = m['ownedDewanyahs'];
      if (rawDew is List) {
        ownedDewanyahs =
            rawDew.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      final rawJoined = m['joinedDewanyahIds'];
      if (rawJoined is List) {
        joinedDewanyahIds = rawJoined.map((e) => e.toString()).toSet();
      }
      final rawBoards = m['managedBoards'];
      if (rawBoards is List) {
        managedBoards =
            rawBoards.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      final rawStats = m['userStats'];
      if (rawStats is Map) {
        userStats = rawStats.map((k, v) => MapEntry(k.toString(), Map<String, dynamic>.from(v as Map)));
      }
      final rawProfiles = m['userProfiles'];
      if (rawProfiles is Map) {
        userProfiles = rawProfiles.map((k, v) => MapEntry(k.toString(), Map<String, dynamic>.from(v as Map)));
      }
      final rawTimeline = m['timeline'];
      if (rawTimeline is List) {
        timeline
          ..clear()
          ..addAll(rawTimeline.whereType<Map>().map((e) {
            return TimelineEntry(
              kind: (e['kind'] ?? 'match').toString(),
              game: (e['game'] ?? '').toString(),
              roomCode: (e['roomCode'] ?? '').toString(),
              winner: (e['winner'] ?? '').toString(),
              winners: (e['winners'] as List?)?.map((x) => x.toString()).toList() ?? const [],
              losers: (e['losers'] as List?)?.map((x) => x.toString()).toList() ?? const [],
              ts: DateTime.tryParse((e['ts'] ?? '').toString()) ?? DateTime.now(),
              meta: e['meta'] is Map ? Map<String, dynamic>.from(e['meta'] as Map) : null,
            );
          }));
      }
      final rawLocalStats = m['localStats'];
      if (rawLocalStats is Map) {
        _stats
          ..clear()
          ..addEntries(rawLocalStats.entries.map((e) {
            final v = e.value;
            final stats = _LocalStats();
            if (v is Map) {
              stats.points = (v['points'] as num?)?.toInt() ?? 0;
              stats.wins = (v['wins'] as num?)?.toInt() ?? 0;
              stats.losses = (v['losses'] as num?)?.toInt() ?? 0;
            }
            return MapEntry(e.key.toString(), stats);
          }));
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
      'age': age,
      'avatarPath': avatarPath,
      'avatarBase64': avatarBase64,
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
      'tutorialSeen': tutorialSeen ?? false,
      'freeThemesOwned': freeThemesOwned.toList(),
      'gamePearls': gamePearls,
      'rulesPromptSeen': rulesPromptSeen ?? false,
      'pearlsResetMonth': pearlsResetMonth,
      'ownedDewanyahs': ownedDewanyahs,
      'joinedDewanyahIds': joinedDewanyahIds.toList(),
      'managedBoards': managedBoards,
      'userStats': userStats,
      'userProfiles': userProfiles,
      'timeline': timeline
          .map((t) => {
                'kind': t.kind,
                'game': t.game,
                'roomCode': t.roomCode,
                'winner': t.winner,
                'winners': t.winners,
                'losers': t.losers,
                'ts': t.ts.toIso8601String(),
                if (t.meta != null) 'meta': t.meta,
              })
          .toList(),
      'localStats': _stats.map((k, v) => MapEntry(k, {
            'points': v.points,
            'wins': v.wins,
            'losses': v.losses,
          })),
    };
    await sp.setString(_kAuthKey, jsonEncode(data));
  }

  // جعل الحفظ متاحاً للصفحات الأخرى بشكل آمن
  Future<void> saveState() => _save();

  void upsertUserStats(String key, Map<String, dynamic> stats) {
    userStats[key] = stats;
    _save();
    notifyListeners();
  }

  void upsertUserProfile(String key, Map<String, dynamic> profile) {
    userProfiles[key] = profile;
    _save();
    notifyListeners();
  }

  /// Called after login/register:
  /// expects response shape:
  /// { token: "...", user: { id, displayName, email, creditPoints, permanentScore } }
  Future<void> setAuthFromBackend({
    required String token,
    required Map<String, dynamic> user,
  }) async {
    final previousUserId = userId;
    this.token = token;

    // support both `id` and `userId` keys
    userId = (user['id'] ?? user['userId'] ?? '').toString();
    publicId = (user['publicId'] ?? '').toString();

    displayName = (user['displayName'] ?? user['name'])?.toString();
    email = (user['email'])?.toString();

    creditPoints = (user['creditPoints'] as num?)?.toInt();
    permanentScore = (user['permanentScore'] as num?)?.toInt();

    // optional fallbacks
    name = displayName ?? name;
    phone = user['phone']?.toString() ?? phone;
    age = (user['age'] as num?)?.toInt() ?? age;

    // لو المستخدم تبدل، نرجّع لآلئ كل الألعاب إلى الرصيد الافتراضي لهذا الشهر
    if (previousUserId != null && previousUserId != userId) {
      gamePearls = {};
      pearlsResetMonth = null;
      await _resetPearlsIfNeeded();
    }

    // fetch timeline from server (best-effort)
    syncTimelineFromServer();

    await _save();
    notifyListeners();
  }

  Future<void> setAvatarPath(String path) async {
    avatarPath = path;
    await _save();
    notifyListeners();
  }

  Future<void> setAvatarBytes(Uint8List bytes, {String? fallbackPath}) async {
    avatarBase64 = base64Encode(bytes);
    if (fallbackPath != null) avatarPath = fallbackPath;
    await _save();
    notifyListeners();
  }

  Future<void> clearAuth() async {
    token = null;
    userId = null;
    publicId = null;
    displayName = null;
    email = null;
    creditPoints = null;
    creditBalance = null;
    permanentScore = null;

    roomCode = null;
    selectedCategory = null;
    selectedGame = null;
    // Keep dewanyah ownership/managed boards so they remain visible after logout
    // ownedDewanyahs = <Map<String, dynamic>>[];
    // managedBoards = <Map<String, dynamic>>[];
    gamePearls = <String, int>{};
    pearlsResetMonth = null;
    rulesPromptSeen = false;
    tutorialSeen = false;
    soundMuted = null;
    profilePrivate = null;
    timeline.clear();
    userStats.clear();
    userProfiles.clear();
    _stats.clear();
    joinedDewanyahIds.clear();

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

  void markRulesPromptSeen() {
    rulesPromptSeen = true;
    _save();
    notifyListeners();
  }

  void markTutorialSeen() {
    tutorialSeen = true;
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
    bool? requireApproval,
    bool? locationLock,
    int? radiusMeters,
  }) async {
    try {
      if (token != null && token!.isNotEmpty) {
        await ApiDewanyah.createRequest(
          name: name,
          contact: contact,
          gameId: gameId,
          note: note,
          requireApproval: requireApproval,
          locationLock: locationLock,
          radiusMeters: radiusMeters,
          token: token,
        );
      }
    } catch (_) {
      // fallback to local-only storing
    }

    ownedDewanyahs.insert(0, {
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

  void addJoinedDewanyah(String dewanyahId) {
    if (dewanyahId.isEmpty) return;
    joinedDewanyahIds.add(dewanyahId);
    _save();
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
  int totalGamesPlayed(String playerName) {
    var total = 0;
    _stats.forEach((k, v) {
      if (k.startsWith('$playerName|')) {
        total += v.wins + v.losses;
      }
    });
    return total;
  }

  /// streak الحالية (عدد الانتصارات المتتالية الأخيرة) للاعب في لعبة معيّنة
  int streakOf(String playerName, String game) {
    final matches = timeline
        .where((t) => t.game == game && (t.winner == playerName || t.losers.contains(playerName)))
        .toList()
      ..sort((a, b) => a.ts.compareTo(b.ts)); // قديم -> جديد
    int streak = 0;
    for (var i = matches.length - 1; i >= 0; i--) {
      final t = matches[i];
      if (t.winner == playerName) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

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
  Future<void> addLocalMatch({
    required String game,
    required String roomCode,
    required String winner,
    required List<String> losers,
    DateTime? ts,
  }) async {
    final when = ts ?? DateTime.now();
    final beforeLevel = levelForGame(winner, game);

    timeline.add(TimelineEntry(
      kind: 'match',
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

    final afterLevel = levelForGame(winner, game);
    if (afterLevel.name != beforeLevel.name) {
      timeline.add(TimelineEntry(
        kind: 'level_up',
        game: game,
        roomCode: roomCode,
        winner: winner,
        losers: losers,
        ts: when,
        meta: {'from': beforeLevel.name, 'to': afterLevel.name},
      ));
    }

    await _save();
    notifyListeners();
  }

  /// Fetch timeline from server and store locally (requires auth token).
  /// By default we fetch all games so "شسالفه" always shows full results feed.
  Future<void> syncTimelineFromServer({String? gameId, bool global = true}) async {
    if (token == null || token!.isEmpty) return;
    try {
      List<String> asStrings(dynamic v) {
        if (v is List) {
          return v
              .map((x) => x.toString().trim())
              .where((s) => s.isNotEmpty)
              .toList();
        }
        if (v == null) return const [];
        final s = v.toString().trim();
        if (s.isEmpty) return const [];
        return [s];
      }

      List<String> uniqueStrings(Iterable<String> values) {
        final out = <String>[];
        final seen = <String>{};
        for (final raw in values) {
          final s = raw.trim();
          if (s.isEmpty) continue;
          if (seen.add(s)) out.add(s);
        }
        return out;
      }

      bool looksLikeUserId(String v) {
        final s = v.trim();
        if (s.isEmpty) return false;
        final uuid = RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
        );
        final cuid = RegExp(r'^c[a-z0-9]{8,}$');
        return uuid.hasMatch(s) || cuid.hasMatch(s);
      }

      Map<String, dynamic> metaOf(Map<String, dynamic> e) {
        final m = e['meta'];
        if (m is Map) return Map<String, dynamic>.from(m);
        return const <String, dynamic>{};
      }

      final userNameById = <String, String>{};
      void cacheProfile(Map<String, dynamic> u) {
        final id = (u['id'] ?? '').toString().trim();
        final pub = (u['publicId'] ?? '').toString().trim();
        final dn = (u['displayName'] ?? '').toString().trim();

        if (id.isNotEmpty) userProfiles[id] = Map<String, dynamic>.from(u);
        if (pub.isNotEmpty) userProfiles[pub] = Map<String, dynamic>.from(u);

        if (dn.isNotEmpty) {
          if (id.isNotEmpty) userNameById[id] = dn;
          if (pub.isNotEmpty) userNameById[pub] = dn;
        }
      }

      String resolveUserLabel(String raw) {
        final s = raw.trim();
        if (s.isEmpty) return '';
        final mapped = userNameById[s];
        if (mapped != null && mapped.isNotEmpty) return mapped;
        return s;
      }

      for (final p in userProfiles.values) {
        cacheProfile(Map<String, dynamic>.from(p));
      }

      final list = await ApiTimeline.list(
        token: token,
        limit: 200,
        gameId: gameId,
        global: global,
      );

      // جمع كل المعرفات (فائزين + خاسرين) لنجلب الأسماء مرة واحدة
      final ids = <String>{};
      void addMaybeIds(Iterable<String> values) {
        for (final v in values) {
          if (looksLikeUserId(v)) ids.add(v);
        }
      }
      for (final e in list) {
        final meta = metaOf(e);
        addMaybeIds(asStrings(e['winners']));
        addMaybeIds(asStrings(e['losers']));
        addMaybeIds(asStrings(meta['winners']));
        addMaybeIds(asStrings(meta['losers']));
        addMaybeIds(asStrings(e['userId']));
      }
      // إذا API يسمح بجلب متعدد /users?ids=...
      if (ids.isNotEmpty) {
        try {
          final fetched = await ApiUsers.getMany(ids: ids.toList(), token: token);
          for (final u in fetched) {
            cacheProfile(Map<String, dynamic>.from(u));
          }
        } catch (_) {
          // تجاهل لو فشل
        }

        // Fallback if batch endpoint is unavailable: resolve unresolved ids one-by-one.
        final unresolved = ids
            .where((id) => !userNameById.containsKey(id))
            .take(12)
            .toList();
        if (unresolved.isNotEmpty) {
          await Future.wait(
            unresolved.map((id) async {
              try {
                final results = await searchUsers(id, token: token);
                if (results.isEmpty) return;
                Map<String, dynamic>? exact;
                for (final r in results) {
                  final rid = (r['id'] ?? '').toString();
                  final rpub = (r['publicId'] ?? '').toString();
                  if (rid == id || rpub == id) {
                    exact = r;
                    break;
                  }
                }
                final picked = exact ?? results.first;
                cacheProfile(Map<String, dynamic>.from(picked));
              } catch (_) {
                // ignore per-id lookup errors
              }
            }),
          );
        }
      }

      timeline
        ..clear()
        ..addAll(list.map((e) {
          final meta = metaOf(e);
          final kind = (e['kind'] ?? 'match').toString();

          final winnersIds = uniqueStrings([
            ...asStrings(e['winners']),
            ...asStrings(meta['winners']),
            ...asStrings(meta['winnerIds']),
            ...asStrings(meta['winnerUserIds']),
            ...asStrings(meta['winnerId']),
            ...asStrings(meta['winnerUserId']),
          ]);

          final winnersNames = uniqueStrings([
            ...asStrings(e['winnersNames']),
            ...asStrings(e['winnerNames']),
            ...asStrings(meta['winnersNames']),
            ...asStrings(meta['winnerNames']),
            ...asStrings(meta['winnersDisplay']),
            ...asStrings(meta['winnerDisplay']),
            ...asStrings(e['winnerName']),
            ...asStrings(e['winner']),
            ...asStrings(meta['winnerName']),
            ...asStrings(meta['winner']),
          ]);

          final losersIds = uniqueStrings([
            ...asStrings(e['losers']),
            ...asStrings(meta['losers']),
            ...asStrings(meta['losersIds']),
            ...asStrings(meta['loserIds']),
            ...asStrings(meta['loserUserIds']),
            ...asStrings(meta['loserUserId']),
          ]);

          final losersNames = uniqueStrings([
            ...asStrings(e['losersNames']),
            ...asStrings(e['loserNames']),
            ...asStrings(meta['losersNames']),
            ...asStrings(meta['loserNames']),
            ...asStrings(meta['losersDisplay']),
            ...asStrings(meta['loserDisplay']),
          ]);

          final winnerCandidates = uniqueStrings([
            ...winnersNames,
            ...winnersIds,
            ...asStrings(e['winnerName']),
            ...asStrings(e['winner']),
          ]);
          var winnerResolved =
              winnerCandidates.isNotEmpty ? winnerCandidates.first : '';

          // Legacy fallback: old APIs may only provide userId on MATCH_WIN.
          if (winnerResolved.isEmpty &&
              kind.toUpperCase() == 'MATCH_WIN' &&
              asStrings(e['userId']).isNotEmpty) {
            winnerResolved = asStrings(e['userId']).first;
          }
          winnerResolved = resolveUserLabel(winnerResolved);

          final winnersForUi = (winnersNames.isNotEmpty
                  ? winnersNames
                  : winnersIds)
              .map(resolveUserLabel)
              .toList();
          final losersForUi = (losersNames.isNotEmpty ? losersNames : losersIds)
              .map(resolveUserLabel)
              .toList();

          return TimelineEntry(
            kind: kind,
            game: (e['gameId'] ?? e['game'] ?? meta['gameId'] ?? '').toString(),
            roomCode: (e['roomCode'] ?? '').toString(),
            winner: winnerResolved,
            winners: winnersForUi,
            losers: losersForUi,
            ts: DateTime.tryParse((e['ts'] ?? '').toString()) ?? DateTime.now(),
            meta: meta.isNotEmpty ? meta : null,
          );
        }));
      await _save();
      notifyListeners();
    } catch (_) {
      // ignore failures
    }
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
  final String kind; // match | level_up | other
  final String game;
  final String roomCode;
  final String winner;
  final List<String> winners;
  final List<String> losers;
  final DateTime ts;
  final Map<String, dynamic>? meta;

  const TimelineEntry({
    this.kind = 'match',
    required this.game,
    required this.roomCode,
    required this.winner,
    this.winners = const [],
    required this.losers,
    required this.ts,
    this.meta,
  });
}

class PlayerProfile {
  final String? phone;
  final String? displayName;
  final String? avatarUrl;
  final String? avatarBase64;
  final String? themeId;
  const PlayerProfile({this.phone, this.displayName, this.avatarUrl, this.avatarBase64, this.themeId});
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

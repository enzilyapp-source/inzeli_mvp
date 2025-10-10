import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Row model for a leaderboard entry
class LBRow {
  final String name;
  final int pts;
  final int w;
  final int l;
  LBRow(this.name, this.pts, this.w, this.l);

  Map<String, dynamic> toJson() => {
    'name': name,
    'pts': pts,
    'w': w,
    'l': l,
  };

  static LBRow fromJson(Map<String, dynamic> m) =>
      LBRow(m['name'] as String, m['pts'] as int, m['w'] as int, m['l'] as int);
}

/// A timeline entry (local log)
class TimelineItem {
  final DateTime ts;
  final String game;
  final String roomCode;
  final String winner;
  final List<String> losers;

  TimelineItem({
    required this.ts,
    required this.game,
    required this.roomCode,
    required this.winner,
    required this.losers,
  });

  Map<String, dynamic> toJson() => {
    'ts': ts.toIso8601String(),
    'game': game,
    'roomCode': roomCode,
    'winner': winner,
    'losers': losers,
  };

  static TimelineItem fromJson(Map<String, dynamic> m) => TimelineItem(
    ts: DateTime.parse(m['ts'] as String),
    game: m['game'] as String,
    roomCode: m['roomCode'] as String,
    winner: m['winner'] as String,
    losers: (m['losers'] as List).cast<String>(),
  );
}

/// Simple local profile model
class UserProfile {
  String name;
  String? phone;
  String? bio50;
  String? activeSponsorCode;

  final Map<String, int> pointsByGame;
  final Map<String, int> winsByGame;
  final Map<String, int> lossesByGame;
  final Map<String, Map<String, Map<String, int>>> archives;

  UserProfile({
    required this.name,
    this.phone,
    this.bio50,
    this.activeSponsorCode,
    Map<String, int>? pointsByGame,
    Map<String, int>? winsByGame,
    Map<String, int>? lossesByGame,
    Map<String, Map<String, Map<String, int>>>? archives,
  })  : pointsByGame = pointsByGame ?? {},
        winsByGame = winsByGame ?? {},
        lossesByGame = lossesByGame ?? {},
        archives = archives ?? {};

  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    'bio50': bio50,
    'activeSponsorCode': activeSponsorCode,
    'pointsByGame': pointsByGame,
    'winsByGame': winsByGame,
    'lossesByGame': lossesByGame,
    'archives': archives,
  };

  static UserProfile fromJson(Map<String, dynamic> m) => UserProfile(
    name: m['name'] as String,
    phone: m['phone'] as String?,
    bio50: m['bio50'] as String?,
    activeSponsorCode: m['activeSponsorCode'] as String?,
    pointsByGame: _mapStringInt(m['pointsByGame']),
    winsByGame: _mapStringInt(m['winsByGame']),
    lossesByGame: _mapStringInt(m['lossesByGame']),
    archives: _mapArchive(m['archives']),
  );

  static Map<String, int> _mapStringInt(Object? o) {
    if (o is Map) {
      return o.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
    }
    return {};
  }

  static Map<String, Map<String, Map<String, int>>> _mapArchive(Object? o) {
    final out = <String, Map<String, Map<String, int>>>{};
    if (o is Map) {
      for (final mk in o.keys) {
        final inner = o[mk];
        if (inner is Map) {
          final perGame = <String, Map<String, int>>{};
          for (final g in inner.keys) {
            final stats = inner[g];
            if (stats is Map) {
              perGame[g.toString()] =
                  stats.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
            }
          }
          out[mk.toString()] = perGame;
        }
      }
    }
    return out;
  }
}

/// For profile ring (level info)
class LevelInfo {
  final String name;
  final double fill01;
  LevelInfo({required this.name, required this.fill01});
}

/// Internal tier helper for wins milestones
class _Tier {
  final String name;
  final int needWins;
  const _Tier({required this.name, required this.needWins});
}

/// Global app state
class AppState extends ChangeNotifier {
  AppState();

  // --- User basics ---
  String? name;
  String? phone;
  String? bio50;
  String? activeSponsorCode;

  // --- Auth (backend) ---
  String? token;
  String? userId;
  String? displayName;
  String? email;
  int? creditPoints;
  int? permanentScore;

  bool get isSignedIn => token != null && userId != null;

  // --- UI selections ---
  String? selectedCategory;
  String? selectedGame;
  String? roomCode;

  // categories/games
  final List<String> categories = const ['جنجفة', 'ألعاب شعبية', 'رياضة'];
  final Map<String, List<String>> games = const {
    'جنجفة': ['كوت', 'بلوت', 'تريكس', 'سبيتة', 'هند'],
    'ألعاب شعبية': ['شطرنج', 'دامه', 'كيرم', 'دومنه', 'طاوله'],
    'رياضة': [
      'قدم',
      'سله',
      'طائره',
      'بادل',
      'بولنج',
      'بيبيفوت',
      'تنس طاولة',
      'تنس ارضي',
      'بلياردو',
    ],
  };

  final Map<String, UserProfile> _users = {};
  final List<TimelineItem> timeline = [];

  String _currentLBMonthKey = _monthKey(DateTime.now());
  static String _monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  // ===== Auth Helpers =====
  Future<void> setAuthFromBackend({
    required String token,
    required Map<String, dynamic> user,
  }) async {
    this.token = token;
    userId = user['id'] as String?;
    displayName = user['displayName'] as String?;
    email = user['email'] as String?;
    creditPoints = (user['creditPoints'] as num?)?.toInt();
    permanentScore = (user['permanentScore'] as num?)?.toInt();

    final sp = await SharedPreferences.getInstance();
    await sp.setString('auth.token', token);
    await sp.setString('auth.user', jsonEncode(user));
    notifyListeners();
  }

  Future<void> clearAuth() async {
    token = null;
    userId = null;
    displayName = null;
    email = null;
    creditPoints = null;
    permanentScore = null;
    final sp = await SharedPreferences.getInstance();
    await sp.remove('auth.token');
    await sp.remove('auth.user');
    notifyListeners();
  }

  // ===== User helpers =====
  UserProfile _ensureUser(String userName) {
    return _users.putIfAbsent(userName, () => UserProfile(name: userName));
  }

  UserProfile get me {
    final uName = (name ?? 'لاعب');
    final u = _ensureUser(uName);
    u.phone ??= phone;
    u.bio50 ??= bio50;
    u.activeSponsorCode ??= activeSponsorCode;
    return u;
  }

  // ===== UI actions =====
  void pickCategory(String cat) {
    if (!categories.contains(cat)) return;
    selectedCategory = cat;
    final list = games[cat];
    if (list != null && list.isNotEmpty) {
      selectedGame = list.first;
    }
    notifyListeners();
  }

  void pickGame(String game) {
    selectedGame = game;
    notifyListeners();
  }

  void setSponsorCode(String? code) {
    activeSponsorCode = (code?.trim().isEmpty ?? true) ? null : code!.trim();
    me.activeSponsorCode = activeSponsorCode;
    save();
    notifyListeners();
  }

  void setBio(String? bio) {
    final b = (bio ?? '').trim();
    bio50 = b.isEmpty ? null : (b.length <= 50 ? b : b.substring(0, 50));
    me.bio50 = bio50;
    save();
    notifyListeners();
  }

  void createRoom() {
    roomCode = _randomRoomCode();
    notifyListeners();
  }

  void clearRoom() {
    roomCode = null;
    notifyListeners();
  }

  static String _randomRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }

  // ===== Record match (local) =====
  void recordMatch({
    required String game,
    required List<String> winners,
    required List<String> losers,
    String? room,
    DateTime? when,
  }) {
    for (final wName in winners) {
      final wUser = _ensureUser(wName);
      wUser.pointsByGame[game] = (wUser.pointsByGame[game] ?? 0) + 1;
      wUser.winsByGame[game] = (wUser.winsByGame[game] ?? 0) + 1;
    }
    for (final lName in losers) {
      final u = _ensureUser(lName);
      u.pointsByGame[game] = (u.pointsByGame[game] ?? 0) - 1;
      u.lossesByGame[game] = (u.lossesByGame[game] ?? 0) + 1;
    }

    final mainWinner = winners.isNotEmpty ? winners.first : '';
    timeline.add(TimelineItem(
      ts: when ?? DateTime.now(),
      game: game,
      roomCode: room ?? (roomCode ?? ''),
      winner: mainWinner,
      losers: losers,
    ));

    _monthlyResetIfNeeded();
    save();
    notifyListeners();
  }

  // ===== Leaderboard =====
  Future<List<LBRow>> getLeaderboard(String? game) async {
    if (game == null || game.isEmpty) return [];
    final rows = <LBRow>[];
    for (final u in _users.values) {
      final pts = u.pointsByGame[game] ?? 0;
      final w = u.winsByGame[game] ?? 0;
      final l = u.lossesByGame[game] ?? 0;
      if (w != 0 || l != 0 || pts != 0) {
        rows.add(LBRow(u.name, pts, w, l));
      }
    }
    rows.sort((a, b) {
      final byPts = b.pts.compareTo(a.pts);
      if (byPts != 0) return byPts;
      final byW = b.w.compareTo(a.w);
      if (byW != 0) return byW;
      return a.name.compareTo(b.name);
    });
    return rows;
  }

  // ===== Level calculation (wins-based tiers) =====
  // المراتب حسب مجموع الفوز لكل لعبة:
  //  <5  : مبتدئ (progress حتى توصل 5)
  //  >=5 : عليمي
  //  >=15: يمشي حاله
  //  >=30: زين بعد
  //  >=50: فنان
  //  >=80: فلته
  static const List<_Tier> _tiers = <_Tier>[
    _Tier(name: 'عليمي', needWins: 5),
    _Tier(name: 'يمشي حاله', needWins: 15),
    _Tier(name: 'زين بعد', needWins: 30),
    _Tier(name: 'فنان', needWins: 50),
    _Tier(name: 'فلته', needWins: 80),
  ];

  /// يرجّع اسم المستوى + نسبة التعبئة داخل المستوى الحالي (0..1)
  /// يعتمد على عدد الفوز فقط (بدون خسائر).
  LevelInfo levelForGame(String userName, String game) {
    final u = _ensureUser(userName);
    final wins = u.winsByGame[game] ?? 0;

    if (wins < _tiers.first.needWins) {
      final need = _tiers.first.needWins; // 5
      final fill = (wins / need).clamp(0.0, 1.0);
      return LevelInfo(name: 'مبتدئ', fill01: fill);
    }

    for (int i = 0; i < _tiers.length; i++) {
      final cur = _tiers[i];
      final next = (i + 1 < _tiers.length) ? _tiers[i + 1] : null;

      if (next == null) {
        return LevelInfo(name: cur.name, fill01: 1.0); // أعلى مرتبة
      }

      if (wins < next.needWins) {
        final prevNeed = cur.needWins;
        final nextNeed = next.needWins;
        final fill =
        ((wins - prevNeed) / (nextNeed - prevNeed)).clamp(0.0, 1.0);
        return LevelInfo(name: cur.name, fill01: fill);
      }
    }

    return LevelInfo(name: _tiers.last.name, fill01: 1.0);
  }

  // ===== Monthly reset =====
  void _monthlyResetIfNeeded() {
    final nowKey = _monthKey(DateTime.now());
    if (nowKey == _currentLBMonthKey) return;
    final prevKey = _currentLBMonthKey;
    for (final u in _users.values) {
      final snapshot = <String, Map<String, int>>{};
      final allGames = <String>{
        ...u.pointsByGame.keys,
        ...u.winsByGame.keys,
        ...u.lossesByGame.keys,
      };
      for (final g in allGames) {
        snapshot[g] = {
          'pts': u.pointsByGame[g] ?? 0,
          'w': u.winsByGame[g] ?? 0,
          'l': u.lossesByGame[g] ?? 0,
        };
      }
      if (snapshot.isNotEmpty) {
        u.archives[prevKey] = snapshot;
      }
      u.pointsByGame.clear();
      u.winsByGame.clear();
      u.lossesByGame.clear();
    }
    _currentLBMonthKey = nowKey;
    save();
    notifyListeners();
  }

  UserProfile? profile(String playerName) => _users[playerName];
  int pointsOf(String playerName, String game) =>
      _users[playerName]?.pointsByGame[game] ?? 0;
  int winsOf(String playerName, String game) =>
      _users[playerName]?.winsByGame[game] ?? 0;
  int lossesOf(String playerName, String game) =>
      _users[playerName]?.lossesByGame[game] ?? 0;

  List<TimelineItem> userMatches(String playerName) {
    return timeline
        .where((t) => t.winner == playerName || t.losers.contains(playerName))
        .toList();
  }

  // ===== Persistence =====
  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    try {
      name = _nz(sp.getString('me.name'));
      phone = _nz(sp.getString('me.phone'));
      bio50 = _nz(sp.getString('me.bio50'));
      activeSponsorCode = _nz(sp.getString('me.sponsor'));
      _currentLBMonthKey =
          sp.getString('lb.month') ?? _monthKey(DateTime.now());

      final rawUsers = sp.getString('users.json');
      if (rawUsers != null && rawUsers.isNotEmpty) {
        final m = jsonDecode(rawUsers) as Map<String, dynamic>;
        _users
          ..clear()
          ..addAll(m.map((k, v) => MapEntry(k, UserProfile.fromJson(v))));
      }

      final rawTL = sp.getString('timeline.json');
      if (rawTL != null && rawTL.isNotEmpty) {
        final list = (jsonDecode(rawTL) as List).cast<Map<String, dynamic>>();
        timeline
          ..clear()
          ..addAll(list.map(TimelineItem.fromJson));
      }

      final savedToken = sp.getString('auth.token');
      final savedUser = sp.getString('auth.user');
      if (savedToken != null &&
          savedToken.isNotEmpty &&
          savedUser != null &&
          savedUser.isNotEmpty) {
        token = savedToken;
        final u = jsonDecode(savedUser) as Map<String, dynamic>;
        userId = u['id'] as String?;
        displayName = u['displayName'] as String?;
        email = u['email'] as String?;
        creditPoints = (u['creditPoints'] as num?)?.toInt();
        permanentScore = (u['permanentScore'] as num?)?.toInt();
      }
    } catch (_) {
      // ignore
    }
    notifyListeners();
  }

  Future<void> save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('me.name', name ?? '');
    await sp.setString('me.phone', phone ?? '');
    await sp.setString('me.bio50', bio50 ?? '');
    await sp.setString('me.sponsor', activeSponsorCode ?? '');
    await sp.setString('lb.month', _currentLBMonthKey);

    final usersJson =
    jsonEncode(_users.map((k, v) => MapEntry(k, v.toJson())));
    await sp.setString('users.json', usersJson);

    final tlJson = jsonEncode(timeline.map((t) => t.toJson()).toList());
    await sp.setString('timeline.json', tlJson);
  }

  static String? _nz(String? s) => (s == null || s.isEmpty) ? null : s;
}
//state.dart
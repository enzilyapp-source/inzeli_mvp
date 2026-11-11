import 'dart:convert';
import 'dart:ui' as ui;

/// Identifiers deliberately match the audited website engines, not translated labels.
enum ScoreKind {
  general('القيد العام', 'general.html'),
  hand('قيد الهند', 'index.html'),
  kout('قيد الكوت', 'kout.html'),
  baloot('قيد البلوت', 'baloot.html'),
  spita('قيد السبيتة', 'spita.html'),
  trix('قيد التركس', 'trix.html');

  const ScoreKind(this.label, this.asset);
  final String label;
  final String asset;
  static ScoreKind? forGame(String game) => switch (game.trim()) {
        'هند' => hand,
        'كوت' => kout,
        'بلوت' => baloot,
        'سبيتة' => spita,
        'تريكس' => trix,
        _ => null,
      };
  static bool supports(String game) => const [
        'هند',
        'كوت',
        'بلوت',
        'سبيتة',
        'تريكس',
        'اونو',
        'دفان'
      ].contains(game.trim());
}

class ScorePerson {
  const ScorePerson(
      {required this.id, required this.name, this.avatar, this.team});
  final String id, name;
  final String? avatar, team;
  factory ScorePerson.fromRoom(Map<String, dynamic> p) {
    final u = Map<String, dynamic>.from(p['user'] as Map? ?? {});
    final raw = (u['avatarBase64'] ?? '').toString();
    final path = (u['avatarPath'] ?? u['avatarUrl'] ?? '').toString();
    String? avatar;
    if (raw.isNotEmpty) {
      avatar =
          raw.startsWith('data:image/') ? raw : 'data:image/jpeg;base64,$raw';
    } else if (Uri.tryParse(path)?.scheme == 'https') {
      avatar = path;
    }
    return ScorePerson(
        id: (p['userId'] ?? '').toString(),
        name: (u['displayName'] ?? u['name'] ?? 'لاعب').toString(),
        avatar: avatar,
        team: ['A', 'B'].contains(p['team']) ? p['team'] as String : null);
  }
  // A room can contain several full-resolution profile photos. Decode them once
  // to small avatars before sending the HTML through the platform channel.
  Future<ScorePerson> thumbnail() async {
    if (avatar == null || !avatar!.startsWith('data:')) return this;
    String? small;
    try {
      final codec = await ui.instantiateImageCodec(
          base64Decode(avatar!.split(',').last),
          targetWidth: 96,
          allowUpscaling: false);
      try {
        final frame = await codec.getNextFrame();
        try {
          final png =
              await frame.image.toByteData(format: ui.ImageByteFormat.png);
          if (png != null) {
            small =
                'data:image/png;base64,${base64Encode(png.buffer.asUint8List())}';
          }
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    } catch (_) {/* Unsupported/corrupt avatars use a name initial. */}
    return ScorePerson(id: id, name: name, avatar: small, team: team);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name.substring(0, name.length.clamp(0, 32)),
        'avatar': avatar,
        'team': team
      };
}

class ScoreRoomInfo {
  const ScoreRoomInfo(
      {required this.code,
      required this.game,
      required this.hostId,
      required this.players,
      required this.teamMode,
      this.startedAt,
      this.timerSeconds,
      this.closed = false});
  final String code, game, hostId;
  final List<ScorePerson> players;
  final bool teamMode, closed;
  final DateTime? startedAt;
  final int? timerSeconds;
  int remaining([DateTime? now]) => startedAt == null || timerSeconds == null
      ? 0
      : (timerSeconds! -
              (now ?? DateTime.now()).difference(startedAt!).inSeconds)
          .clamp(0, 1 << 30);
}

class ScoreSnapshot {
  const ScoreSnapshot(
      {required this.kind,
      required this.rosterIds,
      required this.teamMode,
      required this.teams,
      required this.storage});
  final ScoreKind kind;
  final List<String> rosterIds;
  final bool teamMode;
  final Map<String, String?> teams;
  final Map<String, String> storage;
  factory ScoreSnapshot.fromJson(Map<String, dynamic> json) => ScoreSnapshot(
      kind: ScoreKind.values.byName(json['kind'] as String),
      rosterIds: List<String>.from(json['rosterIds'] as List),
      teamMode: json['teamMode'] == true,
      teams: Map<String, String?>.from(json['teams'] as Map),
      storage: Map<String, String>.from(json['storage'] as Map));
  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'rosterIds': rosterIds,
        'teamMode': teamMode,
        'teams': teams,
        'storage': storage
      };
  String get signature => jsonEncode(toJson());
}

class ScoreEnvelope {
  const ScoreEnvelope(
      {required this.revision, required this.canEdit, this.snapshot});
  final int revision;
  final bool canEdit;
  final ScoreSnapshot? snapshot;
  factory ScoreEnvelope.fromJson(Map<String, dynamic> json) => ScoreEnvelope(
      revision: (json['revision'] as num).toInt(),
      canEdit: json['canEdit'] == true,
      snapshot: json['snapshot'] is Map
          ? ScoreSnapshot.fromJson(
              Map<String, dynamic>.from(json['snapshot'] as Map))
          : null);
}

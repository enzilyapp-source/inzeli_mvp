/// Server-authoritative challenge state. The cached copy is for offline display;
/// equipping a reward still requires ownership verification by the API.
class ChallengeReward {
  const ChallengeReward(
      {required this.id,
      required this.name,
      required this.kind,
      required this.slot,
      required this.target,
      required this.progress,
      required this.unlocked,
      required this.games,
      this.collection = 'classic',
      this.itemKind = 'theme',
      this.legacyRank = false});
  final String id, name, kind, collection, itemKind;
  final bool legacyRank;
  final int slot, target, progress;
  final bool unlocked;
  final List<String> games;
  factory ChallengeReward.fromJson(Map<String, dynamic> json) =>
      ChallengeReward(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        collection: json['collection']?.toString() ?? 'classic',
        itemKind: json['itemKind']?.toString() ?? 'theme',
        legacyRank: json['legacyRank'] == true,
        kind: json['kind']?.toString() ?? 'wins',
        slot: ((json['slot'] as num?)?.toInt() ?? 0).clamp(0, 26),
        target: (json['target'] as num?)?.toInt() ?? 1,
        progress: (json['progress'] as num?)?.toInt() ?? 0,
        unlocked: json['unlocked'] == true,
        games: (json['games'] as List? ?? []).map((e) => e.toString()).toList(),
      );
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind,
        'collection': collection,
        'itemKind': itemKind,
        'legacyRank': legacyRank,
        'slot': slot,
        'target': target,
        'progress': progress,
        'unlocked': unlocked,
        'games': games,
      };
}

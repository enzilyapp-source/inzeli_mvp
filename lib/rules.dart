import 'package:flutter/foundation.dart';

/// نوع اللعب
enum PlayMode {
  solo,     // فردي (1 ضد 1 أو 1 ضد كثير)
  team2v2,  // 2 ضد 2
  team3v3,  // 3 ضد 3
  team5v5,  // 5 ضد 5
  team6v6,  // 6 ضد 6
  team9v9,  // 9 ضد 9
  duo2v2,   // synonym for 2v2 (للتوضيح في بعض الألعاب)
}

/// تعريف قاعدة لعبة واحدة
class GameRule {
  final String name;
  final int timerMinutes;
  final int minPlayers;     // أقل عدد لاعبين لإطلاق المباراة
  final int maxPlayers;     // أقصى عدد
  final List<PlayMode> modes; // أنماط اللعب المدعومة
  final bool pointsPerPlayer; // النقاط +1/-1 لكل لاعب (صحيح هنا)
  final bool allowFreeForAll; // لبعض الفردي (4 أو 5 لاعبين مثلاً سبيتة)

  const GameRule({
    required this.name,
    required this.timerMinutes,
    required this.minPlayers,
    required this.maxPlayers,
    required this.modes,
    this.pointsPerPlayer = true,
    this.allowFreeForAll = false,
  });

  @override
  String toString() => 'GameRule($name m:$timerMinutes p:$minPlayers..$maxPlayers modes:$modes)';
}

/// القواعد لكل لعبة حسب وصفك
const Map<String, GameRule> kGameRules = {
  // جنجفة
  'كوت': GameRule(
    name: 'كوت',
    timerMinutes: 30,
    minPlayers: 4,
    maxPlayers: 6,   // وإذا ضغط Plus يزيد لاعبين 2 إجباري
    modes: [PlayMode.team2v2, PlayMode.team3v3],
    pointsPerPlayer: true,
  ),
  'بلوت': GameRule(
    name: 'بلوت',
    timerMinutes: 30,
    minPlayers: 4,
    maxPlayers: 4,
    modes: [PlayMode.team2v2],
    pointsPerPlayer: true,
  ),
  'تريكس': GameRule(
    name: 'تريكس',
    timerMinutes: 30,
    minPlayers: 4,
    maxPlayers: 4,
    modes: [PlayMode.solo, PlayMode.team2v2],
    pointsPerPlayer: true,
    allowFreeForAll: true, // الفردي نقطة كاملة للفائز/الخاسر
  ),
  'هند': GameRule(
    name: 'هند',
    timerMinutes: 30,
    minPlayers: 2,  // فردي يبدأ 2 ويزيد حتى 5، أو 2×2
    maxPlayers: 5,
    modes: [PlayMode.solo, PlayMode.team2v2],
    pointsPerPlayer: true,
    allowFreeForAll: true,
  ),
  'سبيتة': GameRule(
    name: 'سبيتة',
    timerMinutes: 30,
    minPlayers: 4,
    maxPlayers: 5,
    modes: [PlayMode.solo],
    pointsPerPlayer: true,
    allowFreeForAll: true,
  ),

  // ألعاب شعبية (بورد)
  'شطرنج': GameRule(
    name: 'شطرنج',
    timerMinutes: 10,
    minPlayers: 2,
    maxPlayers: 2,
    modes: [PlayMode.solo],
    pointsPerPlayer: true,
  ),
  'دامه': GameRule(
    name: 'دامه',
    timerMinutes: 10,
    minPlayers: 2,
    maxPlayers: 2,
    modes: [PlayMode.solo],
    pointsPerPlayer: true,
  ),
  'كيرم': GameRule(
    name: 'كيرم',
    timerMinutes: 15,
    minPlayers: 4,
    maxPlayers: 4,
    modes: [PlayMode.team2v2],
    pointsPerPlayer: true,
  ),
  'دومنه': GameRule(
    name: 'دومنه',
    timerMinutes: 15,
    minPlayers: 2,  // 1 ضد 1 إلى 4 ضد بعض
    maxPlayers: 4,
    modes: [PlayMode.solo],
    pointsPerPlayer: true,
    allowFreeForAll: true,
  ),
  'طاوله': GameRule(
    name: 'طاوله',
    timerMinutes: 30,
    minPlayers: 2,
    maxPlayers: 2,
    modes: [PlayMode.solo],
    pointsPerPlayer: true,
  ),

  // رياضة
  'بيبيفوت': GameRule(
    name: 'بيبيفوت',
    timerMinutes: 20,
    minPlayers: 2,
    maxPlayers: 4, // 1v1 أو 2v2
    modes: [PlayMode.solo, PlayMode.team2v2],
    pointsPerPlayer: true,
  ),
  'قدم': GameRule(
    name: 'قدم',
    timerMinutes: 60,
    minPlayers: 10, // 5 ضد 5
    maxPlayers: 18, // 9 ضد 9
    modes: [PlayMode.team5v5, PlayMode.team9v9],
    pointsPerPlayer: true,
  ),
  'سله': GameRule(
    name: 'سله',
    timerMinutes: 60,
    minPlayers: 2, // 1 ضد 1
    maxPlayers: 10, // 5 ضد 5
    modes: [PlayMode.solo, PlayMode.team5v5],
    pointsPerPlayer: true,
  ),
  'طائره': GameRule(
    name: 'طائره',
    timerMinutes: 60,
    minPlayers: 12, // 6 ضد 6
    maxPlayers: 12,
    modes: [PlayMode.team6v6],
    pointsPerPlayer: true,
  ),
  'بولنج': GameRule(
    name: 'بولنج',
    timerMinutes: 30,
    minPlayers: 2, // 1 ضد 1
    maxPlayers: 2,
    modes: [PlayMode.solo],
    pointsPerPlayer: true,
  ),
  'بادل': GameRule(
    name: 'بادل',
    timerMinutes: 90,
    minPlayers: 4, // 2 ضد 2
    maxPlayers: 4,
    modes: [PlayMode.team2v2],
    pointsPerPlayer: true,
  ),
  'تنس طاولة': GameRule(
    name: 'تنس طاولة',
    timerMinutes: 15,
    minPlayers: 2, // 1v1 أو 2v2
    maxPlayers: 4,
    modes: [PlayMode.solo, PlayMode.team2v2],
    pointsPerPlayer: true,
  ),
  'تنس ارضي': GameRule(
    name: 'تنس ارضي',
    timerMinutes: 90,
    minPlayers: 2, // 1v1 أو 2v2
    maxPlayers: 4,
    modes: [PlayMode.solo, PlayMode.team2v2],
    pointsPerPlayer: true,
  ),
  'بلياردو': GameRule(
    name: 'بلياردو',
    timerMinutes: 30,
    minPlayers: 2,   // فردي 1 ضد 1
    maxPlayers: 2,
    modes: [PlayMode.solo],
    pointsPerPlayer: true,   // الفايز +1، الخاسر -1
  ),
};

import 'package:flutter/material.dart';
import '../state.dart';
import '../challenge_rewards.dart';
import '../widgets/reward_avatar_frame.dart';
import '../widgets/rank_identity.dart';
import '../widgets/app_snackbar.dart';

class ChallengeRewardsPage extends StatefulWidget {
  const ChallengeRewardsPage({super.key, required this.app});
  final AppState app;
  @override
  State<ChallengeRewardsPage> createState() => _ChallengeRewardsPageState();
}

class _ChallengeRewardsPageState extends State<ChallengeRewardsPage> {
  bool _loading = true;
  bool _failed = false;
  String? _equipping;
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (mounted) setState(() => _loading = true);
    final ok = await widget.app.refreshChallengeRewards();
    if (mounted) {
      setState(() {
        _loading = false;
        _failed = !ok;
      });
    }
  }

  Future<void> _equip(ChallengeReward reward) async {
    if (_equipping != null) return;
    setState(() => _equipping = reward.id);
    final ok = await widget.app.equipChallengeReward(reward.id);
    if (!mounted) return;
    setState(() => _equipping = null);
    showAppSnack(
        context,
        widget.app.tr(
            ar: ok
                ? 'تم تطبيق الإطار'
                : 'تعذّر تطبيق الإطار. تأكد من الاتصال وحدّث الجوائز.',
            en: ok
                ? 'Frame applied'
                : 'Could not apply the frame. Check your connection and refresh rewards.'),
        error: !ok,
        success: ok);
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    return Directionality(
      textDirection: app.isEnglish ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF11273C),
        appBar: AppBar(
            backgroundColor: const Color(0xFF11273C),
            title: Text(
                app.tr(ar: 'تحديات اللعب والجوائز', en: 'Challenges & rewards'),
                style: const TextStyle(fontSize: 18)),
            actions: [
              IconButton(
                  onPressed: _loading ? null : _refresh,
                  tooltip: app.tr(ar: 'تحديث الجوائز', en: 'Refresh rewards'),
                  icon: const Icon(Icons.refresh))
            ]),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                            app.tr(
                                ar: 'العب، ترقَّ، واحتفظ بجائزتك',
                                en: 'Play, level up, keep your rewards'),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text(
                            app.tr(
                                ar:
                                    'إطارات المستويات حسب أنواطك. تحديات الفوز تُحسب من المباريات المسجلة، وتبقى الجوائز معك بعد انتهاء الموسم.',
                                en:
                                    'Rank frames follow your badges. Win challenges use recorded matches. Earned rewards stay yours after the season ends.'),
                            style: const TextStyle(
                                color: Colors.white70, height: 1.6)),
                        const SizedBox(height: 16),
                        if (_loading) const LinearProgressIndicator(),
                        if (_failed) ...[
                          Text(
                              app.tr(
                                  ar:
                                      'تعذّر تحديث الجوائز. تأكد من الاتصال وتحديث السيرفر؛ الجوائز المحفوظة باقية.',
                                  en:
                                      'Rewards could not refresh. Check your connection and server update. Cached rewards are kept.'),
                              style:
                                  const TextStyle(color: Colors.orangeAccent)),
                          TextButton(
                              onPressed: _refresh,
                              child: Text(
                                  app.tr(ar: 'إعادة المحاولة', en: 'Retry'))),
                        ],
                        for (final kind in ['rank', 'wins', 'heritage']) ...[
                          if (app.challengeRewards.any((reward) =>
                              kind == 'heritage'
                                  ? reward.collection == 'heritage'
                                  : reward.kind == kind &&
                                      reward.collection != 'heritage' &&
                                      !reward.legacyRank))
                            Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                    app.tr(
                                        ar: kind == 'rank'
                                            ? 'جوائز المستويات'
                                            : kind == 'heritage'
                                                ? 'تحديات تراثية'
                                                : 'تحديات الفوز',
                                        en: kind == 'rank'
                                            ? 'Rank rewards'
                                            : kind == 'heritage'
                                                ? 'Heritage challenges'
                                                : 'Win challenges'),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 18))),
                          ...app.challengeRewards
                              .where((reward) => kind == 'heritage'
                                  ? reward.collection == 'heritage'
                                  : reward.kind == kind &&
                                      reward.collection != 'heritage' &&
                                      !reward.legacyRank)
                              .map((reward) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: ChallengeRewardCard(
                                        reward: reward,
                                        app: app,
                                        equipped: reward.itemKind == 'card'
                                            ? app.cardId == reward.id
                                            : app.themeId == reward.id,
                                        busy: _equipping != null,
                                        onEquip: () => _equip(reward)),
                                  )),
                        ],
                      ],
                    )))),
      ),
    );
  }
}

class ChallengeRewardCard extends StatelessWidget {
  const ChallengeRewardCard(
      {super.key,
      required this.reward,
      required this.app,
      required this.equipped,
      required this.busy,
      required this.onEquip});
  final ChallengeReward reward;
  final AppState app;
  final bool equipped, busy;
  final VoidCallback onEquip;
  @override
  Widget build(BuildContext context) {
    final rankName = AppState.badgeDisplayLabel(switch (reward.target) {
      5 => 'Beginner',
      10 => 'Good',
      15 => 'Professional',
      20 => 'Legendary',
      30 => 'Best',
      _ => '',
    });
    final condition = reward.kind == 'rank'
        ? app.tr(
            ar: 'الوصول إلى مستوى $rankName في أي لعبة',
            en: 'Reach badge level $rankName in any game')
        : app.tr(
            ar: 'الفوز ${reward.target} مرات${reward.games.isEmpty ? ' في أي لعبة' : ' في ${reward.games.map(app.gameLabel).join('، ')}'}',
            en: 'Record ${reward.target} wins${reward.games.isEmpty ? ' in any game' : ' in ${reward.games.map(app.gameLabel).join(', ')}'}');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: const Color(0xFF1B384E),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color:
                  reward.unlocked ? const Color(0xFFB78C4D) : Colors.white12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 86,
              height: 86,
              child: Stack(alignment: Alignment.center, children: [
                CircleAvatar(
                    radius: 25,
                    backgroundColor: const Color(0xFF253347),
                    child: Icon(
                        reward.unlocked ? Icons.person : Icons.lock_outline,
                        color: Colors.white70)),
                if (reward.itemKind == 'card' &&
                    rankIdentityForBanner(reward.id) != null)
                  RankBannerPreview(
                      rank: rankIdentityForBanner(reward.id)!, height: 70)
                else
                  RewardFrameArt(slot: reward.slot, size: 86),
              ])),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(reward.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 17)),
                const SizedBox(height: 5),
                Text(condition,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12, height: 1.5)),
                const SizedBox(height: 5),
                Text(app.tr(ar: 'جائزة دائمة', en: 'Permanent reward'),
                    style: const TextStyle(
                        color: Color(0xFFFFC469), fontSize: 11)),
              ])),
        ]),
        const SizedBox(height: 12),
        if (!reward.unlocked) ...[
          LinearProgressIndicator(
              value: (reward.progress / (reward.target > 0 ? reward.target : 1))
                  .clamp(0.0, 1.0),
              color: const Color(0xFFFFB33B),
              backgroundColor: Colors.white12,
              minHeight: 6,
              borderRadius: BorderRadius.circular(9)),
          const SizedBox(height: 6),
          if (reward.kind == 'wins')
            Text('${reward.progress} / ${reward.target}',
                textDirection: TextDirection.ltr,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
        OutlinedButton.icon(
            onPressed: reward.unlocked && !equipped && !busy ? onEquip : null,
            style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFFC469)),
            icon: Icon(
                equipped
                    ? Icons.check_circle_outline
                    : reward.unlocked
                        ? Icons.auto_awesome
                        : Icons.lock_outline,
                size: 18),
            label: Text(app.tr(
                ar: equipped
                    ? 'مُطبّق'
                    : reward.unlocked
                        ? (reward.itemKind == 'card'
                            ? 'تطبيق البنر'
                            : 'تطبيق الإطار')
                        : 'لم يُفتح بعد',
                en: equipped
                    ? 'Applied'
                    : reward.unlocked
                        ? (reward.itemKind == 'card'
                            ? 'Apply banner'
                            : 'Apply frame')
                        : 'Locked'))),
      ]),
    );
  }
}

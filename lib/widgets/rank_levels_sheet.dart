import 'dart:async';
import 'package:flutter/material.dart';
import '../state.dart';
import 'rank_identity.dart';
import 'reward_avatar_frame.dart';

class RankLevelsSheet extends StatefulWidget {
  const RankLevelsSheet(
      {super.key, required this.app, required this.currentThreshold});
  final AppState app;
  final int currentThreshold;
  @override
  State<RankLevelsSheet> createState() => _RankLevelsSheetState();
}

class _RankLevelsSheetState extends State<RankLevelsSheet> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.app.refreshChallengeRewards());
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
            child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: .78,
          minChildSize: .4,
          maxChildSize: .95,
          builder: (context, controller) => ListenableBuilder(
            listenable: widget.app,
            builder: (context, _) => ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                children: [
                  Row(children: [
                    const Expanded(
                        child: Text('المستوى',
                            style: TextStyle(
                                fontSize: 23, fontWeight: FontWeight.w800))),
                    IconButton(
                        onPressed: () => Navigator.pop(context),
                        tooltip: 'إغلاق المستويات',
                        icon: const Icon(Icons.close))
                  ]),
                  const Text(
                      'مسمياتنا نفسها، ولكل نوط دائرته وبنره. الجوائز المفتوحة تبقى معك بعد الموسم.',
                      style: TextStyle(color: Colors.white70, height: 1.6)),
                  const SizedBox(height: 14),
                  for (final rank in rankIdentities)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .045),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                              color: rankIdentityForThreshold(
                                          widget.currentThreshold) ==
                                      rank
                                  ? rank.colors.first
                                  : Colors.white12)),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(children: [
                              RankMedal(threshold: rank.threshold, size: 46),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text('${rank.arabic} • ${rank.metalAr}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 18)),
                                    Text(
                                        'يبدأ عند ${rank.threshold} من تقدم المستوى',
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12)),
                                  ])),
                            ]),
                            const SizedBox(height: 12),
                            Row(children: [
                              RewardAvatarFrame(
                                  slot: rank.slot,
                                  size: 66,
                                  child: const CircleAvatar(
                                      backgroundColor: Color(0xFF2A3E54),
                                      child: Icon(Icons.person_outline))),
                              const SizedBox(width: 14),
                              Expanded(
                                  child: RankBannerPreview(
                                      rank: rank, height: 66)),
                            ]),
                            const SizedBox(height: 10),
                            Text(
                                widget.app.earnedRewardIds
                                            .contains(rank.frameId) &&
                                        widget.app.earnedRewardIds
                                            .contains(rank.bannerId)
                                    ? 'الدائرة والبنر مفتوحان لك دائمًا'
                                    : rank.threshold == 5
                                        ? 'الدائرة والبنر مع بداية حسابك'
                                        : 'تفتح الدائرة والبنر عند الوصول لهذا النوط',
                                style: TextStyle(
                                    color: rank.colors.first, fontSize: 12)),
                            if (rankIdentityForThreshold(
                                    widget.currentThreshold) ==
                                rank)
                              const Padding(
                                  padding: EdgeInsets.only(top: 6),
                                  child: Text('مستواك الحالي',
                                      style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12))),
                          ]),
                    ),
                ]),
          ),
        )),
      );
}

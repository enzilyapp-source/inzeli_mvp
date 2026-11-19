import 'package:flutter/material.dart';

/// Stable slots 0–14 use the classic sheet; 15–26 use the heritage sheet.
/// Keep this sheet bundled so rewards remain visible without network image loads.
class RewardAvatarFrame extends StatelessWidget {
  const RewardAvatarFrame(
      {super.key, required this.slot, required this.size, required this.child});
  final int slot;
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Stack(alignment: Alignment.center, children: [
          SizedBox(
              width: size * .70,
              height: size * .70,
              child: ClipOval(child: child)),
          IgnorePointer(child: RewardFrameArt(slot: slot, size: size)),
        ]),
      );
}

class RewardFrameArt extends StatelessWidget {
  const RewardFrameArt({super.key, required this.slot, required this.size});
  final int slot;
  final double size;

  @override
  Widget build(BuildContext context) {
    final heritage = slot >= 15;
    final columns = heritage ? 4 : 5;
    final localSlot = heritage ? slot - 15 : slot;
    final asset = heritage
        ? 'lib/assets/rewards/heritage_frames_v1.png'
        : 'lib/assets/rewards/avatar_frames_v1.png';
    return SizedBox(
      width: size,
      height: size,
      child: ClipRect(
          child: OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: size * columns,
        maxWidth: size * columns,
        minHeight: size * 3,
        maxHeight: size * 3,
        child: Transform.translate(
            offset: Offset(
                -(localSlot % columns) * size, -(localSlot ~/ columns) * size),
            child: Image.asset(asset,
                width: size * columns,
                height: size * 3,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.medium,
                cacheWidth: 1620)),
      )),
    );
  }
}

import 'package:flutter/services.dart';

/// Lightweight SFX helper that relies on system sounds only
/// (no external assets needed). Honors a simple mute flag.
class Sfx {
  static bool muted = false;

  static void tap({bool? mute}) {
    if (mute ?? muted) return;
    SystemSound.play(SystemSoundType.click);
  }

  static void success({bool? mute}) {
    if (mute ?? muted) return;
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.mediumImpact();
  }

  static void error({bool? mute}) {
    if (mute ?? muted) return;
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.vibrate();
  }

  static void timerStart({bool? mute}) {
    if (mute ?? muted) return;
    SystemSound.play(SystemSoundType.click);
  }

  static void timerEnd({bool? mute}) {
    if (mute ?? muted) return;
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.selectionClick();
  }
}

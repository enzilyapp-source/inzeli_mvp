import 'dart:async';

import 'package:flutter/services.dart';
import 'sound_manager.dart';

/// Lightweight SFX helper that relies on system sounds only
/// (no external assets needed). Honors a simple mute flag.
class Sfx {
  static bool muted = false;

  static void tap({bool? mute}) {
    if (mute ?? muted) return;
    unawaited(SoundManager().tap());
    SystemSound.play(SystemSoundType.click);
  }

  static void success({bool? mute}) {
    if (mute ?? muted) return;
    unawaited(SoundManager().ok());
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.mediumImpact();
  }

  static void error({bool? mute}) {
    if (mute ?? muted) return;
    unawaited(SoundManager().err());
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.vibrate();
  }

  static void timerStart({bool? mute}) {
    if (mute ?? muted) return;
    unawaited(SoundManager().primary());
    SystemSound.play(SystemSoundType.click);
  }

  static void primaryAction({bool? mute}) {
    if (mute ?? muted) return;
    unawaited(SoundManager().primary());
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.selectionClick();
  }

  static void timerEnd({bool? mute}) {
    if (mute ?? muted) return;
    unawaited(SoundManager().timerEnd());
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.selectionClick();
  }

  static void winner({bool? mute}) {
    if (mute ?? muted) return;
    unawaited(SoundManager().winner());
    HapticFeedback.heavyImpact();
    for (var i = 0; i < 4; i++) {
      unawaited(Future<void>.delayed(
        Duration(milliseconds: i * 120),
        () => SystemSound.play(SystemSoundType.click),
      ));
    }
  }
}

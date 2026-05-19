import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// Simple, safe sound manager. Optional: only use if you wired assets.
class SoundManager {
  static final SoundManager _i = SoundManager._internal();
  factory SoundManager() => _i;
  SoundManager._internal();

  Future<void> tap() => _play('lib/assets/sfx/tap.wav');
  Future<void> primary() => _play('lib/assets/sfx/primary.wav');
  Future<void> ok() => _play('lib/assets/sfx/success.wav');
  Future<void> err() => _play('lib/assets/sfx/error.wav');
  Future<void> timerEnd() => _play('lib/assets/sfx/timer_end.wav');
  Future<void> winner() => _play('lib/assets/sfx/winner.wav');

  Future<void> _play(String assetPath) async {
    final player = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
    try {
      unawaited(player.onPlayerComplete.first.then((_) => player.dispose()));
      await player.play(AssetSource(assetPath));
    } catch (_) {
      unawaited(player.dispose());
    }
  }
}

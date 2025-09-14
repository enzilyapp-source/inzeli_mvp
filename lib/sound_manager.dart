import 'package:audioplayers/audioplayers.dart';

/// Simple, safe sound manager. Optional: only use if you wired assets.
class SoundManager {
  static final SoundManager _i = SoundManager._internal();
  factory SoundManager() => _i;
  SoundManager._internal();

  final AudioPlayer _player = AudioPlayer();

  Future<void> click() => _play('sfx/click.mp3');
  Future<void> ok()    => _play('sfx/success.mp3');
  Future<void> err()   => _play('sfx/error.mp3');

  Future<void> _play(String assetRelativeToAssetsFolder) async {
    try {
      // pubspec should have:
      // assets:
      //   - assets/sfx/click.mp3
      //   - assets/sfx/success.mp3
      //   - assets/sfx/error.mp3
      await _player.play(AssetSource(assetRelativeToAssetsFolder));
    } catch (_) {
      // swallow errors in dev
    }
  }
}

import 'dart:io';

import 'package:audioplayers/audioplayers.dart';

/// Sons courts. Muet pendant les tests, et selon les trois réglages.
class TableAudio {
  static var master = true;
  static var effects = true;
  static var touches = true;
  static AudioPlayer? _player;
  static AudioPlayer? _uiPlayer;
  static String? _last;
  static DateTime? _touchAt;
  static DateTime? _woundAt;

  static const pools = <String, List<String>>{
    'swing': [
      'sfx/swing-2.wav',
      'sfx/swing-3.wav',
      'sfx/blade-1.wav',
      'sfx/blade-2.wav',
      'sfx/blade-3.wav',
    ],
    'fire': ['sfx/fire-1.wav'],
    'ice': ['sfx/ice-1.wav'],
    'bolt': ['sfx/bolt-1.wav'],
    'heal': ['sfx/heal.wav'],
    'win': ['sfx/win-fretless.wav'],
    'fall': ['sfx/sword-strike.wav'],
    'tap': ['sfx/tap.wav'],
    'slide': ['sfx/slide-1.wav', 'sfx/slide-2.wav'],
  };

  static void playTouch() => _ui('tap');

  static void playSlide() => _ui('slide');

  /// Son d’effet d’une vie qui monte ou qui descend. Les touches restent à part.
  static void playWound(int delta) {
    if (delta == 0 || !master || !effects) return;
    final now = DateTime.now();
    final last = _woundAt;
    if (last != null && now.difference(last).inMilliseconds < 70) return;
    _woundAt = now;
    play(delta > 0 ? 'heal' : 'swing');
  }

  static void _ui(String pool) {
    if (!master || !touches) return;
    final now = DateTime.now();
    final last = _touchAt;
    if (last != null && now.difference(last).inMilliseconds < 90) return;
    _touchAt = now;
    play(pool, gate: false);
  }

  static Future<void> play(String pool, {int salt = 0, bool gate = true}) async {
    if (gate && (!master || !effects)) return;
    if (!gate && (!master || !touches)) return;
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    final list = pools[pool];
    if (list == null || list.isEmpty) return;
    var index = salt.abs() % list.length;
    if (list.length > 1 && list[index] == _last) {
      index = (index + 1) % list.length;
    }
    final asset = list[index];
    _last = asset;
    try {
      final player = gate
          ? (_player ??= AudioPlayer())
          : (_uiPlayer ??= AudioPlayer());
      try {
        await player.stop();
      } catch (_) {}
      await player.play(AssetSource(asset));
    } catch (_) {
      if (gate) {
        _player = null;
      } else {
        _uiPlayer = null;
      }
    }
  }
}

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibration/vibration.dart';

/// Plays the attention alert for a new Line Takeover Request — a loud sound
/// plus a strong vibration pattern, suited to a noisy factory floor.
///
/// Every step is defensively guarded: a missing/invalid sound asset, a device
/// with no vibration motor, or a plugin that is unavailable (e.g. under
/// `flutter test`) must never crash the caller. When the bundled sound fails
/// to play, the service falls back to the platform alert sound.
///
/// De-duplication is the *caller's* responsibility — [playAlert] always plays.
/// The home screen triggers it exactly once per takeover `requestId` (when the
/// status first becomes `PENDING`), never on a plain refresh.
class TakeoverAlertService {
  TakeoverAlertService();

  /// Asset path relative to `assets/` (declared in `pubspec.yaml`).
  static const String _soundAsset = 'sounds/takeover_alert.mp3';

  /// `[wait, vibrate, wait, vibrate, …]` in milliseconds — three long buzzes.
  static const List<int> _vibrationPattern = <int>[
    0,
    600,
    250,
    600,
    250,
    600,
  ];

  AudioPlayer? _player;

  /// Plays the sound and triggers the vibration. Never throws.
  Future<void> playAlert() async {
    await Future.wait<void>(<Future<void>>[_vibrate(), _playSound()]);
  }

  Future<void> _vibrate() async {
    try {
      final bool hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator) {
        await Vibration.vibrate(pattern: _vibrationPattern);
        return;
      }
    } catch (_) {
      // Fall through to the haptic fallback below.
    }
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {
      // No haptics available — nothing more we can do.
    }
  }

  Future<void> _playSound() async {
    try {
      final AudioPlayer player = _player ??= AudioPlayer();
      await player.stop();
      await player.play(AssetSource(_soundAsset));
    } catch (_) {
      await _playSystemFallback();
    }
  }

  Future<void> _playSystemFallback() async {
    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {
      // Nothing else to try.
    }
  }

  void dispose() {
    _player?.dispose();
    _player = null;
  }
}

/// Exposes a single shared [TakeoverAlertService]. Override in tests to assert
/// the alert fired without touching real audio/vibration plugins.
final takeoverAlertServiceProvider = Provider<TakeoverAlertService>((ref) {
  final TakeoverAlertService service = TakeoverAlertService();
  ref.onDispose(service.dispose);
  return service;
});

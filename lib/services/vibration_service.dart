import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// Vibration service with enhanced haptic feedback support
/// 
/// This service provides reliable vibration functionality across different devices
/// by checking device capabilities and using appropriate vibration patterns.
class VibrationService {
  static final VibrationService _instance = VibrationService._internal();
  factory VibrationService() => _instance;
  VibrationService._internal();

  /// Check if the device has vibration capability
  Future<bool> hasVibrator() async {
    try {
      final hasVibrator = await Vibration.hasVibrator() ?? false;
      return hasVibrator;
    } catch (e) {
      // If check fails, assume device has vibration
      return true;
    }
  }

  /// Check if the device can amplitude control vibration
  Future<bool> hasAmplitudeControl() async {
    try {
      return await Vibration.hasAmplitudeControl() ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Trigger a light tap vibration (success feedback)
  Future<void> tap() async {
    try {
      if (await hasVibrator()) {
        // Use HapticFeedback for lighter tap
        await HapticFeedback.lightImpact();
        // Also trigger vibration for devices that support it
        await Vibration.vibrate(duration: 50);
      }
    } catch (e) {
      // Fallback to HapticFeedback only
      await HapticFeedback.lightImpact();
    }
  }

  /// Trigger a medium vibration (selection/warning feedback)
  Future<void> medium() async {
    try {
      if (await hasVibrator()) {
        await HapticFeedback.mediumImpact();
        await Vibration.vibrate(duration: 100);
      }
    } catch (e) {
      await HapticFeedback.mediumImpact();
    }
  }

  /// Trigger a heavy vibration (error/important feedback)
  Future<void> heavy() async {
    try {
      if (await hasVibrator()) {
        await HapticFeedback.heavyImpact();
        await Vibration.vibrate(duration: 200);
      }
    } catch (e) {
      await HapticFeedback.heavyImpact();
    }
  }

  /// Trigger a success vibration pattern
  Future<void> success() async {
    try {
      if (await hasVibrator()) {
        // Double tap pattern for success
        await Vibration.vibrate(pattern: [0, 50, 50, 50]);
      } else {
        await HapticFeedback.lightImpact();
      }
    } catch (e) {
      await HapticFeedback.lightImpact();
    }
  }

  /// Trigger an error vibration pattern
  Future<void> error() async {
    try {
      if (await hasVibrator()) {
        // Heavy double vibration for error
        await Vibration.vibrate(pattern: [0, 100, 50, 100]);
      } else {
        await HapticFeedback.heavyImpact();
      }
    } catch (e) {
      await HapticFeedback.heavyImpact();
    }
  }

  /// Trigger a warning vibration pattern
  Future<void> warning() async {
    try {
      if (await hasVibrator()) {
        // Single long vibration for warning
        await Vibration.vibrate(duration: 300);
      } else {
        await HapticFeedback.mediumImpact();
      }
    } catch (e) {
      await HapticFeedback.mediumImpact();
    }
  }

  /// Trigger a custom vibration pattern
  Future<void> vibratePattern({
    List<int>? pattern,
    int? duration,
    int? amplitude,
  }) async {
    try {
      if (await hasVibrator()) {
        if (pattern != null) {
          await Vibration.vibrate(pattern: pattern);
        } else if (duration != null) {
          if (amplitude != null && await hasAmplitudeControl()) {
            await Vibration.vibrate(duration: duration, amplitude: amplitude);
          } else {
            await Vibration.vibrate(duration: duration);
          }
        } else {
          await Vibration.vibrate(duration: 100);
        }
      }
    } catch (e) {
      // Silent fail - vibration is not critical
    }
  }

  /// Cancel any ongoing vibration
  Future<void> cancel() async {
    try {
      await Vibration.cancel();
    } catch (e) {
      // Silent fail
    }
  }
}

import 'dart:io';

import 'package:disk_space_plus/disk_space_plus.dart';
import 'package:flutter/services.dart';

import 'model_catalog.dart';

const _deviceInfoChannel = MethodChannel('high_ai/device_info');
const _bytesPerGib = 1024 * 1024 * 1024;

/// Result of a pre-download device check, shown to the user before they
/// commit to a multi-GB download — see the brief's requirements around
/// insufficient storage/RAM and unsupported devices.
class DeviceCapabilityResult {
  const DeviceCapabilityResult({
    required this.freeStorageBytes,
    required this.totalRamBytes,
    required this.requiredStorageBytes,
    required this.recommendedRamBytes,
  });

  /// Null when the platform doesn't expose this (e.g. this dev sandbox, or
  /// a platform without the native channel implemented yet) — callers must
  /// treat null as "unknown", not "insufficient".
  final int? freeStorageBytes;
  final int? totalRamBytes;

  final int requiredStorageBytes;
  final int recommendedRamBytes;

  /// False only when we positively know there isn't enough room — unknown
  /// free space never blocks the user, it just can't confirm either way.
  bool get isStorageSufficient {
    if (freeStorageBytes == null) return true;
    // A little headroom beyond the exact file size for the atomic
    // rename and any temp state.
    return freeStorageBytes! > (requiredStorageBytes * 1.05);
  }

  bool get isRamLikelySufficient {
    if (totalRamBytes == null) return true;
    // Android reports somewhat less than a device's marketed RAM (some is
    // reserved for hardware), so a "true" 8GB device might report ~7.4GB
    // via ActivityManager — allow 10% slack against the nominal spec
    // rather than false-flagging exactly-at-spec devices.
    return totalRamBytes! >= recommendedRamBytes * 0.9;
  }

  bool get canProceed => isStorageSufficient;
}

/// Checks free storage and total RAM against a model's requirements before
/// a download starts. Never throws — an unsupported platform or a failed
/// native call just yields unknown (null) figures rather than blocking the
/// user or crashing the download flow.
class DeviceCapabilityChecker {
  Future<DeviceCapabilityResult> check(ModelDefinition model, String installDir) async {
    final requiredStorage = model.defaultVariant.approximateSizeBytes;
    final recommendedRam = model.minRamGb * _bytesPerGib;

    int? freeStorage;
    try {
      final freeMb = await DiskSpacePlus().getFreeDiskSpaceForPath(installDir);
      if (freeMb != null) freeStorage = (freeMb * 1024 * 1024).round();
    } catch (_) {
      // Not supported on this platform (e.g. desktop) — leave as unknown.
    }

    int? totalRam;
    if (Platform.isAndroid) {
      try {
        final result = await _deviceInfoChannel.invokeMapMethod<String, Object?>(
          'getMemoryInfo',
        );
        totalRam = (result?['totalRamBytes'] as num?)?.toInt();
      } catch (_) {
        // Channel not available (e.g. running in a test harness) — unknown.
      }
    }

    return DeviceCapabilityResult(
      freeStorageBytes: freeStorage,
      totalRamBytes: totalRam,
      requiredStorageBytes: requiredStorage,
      recommendedRamBytes: recommendedRam,
    );
  }
}

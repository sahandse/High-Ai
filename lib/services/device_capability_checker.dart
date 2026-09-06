import 'dart:io';

import 'package:disk_space_plus/disk_space_plus.dart';
import 'package:flutter/services.dart';

import 'model_catalog.dart';

const _deviceInfoChannel = MethodChannel('high_ai/device_info');

/// A minimum-RAM heuristic per model — not an exact figure from LiteRT-LM
/// (no such published number was found — see docs/ARCHITECTURE.md), but a
/// conservative estimate: a `.litertlm` file's on-disk size is a mix of
/// 2/4/8-bit weights, so resident memory is well under the file size, but
/// the OS, Flutter engine, and the rest of a real phone's workload need
/// headroom too.
int _minimumRamBytesFor(ModelDefinition model) =>
    (model.defaultVariant.approximateSizeBytes * 1.3).round();

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
    return totalRamBytes! >= recommendedRamBytes;
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
    final recommendedRam = _minimumRamBytesFor(model);

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

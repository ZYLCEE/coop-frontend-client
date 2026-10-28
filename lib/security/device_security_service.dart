import 'package:flutter/foundation.dart';
import 'package:safe_device/safe_device.dart';
import 'package:safe_device/safe_device_config.dart';

enum DeviceSecurityRisk {
  none,
  emulatorOrSimulator,
  rootOrJailbreak,
  emulatorAndRootOrJailbreak,
  unavailable,
}

class DeviceSecurityStatus {
  const DeviceSecurityStatus({
    required this.platform,
    required this.isSupported,
    required this.isPhysicalDevice,
    required this.isEmulatorOrSimulator,
    required this.isRootedOrJailbroken,
    required this.risk,
  });

  final String platform;
  final bool isSupported;
  final bool? isPhysicalDevice;
  final bool? isEmulatorOrSimulator;
  final bool? isRootedOrJailbroken;
  final DeviceSecurityRisk risk;

  bool get isRisky => risk != DeviceSecurityRisk.none;

  String get debugSummary =>
      'Device security: platform=$platform, risk=${risk.name}';
}

class DeviceSecurityService {
  static bool _initialized = false;

  static void initialize() {
    if (_initialized) return;
    SafeDevice.init(SafeDeviceConfig(mockLocationCheckEnabled: false));
    _initialized = true;
  }

  Future<DeviceSecurityStatus> check() async {
    initialize();

    final platform = _platformName;
    if (platform == null) {
      return const DeviceSecurityStatus(
        platform: 'unsupported',
        isSupported: false,
        isPhysicalDevice: null,
        isEmulatorOrSimulator: null,
        isRootedOrJailbroken: null,
        risk: DeviceSecurityRisk.unavailable,
      );
    }

    try {
      final isPhysicalDevice = await SafeDevice.isRealDevice;
      final isRootedOrJailbroken = await SafeDevice.isJailBroken;
      final isEmulatorOrSimulator = !isPhysicalDevice;

      return DeviceSecurityStatus(
        platform: platform,
        isSupported: true,
        isPhysicalDevice: isPhysicalDevice,
        isEmulatorOrSimulator: isEmulatorOrSimulator,
        isRootedOrJailbroken: isRootedOrJailbroken,
        risk: _riskFor(
          isEmulatorOrSimulator: isEmulatorOrSimulator,
          isRootedOrJailbroken: isRootedOrJailbroken,
        ),
      );
    } catch (_) {
      return DeviceSecurityStatus(
        platform: platform,
        isSupported: true,
        isPhysicalDevice: null,
        isEmulatorOrSimulator: null,
        isRootedOrJailbroken: null,
        risk: DeviceSecurityRisk.unavailable,
      );
    }
  }

  String? get _platformName {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return null;
    }
  }

  DeviceSecurityRisk _riskFor({
    required bool isEmulatorOrSimulator,
    required bool isRootedOrJailbroken,
  }) {
    if (isEmulatorOrSimulator && isRootedOrJailbroken) {
      return DeviceSecurityRisk.emulatorAndRootOrJailbreak;
    }
    if (isEmulatorOrSimulator) {
      return DeviceSecurityRisk.emulatorOrSimulator;
    }
    if (isRootedOrJailbroken) {
      return DeviceSecurityRisk.rootOrJailbreak;
    }
    return DeviceSecurityRisk.none;
  }
}

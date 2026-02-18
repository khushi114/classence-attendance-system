import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service to manage BLE beacon advertising from the faculty device.
///
/// The faculty device acts as a BLE peripheral, broadcasting a session UUID
/// so that student devices can detect proximity without any external simulator.
class BeaconAdvertisingService {
  // ─── Singleton ───────────────────────────────────────────────────────────
  static final BeaconAdvertisingService _instance =
      BeaconAdvertisingService._internal();
  factory BeaconAdvertisingService() => _instance;
  BeaconAdvertisingService._internal();

  // ─── State ───────────────────────────────────────────────────────────────
  final FlutterBlePeripheral _blePeripheral = FlutterBlePeripheral();
  bool _isAdvertising = false;
  String? _currentUuid;

  bool get isAdvertising => _isAdvertising;
  String? get currentUuid => _currentUuid;

  // ─── UUID Generation ─────────────────────────────────────────────────────

  /// Generate a valid 128-bit UUID for BLE advertising.
  ///
  /// Format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  /// Example: `550e8400-e29b-41d4-a716-446655440000`
  String generateBeaconUuid(String classId) {
    final rng = Random();
    // Use classId hash as seed for reproducibility within the same class
    final seed = classId.hashCode ^ DateTime.now().millisecondsSinceEpoch;
    final seededRng = Random(seed);

    String hex(int length) => List.generate(
      length,
      (_) => seededRng.nextInt(16).toRadixString(16),
    ).join();

    final uuid =
        '${hex(8)}-${hex(4)}-4${hex(3)}-${(8 + rng.nextInt(4)).toRadixString(16)}${hex(3)}-${hex(12)}';
    _currentUuid = uuid;
    debugPrint('🔑 Generated beacon UUID: $uuid');
    return uuid;
  }

  // ─── Permission ──────────────────────────────────────────────────────────

  /// Request all Bluetooth permissions needed for advertising.
  Future<bool> _requestPermissions() async {
    final statuses = await [
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ].request();

    final advertise = statuses[Permission.bluetoothAdvertise];
    final connect = statuses[Permission.bluetoothConnect];

    debugPrint('📋 BLE Permissions — advertise: $advertise, connect: $connect');

    return advertise?.isGranted == true;
  }

  // ─── Advertising ─────────────────────────────────────────────────────────

  /// Start BLE advertising with the given [uuid].
  ///
  /// Returns `true` if advertising started successfully, `false` otherwise.
  Future<bool> startAdvertising(String uuid) async {
    debugPrint('🚀 startAdvertising() called with uuid: $uuid');

    try {
      // Request permissions first
      final hasPermission = await _requestPermissions();
      if (!hasPermission) {
        debugPrint('❌ BLE advertise permission denied — cannot start');
        return false;
      }

      // Stop any existing advertisement first
      if (_isAdvertising) {
        await stopAdvertising();
      }

      final advertiseData = AdvertiseData(
        serviceUuid: uuid,
        includeDeviceName: false,
      );

      final advertiseSettings = AdvertiseSettings(
        advertiseMode: AdvertiseMode.advertiseModeBalanced,
        txPowerLevel: AdvertiseTxPower.advertiseTxPowerMedium,
        connectable: false,
        timeout: 0, // Advertise indefinitely
      );

      debugPrint('📡 Calling _blePeripheral.start()...');
      await _blePeripheral.start(
        advertiseData: advertiseData,
        advertiseSettings: advertiseSettings,
      );

      _isAdvertising = true;
      _currentUuid = uuid;
      debugPrint('✅ BLE advertising STARTED: $uuid');
      return true;
    } catch (e, stack) {
      debugPrint('❌ BLE advertising FAILED: $e');
      debugPrint('Stack: $stack');
      _isAdvertising = false;
      return false;
    }
  }

  /// Stop BLE advertising and clear state.
  Future<void> stopAdvertising() async {
    try {
      await _blePeripheral.stop();
      debugPrint('🛑 BLE advertising stopped');
    } catch (e) {
      debugPrint('⚠️ Error stopping BLE advertising: $e');
    } finally {
      _isAdvertising = false;
      _currentUuid = null;
    }
  }

  /// Check if BLE peripheral advertising is supported on this device.
  Future<bool> isAdvertisingSupported() async {
    try {
      return await _blePeripheral.isSupported;
    } catch (_) {
      return false;
    }
  }
}

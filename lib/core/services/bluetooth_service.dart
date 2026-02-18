import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:attendance_system/features/attendance/domain/ble_verification_result.dart';

/// Service to handle Bluetooth Low Energy (BLE) proximity verification.
///
/// Features:
/// - Scan for nearby BLE beacons
/// - Filter beacons by UUID
/// - Read and track RSSI (signal strength)
/// - Apply rolling average for RSSI smoothing
/// - Validate RSSI against proximity threshold
/// - Handle scan timeout
class BluetoothService {
  /// RSSI threshold for proximity verification (in dBm)
  /// -85 dBm allows detection within ~15 meters
  static const int rssiThreshold = -85;

  /// Scan timeout duration in seconds
  static const int scanTimeoutSeconds = 10;

  /// Number of RSSI readings to average
  static const int rssiSampleSize = 3;

  // ──────────────────── PERMISSION HANDLING ────────────────────

  /// Check if Bluetooth permission has been granted.
  Future<bool> hasBluetoothPermission() async {
    final bluetoothScan = await Permission.bluetoothScan.status;
    final bluetoothConnect = await Permission.bluetoothConnect.status;
    return bluetoothScan.isGranted && bluetoothConnect.isGranted;
  }

  /// Request Bluetooth permission from the user.
  ///
  /// Returns true if permissions were granted, false otherwise.
  Future<bool> requestBluetoothPermission() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    return statuses[Permission.bluetoothScan]!.isGranted &&
        statuses[Permission.bluetoothConnect]!.isGranted;
  }

  /// Check if Bluetooth adapter is turned on.
  Future<bool> isBluetoothEnabled() async {
    try {
      final adapterState = await FlutterBluePlus.adapterState.first;
      return adapterState == BluetoothAdapterState.on;
    } catch (e) {
      return false;
    }
  }

  /// Request user to turn on Bluetooth.
  Future<void> requestEnableBluetooth() async {
    try {
      await FlutterBluePlus.turnOn();
    } catch (e) {
      // User denied or platform doesn't support automatic enable
    }
  }

  // ──────────────────── BLE SCANNING ────────────────────

  /// Verify proximity to classroom beacon using BLE.
  ///
  /// This is the main entry point for BLE verification.
  ///
  /// Returns a [BleVerificationResult] with detailed information about the verification.
  Future<BleVerificationResult> verifyProximity({
    required String beaconUuid,
  }) async {
    // 1. Check if Bluetooth is enabled
    final bluetoothEnabled = await isBluetoothEnabled();
    if (!bluetoothEnabled) {
      return BleVerificationResult.failure(
        errorMessage: 'Bluetooth is disabled. Please enable Bluetooth.',
      );
    }

    // 2. Check permissions
    final hasPermission = await hasBluetoothPermission();
    if (!hasPermission) {
      final granted = await requestBluetoothPermission();
      if (!granted) {
        return BleVerificationResult.failure(
          errorMessage:
              'Bluetooth permission denied. Please grant permission in settings.',
        );
      }
    }

    // 3. Start scanning for beacons
    try {
      return await _scanForBeacon(beaconUuid);
    } catch (e) {
      return BleVerificationResult.failure(errorMessage: 'BLE scan failed: $e');
    }
  }

  /// Scan for the specified beacon and validate RSSI.
  Future<BleVerificationResult> _scanForBeacon(String targetUuid) async {
    final List<int> rssiReadings = [];

    // Create a completer for timeout handling
    final completer = Completer<BleVerificationResult>();

    // Set up timeout
    Timer.periodic(Duration(seconds: scanTimeoutSeconds), (timer) {
      timer.cancel();
      if (!completer.isCompleted) {
        completer.complete(
          BleVerificationResult.failure(
            errorMessage:
                'Beacon not detected within ${scanTimeoutSeconds}s timeout.',
          ),
        );
      }
    });
    // Listen to scan results
    StreamSubscription? scanSubscription;

    try {
      // Start scanning
      await FlutterBluePlus.startScan(
        timeout: Duration(seconds: scanTimeoutSeconds),
      );

      scanSubscription = FlutterBluePlus.scanResults.listen(
        (results) {
          for (ScanResult result in results) {
            // Check if this is our target beacon by device name or advertised services
            final deviceId = result.device.remoteId.str;
            final deviceName = result.device.platformName;

            // Match by UUID (you might need to adjust this based on your beacon configuration)
            // Some beacons advertise their UUID as device name, others as service UUID
            bool isTargetBeacon =
                deviceName.contains(targetUuid) ||
                deviceId.contains(targetUuid) ||
                result.advertisementData.serviceUuids.any(
                  (uuid) => uuid.toString().contains(targetUuid),
                );

            if (isTargetBeacon) {
              // Add to rolling average
              rssiReadings.add(result.rssi);
              if (rssiReadings.length > rssiSampleSize) {
                rssiReadings.removeAt(0); // Keep only last N readings
              }

              // Calculate average RSSI
              if (rssiReadings.isNotEmpty) {
                final avgRssi =
                    rssiReadings.reduce((a, b) => a + b) / rssiReadings.length;

                // Check if average RSSI meets threshold
                if (avgRssi >= rssiThreshold && !completer.isCompleted) {
                  completer.complete(
                    BleVerificationResult.success(
                      beaconUuid: targetUuid,
                      rssi: result.rssi,
                      rssiAverage: avgRssi,
                      threshold: rssiThreshold,
                    ),
                  );
                }
              }
            }
          }
        },
        onError: (error) {
          if (!completer.isCompleted) {
            completer.complete(
              BleVerificationResult.failure(errorMessage: 'Scan error: $error'),
            );
          }
        },
      );

      // Wait for either success or timeout
      return await completer.future;
    } finally {
      // Clean up
      await scanSubscription?.cancel();
      await FlutterBluePlus.stopScan();
    }
  }

  /// Quick check to see if BLE verification is possible.
  ///
  /// Returns an error message if not possible, null if OK.
  Future<String?> checkPrerequisites() async {
    if (!await isBluetoothEnabled()) {
      return 'Bluetooth is disabled';
    }
    if (!await hasBluetoothPermission()) {
      return 'Bluetooth permission not granted';
    }
    return null;
  }
}

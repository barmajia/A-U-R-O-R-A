import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPermissions {
  static const String _permissionsGrantedKey = 'permissions_granted';
  static bool _permissionsChecked = false;

  /// Request all required permissions on first app launch
  static Future<bool> requestPermissions() async {
    // Check if we already requested permissions before
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_permissionsGrantedKey) == true) {
      return true;
    }

    if (_permissionsChecked) {
      return true;
    }

    try {
      // Request camera permission
      var cameraStatus = await Permission.camera.status;
      if (!cameraStatus.isGranted) {
        cameraStatus = await Permission.camera.request();
      }

      // Request storage permission (for Android < 13)
      var storageStatus = await Permission.storage.status;
      if (!storageStatus.isGranted) {
        storageStatus = await Permission.storage.request();
      }

      // Request photos permission (for Android >= 13)
      var photosStatus = await Permission.photos.status;
      if (!photosStatus.isGranted) {
        photosStatus = await Permission.photos.request();
      }

      // Request location permission (already in your app)
      var locationStatus = await Permission.locationWhenInUse.status;
      if (!locationStatus.isGranted) {
        locationStatus = await Permission.locationWhenInUse.request();
      }

      _permissionsChecked = true;
      
      // Save that we've requested permissions
      await prefs.setBool(_permissionsGrantedKey, true);

      // Check if camera permission is granted (most critical)
      final cameraGranted = await Permission.camera.isGranted;

      debugPrint('Permissions Status:');
      debugPrint('  Camera: ${cameraStatus.name}');
      debugPrint('  Storage: ${storageStatus.name}');
      debugPrint('  Photos: ${photosStatus.name}');
      debugPrint('  Location: ${locationStatus.name}');

      return cameraGranted;
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      return false;
    }
  }

  /// Check if permissions are already granted
  static Future<Map<String, bool>> checkPermissions() async {
    return {
      'camera': await Permission.camera.isGranted,
      'storage': await Permission.storage.isGranted,
      'photos': await Permission.photos.isGranted,
      'location': await Permission.locationWhenInUse.isGranted,
    };
  }

  /// Open app settings if permissions are denied
  static Future<void> openAppSettings() async {
    await openAppSettings();
  }

  /// Show permission dialog if needed
  static Future<bool> showPermissionDialog(BuildContext context) async {
    final status = await checkPermissions();

    if (!status['camera']!) {
      final shouldRequest = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text('Camera Permission Required'),
          content: const Text(
            'We need camera access to take photos of your products. '
            'Please grant camera permission to continue.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Grant Permission'),
            ),
          ],
        ),
      );

      if (shouldRequest == true) {
        await requestPermissions();
        return await Permission.camera.isGranted;
      }
      return false;
    }

    return true;
  }
}

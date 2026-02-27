import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Service for ESP32 camera integration
class ESP32CameraService {
  static Box<Map>? _imageBox;
  static const String _imageBoxName = 'esp32_images';

  /// Initialize the image storage database
  static Future<void> initialize() async {
    _imageBox = await Hive.openBox<Map>(_imageBoxName);
  }

  /// Capture image from ESP32 camera
  ///
  /// Parameters:
  /// - cameraUrl: The ESP32 camera URL (e.g., http://192.168.206.36/capture)
  ///
  /// Returns the local file path of the captured image or null if failed
  static Future<String?> captureImage(String cameraUrl) async {
    try {
      print('📷 Capturing image from ESP32: $cameraUrl');

      // Make HTTP request to ESP32 camera
      final response = await http
          .get(Uri.parse(cameraUrl))
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw Exception(
                'Camera request timeout. Please check if ESP32 is online.',
              );
            },
          );

      if (response.statusCode == 200) {
        // Get app documents directory
        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filePath = '${directory.path}/esp32_$timestamp.jpg';

        // Save image to local storage
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        print('✅ Image saved: $filePath');

        // Save metadata to database
        await _saveImageMetadata(filePath, cameraUrl);

        return filePath;
      } else {
        throw Exception(
          'Failed to capture image. Status: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Error capturing image from ESP32: $e');
      return null;
    }
  }

  /// Save image metadata to database
  static Future<void> _saveImageMetadata(
    String filePath,
    String cameraUrl,
  ) async {
    final imageData = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'filePath': filePath,
      'cameraUrl': cameraUrl,
      'capturedAt': DateTime.now().toIso8601String(),
      'analyzed': false,
      'result': null,
    };

    await _imageBox?.put(imageData['id'], imageData);
  }

  /// Get all captured images from database
  static Future<List<Map<String, dynamic>>> getAllImages() async {
    if (_imageBox == null || _imageBox!.isEmpty) return [];

    final images = <Map<String, dynamic>>[];
    for (final imageMap in _imageBox!.values) {
      images.add({
        'id': imageMap['id'] as String,
        'filePath': imageMap['filePath'] as String,
        'cameraUrl': imageMap['cameraUrl'] as String,
        'capturedAt': DateTime.parse(imageMap['capturedAt'] as String),
        'analyzed': imageMap['analyzed'] as bool? ?? false,
        'result': imageMap['result'] as Map<String, dynamic>?,
      });
    }

    // Sort by captured date (newest first)
    images.sort(
      (a, b) =>
          (b['capturedAt'] as DateTime).compareTo(a['capturedAt'] as DateTime),
    );

    return images;
  }

  /// Get unanalyzed images
  static Future<List<Map<String, dynamic>>> getUnanalyzedImages() async {
    final allImages = await getAllImages();
    return allImages.where((img) => !(img['analyzed'] as bool)).toList();
  }

  /// Mark image as analyzed and save result
  static Future<void> markImageAnalyzed(
    String imageId,
    Map<String, dynamic> result,
  ) async {
    final imageData = _imageBox?.get(imageId);
    if (imageData != null) {
      imageData['analyzed'] = true;
      imageData['result'] = result;
      await _imageBox?.put(imageId, imageData);
    }
  }

  /// Delete an image from database and file system
  static Future<void> deleteImage(String imageId) async {
    final imageData = _imageBox?.get(imageId);
    if (imageData != null) {
      final filePath = imageData['filePath'] as String;
      final file = File(filePath);

      // Delete file if exists
      if (await file.exists()) {
        await file.delete();
      }

      // Delete from database
      await _imageBox?.delete(imageId);
    }
  }

  /// Delete all images
  static Future<void> deleteAllImages() async {
    final images = await getAllImages();

    for (final image in images) {
      await deleteImage(image['id'] as String);
    }
  }

  /// Check if URL is valid ESP32 camera URL
  static bool isValidCameraUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get image count
  static Future<int> getImageCount() async {
    return _imageBox?.length ?? 0;
  }

  /// Get analyzed image count
  static Future<int> getAnalyzedImageCount() async {
    final images = await getAllImages();
    return images.where((img) => img['analyzed'] as bool).length;
  }
}

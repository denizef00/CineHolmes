// camera_service.dart - Camera control and frame extraction service

import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class CameraService {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isProcessing = false;

  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;
  bool get isProcessing => _isProcessing;

  // Initialize camera
  Future<bool> initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        debugPrint('❌ No cameras available');
        return false;
      }

      // Use back camera by default
      final camera = _cameras!.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      _controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();
      _isInitialized = true;

      debugPrint('✅ Camera initialized successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Camera initialization error: $e');
      return false;
    }
  }

  // Start camera preview
  Future<void> startPreview() async {
    if (_controller != null && _isInitialized) {
      try {
        await _controller!.startImageStream((CameraImage image) {
          // This is for image stream mode if needed
        });
      } catch (e) {
        debugPrint('❌ Failed to start preview: $e');
      }
    }
  }

  // Stop camera preview
  Future<void> stopPreview() async {
    if (_controller != null && _isInitialized) {
      try {
        await _controller!.stopImageStream();
      } catch (e) {
        debugPrint('⚠️ Stop preview warning: $e');
      }
    }
  }

  // Capture a single frame from camera
  Future<Uint8List?> captureFrame() async {
    if (_controller == null || !_isInitialized || _isProcessing) {
      debugPrint('❌ Cannot capture: controller=${_controller != null}, initialized=$_isInitialized, processing=$_isProcessing');
      return null;
    }

    // ✅ Wait a bit to ensure camera is stable
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      _isProcessing = true;

      // Take picture
      debugPrint('📸 Taking picture...');
      final XFile picture = await _controller!.takePicture();
      debugPrint('✅ Picture taken, reading bytes...');
      
      final bytes = await picture.readAsBytes();
      debugPrint('✅ Bytes read: ${bytes.length}');

      // Compress and resize image for faster processing
      debugPrint('🔄 Decoding image...');
      final image = img.decodeImage(bytes);
      if (image == null) {
        debugPrint('❌ Failed to decode image');
        _isProcessing = false;
        return null;
      }

      debugPrint('🔄 Resizing image...');
      // Resize to max 1280px width (maintains aspect ratio)
      final resized = img.copyResize(
        image,
        width: image.width > 1280 ? 1280 : image.width,
      );

      debugPrint('🔄 Compressing to JPEG...');
      // Encode to JPEG with quality 85
      final compressed = Uint8List.fromList(
        img.encodeJpg(resized, quality: 85),
      );

      _isProcessing = false;
      debugPrint('✅ Frame ready: ${compressed.length} bytes (original: ${bytes.length})');
      return compressed;
    } catch (e) {
      debugPrint('❌ Frame capture error: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      _isProcessing = false;
      return null;
    }
  }

  // Switch between front and back camera
  Future<bool> switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) {
      return false;
    }

    try {
      final currentDirection = _controller?.description.lensDirection;
      final newCamera = _cameras!.firstWhere(
        (cam) => cam.lensDirection != currentDirection,
        orElse: () => _cameras!.first,
      );

      await dispose();

      _controller = CameraController(
        newCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();
      _isInitialized = true;

      debugPrint('✅ Camera switched');
      return true;
    } catch (e) {
      debugPrint('❌ Camera switch error: $e');
      return false;
    }
  }

  // Dispose camera resources
  Future<void> dispose() async {
    try {
      if (_controller != null) {
        if (_controller!.value.isStreamingImages) {
          await _controller!.stopImageStream();
        }
        await _controller!.dispose();
      }
      _controller = null;
      _isInitialized = false;
      _isProcessing = false;
      debugPrint('✅ Camera disposed');
    } catch (e) {
      debugPrint('⚠️ Camera dispose warning: $e');
    }
  }

  // Get camera aspect ratio
  double getAspectRatio() {
    if (_controller != null && _isInitialized) {
      return _controller!.value.aspectRatio;
    }
    return 16 / 9; // Default aspect ratio
  }

  // Check if camera has flash
  bool hasFlash() {
    return _controller?.description.lensDirection == CameraLensDirection.back;
  }

  // Toggle flash mode
  Future<void> toggleFlash() async {
    if (_controller == null || !_isInitialized) return;

    try {
      final currentMode = _controller!.value.flashMode;
      if (currentMode == FlashMode.off) {
        await _controller!.setFlashMode(FlashMode.torch);
      } else {
        await _controller!.setFlashMode(FlashMode.off);
      }
    } catch (e) {
      debugPrint('⚠️ Flash toggle warning: $e');
    }
  }
}
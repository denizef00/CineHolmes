// live_camera_detection_page.dart - Live camera detection screen

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/camera_service.dart';
import '../services/frame_analyzer.dart';
import '../services/gemini_service.dart';
import '../services/tmdb_service.dart';
import 'info_page.dart';

class LiveCameraDetectionPage extends StatefulWidget {
  const LiveCameraDetectionPage({super.key});

  @override
  State<LiveCameraDetectionPage> createState() =>
      _LiveCameraDetectionPageState();
}

class _LiveCameraDetectionPageState extends State<LiveCameraDetectionPage>
    with WidgetsBindingObserver {
  final CameraService _cameraService = CameraService();
  late final FrameAnalyzer _frameAnalyzer;
  late final TMDBService _tmdbService;
  late final GeminiService _geminiService;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isInitialized = false;
  bool _isDetecting = false;
  bool _isProcessingFrame = false;
  String _statusMessage = 'Initializing camera...';
  Timer? _captureTimer;
  Map<String, dynamic>? _detectedMovie;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _captureTimer?.cancel();
    _frameAnalyzer.stopAnalysis();
    _cameraService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isInitialized) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _stopDetection();
    } else if (state == AppLifecycleState.resumed) {
      _cameraService.initializeCamera().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _initializeServices() async {
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
      final tmdbApiKey = dotenv.env['TMDB_API_KEY'] ?? '';

      _geminiService = GeminiService(
        apiKey: apiKey,
        tmdbApiKey: tmdbApiKey,
      );
      _frameAnalyzer = FrameAnalyzer(geminiService: _geminiService);
      _tmdbService = TMDBService();

      final success = await _cameraService.initializeCamera();

      if (!mounted) return;

      setState(() {
        _isInitialized = success;
        _statusMessage = success
            ? 'Point camera at screen and tap Start'
            : 'Failed to initialize camera';
      });
    } catch (e) {
      debugPrint('❌ Service initialization error: $e');
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Initialization failed: $e';
      });
    }
  }

  void _startDetection() {
    if (!_isInitialized || _isDetecting) return;

    setState(() {
      _isDetecting = true;
      _statusMessage = 'Analyzing frames...';
      _detectedMovie = null;
    });

    _frameAnalyzer.startAnalysis();

    // 🆕 Capture frames every second (no interval check needed)
    _captureTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      // Don't capture if already processing or reached max
      if (_isProcessingFrame || _frameAnalyzer.totalFramesAnalyzed >= 7) {
        return;
      }

      // Capture frame immediately
      await _processFrame();

      // Update UI
      if (mounted && _isDetecting) {
        setState(() {
          _statusMessage = 'Analyzing frame ${_frameAnalyzer.totalFramesAnalyzed + 1}/7...';
        });
      }
    });
  }

  Future<void> _processFrame() async {
    if (!_isDetecting || _isProcessingFrame) return;

    setState(() => _isProcessingFrame = true);

    try {
      debugPrint('📸 Capturing frame ${_frameAnalyzer.totalFramesAnalyzed + 1}/5...');
      
      // Capture frame from camera
      final frameBytes = await _cameraService.captureFrame();
      if (frameBytes == null) {
        debugPrint('❌ Frame capture failed - frameBytes is null');
        setState(() => _isProcessingFrame = false);
        return;
      }

      debugPrint('✅ Frame captured: ${frameBytes.length} bytes');

      // Analyze frame with timeout
      final result = await _frameAnalyzer.analyzeFrame(frameBytes).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('⏱️ Frame analysis timeout (30 seconds)');
          return null;
        },
      );

      if (result != null) {
        debugPrint('🎯 Movie detected: ${result['title']}');
        
        // 🆕 Hemen UI'yı güncelle
        if (mounted) {
          setState(() {
            _statusMessage = 'Movie found! Loading...';
          });
        }
        
        // Confident detection achieved!
        await _handleDetectionResult(result);
        return; // 🆕 Hemen çık, daha fazla işlem yapma
      } else {
        debugPrint('ℹ️ No confident detection yet, continuing...');
        
        // Check if we've reached max frames without detection
        if (_frameAnalyzer.totalFramesAnalyzed >= 7) { // 🆕 5 → 7
          debugPrint('⚠️ Max frames reached (7), stopping detection');
          _stopDetection();
          
          if (mounted) {
            setState(() {
              _statusMessage = 'Could not detect movie. Try a different scene.';
            });
            
            // Show error dialog
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) _showErrorDialog();
            });
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Frame processing error: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessingFrame = false);
      }
    }
  }

  Future<void> _handleDetectionResult(Map<String, dynamic> result) async {
    _stopDetection();

    setState(() {
      _statusMessage = 'Movie found!';
    });

    try {
      // Search in TMDB
      final movieData = await _geminiService.searchInTMDB(
        result['title']?.toString() ?? '',
        result['year']?.toString() ?? '',
        result['type']?.toString() ?? 'movie',
      );

      if (movieData != null) {
        // Save to history
        await _saveToHistory(movieData);

        if (!mounted) return;

        // 🆕 Navigate directly to InfoPage (like gallery flow)
        Navigator.pop(context); // Close camera page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InfoPage(
              id: movieData['id'],
              title: movieData['title'],
              type: movieData['type'] ?? 'movie',
            ),
          ),
        );
      } else {
        if (!mounted) return;
        setState(() {
          _statusMessage = 'Movie not found';
        });
        // Show error and allow retry
        _showErrorDialog();
      }
    } catch (e) {
      debugPrint('❌ Detection result handling error: $e');
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Error occurred';
      });
      _showErrorDialog();
    }
  }

  void _stopDetection() {
    _captureTimer?.cancel();
    _frameAnalyzer.stopAnalysis();
    setState(() {
      _isDetecting = false;
      _isProcessingFrame = false;
    });
  }

  void _resetDetection() {
    _stopDetection();
    _frameAnalyzer.reset();
    setState(() {
      _detectedMovie = null;
      _statusMessage = 'Point camera at screen and tap Start';
    });
  }

  Future<void> _saveToHistory(Map<String, dynamic> movieInfo) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final movieId = movieInfo['id'];

      final existingDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('upload_history')
          .where('id', isEqualTo: movieId)
          .limit(1)
          .get();

      if (existingDoc.docs.isNotEmpty) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('upload_history')
            .doc(existingDoc.docs.first.id)
            .update({'timestamp': FieldValue.serverTimestamp()});
      } else {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('upload_history')
            .add({...movieInfo, 'timestamp': FieldValue.serverTimestamp()});
      }

      debugPrint('✅ Saved to history');
    } catch (e) {
      debugPrint('❌ History save error: $e');
    }
  }

  void _showErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('Could not detect movie', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'Please try again or use a different scene.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close camera page
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6A0DAD),
            ),
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _resetDetection(); // Try again
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Live Detection',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          if (_isInitialized && !_isDetecting)
            IconButton(
              icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
              onPressed: () async {
                await _cameraService.switchCamera();
                setState(() {});
              },
            ),
          if (_isInitialized && _cameraService.hasFlash())
            IconButton(
              icon: Icon(
                _cameraService.controller?.value.flashMode == FlashMode.torch
                    ? Icons.flash_on
                    : Icons.flash_off,
                color: Colors.white,
              ),
              onPressed: () async {
                await _cameraService.toggleFlash();
                setState(() {});
              },
            ),
        ],
      ),
      body: !_isInitialized
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF6A0DAD)),
                  const SizedBox(height: 24),
                  Text(
                    _statusMessage,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                // Camera Preview
                Positioned.fill(
                  child: _cameraService.controller != null
                      ? CameraPreview(_cameraService.controller!)
                      : Container(color: Colors.black),
                ),

                // Overlay with scanning guide
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ScannerOverlayPainter(
                      isDetecting: _isDetecting,
                    ),
                  ),
                ),

                // Status and Controls
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.8),
                        ],
                      ),
                    ),
                    child: Column(
                      children: [
                        // Status Message
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _statusMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Control Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (!_isDetecting && _detectedMovie == null) ...[
                              // Start Button
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6A0DAD),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 48,
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                onPressed: _startDetection,
                                child: const Row(
                                  children: [
                                    Icon(Icons.play_arrow, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text(
                                      'Start Detection',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (_isDetecting) ...[
                              // Stop Button
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 48,
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                onPressed: _stopDetection,
                                child: const Row(
                                  children: [
                                    Icon(Icons.stop, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text(
                                      'Stop',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// Custom painter for scanner overlay
class _ScannerOverlayPainter extends CustomPainter {
  final bool isDetecting;

  _ScannerOverlayPainter({
    required this.isDetecting,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // Semi-transparent black overlay
    final overlayPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    // Draw overlay
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), overlayPaint);

    // Scanning frame
    final frameRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.8,
      height: size.height * 0.5,
    );

    // Clear the center
    canvas.drawRect(
      frameRect,
      Paint()
        ..color = Colors.transparent
        ..blendMode = BlendMode.clear,
    );

    // Draw frame border
    paint.color = isDetecting ? const Color(0xFF6A0DAD) : Colors.white;
    canvas.drawRect(frameRect, paint);

    // Draw corner indicators
    final cornerLength = 30.0;
    paint.strokeWidth = 4.0;

    // Top-left
    canvas.drawLine(
      frameRect.topLeft,
      frameRect.topLeft + Offset(cornerLength, 0),
      paint,
    );
    canvas.drawLine(
      frameRect.topLeft,
      frameRect.topLeft + Offset(0, cornerLength),
      paint,
    );

    // Top-right
    canvas.drawLine(
      frameRect.topRight,
      frameRect.topRight + Offset(-cornerLength, 0),
      paint,
    );
    canvas.drawLine(
      frameRect.topRight,
      frameRect.topRight + Offset(0, cornerLength),
      paint,
    );

    // Bottom-left
    canvas.drawLine(
      frameRect.bottomLeft,
      frameRect.bottomLeft + Offset(cornerLength, 0),
      paint,
    );
    canvas.drawLine(
      frameRect.bottomLeft,
      frameRect.bottomLeft + Offset(0, -cornerLength),
      paint,
    );

    // Bottom-right
    canvas.drawLine(
      frameRect.bottomRight,
      frameRect.bottomRight + Offset(-cornerLength, 0),
      paint,
    );
    canvas.drawLine(
      frameRect.bottomRight,
      frameRect.bottomRight + Offset(0, -cornerLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ScannerOverlayPainter oldDelegate) {
    return isDetecting != oldDelegate.isDetecting;
  }
}
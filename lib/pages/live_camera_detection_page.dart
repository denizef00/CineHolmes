// live_camera_detection_page.dart - Live camera detection with batch analysis

import 'dart:async';
import 'dart:typed_data'; // ✅ Added for Uint8List
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/camera_service.dart';
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
  late final GeminiService _geminiService;
  late final TMDBService _tmdbService;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isInitialized = false;
  bool _isCapturing = false;
  bool _isAnalyzing = false;
  String _statusMessage = 'Initializing camera...';
  
  List<Map<String, dynamic>> _suggestions = [];
  int _capturedFrames = 0;
  final int _totalFramesNeeded = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isInitialized) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // Pause camera
    } else if (state == AppLifecycleState.resumed) {
      _cameraService.initializeCamera().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _initializeServices() async {
    try {
      debugPrint('🔧 Initializing services...');
      
      final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
      final tmdbApiKey = dotenv.env['TMDB_API_KEY'] ?? '';

      debugPrint('🔑 API Keys status:');
      debugPrint('   Gemini: ${apiKey.isEmpty ? "❌ EMPTY" : "✅ Loaded (${apiKey.length} chars)"}');
      debugPrint('   TMDB: ${tmdbApiKey.isEmpty ? "❌ EMPTY" : "✅ Loaded (${tmdbApiKey.length} chars)"}');

      if (apiKey.isEmpty) {
        throw Exception('Gemini API key is empty! Check .env file');
      }

      _geminiService = GeminiService(
        apiKey: apiKey,
        tmdbApiKey: tmdbApiKey,
      );
      _tmdbService = TMDBService();

      debugPrint('📷 Initializing camera...');
      final success = await _cameraService.initializeCamera();

      if (!mounted) return;

      setState(() {
        _isInitialized = success;
        _statusMessage = success
            ? 'Point camera at screen and tap Scan'
            : 'Failed to initialize camera';
      });
      
      if (success) {
        debugPrint('✅ All services initialized successfully');
      }
    } catch (e) {
      debugPrint('❌ Service initialization error: $e');
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Initialization failed: $e';
      });
    }
  }

  Future<void> _startScanning() async {
    if (!_isInitialized || _isCapturing) return;

    // ✅ Kamera kontrolü
    if (_cameraService.controller == null || 
        !_cameraService.controller!.value.isInitialized) {
      _showErrorDialog('Camera not ready. Please try again.');
      return;
    }

    setState(() {
      _isCapturing = true;
      _capturedFrames = 0;
      _suggestions = [];
      _statusMessage = 'Capturing frames...';
    });

    // 🎯 YENİ YÖNTEM: Önce 3 frame'i topla, sonra hepsini birden yolla
    final List<Uint8List> capturedFrames = [];
    await Future.delayed(const Duration(seconds: 1));
    try {
      // ADIM 1: 3 frame yakala (upload YOK henüz!)
      debugPrint('📸 Step 1: Capturing 3 frames...');
      
      for (int i = 0; i < _totalFramesNeeded; i++) {
        setState(() {
          _capturedFrames = i + 1;
          _statusMessage = 'Capturing frame ${i + 1}/$_totalFramesNeeded...';
        });

        // Kamera kontrolü
        if (_cameraService.controller == null || 
            !_cameraService.controller!.value.isInitialized) {
          throw Exception('Camera disconnected');
        }

        final frameBytes = await _cameraService.captureFrame();
        if (frameBytes == null) {
          debugPrint('❌ Frame ${i + 1} capture returned null');
          throw Exception('Failed to capture frame ${i + 1}');
        }

        capturedFrames.add(frameBytes);
        debugPrint('✅ Frame ${i + 1} captured: ${frameBytes.length} bytes');

        // 1 saniye bekle (son frame hariç)
        if (i < _totalFramesNeeded - 1) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }

      debugPrint('✅ All 3 frames captured!');

      // ADIM 2: Şimdi 3 frame'i birden upload et
      setState(() {
        _isCapturing = false;
        _isAnalyzing = true;
        _statusMessage = 'Uploading frames to AI...';
      });

      debugPrint('⬆️ Step 2: Uploading all frames together...');
      final List<String> frameFiles = [];

      for (int i = 0; i < capturedFrames.length; i++) {
        debugPrint('⬆️ Uploading frame ${i + 1}/${capturedFrames.length}...');
        
        final fileName = 'frame_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final fileNameForModel = await _geminiService.uploadVideoToGemini(
          capturedFrames[i],
          fileName,
          'image/jpeg',
        );

        if (fileNameForModel == null) {
          debugPrint('❌ Frame ${i + 1} upload failed');
          throw Exception('Failed to upload frame ${i + 1}');
        }

        // Wait for processing
        debugPrint('⏳ Waiting for frame ${i + 1} processing...');
        final isReady = await _geminiService.waitForFileProcessing(fileNameForModel);
        if (!isReady) {
          debugPrint('❌ Frame ${i + 1} processing timeout');
          throw Exception('Frame ${i + 1} processing failed');
        }

        frameFiles.add(fileNameForModel);
        debugPrint('✅ Frame ${i + 1} ready: $fileNameForModel');
      }

      debugPrint('✅ All frames uploaded and ready!');

      // ADIM 3: Toplu analiz
      await _analyzeFramesBatch(frameFiles);

    } catch (e) {
      debugPrint('❌ Frame capture/upload error: $e');
      
      if (mounted) {
        setState(() {
          _isCapturing = false;
          _isAnalyzing = false;
          _statusMessage = 'Error occurred';
        });
        _showErrorDialog('Error: ${e.toString()}\n\nPlease try again.');
      }
    }
  }

  Future<void> _analyzeFramesBatch(List<String> frameFiles) async {
    setState(() {
      _isCapturing = false;
      _isAnalyzing = true;
      _statusMessage = 'Analyzing frames with AI...';
    });

    try {
      // Call Gemini with all 3 frames and ask for 4 suggestions
      final suggestions = await _geminiService.analyzeMultipleFramesForSuggestions(frameFiles);

      // Clean up uploaded files
      for (final file in frameFiles) {
        await _geminiService.deleteFileFromGemini(file);
      }

      if (suggestions == null || suggestions.isEmpty) {
        throw Exception('No movies detected');
      }

      debugPrint('🎯 Received ${suggestions.length} suggestions from Gemini');

      // Search each suggestion in TMDB and save to history
      final List<Map<String, dynamic>> validSuggestions = [];
      
      for (final suggestion in suggestions.take(4)) {  // Max 4
        final tmdbData = await _geminiService.searchInTMDB(
          suggestion['title'] ?? '',
          suggestion['year'] ?? '',
          suggestion['type'] ?? 'movie',
        );

        if (tmdbData != null) {
          validSuggestions.add(tmdbData);
          // Save to history
          await _saveToHistory(tmdbData);
        }
      }

      if (!mounted) return;

      if (validSuggestions.isEmpty) {
        throw Exception('Could not find movies in database');
      }

      setState(() {
        _suggestions = validSuggestions;
        _isAnalyzing = false;
        _statusMessage = 'Found ${validSuggestions.length} suggestions!';
      });

    } catch (e) {
      debugPrint('❌ Analysis error: $e');
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _statusMessage = 'Analysis failed';
        });
        _showErrorDialog('Could not identify movies. Try a different scene.');
      }
    }
  }

  Future<void> _saveToHistory(Map<String, dynamic> movieInfo) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Check if already exists
      final existingDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('upload_history')
          .where('id', isEqualTo: movieInfo['id'])
          .limit(1)
          .get();

      if (existingDoc.docs.isNotEmpty) {
        // Update timestamp
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('upload_history')
            .doc(existingDoc.docs.first.id)
            .update({'timestamp': FieldValue.serverTimestamp()});
      } else {
        // Add new
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('upload_history')
            .add({
          ...movieInfo,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('❌ Error saving to history: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('Detection Failed', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70),
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
              _startScanning(); // Try again
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
          'Camera Detection',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          if (_isInitialized && !_isCapturing && !_isAnalyzing)
            IconButton(
              icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
              onPressed: () async {
                await _cameraService.switchCamera();
                setState(() {});
              },
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (!_isInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF6A0DAD)),
            const SizedBox(height: 16),
            Text(
              _statusMessage,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_suggestions.isNotEmpty) {
      // Show grid of suggestions
      return _buildSuggestionsGrid();
    }

    // Show camera preview
    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera Preview
        if (_cameraService.controller != null &&
            _cameraService.controller!.value.isInitialized)
          CameraPreview(_cameraService.controller!),

        // Scanning overlay
        if (_isCapturing || _isAnalyzing)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF6A0DAD)),
                  const SizedBox(height: 24),
                  if (_isCapturing)
                    Text(
                      'Capturing frame $_capturedFrames/$_totalFramesNeeded',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (_isAnalyzing)
                    const Text(
                      'Analyzing with AI...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ),

        // Bottom controls
        if (!_isCapturing && !_isAnalyzing)
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
                  Text(
                    _statusMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
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
                    onPressed: _startScanning,
                    icon: const Icon(Icons.camera_alt, color: Colors.white),
                    label: const Text(
                      'Scan Movie',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSuggestionsGrid() {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.black,
          child: Column(
            children: [
              const Text(
                'Movie Suggestions',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Found ${_suggestions.length} matches',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),

        // Grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.7,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _suggestions.length,
            itemBuilder: (context, index) {
              final movie = _suggestions[index];
              return _buildMovieCard(movie);
            },
          ),
        ),

        // Scan Again Button
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.black,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6A0DAD),
              padding: const EdgeInsets.symmetric(vertical: 16),
              minimumSize: const Size(double.infinity, 48),
            ),
            onPressed: () {
              setState(() {
                _suggestions = [];
                _statusMessage = 'Point camera at screen and tap Scan';
              });
            },
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: const Text(
              'Scan Again',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMovieCard(Map<String, dynamic> movie) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InfoPage(
              id: movie['id'],
              title: movie['title'],
              type: movie['type'] ?? 'movie',
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  color: Colors.grey.shade900,
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: movie['poster'] != null &&
                          movie['poster'].toString().isNotEmpty
                      ? Image.network(
                          movie['poster'],
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(
                              Icons.movie,
                              color: Colors.white24,
                              size: 48,
                            ),
                          ),
                        )
                      : const Center(
                          child: Icon(
                            Icons.movie,
                            color: Colors.white24,
                            size: 48,
                          ),
                        ),
                ),
              ),
            ),

            // Info
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movie['title'] ?? 'Unknown',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (movie['year'] != null &&
                          movie['year'].toString().isNotEmpty)
                        Text(
                          movie['year'].toString(),
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      if (movie['rating'] != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 14,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                movie['rating'].toString(),
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
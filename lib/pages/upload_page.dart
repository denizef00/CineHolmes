// upload_page.dart - Main upload page with 4 suggestions grid

import 'dart:async';
import 'dart:io'; // ✅ For Platform check
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart'; // ✅ Re-added
import 'package:device_info_plus/device_info_plus.dart'; // ✅ For Android version check

import '../services/tmdb_service.dart';
import '../services/gemini_service.dart';
import 'info_page.dart';
import 'history_drawer.dart';
import 'profile_drawer.dart';
import 'live_camera_detection_page.dart';

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage>
    with SingleTickerProviderStateMixin {
  final picker = ImagePicker();
  late final TMDBService tmdbService;
  late final GeminiService geminiService;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String status = "No video selected yet.";
  List<Map<String, dynamic>> _suggestions = [];
  List<Map<String, dynamic>> history = [];
  bool isPicking = false;
  bool _isAnalyzing = false;
  bool _isLoadingHistory = true;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  String get apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  String get tmdbApiKey => dotenv.env['TMDB_API_KEY'] ?? '';

  @override
  void initState() {
    super.initState();
    tmdbService = TMDBService();
    geminiService = GeminiService(apiKey: apiKey, tmdbApiKey: tmdbApiKey);
    _loadUserHistory();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadUserHistory() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => _isLoadingHistory = false);
      return;
    }

    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('upload_history')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();

      setState(() {
        history = querySnapshot.docs
            .map((doc) => {...doc.data(), 'docId': doc.id})
            .toList();
        _isLoadingHistory = false;
      });
    } catch (e) {
      debugPrint('❌ History Loading Error: $e');
      setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _saveToUserHistory(Map<String, dynamic> movieInfo) async {
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
        final docId = existingDoc.docs.first.id;

        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('upload_history')
            .doc(docId)
            .update({'timestamp': FieldValue.serverTimestamp()});

        setState(() {
          final oldIndex = history.indexWhere((m) => m['id'] == movieId);
          if (oldIndex != -1) {
            final movie = history.removeAt(oldIndex);
            history.insert(0, {...movie, 'docId': docId});
          }
        });

        debugPrint('✅ Film zaten history\'de, timestamp güncellendi');
        return;
      }

      final docRef = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('upload_history')
          .add({...movieInfo, 'timestamp': FieldValue.serverTimestamp()});

      setState(() {
        history.insert(0, {...movieInfo, 'docId': docRef.id});
        if (history.length > 20) {
          history = history.sublist(0, 20);
        }
      });

      debugPrint('✅ Yeni film history\'ye eklendi');
    } catch (e) {
      debugPrint('❌ History Save Error: $e');
    }
  }

  // ✅ PROPER PERMISSION REQUEST - Works for both Android & iOS
  Future<bool> _requestStoragePermission() async {
    try {
      // Platform-specific permission handling
      PermissionStatus status;
      
      if (Platform.isAndroid) {
        // Android 13+ (API 33+) uses different permissions
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt >= 33) {
          // Android 13+: Request videos permission
          status = await Permission.videos.status;
          if (!status.isGranted) {
            status = await Permission.videos.request();
          }
        } else {
          // Android 12 and below: Request storage permission
          status = await Permission.storage.status;
          if (!status.isGranted) {
            status = await Permission.storage.request();
          }
        }
      } else {
        // iOS: Request photos permission
        status = await Permission.photos.status;
        if (!status.isGranted) {
          status = await Permission.photos.request();
        }
      }

      // Check result
      if (status.isGranted) {
        return true;
      }

      // If permanently denied, show settings dialog
      if (status.isPermanentlyDenied) {
        if (mounted) {
          final goToSettings = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1C1C1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Permission Required',
                style: TextStyle(color: Colors.white),
              ),
              content: const Text(
                'CineHolmes needs access to your gallery to select videos. Please grant permission in Settings.',
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6A0DAD),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );

          if (goToSettings == true) {
            await openAppSettings();
          }
        }
        return false;
      }

      // Permission denied (not permanently)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gallery permission is required to select videos'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return false;

    } catch (e) {
      debugPrint('❌ Permission error: $e');
      return false;
    }
  }

  // ✅ Video picking with permission check
  Future<void> _pickVideo() async {
    if (isPicking || _isAnalyzing) return;

    // ✅ Request permission first
    final hasPermission = await _requestStoragePermission();
    if (!hasPermission) {
      return;
    }

    setState(() {
      isPicking = true;
      status = "Selecting video...";
      _suggestions = [];
    });

    try {
      final XFile? pickedFile = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 20),
      );

      if (pickedFile == null) {
        setState(() {
          status = "No video selected.";
          isPicking = false;
        });
        return;
      }

      setState(() {
        status = "Uploading to Gemini...";
        _isAnalyzing = true;
      });

      final videoBytes = await pickedFile.readAsBytes();
      final mimeType = geminiService.getMimeType(pickedFile.name);

      final fileNameForModel = await geminiService.uploadVideoToGemini(
        videoBytes,
        pickedFile.name,
        mimeType,
      );

      if (fileNameForModel == null) {
        if (mounted) {
          setState(() {
            status = "❌ Upload failed. Please try again.";
            _isAnalyzing = false;
            isPicking = false;
          });
        }
        return;
      }

      setState(() => status = "Processing video...");

      final isReady = await geminiService.waitForFileProcessing(
        fileNameForModel,
      );
      if (!isReady) {
        await geminiService.deleteFileFromGemini(fileNameForModel);
        if (mounted) {
          setState(() {
            status = "❌ Processing failed. Please try again.";
            _isAnalyzing = false;
            isPicking = false;
          });
        }
        return;
      }

      setState(() => status = "Analyzing with AI...");

      final suggestions = await geminiService.analyzeVideoForSuggestions(
        fileNameForModel,
        mimeType,
      );
      
      await geminiService.deleteFileFromGemini(fileNameForModel);

      if (suggestions == null || suggestions.isEmpty) {
        if (mounted) {
          setState(() {
            status = "❌ Could not identify movie. Try again.";
            _isAnalyzing = false;
            isPicking = false;
          });
        }
        return;
      }

      setState(() => status = "Searching in database...");

      final List<Map<String, dynamic>> validSuggestions = [];
      
      for (final suggestion in suggestions.take(4)) {
        final tmdbResult = await geminiService.searchInTMDB(
          suggestion['title'] ?? '',
          suggestion['year'] ?? '',
          suggestion['type'] ?? 'movie',
        );

        if (tmdbResult != null) {
          validSuggestions.add(tmdbResult);
          await _saveToUserHistory(tmdbResult);
        }
      }

      if (mounted) {
        if (validSuggestions.isNotEmpty) {
          setState(() {
            _suggestions = validSuggestions;
            status = "✅ Found ${validSuggestions.length} suggestions!";
            _isAnalyzing = false;
            isPicking = false;
          });
        } else {
          setState(() {
            status = "❌ Movies not found in database.";
            _isAnalyzing = false;
            isPicking = false;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Video processing error: $e');
      if (mounted) {
        setState(() {
          status = "❌ Error: ${e.toString()}";
          _isAnalyzing = false;
          isPicking = false;
        });
      }
    }
  }

  void _showDetectionMethodDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Choose Detection Method',
          style: TextStyle(color: Colors.white, fontSize: 20),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () {
                Navigator.pop(context);
                _pickVideo();
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF6A0DAD).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF6A0DAD), width: 2),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6A0DAD),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.video_library,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gallery',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Select from videos',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () {
                Navigator.pop(context);
                _openLiveCameraDetection();
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF6A0DAD).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF6A0DAD), width: 2),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6A0DAD),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Live Camera',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Point at screen',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openLiveCameraDetection() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LiveCameraDetectionPage()),
    ).then((_) {
      _loadUserHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text(
          'CineHolmes',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.person, color: Colors.white),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      drawer: const HistoryDrawer(),
      endDrawer: const ProfileDrawer(),
      body: _buildMainContent(),
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),

          Center(
            child: Text(
              status,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
          ),

          const SizedBox(height: 60),

          if (_suggestions.isNotEmpty) ...[
            _buildSuggestionsGrid(),
          ] else if (!_isAnalyzing) ...[
            Center(
              child: ScaleTransition(
                scale: _pulseAnimation,
                child: GestureDetector(
                  onTap: _showDetectionMethodDialog,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6A0DAD), Color(0xFF9D4EDD)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6A0DAD).withOpacity(0.5),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.videocam,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'Tap to identify a movie',
                style: TextStyle(fontSize: 16, color: Colors.white60),
              ),
            ),
          ],

          if (_isAnalyzing) ...[
            const Center(
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6A0DAD)),
              ),
            ),
            const SizedBox(height: 24),
            const Center(
              child: Text(
                'Analyzing...',
                style: TextStyle(fontSize: 16, color: Colors.white60),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSuggestionsGrid() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
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

        const SizedBox(height: 16),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.7,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _suggestions.length,
          itemBuilder: (context, index) {
            final movie = _suggestions[index];
            return _buildMovieCard(movie);
          },
        ),

        const SizedBox(height: 24),

        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6A0DAD),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () {
            setState(() {
              _suggestions = [];
              status = "Ready to identify movies and TV shows";
            });
          },
          icon: const Icon(Icons.refresh, color: Colors.white),
          label: const Text(
            'New Search',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
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
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
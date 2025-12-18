// upload_page.dart - Main upload page with camera detection (Updated)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/tmdb_service.dart';
import '../services/gemini_service.dart';
import 'info_page.dart';
import 'history_drawer.dart';
import 'profile_drawer.dart';
import 'live_camera_detection_page.dart'; // 🆕 ADDED

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
  Map<String, dynamic>? movieData;
  List<Map<String, dynamic>> history = [];
  bool isPicking = false;
  bool _isAnalyzing = false;
  bool _isLoadingHistory = true;

  // Animation controller for pulse effect
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  String get apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  String get tmdbApiKey => dotenv.env['TMDB_API_KEY'] ?? '';

  @override
  void initState() {
    super.initState();
    tmdbService = TMDBService();
    geminiService = GeminiService(
      apiKey: apiKey,
      tmdbApiKey: tmdbApiKey,
    );
    _loadUserHistory();

    // Initialize pulse animation
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

  // ---------- FIRESTORE HISTORY ----------

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

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${movieInfo['title']} moved to top of history'),
              duration: const Duration(seconds: 2),
              backgroundColor: const Color(0xFF6A0DAD),
            ),
          );
        }

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

  Future<void> _deleteFromHistory(int index) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final movie = history[index];
    final docId = movie['docId'];
    if (docId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('upload_history')
          .doc(docId)
          .delete();

      setState(() {
        history.removeAt(index);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${movie['title']} deleted from history'),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF6A0DAD),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ History silme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not delete. Please try again.'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showDeleteConfirmation(int index) async {
    final movie = history[index];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete from history?',
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        content: Text(
          'Remove "${movie['title']}" from your history?',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteFromHistory(index);
    }
  }

  // ---------- VIDEO UPLOAD & ANALYSIS ----------

  Future<void> _pickVideo() async {
    if (isPicking || _isAnalyzing) return;

    setState(() {
      isPicking = true;
      status = "Selecting video...";
      movieData = null;
    });

    try {
      final XFile? pickedFile = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 20), // 🆕 20 saniye limit
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

      final isReady = await geminiService.waitForFileProcessing(fileNameForModel);
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

      final result = await geminiService.analyzeVideo(fileNameForModel, mimeType);
      await geminiService.deleteFileFromGemini(fileNameForModel);

      if (result == null) {
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

      final tmdbResult = await geminiService.searchInTMDB(
        result['title']!,
        result['year']!,
        result['type']!,
      );

      if (tmdbResult != null) {
        await _saveToUserHistory(tmdbResult);
        if (mounted) {
          setState(() {
            movieData = tmdbResult;
            status = "✅ Movie identified!";
            _isAnalyzing = false;
            isPicking = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            status = "❌ Movie not found in database.";
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

  // 🆕 SHOW DETECTION METHOD SELECTION
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
            // Gallery Option
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
                  border: Border.all(
                    color: const Color(0xFF6A0DAD),
                    width: 2,
                  ),
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
            // Live Camera Option
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
                  border: Border.all(
                    color: const Color(0xFF6A0DAD),
                    width: 2,
                  ),
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

  // 🆕 OPEN LIVE CAMERA DETECTION
  void _openLiveCameraDetection() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LiveCameraDetectionPage(),
      ),
    ).then((_) {
      // Refresh history when returning from camera detection
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
        children: [
          const SizedBox(height: 40),

          // Status Text
          Text(
            status,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),

          const SizedBox(height: 60),

          // 🆕 UPDATED: Main button now shows selection dialog
          if (!_isAnalyzing && movieData == null) ...[
            ScaleTransition(
              scale: _pulseAnimation,
              child: GestureDetector(
                onTap: _showDetectionMethodDialog, // 🆕 Changed to dialog
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
                    Icons.videocam, // ✅ Original icon
                    size: 80,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tap to identify a movie',
              style: TextStyle(fontSize: 16, color: Colors.white60),
            ),
          ],

          // Analyzing Indicator
          if (_isAnalyzing) ...[
            const CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6A0DAD)),
            ),
            const SizedBox(height: 24),
            const Text(
              'Analyzing...',
              style: TextStyle(fontSize: 16, color: Colors.white60),
            ),
          ],

          // Movie Result Card
          if (movieData != null) ...[
            Container(
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Poster
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child:
                        movieData!['poster'] != null &&
                            movieData!['poster'].toString().isNotEmpty
                        ? Image.network(
                            movieData!['poster'],
                            height: 300,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 300,
                              color: Colors.grey.shade800,
                              child: const Icon(
                                Icons.broken_image,
                                color: Colors.white54,
                                size: 64,
                              ),
                            ),
                          )
                        : Container(
                            height: 300,
                            color: Colors.grey.shade800,
                            child: const Icon(
                              Icons.movie,
                              color: Colors.white54,
                              size: 64,
                            ),
                          ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  Text(
                    movieData!['title'] ?? 'Unknown',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Year & Rating
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        movieData!['year']?.toString() ?? '',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white60,
                        ),
                      ),
                      if (movieData!['rating'] != null) ...[
                        const SizedBox(width: 12),
                        const Icon(Icons.star, color: Colors.amber, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          movieData!['rating'].toString(),
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6A0DAD),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => InfoPage(
                                  id: movieData!['id'],
                                  title: movieData!['title'],
                                  type: movieData!['type'] ?? 'movie',
                                ),
                              ),
                            );
                          },
                          child: const Text(
                            'View Details',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.1),
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 20,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            movieData = null;
                            status = "Ready to identify movies and TV shows";
                          });
                        },
                        child: const Text(
                          'New Search',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
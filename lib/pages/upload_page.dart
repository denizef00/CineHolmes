// upload_page.dart - Main upload page

import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/tmdb_service.dart';
import 'info_page.dart';
import 'history_drawer.dart';
import 'profile_drawer.dart';

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage>
    with SingleTickerProviderStateMixin {
  // --- Dependencies ---
  final picker = ImagePicker();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final TMDBService tmdbService;

  String get apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  // --- UI State ---
  String status = "Ready to identify movies and TV shows";
  Map<String, dynamic>? movieData;

  bool isPicking = false;
  bool _isAnalyzing = false;

  int _runId = 0;

  // Pulse animation for the camera button
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  static const int _maxVideoMB = 100;

  static const String _prompt = '''
Identify this movie or TV series.
Respond in this exact format:
Title|Year|Type

Where:
- Title: The original English title
- Year: Release year (4 digits, approximate if unsure)
- Type: Either "movie" or "tv"

Examples:
"Inception|2010|movie"
"Breaking Bad|2008|tv"
"The Matrix|1999|movie"

Return only that single line.''';

  @override
  void initState() {
    super.initState();
    tmdbService = TMDBService();

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

      if (!mounted) return;

      if (existingDoc.docs.isNotEmpty) {
        final docId = existingDoc.docs.first.id;

        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('upload_history')
            .doc(docId)
            .update({'timestamp': FieldValue.serverTimestamp()});

        debugPrint('✅ Film already in history, timestamp updated');
        return;
      }

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('upload_history')
          .add({...movieInfo, 'timestamp': FieldValue.serverTimestamp()});

      debugPrint('✅ New film added to history');
    } catch (e) {
      debugPrint('❌ History Save Error: $e');
    }
  }

  // ----------------------------
  // VIDEO PICKING & ANALYSIS
  // ----------------------------

  Future<void> _pickAndAnalyzeVideo() async {
    if (isPicking || _isAnalyzing) return;

    setState(() {
      isPicking = true;
      status = "Opening gallery...";
      movieData = null;
    });

    try {
      final XFile? pickedFile = await picker.pickVideo(
        source: ImageSource.gallery,
      );

      if (pickedFile == null) {
        if (!mounted) return;
        setState(() {
          status = "No video selected.";
          isPicking = false;
        });
        return;
      }

      if (!mounted) return;

      setState(() {
        status = "Preparing video...";
      });

      final int currentRun = ++_runId;

      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        if (currentRun != _runId || !mounted) return;

        final sizeInMB = bytes.length / (1024 * 1024);
        if (sizeInMB > _maxVideoMB) {
          setState(() {
            status = "Video too large (max ${_maxVideoMB}MB).";
            isPicking = false;
          });
          return;
        }

        await _analyzeVideoFromBytes(
          bytes: bytes,
          filename: pickedFile.name,
          currentRun: currentRun,
        );
      } else {
        final file = File(pickedFile.path);
        final stat = await file.stat();
        final sizeInMB = stat.size / (1024 * 1024);

        if (sizeInMB > _maxVideoMB) {
          if (currentRun != _runId || !mounted) return;
          setState(() {
            status = "Video too large (max ${_maxVideoMB}MB).";
            isPicking = false;
          });
          return;
        }

        if (currentRun != _runId || !mounted) return;
        await _analyzeVideoFromFile(file: file, currentRun: currentRun);
      }
    } catch (e) {
      debugPrint('❌ Pick Error: $e');
      if (!mounted) return;
      setState(() {
        status = "Error: $e";
        isPicking = false;
      });
    }
  }

  Future<void> _analyzeVideoFromBytes({
    required Uint8List bytes,
    required String filename,
    required int currentRun,
  }) async {
    if (currentRun != _runId || !mounted) return;

    setState(() {
      _isAnalyzing = true;
      isPicking = false;
      status = "Analyzing with Gemini AI...";
    });

    try {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=$apiKey',
      );

      final base64Video = base64Encode(bytes);

      final requestBody = {
        "contents": [
          {
            "parts": [
              {"text": _prompt},
              {
                "inline_data": {"mime_type": "video/mp4", "data": base64Video},
              },
            ],
          },
        ],
        "generationConfig": {
          "temperature": 0.4,
          "topK": 32,
          "topP": 1,
          "maxOutputTokens": 512,
        },
      };

      if (currentRun != _runId || !mounted) return;

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (currentRun != _runId || !mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];

        if (text != null) {
          await _processGeminiResponse(text.toString().trim(), currentRun);
        } else {
          setState(() {
            status = "No response from Gemini.";
            _isAnalyzing = false;
          });
        }
      } else {
        setState(() {
          status = "Gemini API error: ${response.statusCode}";
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Analysis Error: $e');
      if (currentRun != _runId || !mounted) return;
      setState(() {
        status = "Error: $e";
        _isAnalyzing = false;
      });
    }
  }

  Future<void> _analyzeVideoFromFile({
    required File file,
    required int currentRun,
  }) async {
    if (currentRun != _runId || !mounted) return;

    setState(() {
      _isAnalyzing = true;
      isPicking = false;
      status = "Analyzing with Gemini AI...";
    });

    try {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=$apiKey',
      );

      final request = http.MultipartRequest('POST', uri);

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          contentType: MediaType('video', 'mp4'),
        ),
      );

      final jsonPayload = {
        "contents": [
          {
            "parts": [
              {"text": _prompt},
            ],
          },
        ],
        "generationConfig": {
          "temperature": 0.4,
          "topK": 32,
          "topP": 1,
          "maxOutputTokens": 512,
        },
      };

      request.fields['request'] = jsonEncode(jsonPayload);

      if (currentRun != _runId || !mounted) return;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (currentRun != _runId || !mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];

        if (text != null) {
          await _processGeminiResponse(text.toString().trim(), currentRun);
        } else {
          setState(() {
            status = "No response from Gemini.";
            _isAnalyzing = false;
          });
        }
      } else {
        setState(() {
          status = "Gemini API error: ${response.statusCode}";
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Analysis Error: $e');
      if (currentRun != _runId || !mounted) return;
      setState(() {
        status = "Error: $e";
        _isAnalyzing = false;
      });
    }
  }

  Future<void> _processGeminiResponse(String text, int currentRun) async {
    if (currentRun != _runId || !mounted) return;

    debugPrint('🤖 Gemini Response: $text');

    setState(() {
      status = "Searching TMDB...";
    });

    final parts = text.split('|');
    if (parts.length < 3) {
      setState(() {
        status = "Could not identify the movie.";
        _isAnalyzing = false;
      });
      return;
    }

    final title = parts[0].trim();
    final year = parts[1].trim();
    final type = parts[2].trim().toLowerCase();

    if (currentRun != _runId || !mounted) return;

    try {
      final allResults = await tmdbService.searchMulti(title, limit: 20);

      if (currentRun != _runId || !mounted) return;

      final filtered = allResults.where((item) {
        final itemType = (item['type'] ?? '').toString().toLowerCase();
        final itemYear = (item['year'] ?? '').toString();

        if (itemType != type) return false;

        if (itemYear.isNotEmpty && itemYear == year) return true;

        if (itemYear.isNotEmpty) {
          final yearInt = int.tryParse(year);
          final itemYearInt = int.tryParse(itemYear);
          if (yearInt != null && itemYearInt != null) {
            return (yearInt - itemYearInt).abs() <= 2;
          }
        }

        return true;
      }).toList();

      if (currentRun != _runId || !mounted) return;

      if (filtered.isNotEmpty) {
        final movie = filtered.first;
        setState(() {
          movieData = movie;
          status = "Movie identified!";
          _isAnalyzing = false;
        });

        await _saveToUserHistory(movie);
      } else {
        setState(() {
          status = "Movie not found on TMDB.";
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      debugPrint('❌ TMDB Error: $e');
      if (currentRun != _runId || !mounted) return;
      setState(() {
        status = "TMDB search error.";
        _isAnalyzing = false;
      });
    }
  }

  // ----------------------------
  // UI BUILDERS
  // ----------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      endDrawer: const ProfileDrawer(),
      drawer: const HistoryDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            _buildTopBar(),

            // Main Content Area
            Expanded(child: _buildMainContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.1), width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // History Icon (Left)
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.history, color: Colors.white, size: 28),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            ),
          ),

          // Logo
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF6A0DAD), Color(0xFF9D4EDD)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: const Text(
              'CineHolmes',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w400,
                fontFamily: 'Pacifico',
                color: Colors.white,
              ),
            ),
          ),

          // Profile Icon (Right)
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.person, color: Colors.white, size: 28),
              onPressed: () {
                Scaffold.of(context).openEndDrawer();
              },
            ),
          ),
        ],
      ),
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

          // Camera Button (Shazam style)
          if (!_isAnalyzing && movieData == null) ...[
            ScaleTransition(
              scale: _pulseAnimation,
              child: GestureDetector(
                onTap: _pickAndAnalyzeVideo,
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
            const SizedBox(height: 24),
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

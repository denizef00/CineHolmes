import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:http_parser/http_parser.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../services/tmdb_service.dart';
import 'info_page.dart';
import 'library_provider.dart';

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> with SingleTickerProviderStateMixin {
  final picker = ImagePicker();
  late final TMDBService tmdbService;
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
      _deleteFromHistory(index);
    }
  }

  // ---------- GEMINI UPLOAD / ANALYZE ----------

  Future<String?> _uploadVideoToGemini(
    Uint8List videoBytes,
    String fileName,
    String mimeType,
  ) async {
    final uploadUrl = Uri.parse(
      'https://generativelanguage.googleapis.com/upload/v1beta/files?key=$apiKey',
    );
    try {
      var request = http.MultipartRequest('POST', uploadUrl);
      final parts = mimeType.split('/');
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          videoBytes,
          filename: fileName,
          contentType: MediaType(parts[0], parts[1]),
        ),
      );
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        final uploadResult = jsonDecode(response.body);
        final fileInfo = uploadResult['file'];
        return fileInfo?['name'] as String?;
      } else {
        debugPrint('❌ Upload error (${response.statusCode}): ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Upload exception: $e');
      return null;
    }
  }

  Future<bool> _waitForFileProcessing(String fileNameForModel) async {
    final checkUrl = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/$fileNameForModel?key=$apiKey',
    );
    for (int i = 0; i < 20; i++) {
      try {
        final response = await http.get(checkUrl);
        if (response.statusCode == 200) {
          final fileInfo = jsonDecode(response.body);
          final state = fileInfo['state'] as String?;
          if (state == 'ACTIVE') return true;
          if (state == 'FAILED') return false;
        }
        await Future.delayed(const Duration(seconds: 2));
      } catch (_) {}
    }
    return false;
  }

  Future<void> _deleteFileFromGemini(String? fileNameForModel) async {
    if (fileNameForModel == null) return;
    final deleteUrl = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/$fileNameForModel?key=$apiKey',
    );
    try {
      await http.delete(deleteUrl);
    } catch (_) {}
  }

  Future<void> _pickVideo() async {
    if (isPicking || _isAnalyzing) return;
    setState(() => isPicking = true);

    final XFile? file =
        await picker.pickVideo(source: ImageSource.gallery).catchError((_) {
      return null;
    });

    if (!mounted) return;
    if (file == null) {
      setState(() {
        isPicking = false;
        status = "No video selected.";
      });
      return;
    }

    setState(() {
      status = "Video selected: ${file.name}";
      isPicking = false;
      movieData = null;
    });

    await _analyzeVideoWithGemini(file);
  }Future<void> _analyzeVideoWithGemini(XFile video) async {
    if (apiKey.isEmpty) {
      setState(() {
        status =
            'Gemini API key is missing. Please set GEMINI_API_KEY in your .env file.';
      });
      return;
    }

    String? fileNameForModel;
    try {
      setState(() {
        _isAnalyzing = true;
        status = 'Uploading video...';
      });

      final videoBytes = await video.readAsBytes();
      final sizeMB = videoBytes.length / 1024 / 1024;
      if (sizeMB > 100) {
        setState(() {
          status =
              'Video is too large! (${sizeMB.toStringAsFixed(1)} MB > 100 MB)';
          _isAnalyzing = false;
        });
        return;
      }

      String mimeType = 'video/mp4';
      final fileName = video.name.toLowerCase();
      if (fileName.endsWith('.mov')) mimeType = 'video/quicktime';
      if (fileName.endsWith('.avi')) mimeType = 'video/x-msvideo';
      if (fileName.endsWith('.mkv')) mimeType = 'video/x-matroska';
      if (fileName.endsWith('.webm')) mimeType = 'video/webm';

      fileNameForModel = await _uploadVideoToGemini(
        videoBytes,
        video.name,
        mimeType,
      );

      if (fileNameForModel == null) {
        setState(() {
          status = 'Video could not be uploaded. Please try again.';
          _isAnalyzing = false;
        });
        return;
      }

      setState(() {
        status = 'Video is being processed...';
      });

      final isReady = await _waitForFileProcessing(fileNameForModel);

      if (!isReady) {
        setState(() {
          status = 'Video could not be processed. Please try again.';
          _isAnalyzing = false;
        });
        await _deleteFileFromGemini(fileNameForModel);
        return;
      }

      setState(() {
        status = 'Analyzing video with AI...';
      });

      const modelName = 'gemini-2.5-flash';
      final analyzeUrl = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey',
      );

      String? resultText;

      final response = await http.post(
        analyzeUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'text': '''Identify this movie or TV series.
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

Return only that single line.''',
                },
                {
                  'fileData': {
                    'mimeType': mimeType,
                    'fileUri':
                        'https://generativelanguage.googleapis.com/v1beta/$fileNameForModel',
                  },
                },
              ],
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['candidates'] != null &&
            jsonResponse['candidates'].isNotEmpty) {
          resultText =
              jsonResponse['candidates'][0]['content']['parts'][0]['text'];
        }
      } else {
        debugPrint('❌ Error from Gemini: ${response.body}');
        setState(() {
          status =
              'AI request failed (${response.statusCode}). Check console logs.';
        });
      }

      await _deleteFileFromGemini(fileNameForModel);

      if (resultText != null) {
        final parts = resultText.trim().split('|');
        if (parts.length >= 3) {
          final title = parts[0].trim();
          final year = parts[1].trim();
          final type = parts[2].trim().toLowerCase();

          setState(() {
            status = 'Searching in TMDB database...';
          });

          final movieInfo = await _searchInTMDB(title, year, type);

          if (movieInfo != null) {
            setState(() {
              movieData = movieInfo;
              status = 'Successfully identified!';
            });
            await _saveToUserHistory(movieInfo);
          } else {
            setState(() {
              status = 'Could not find in TMDB: $title ($year)';
            });
          }
        } else {
          setState(() {
            status = 'Invalid response format from AI.';
          });
        }
      } else {
        if (!_isAnalyzing) return;
        setState(() {
          status =
              'AI could not analyze the video. Please try again or check your API usage.';
        });
      }
    } catch (e) {
      await _deleteFileFromGemini(fileNameForModel);
      debugPrint('❌ Exception in analyze: $e');
      setState(() {
        status = 'Error: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  Future<Map<String, dynamic>?> _searchInTMDB(
    String title,
    String year,
    String type,
  ) async {
    final searchUrl = Uri.parse(
      'https://api.themoviedb.org/3/search/$type?api_key=$tmdbApiKey&query=${Uri.encodeComponent(title)}',
    );

    try {
      final response = await http.get(searchUrl);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List;

        if (results.isEmpty) return null;

        Map<String, dynamic>? bestMatch;
        double bestScore = 0;

        for (var result in results) {
          double score = 100.0;

          final resultTitle =
              type == 'movie' ? (result['title'] ?? '') : (result['name'] ?? '');
          final resultYear = type == 'movie'
              ? (result['release_date'] ?? '').split('-').first
              : (result['first_air_date'] ?? '').split('-').first;

          if (resultTitle.toLowerCase() != title.toLowerCase()) {
            score -= 20;
          }

          if (resultYear.isNotEmpty && year.isNotEmpty) {
            final yearDiff =
                (int.tryParse(resultYear) ?? 0) - (int.tryParse(year) ?? 0);
            if (yearDiff.abs() > 2) {
              score -= 30;
            } else if (yearDiff.abs() == 0) {
              score += 50;
            }
          }

          final popularity = (result['popularity'] ?? 0).toDouble();
          score += popularity / 10;

          if (score > bestScore) {
            bestScore = score;
            bestMatch = result;
          }
        }

        if (bestMatch != null) {
          return {
            'id': bestMatch['id'],
            'title': type == 'movie' ? bestMatch['title'] : bestMatch['name'],
            'overview': bestMatch['overview'],
            'poster': bestMatch['poster_path'] != null
                ? 'https://image.tmdb.org/t/p/w500${bestMatch['poster_path']}'
                : null,
            'rating': (bestMatch['vote_average'] is num)
                ? (bestMatch['vote_average'] as num).toStringAsFixed(1)
                : 'N/A',
            'year': type == 'movie'
                ? (bestMatch['release_date'] ?? '').split('-').first
                : (bestMatch['first_air_date'] ?? '').split('-').first,
            'type': type,
          };
        }
      }
    } catch (e) {
      debugPrint('❌ TMDB Search Error: $e');
    }
    return null;
  }// ---------- BUILD ----------

 // ---------- BUILD ----------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paddingTop = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : Colors.white,
      body: Column(
        children: [
          // Instagram-style header with CineHolmes title (matching HomePage)
          Container(
            color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
            padding: EdgeInsets.only(top: paddingTop),
            child: Column(
              children: [
                // CineHolmes title (same as HomePage)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF6A0DAD), Color(0xFF9D4EDD)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: const Text(
                      'CineHolmes',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w400,
                        fontFamily: 'Pacifico',
                        color: Colors.white,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
                
                // Section title
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Text(
                    'Identify Movies & Shows',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
                
                // Divider
                Divider(
                  height: 1,
                  thickness: 0.5,
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.1),
                ),
              ],
            ),
          ),

          // Main content
          Expanded(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    // Main Upload Button with Shazam-style design
                    if (!_isAnalyzing && movieData == null) ...[
                      const SizedBox(height: 40),
                      
                      // Animated button
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _isAnalyzing ? 1.0 : _pulseAnimation.value,
                            child: child,
                          );
                        },
                        child: GestureDetector(
                          onTap: _pickVideo,
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6A0DAD), Color(0xFF9D4EDD)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6A0DAD).withOpacity(0.4),
                                  blurRadius: 40,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.videocam_rounded,
                              size: 80,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Instructions
                      Text(
                        'Tap to identify',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Upload a video clip from your gallery',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],

                    // Analyzing state
                    if (_isAnalyzing) ...[
                      const SizedBox(height: 60),
                      Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF6A0DAD).withOpacity(0.3),
                              const Color(0xFF9D4EDD).withOpacity(0.3),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF9D4EDD),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Analyzing...',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        status,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],

                    // Result card
                    if (movieData != null) ...[
                      const SizedBox(height: 20),
                      
                      // Success animation indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6A0DAD), Color(0xFF9D4EDD)],
                          ),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6A0DAD).withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.check_circle, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Match Found!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Movie/Show card
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Poster with favorite button
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(20),
                                  ),
                                  child: AspectRatio(
                                    aspectRatio: 2 / 3,
                                    child: movieData!['poster'] != null && movieData!['poster'].isNotEmpty
                                        ? Image.network(
                                            movieData!['poster'],
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                              color: Colors.grey.shade800,
                                              child: const Icon(
                                                Icons.movie,
                                                size: 60,
                                                color: Colors.white54,
                                              ),
                                            ),
                                          )
                                        : Container(
                                            color: Colors.grey.shade800,
                                            child: const Icon(
                                              Icons.movie,
                                              size: 60,
                                              color: Colors.white54,
                                            ),
                                          ),
                                  ),
                                ),
                                
                                // Close button (sol üst)
                                Positioned(
                                  top: 12,
                                  left: 12,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        movieData = null;
                                        status = "No video selected yet.";
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.black.withOpacity(0.6),
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                                
                                // Favorite button (sağ üst)
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: Consumer<LibraryProvider>(
                                    builder: (context, libraryProvider, _) {
                                      final isFav = libraryProvider.isInLibrary(
                                        movieData!['id'],
                                      );
                                      return GestureDetector(
                                        onTap: () {
                                          if (isFav) {
                                            libraryProvider.removeFromLibrary(
                                              movieData!['id'],
                                            );
                                          } else {
                                            libraryProvider.addToLibrary({
                                              'id': movieData!['id'],
                                              'title': movieData!['title'],
                                              'poster': movieData!['poster'],
                                              'rating': movieData!['rating'],
                                              'year': movieData!['year'],
                                              'type': movieData!['type'],
                                            });
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.black.withOpacity(0.6),
                                            boxShadow: [
                                              BoxShadow(
                                                color: isFav
                                                    ? const Color(0xFFEC5FFF)
                                                        .withOpacity(0.5)
                                                    : Colors.transparent,
                                                blurRadius: 12,
                                                spreadRadius: 2,
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            isFav ? Icons.favorite : Icons.favorite_border,
                                            color: isFav
                                                ? const Color(0xFFEC5FFF)
                                                : Colors.white,
                                            size: 24,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                            
                            // Info section
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  Text(
                                    movieData!['title'] ?? 'Unknown Title',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 22,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.star,
                                        color: Color(0xFFFFD700),
                                        size: 18,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        "${movieData!['rating']}",
                                        style: TextStyle(
                                          color: isDark ? Colors.white : Colors.black87,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Container(
                                        width: 4,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isDark ? Colors.white60 : Colors.black54,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        "${movieData!['year']}",
                                        style: TextStyle(
                                          color: isDark ? Colors.white70 : Colors.black54,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    movieData!['overview'] ?? "No overview available.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.5,
                                      color: isDark ? Colors.white70 : Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  
                                  // Action buttons
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: const Color(0xFF6A0DAD),
                                            side: const BorderSide(
                                              color: Color(0xFF6A0DAD),
                                              width: 2,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              movieData = null;
                                              status = "No video selected yet.";
                                            });
                                          },
                                          child: const Text(
                                            'Try Another',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFF6A0DAD),
                                                Color(0xFF9D4EDD),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.transparent,
                                              shadowColor: Colors.transparent,
                                              padding: const EdgeInsets.symmetric(
                                                vertical: 14,
                                              ),
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
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                    ],

                    // History section
                    if (!_isAnalyzing && movieData == null) ...[
                      const SizedBox(height: 40),
                      
                      if (_isLoadingHistory)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF6A0DAD),
                              ),
                            ),
                          ),
                        ),
                        
                      if (!_isLoadingHistory && history.isNotEmpty) ...[
                        Row(
                          children: [
                            Text(
                              'Recent Matches',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${history.length}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Grid view of history
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: history.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.66,
                          ),
                          itemBuilder: (context, index) {
                            final movie = history[index];
                            final poster = movie['poster'] as String? ?? '';

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
                              onLongPress: () => _showDeleteConfirmation(index),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    poster.isNotEmpty
                                        ? Image.network(
                                            poster,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Container(
                                              color: Colors.grey.shade800,
                                              child: const Icon(
                                                Icons.broken_image,
                                                color: Colors.white54,
                                                size: 32,
                                              ),
                                            ),
                                          )
                                        : Container(
                                            color: Colors.grey.shade800,
                                            child: const Icon(
                                              Icons.movie,
                                              color: Colors.white54,
                                              size: 32,
                                            ),
                                          ),
                                    
                                    // Gradient overlay
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black.withOpacity(0.5),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                      
                      if (!_isLoadingHistory && history.isEmpty) ...[
                        const SizedBox(height: 20),
                        Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.history,
                                size: 48,
                                color: isDark ? Colors.white24 : Colors.black26,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No recent matches',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
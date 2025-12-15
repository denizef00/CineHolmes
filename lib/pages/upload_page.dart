// upload_page.dart (cleaned + more stable + no full RAM load on mobile)

import 'dart:async';
import 'dart:convert';
import 'dart:io' show File; // only used on mobile/desktop (guarded by kIsWeb)
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
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

class _UploadPageState extends State<UploadPage>
    with SingleTickerProviderStateMixin {
  // --- deps ---
  final picker = ImagePicker();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final TMDBService tmdbService;

  String get apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  String get tmdbApiKey => dotenv.env['TMDB_API_KEY'] ?? '';

  // --- UI state ---
  String status = "No video selected yet.";
  Map<String, dynamic>? movieData;
  List<Map<String, dynamic>> history = [];

  bool isPicking = false;
  bool _isAnalyzing = false;
  bool _isLoadingHistory = true;

  // prevent stale async updates
  int _runId = 0;

  // pulse animation
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  static const int _historyLimit = 20;
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

  // ----------------------------
  // FIRESTORE HISTORY
  // ----------------------------

  Future<void> _loadUserHistory() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() => _isLoadingHistory = false);
      return;
    }

    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('upload_history')
          .orderBy('timestamp', descending: true)
          .limit(_historyLimit)
          .get();

      if (!mounted) return;

      setState(() {
        history = querySnapshot.docs
            .map((doc) => {...doc.data(), 'docId': doc.id})
            .toList();
        _isLoadingHistory = false;
      });
    } catch (e) {
      debugPrint('❌ History Loading Error: $e');
      if (!mounted) return;
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

      if (!mounted) return;

      if (existingDoc.docs.isNotEmpty) {
        final docId = existingDoc.docs.first.id;

        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('upload_history')
            .doc(docId)
            .update({'timestamp': FieldValue.serverTimestamp()});

        if (!mounted) return;

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

      if (!mounted) return;

      setState(() {
        history.insert(0, {...movieInfo, 'docId': docRef.id});
        if (history.length > _historyLimit) {
          history = history.sublist(0, _historyLimit);
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

    if (index < 0 || index >= history.length) return;

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

      if (!mounted) return;

      setState(() => history.removeAt(index));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${movie['title']} deleted from history'),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF6A0DAD),
        ),
      );
    } catch (e) {
      debugPrint('❌ History silme hatası: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete. Please try again.'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
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

  // ----------------------------
  // GEMINI: UPLOAD / ANALYZE
  // ----------------------------

  String _inferMimeType(String fileNameLower) {
    if (fileNameLower.endsWith('.mov')) return 'video/quicktime';
    if (fileNameLower.endsWith('.avi')) return 'video/x-msvideo';
    if (fileNameLower.endsWith('.mkv')) return 'video/x-matroska';
    if (fileNameLower.endsWith('.webm')) return 'video/webm';
    return 'video/mp4';
  }

  Future<int?> _getVideoSizeBytes(XFile video) async {
    try {
      if (kIsWeb) {
        final bytes = await video.readAsBytes();
        return bytes.length;
      } else {
        // XFile.length() exists on most platforms; safer than reading bytes.
        return await video.length();
      }
    } catch (_) {
      // fallback for some edge devices
      try {
        if (!kIsWeb && video.path.isNotEmpty) {
          return File(video.path).lengthSync();
        }
      } catch (_) {}
    }
    return null;
  }

  Future<String?> _uploadVideoToGemini({
    required XFile video,
    required String mimeType,
  }) async {
    final uploadUrl = Uri.parse(
      'https://generativelanguage.googleapis.com/upload/v1beta/files?key=$apiKey',
    );

    try {
      final request = http.MultipartRequest('POST', uploadUrl);

      final parts = mimeType.split('/');
      final mediaType = MediaType(parts.first, parts.length > 1 ? parts[1] : '');

      if (kIsWeb) {
        // Web: must read bytes
        final Uint8List bytes = await video.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: video.name,
            contentType: mediaType,
          ),
        );
      } else {
        // Mobile/Desktop: stream from file path (no huge RAM spike)
        if (video.path.isEmpty) return null;
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            video.path,
            filename: video.name,
            contentType: mediaType,
          ),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse)
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final uploadResult = jsonDecode(response.body);
        final fileInfo = uploadResult['file'];
        return fileInfo?['name'] as String?;
      } else {
        debugPrint('❌ Upload error (${response.statusCode}): ${response.body}');
        return null;
      }
    } on TimeoutException {
      debugPrint('❌ Upload timeout');
      return null;
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
        final response =
            await http.get(checkUrl).timeout(const Duration(seconds: 20));

        if (response.statusCode == 200) {
          final fileInfo = jsonDecode(response.body);
          final state = fileInfo['state'] as String?;
          if (state == 'ACTIVE') return true;
          if (state == 'FAILED') return false;
        }

        await Future.delayed(const Duration(seconds: 2));
      } catch (_) {
        // ignore transient network errors, keep polling
      }
    }
    return false;
  }

  Future<void> _deleteFileFromGemini(String? fileNameForModel) async {
    if (fileNameForModel == null) return;

    final deleteUrl = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/$fileNameForModel?key=$apiKey',
    );
    try {
      await http.delete(deleteUrl).timeout(const Duration(seconds: 15));
    } catch (_) {}
  }

  String? _normalizeAiLine(String raw) {
    final line = raw.trim();
    if (line.isEmpty) return null;

    // If AI returns multiple lines, take the first meaningful one
    final firstLine = line.split('\n').map((e) => e.trim()).firstWhere(
          (e) => e.isNotEmpty,
          orElse: () => '',
        );

    if (firstLine.isEmpty) return null;

    // remove wrapping quotes
    final cleaned = firstLine.replaceAll('"', '').replaceAll("“", '').replaceAll("”", '');
    return cleaned.trim();
  }

  Future<void> _pickVideo() async {
    if (isPicking || _isAnalyzing) return;

    setState(() => isPicking = true);

    XFile? file;
    try {
      file = await picker.pickVideo(source: ImageSource.gallery);
    } catch (_) {
      file = null;
    }

    if (!mounted) return;

    if (file == null) {
      setState(() {
        isPicking = false;
        status = "No video selected.";
      });
      return;
    }

    setState(() {
      status = "Video selected: ${file!.name}";
      isPicking = false;
      movieData = null;
    });

    final int localRunId = ++_runId;
    await _analyzeVideoWithGemini(file, runId: localRunId);
  }

  Future<void> _analyzeVideoWithGemini(XFile video, {required int runId}) async {
    if (apiKey.isEmpty) {
      if (!mounted) return;
      setState(() {
        status =
            'Gemini API key is missing. Please set GEMINI_API_KEY in your .env file.';
      });
      return;
    }

    String? fileNameForModel;

    try {
      if (!mounted || runId != _runId) return;
      setState(() {
        _isAnalyzing = true;
        status = 'Preparing...';
      });

      // size check without loading bytes into RAM (mobile)
      final sizeBytes = await _getVideoSizeBytes(video);
      if (!mounted || runId != _runId) return;

      if (sizeBytes == null) {
        setState(() {
          status = 'Could not read video size. Please try another file.';
          _isAnalyzing = false;
        });
        return;
      }

      final sizeMB = sizeBytes / 1024 / 1024;
      if (sizeMB > _maxVideoMB) {
        setState(() {
          status =
              'Video is too large! (${sizeMB.toStringAsFixed(1)} MB > $_maxVideoMB MB)';
          _isAnalyzing = false;
        });
        return;
      }

      final mimeType = _inferMimeType(video.name.toLowerCase());

      setState(() => status = 'Uploading video...');

      fileNameForModel = await _uploadVideoToGemini(video: video, mimeType: mimeType);

      if (!mounted || runId != _runId) return;

      if (fileNameForModel == null) {
        setState(() {
          status = 'Video could not be uploaded. Please try again.';
          _isAnalyzing = false;
        });
        return;
      }

      setState(() => status = 'Video is being processed...');

      final isReady = await _waitForFileProcessing(fileNameForModel);

      if (!mounted || runId != _runId) {
        await _deleteFileFromGemini(fileNameForModel);
        return;
      }

      if (!isReady) {
        setState(() {
          status = 'Video could not be processed. Please try again.';
          _isAnalyzing = false;
        });
        await _deleteFileFromGemini(fileNameForModel);
        return;
      }

      setState(() => status = 'Analyzing video with AI...');

      const modelName = 'gemini-2.5-flash';
      final analyzeUrl = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey',
      );

      final response = await http
          .post(
            analyzeUrl,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': _prompt},
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
          )
          .timeout(const Duration(seconds: 60));

      if (!mounted || runId != _runId) {
        await _deleteFileFromGemini(fileNameForModel);
        return;
      }

      String? resultText;
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final candidates = jsonResponse['candidates'];
        if (candidates != null && candidates is List && candidates.isNotEmpty) {
          final parts = candidates[0]?['content']?['parts'];
          if (parts != null && parts is List && parts.isNotEmpty) {
            resultText = parts[0]?['text']?.toString();
          }
        }
      } else {
        debugPrint('❌ Error from Gemini: ${response.body}');
        setState(() {
          status =
              'AI request failed (${response.statusCode}). Check console logs.';
        });
      }

      await _deleteFileFromGemini(fileNameForModel);

      if (!mounted || runId != _runId) return;

      final normalized = resultText == null ? null : _normalizeAiLine(resultText);
      if (normalized == null) {
        setState(() {
          status =
              'AI could not analyze the video. Please try again or check your API usage.';
        });
        return;
      }

      final parts = normalized.split('|').map((e) => e.trim()).toList();
      if (parts.length < 3) {
        setState(() => status = 'Invalid response format from AI.');
        return;
      }

      final title = parts[0];
      final year = parts[1];
      final type = parts[2].toLowerCase();

      if (title.isEmpty || (type != 'movie' && type != 'tv')) {
        setState(() => status = 'Invalid response format from AI.');
        return;
      }

      setState(() => status = 'Searching in TMDB database...');

      final movieInfo = await _searchInTMDB(title, year, type);

      if (!mounted || runId != _runId) return;

      if (movieInfo != null) {
        setState(() {
          movieData = movieInfo;
          status = 'Successfully identified!';
        });
        await _saveToUserHistory(movieInfo);
      } else {
        setState(() => status = 'Could not find in TMDB: $title ($year)');
      }
    } on TimeoutException catch (_) {
      debugPrint('❌ Timeout in analyze');
      if (fileNameForModel != null) await _deleteFileFromGemini(fileNameForModel);
      if (!mounted || runId != _runId) return;
      setState(() => status = 'Request timed out. Please try again.');
    } catch (e) {
      debugPrint('❌ Exception in analyze: $e');
      if (fileNameForModel != null) await _deleteFileFromGemini(fileNameForModel);
      if (!mounted || runId != _runId) return;
      setState(() => status = 'Error: $e');
    } finally {
      if (!mounted || runId != _runId) return;
      setState(() => _isAnalyzing = false);
    }
  }

  Future<Map<String, dynamic>?> _searchInTMDB(
    String title,
    String year,
    String type,
  ) async {
    if (tmdbApiKey.isEmpty) return null;

    final searchUrl = Uri.parse(
      'https://api.themoviedb.org/3/search/$type?api_key=$tmdbApiKey&query=${Uri.encodeComponent(title)}',
    );

    try {
      final response =
          await http.get(searchUrl).timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      final results = (data['results'] as List?) ?? const [];
      if (results.isEmpty) return null;

      Map<String, dynamic>? bestMatch;
      double bestScore = -99999;

      for (final r in results) {
        if (r is! Map) continue;
        final result = Map<String, dynamic>.from(r);

        double score = 100.0;

        final resultTitle = type == 'movie'
            ? (result['title'] ?? '').toString()
            : (result['name'] ?? '').toString();

        final resultYear = type == 'movie'
            ? (result['release_date'] ?? '').toString().split('-').first
            : (result['first_air_date'] ?? '').toString().split('-').first;

        if (resultTitle.toLowerCase() != title.toLowerCase()) score -= 20;

        final y1 = int.tryParse(resultYear);
        final y2 = int.tryParse(year);
        if (y1 != null && y2 != null) {
          final diff = (y1 - y2).abs();
          if (diff > 2) score -= 30;
          if (diff == 0) score += 50;
        }

        final popularity = (result['popularity'] is num)
            ? (result['popularity'] as num).toDouble()
            : 0.0;
        score += popularity / 10;

        if (score > bestScore) {
          bestScore = score;
          bestMatch = result;
        }
      }

      if (bestMatch == null) return null;

      final posterPath = bestMatch['poster_path']?.toString();
      final poster = (posterPath != null && posterPath.isNotEmpty)
          ? 'https://image.tmdb.org/t/p/w500$posterPath'
          : null;

      final voteAverage = bestMatch['vote_average'];
      final rating = (voteAverage is num) ? voteAverage.toStringAsFixed(1) : 'N/A';

      final finalYear = type == 'movie'
          ? (bestMatch['release_date'] ?? '').toString().split('-').first
          : (bestMatch['first_air_date'] ?? '').toString().split('-').first;

      return {
        'id': bestMatch['id'],
        'title': type == 'movie' ? bestMatch['title'] : bestMatch['name'],
        'overview': bestMatch['overview'],
        'poster': poster,
        'rating': rating,
        'year': finalYear,
        'type': type,
      };
    } catch (e) {
      debugPrint('❌ TMDB Search Error: $e');
      return null;
    }
  }

  // ----------------------------
  // UI
  // ----------------------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paddingTop = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : Colors.white,
      body: Column(
        children: [
          // Header
          Container(
            color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
            padding: EdgeInsets.only(top: paddingTop),
            child: Column(
              children: [
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

          Expanded(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    // Upload state
                    if (!_isAnalyzing && movieData == null) ...[
                      const SizedBox(height: 40),

                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
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
                                  color:
                                      const Color(0xFF6A0DAD).withOpacity(0.4),
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

                    // Analyzing
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

                    // Result
                    if (movieData != null) ...[
                      const SizedBox(height: 20),
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
                            Icon(Icons.check_circle,
                                color: Colors.white, size: 20),
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

                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(20),
                                  ),
                                  child: AspectRatio(
                                    aspectRatio: 2 / 3,
                                    child: (movieData!['poster'] ?? '')
                                            .toString()
                                            .isNotEmpty
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

                                // Close
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

                                // Favorite
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: Consumer<LibraryProvider>(
                                    builder: (context, libraryProvider, _) {
                                      final id = movieData!['id'];
                                      final isFav =
                                          libraryProvider.isInLibrary(id);

                                      return GestureDetector(
                                        onTap: () {
                                          if (isFav) {
                                            libraryProvider.removeFromLibrary(id);
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
                                            color:
                                                Colors.black.withOpacity(0.6),
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
                                            isFav
                                                ? Icons.favorite
                                                : Icons.favorite_border,
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

                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  Text(
                                    (movieData!['title'] ?? 'Unknown Title')
                                        .toString(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 22,
                                      color:
                                          isDark ? Colors.white : Colors.black87,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.star,
                                          color: Color(0xFFFFD700), size: 18),
                                      const SizedBox(width: 4),
                                      Text(
                                        "${movieData!['rating']}",
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
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
                                          color: isDark
                                              ? Colors.white60
                                              : Colors.black54,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        "${movieData!['year']}",
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black54,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    (movieData!['overview'] ??
                                            "No overview available.")
                                        .toString(),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.5,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor:
                                                const Color(0xFF6A0DAD),
                                            side: const BorderSide(
                                              color: Color(0xFF6A0DAD),
                                              width: 2,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
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
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.transparent,
                                              shadowColor: Colors.transparent,
                                              padding: const EdgeInsets.symmetric(
                                                vertical: 14,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => InfoPage(
                                                    id: movieData!['id'],
                                                    title: movieData!['title'],
                                                    type: movieData!['type'] ??
                                                        'movie',
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

                    // History
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
                                color:
                                    isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
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
                            final poster = (movie['poster'] ?? '').toString();

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
                                            errorBuilder: (_, __, ___) =>
                                                Container(
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
                                color: isDark
                                    ? Colors.white24
                                    : Colors.black26,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No recent matches',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: isDark
                                      ? Colors.white60
                                      : Colors.black54,
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

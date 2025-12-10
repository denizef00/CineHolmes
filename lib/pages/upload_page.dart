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

class _UploadPageState extends State<UploadPage> {
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

  String get apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  String get tmdbApiKey => dotenv.env['TMDB_API_KEY'] ?? '';

  @override
  void initState() {
    super.initState();
    tmdbService = TMDBService();
    _loadUserHistory();
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
            action: SnackBarAction(label: 'OK', onPressed: () {}),
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
          ),
        );
      }
    }
  }

  Future<void> _showDeleteConfirmation(int index) async {
    final movie = history[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete from history?'),
        content: Text('Remove "${movie['title']}" from your history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
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
  }

  Future<void> _analyzeVideoWithGemini(XFile video) async {
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
  }

  // ---------- UI HELPERS ----------

  Color _statusColor(String s, ThemeData theme) {
    final lower = s.toLowerCase();
    if (lower.contains('error') ||
        lower.contains('could not') ||
        lower.contains('missing') ||
        lower.contains('failed')) {
      return Colors.redAccent.withOpacity(0.15);
    }
    if (lower.contains('success')) {
      return Colors.green.withOpacity(0.15);
    }
    if (lower.contains('uploading') ||
        lower.contains('processing') ||
        lower.contains('analyzing') ||
        lower.contains('searching')) {
      return Colors.amber.withOpacity(0.12);
    }
    return theme.cardColor.withOpacity(0.35);
  }

  IconData _statusIcon(String s) {
    final lower = s.toLowerCase();
    if (lower.contains('error') ||
        lower.contains('could not') ||
        lower.contains('missing') ||
        lower.contains('failed')) {
      return Icons.error_outline;
    }
    if (lower.contains('success')) {
      return Icons.check_circle_outline;
    }
    if (lower.contains('uploading')) {
      return Icons.cloud_upload_outlined;
    }
    if (lower.contains('processing')) {
      return Icons.hourglass_bottom;
    }
    if (lower.contains('analyzing')) {
      return Icons.auto_awesome;
    }
    if (lower.contains('searching')) {
      return Icons.search;
    }
    return Icons.info_outline;
  }

  // ---------- BUILD ----------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paddingTop = MediaQuery.of(context).padding.top;

    return Container(
      color: const Color(0xFF202227), // alt zemin gri
      child: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            // Üst siyah bar (HomePage ile uyumlu yükseklik)
            Container(
              color: Colors.black,
              height: paddingTop + kToolbarHeight,
              padding: EdgeInsets.only(top: paddingTop),
              alignment: Alignment.center,
              child: const Text(
                'CineHolmes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            // Gövde
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxWidth =
                      constraints.maxWidth > 600 ? 600.0 : constraints.maxWidth;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Sayfa başlığı
                            Text(
                              'Identify from a clip',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Hero: tek büyük buton
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E1E2C),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.08),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 18,
                              ),
                              child: Column(
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: (isPicking || _isAnalyzing)
                                          ? null
                                          : _pickVideo,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF6A0DAD),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(28),
                                        ),
                                      ),
                                      child: Text(
                                        isPicking
                                            ? 'Opening gallery...'
                                            : _isAnalyzing
                                                ? 'Analyzing...'
                                                : 'Upload & identify',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (_isAnalyzing) ...[
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: const [
                                        SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'This may take a few seconds...',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            const SizedBox(height: 18),

                            // Status kartı
                            Container(
                              decoration: BoxDecoration(
                                color: _statusColor(status, theme),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.05),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    _statusIcon(status),
                                    size: 20,
                                    color: Colors.white70,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      status,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Sonuç kartı
                            if (movieData != null) ...[
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E2C),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.06),
                                  ),
                                ),
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: Image.network(
                                            movieData!['poster'] ?? '',
                                            height: 230,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error,
                                                    stackTrace) =>
                                                Container(
                                              height: 230,
                                              alignment: Alignment.center,
                                              color: Colors.grey.shade800,
                                              child: const Icon(
                                                Icons.broken_image,
                                                size: 80,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 10,
                                          right: 10,
                                          child: Consumer<LibraryProvider>(
                                            builder: (context,
                                                libraryProvider, _) {
                                              final id =
                                                  movieData!['id'] as int;
                                              final isFav = libraryProvider
                                                  .isInLibrary(id);

                                              return GestureDetector(
                                                onTap: () {
                                                  libraryProvider
                                                      .toggleLibrary({
                                                    'id': id,
                                                    'title':
                                                        movieData!['title'],
                                                    'poster':
                                                        movieData!['poster'],
                                                    'type':
                                                        movieData!['type'],
                                                    'year':
                                                        movieData!['year'],
                                                    'rating':
                                                        movieData!['rating'],
                                                  });
                                                },
                                                child: CircleAvatar(
                                                  radius: 18,
                                                  backgroundColor: Colors.black
                                                      .withOpacity(0.65),
                                                  child: Icon(
                                                    isFav
                                                        ? Icons.favorite
                                                        : Icons.favorite_border,
                                                    color: isFav
                                                        ? const Color(
                                                            0xFFEC5FFF)
                                                        : Colors.white,
                                                    size: 20,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      movieData!['title'] ?? 'Unknown Title',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "⭐ ${movieData!['rating']}  •  ${movieData!['year']}",
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      movieData!['overview'] ??
                                          "No overview available.",
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        height: 1.4,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          side: BorderSide(
                                            color: Colors.white
                                                .withOpacity(0.4),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 10,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(30),
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
                                        child:
                                            const Text('View full details'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],

                            // History
                            if (_isLoadingHistory)
                              const Padding(
                                padding: EdgeInsets.only(top: 10),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            if (!_isLoadingHistory && history.isNotEmpty) ...[
                              Text(
                                'Previously matched',
                                style:
                                    theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),

                              // 3 sütunlu grid (homepage posteri gibi)
                              GridView.builder(
                                shrinkWrap: true,
                                physics:
                                    const NeverScrollableScrollPhysics(),
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
                                    onLongPress: () =>
                                        _showDeleteConfirmation(index),
                                    child: ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(10),
                                      child: AspectRatio(
                                        aspectRatio: 2 / 3,
                                        child: poster.isNotEmpty
                                            ? Image.network(
                                                poster,
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (_, __, ___) =>
                                                        Container(
                                                  color:
                                                      Colors.grey.shade800,
                                                  alignment:
                                                      Alignment.center,
                                                  child: const Icon(
                                                    Icons.broken_image,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              )
                                            : Container(
                                                color: Colors.grey.shade800,
                                                alignment: Alignment.center,
                                                child: const Icon(
                                                  Icons.broken_image,
                                                  color: Colors.white,
                                                ),
                                              ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

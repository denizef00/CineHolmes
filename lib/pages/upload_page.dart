import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:http_parser/http_parser.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart'; // Provider

import '../services/tmdb_service.dart';
import 'info_page.dart';
import 'library_provider.dart'; // SAME folder (pages)

// If you will use MovieCard from lib/movie_card.dart elsewhere:
// import '../movie_card.dart';
// 🔒 Yolunu proje yapısına göre doğrula

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

  // Firestore'dan kullanıcının upload geçmişini yükle
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
      print('❌ History Loading Error: $e');
      setState(() => _isLoadingHistory = false);
    }
  }

  // Yeni sonucu Firestore'a kaydet ve yerel history'ye ekle
  Future<void> _saveToUserHistory(Map<String, dynamic> movieInfo) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final movieId = movieInfo['id'];

      // ÖNCELİKLE: Bu film daha önce history'de var mı kontrol et
      final existingDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('upload_history')
          .where('id', isEqualTo: movieId)
          .limit(1)
          .get();

      // Eğer varsa, sadece timestamp'ini güncelle
      if (existingDoc.docs.isNotEmpty) {
        final docId = existingDoc.docs.first.id;

        // Firestore'da timestamp güncelle
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('upload_history')
            .doc(docId)
            .update({'timestamp': FieldValue.serverTimestamp()});

        // Local history'de de en üste taşı
        setState(() {
          // Önce eski kaydı bul ve çıkar
          final oldIndex = history.indexWhere((m) => m['id'] == movieId);
          if (oldIndex != -1) {
            final movie = history.removeAt(oldIndex);
            // En üste ekle
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

        print('✅ Film zaten history\'de, timestamp güncellendi');
        return;
      }

      // Eğer yoksa, yeni kayıt ekle
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

      print('✅ Yeni film history\'ye eklendi');
    } catch (e) {
      print('❌ History Save Error: $e');
    }
  }

  // History'den bir öğeyi sil
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
      print('❌ History silme hatası: $e');
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

  // Silme onayı diyalogu
  Future<void> _showDeleteConfirmation(int index) async {
    final movie = history[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete from History?'),
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
        print('❌ Upload error (${response.statusCode}): ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Upload exception: $e');
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

    final XFile? file = await picker
        .pickVideo(source: ImageSource.gallery)
        .catchError((_) => null);

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
    // API key boşsa erkenden dön
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
        status = 'Video is being processed... Please wait.';
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

      // 🔹 Tek model: gemini-2.5-flash (docs ile uyumlu)
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

Be precise. Just give me one line, no extra text.''',
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
        print('❌ Error: ${response.body}');
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
            status = 'Invalid response format from AI';
          });
        }
      } else {
        setState(() {
          status =
              'AI could not analyze the video. Please try again or check your API usage.';
        });
      }
    } catch (e) {
      await _deleteFileFromGemini(fileNameForModel);
      setState(() {
        status = 'Error: $e';
      });
    } finally {
      setState(() => _isAnalyzing = false);
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

          final resultTitle = type == 'movie'
              ? (result['title'] ?? '')
              : (result['name'] ?? '');
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
      print('❌ TMDB Search Error: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.upload),
              label: Text(
                isPicking
                    ? "Opening gallery..."
                    : _isAnalyzing
                        ? "Analyzing..."
                        : "Upload and identify",
              ),
              onPressed: (isPicking || _isAnalyzing) ? null : _pickVideo,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            status,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          if (_isAnalyzing) const SizedBox(height: 20),
          if (_isAnalyzing) const CircularProgressIndicator(),

          // Poster + sağ üstte kalp
          if (movieData != null) ...[
            const SizedBox(height: 20),
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    movieData!['poster'] ?? '',
                    height: 250,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.broken_image, size: 100),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Consumer<LibraryProvider>(
                    builder: (context, libraryProvider, _) {
                      final id = movieData!['id'] as int;
                      final isFav = libraryProvider.isInLibrary(id);

                      return GestureDetector(
                        onTap: () {
                          libraryProvider.toggleLibrary({
                            'id': id,
                            'title': movieData!['title'],
                            'poster': movieData!['poster'],
                            'type': movieData!['type'],
                            'year': movieData!['year'],
                            'rating': movieData!['rating'],
                          });
                        },
                        child: CircleAvatar(
                          backgroundColor: Colors.black.withOpacity(0.6),
                          child: Icon(
                            isFav ? Icons.favorite : Icons.favorite_border,
                            color: isFav
                                ? const Color(0xFF6A0DAD)
                                : Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              movieData!['title'] ?? 'Unknown Title',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              textAlign: TextAlign.center,
            ),
            Text(
              "⭐ ${movieData!['rating']}  |  ${movieData!['year']}",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Text(
              movieData!['overview'] ?? "No overview available.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.info_outline),
              label: const Text("View Full Details"),
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
            ),
          ],

          if (_isLoadingHistory)
            const Padding(
              padding: EdgeInsets.only(top: 30),
              child: CircularProgressIndicator(),
            ),
          if (!_isLoadingHistory && history.isNotEmpty) ...[
            const SizedBox(height: 30),
            const Text(
              "History",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: history.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final movie = history[index];
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
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                movie['poster'] ?? '',
                                width: 80,
                                height: 100,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.broken_image, size: 50),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        SizedBox(
                          width: 80,
                          child: Text(
                            movie['title'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

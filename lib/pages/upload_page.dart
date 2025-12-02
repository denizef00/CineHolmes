import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:http_parser/http_parser.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/tmdb_service.dart';
import 'info_page.dart';

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final picker = ImagePicker();
  late final TMDBService tmdbService;

  String status = "No video selected yet.";
  Map<String, dynamic>? movieData;
  List<Map<String, dynamic>> history = [];
  bool isPicking = false;
  bool _isAnalyzing = false;

  String get apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  String get tmdbApiKey => dotenv.env['TMDB_API_KEY'] ?? '';

  @override
  void initState() {
    super.initState();
    tmdbService = TMDBService();
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
        .catchError((_) {
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

      // Gemini'den SADECE isim ve tür bilgisi iste
      final modelsToTry = [
        'gemini-2.0-flash',
        'gemini-1.5-flash',
        'gemini-1.5-pro',
      ];
      String? resultText;

      for (final modelName in modelsToTry) {
        print('📄 Trying model: $modelName');
        final analyzeUrl = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey',
        );

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

        print('📡 Response status: ${response.statusCode}');
        if (response.statusCode == 200) {
          final jsonResponse = jsonDecode(response.body);
          if (jsonResponse['candidates'] != null &&
              jsonResponse['candidates'].isNotEmpty) {
            resultText =
                jsonResponse['candidates'][0]['content']['parts'][0]['text'];
            print('✅ Gemini result: $resultText');
            break;
          }
        } else {
          print('❌ Error: ${response.body}');
        }
      }

      await _deleteFileFromGemini(fileNameForModel);

      if (resultText != null) {
        // "Title|Year|Type" formatını parse et
        final parts = resultText.trim().split('|');
        if (parts.length >= 3) {
          final title = parts[0].trim();
          final year = parts[1].trim();
          final type = parts[2].trim().toLowerCase();

          print('🎬 Parsed: Title=$title, Year=$year, Type=$type');

          // TMDB'de ara
          setState(() {
            status = 'Searching in TMDB database...';
          });

          final movieInfo = await _searchInTMDB(title, year, type);

          if (movieInfo != null) {
            setState(() {
              movieData = movieInfo;
              history.add(movieInfo);
              status = 'Successfully identified!';
            });
          } else {
            setState(() {
              status = 'Could not find in TMDB: $title ($year)';
            });
          }
        } else {
          print('❌ Invalid format: $resultText');
          setState(() {
            status = 'Invalid response format from AI';
          });
        }
      } else {
        setState(() {
          status = 'No model worked. Please check your API key.';
        });
      }
    } catch (e) {
      await _deleteFileFromGemini(fileNameForModel);
      setState(() {
        status = 'Error: $e';
      });
      print('❌ Exception: $e');
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  // TMDB'de isim ve yıla göre ara, en iyi eşleşmeyi bul
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

        if (results.isEmpty) {
          print('❌ No results found for: $title');
          return null;
        }

        // En iyi eşleşmeyi bul
        Map<String, dynamic>? bestMatch;
        double bestScore = 0;

        for (var result in results) {
          double score = 100.0; // Başlangıç skoru

          final resultTitle = type == 'movie'
              ? (result['title'] ?? '')
              : (result['name'] ?? '');
          final resultYear = type == 'movie'
              ? (result['release_date'] ?? '').split('-').first
              : (result['first_air_date'] ?? '').split('-').first;

          // İsim benzerliği kontrolü (basit)
          if (resultTitle.toLowerCase() != title.toLowerCase()) {
            score -= 20;
          }

          // Yıl kontrolü
          if (resultYear.isNotEmpty && year.isNotEmpty) {
            final yearDiff =
                (int.tryParse(resultYear) ?? 0) - (int.tryParse(year) ?? 0);
            if (yearDiff.abs() > 2) {
              score -= 30;
            } else if (yearDiff.abs() == 0) {
              score += 50; // Tam eşleşme bonusu
            }
          }

          // Popülerlik bonusu
          final popularity = (result['popularity'] ?? 0).toDouble();
          score += popularity / 10;

          print('📊 $resultTitle ($resultYear) - Score: $score');

          if (score > bestScore) {
            bestScore = score;
            bestMatch = result;
          }
        }

        if (bestMatch != null) {
          print(
            '🎯 Best match: ${type == 'movie' ? bestMatch['title'] : bestMatch['name']} (Score: $bestScore)',
          );

          return {
            'id': bestMatch['id'],
            'title': type == 'movie' ? bestMatch['title'] : bestMatch['name'],
            'overview': bestMatch['overview'],
            'poster': bestMatch['poster_path'] != null
                ? 'https://image.tmdb.org/t/p/w500${bestMatch['poster_path']}'
                : null,
            'rating': bestMatch['vote_average']?.toStringAsFixed(1) ?? 'N/A',
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
          ElevatedButton.icon(
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
          const SizedBox(height: 20),
          Text(
            status,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          if (_isAnalyzing) const SizedBox(height: 20),
          if (_isAnalyzing) const CircularProgressIndicator(),
          if (movieData != null) ...[
            const SizedBox(height: 20),
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
          if (history.isNotEmpty) ...[
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
                    child: Column(
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

/*import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:http_parser/http_parser.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/tmdb_service.dart';
import 'info_page.dart';

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final picker = ImagePicker();
  late final TMDBService tmdbService;

  String status = "No video selected yet.";
  Map<String, dynamic>? movieData;
  List<Map<String, dynamic>> history = [];
  bool isPicking = false;
  bool _isAnalyzing = false;

  String get apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  String get tmdbApiKey => dotenv.env['TMDB_API_KEY'] ?? '';

  @override
  void initState() {
    super.initState();
    tmdbService = TMDBService();
    _listAvailableModels();
  }

  Future<void> _listAvailableModels() async {
    final modelsUrl = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey',
    );
    try {
      final response = await http.get(modelsUrl);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('📋 AVAILABLE MODELS (v1beta API):');
        for (var model in data['models']) {
          final name = model['name'];
          final displayName = model['displayName'];
          final supportedMethods = model['supportedGenerationMethods'];
          if (supportedMethods != null &&
              supportedMethods.contains('generateContent')) {
            print('  ✅ $name - $displayName');
          }
        }
      }
    } catch (e) {
      print('⚠️ Could not fetch models: $e');
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
        .catchError((_) {
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
        status = 'Video analyzed!';
      });

      // TMDB: Search for movie info
      final modelsToTry = [
        'gemini-1.5-flash',
        'gemini-1.5-pro',
        'gemini-2.0-flash',
      ];
      String? resultText;

      for (final modelName in modelsToTry) {
        final analyzeUrl = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey',
        );

        final response = await http.post(
          analyzeUrl,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {
                    'text':
                        'Which TV series or movie is this? Just give me the name briefly.',
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
            break;
          }
        }
      }

      await _deleteFileFromGemini(fileNameForModel);

      if (resultText != null) {
        final movieTitle = resultText.trim();
        final res = await tmdbService.searchMovie(movieTitle);
        if (res != null) {
          setState(() {
            movieData = res;
            history.add(res); // Add to history
          });
        }
      } else {
        setState(() {
          status = 'No model worked. Please check your API key.';
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          ElevatedButton.icon(
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
          const SizedBox(height: 20),
          Text(
            status,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          if (_isAnalyzing) const SizedBox(height: 20),
          if (_isAnalyzing) const CircularProgressIndicator(),
          if (movieData != null) ...[
            const SizedBox(height: 20),
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
          if (history.isNotEmpty) ...[
            const SizedBox(height: 30),
            const Text(
              "History",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: history.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final movie = history[index];
                  return Column(
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
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}*/

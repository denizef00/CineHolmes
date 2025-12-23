// gemini_service.dart - Gemini AI video analysis service

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class GeminiService {
  final String apiKey;
  final String tmdbApiKey;

  GeminiService({
    required this.apiKey,
    required this.tmdbApiKey,
  }) {
    // ✅ Validate API keys
    if (apiKey.isEmpty || apiKey.length < 30) {
      debugPrint('⚠️ WARNING: Gemini API key looks invalid (length: ${apiKey.length})');
      debugPrint('   Expected: 39+ characters');
      debugPrint('   Got: "${apiKey.substring(0, apiKey.length > 10 ? 10 : apiKey.length)}..."');
    } else {
      debugPrint('✅ Gemini API key loaded (${apiKey.length} chars)');
    }
    
    if (tmdbApiKey.isEmpty || tmdbApiKey.length < 30) {
      debugPrint('⚠️ WARNING: TMDB API key looks invalid (length: ${tmdbApiKey.length})');
    } else {
      debugPrint('✅ TMDB API key loaded (${tmdbApiKey.length} chars)');
    }
  }

  // Upload video to Gemini
  Future<String?> uploadVideoToGemini(
    Uint8List videoBytes,
    String fileName,
    String mimeType,
  ) async {
    final uploadUrl = Uri.parse(
      'https://generativelanguage.googleapis.com/upload/v1beta/files?key=$apiKey',
    );
    
    try {
      debugPrint('⬆️ Uploading to Gemini...');
      debugPrint('   File: $fileName');
      debugPrint('   Size: ${videoBytes.length} bytes');
      debugPrint('   MIME: $mimeType');
      debugPrint('   URL: ${uploadUrl.toString().replaceAll(apiKey, "***")}');
      
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
      
      debugPrint('   Sending request...');
      var streamedResponse = await request.send();
      
      debugPrint('   Got response: ${streamedResponse.statusCode}');
      var response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final uploadResult = jsonDecode(response.body);
        final fileInfo = uploadResult['file'];
        final fileName = fileInfo?['name'] as String?;
        debugPrint('✅ Upload success: $fileName');
        return fileName;
      } else {
        debugPrint('❌ Upload error (${response.statusCode})');
        debugPrint('   Response body: ${response.body}');
        
        // Parse error for better message
        try {
          final errorData = jsonDecode(response.body);
          final errorMsg = errorData['error']?['message'] ?? 'Unknown error';
          debugPrint('   Error message: $errorMsg');
        } catch (_) {}
        
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Upload exception: $e');
      debugPrint('   Stack trace: ${stackTrace.toString().split('\n').take(3).join('\n')}');
      return null;
    }
  }

  // Wait for file processing
  Future<bool> waitForFileProcessing(String fileNameForModel) async {
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

  // Delete file from Gemini
  Future<void> deleteFileFromGemini(String? fileNameForModel) async {
    if (fileNameForModel == null) return;
    final deleteUrl = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/$fileNameForModel?key=$apiKey',
    );
    try {
      await http.delete(deleteUrl);
    } catch (_) {}
  }

  // Analyze video with Gemini AI
  Future<Map<String, String>?> analyzeVideo(
    String fileNameForModel,
    String mimeType,
  ) async {
    const modelName = 'gemini-2.5-flash';
    final analyzeUrl = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey',
    );

    try {
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
          final resultText =
              jsonResponse['candidates'][0]['content']['parts'][0]['text'];
          
          final parts = resultText.trim().split('|');
          if (parts.length >= 3) {
            return {
              'title': parts[0].trim(),
              'year': parts[1].trim(),
              'type': parts[2].trim().toLowerCase(),
            };
          }
        }
      } else {
        debugPrint('❌ Error from Gemini: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Analyze exception: $e');
    }
    return null;
  }

  // Search in TMDB database
  Future<Map<String, dynamic>?> searchInTMDB(
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
      debugPrint('❌ TMDB Search Error: $e');
    }
    return null;
  }

  // Helper: Get MIME type from filename
  String getMimeType(String fileName) {
    final name = fileName.toLowerCase();
    if (name.endsWith('.mov')) return 'video/quicktime';
    if (name.endsWith('.avi')) return 'video/x-msvideo';
    if (name.endsWith('.mkv')) return 'video/x-matroska';
    if (name.endsWith('.webm')) return 'video/webm';
    return 'video/mp4';
  }

  /// Analyze multiple frames together and get 4 movie suggestions
  Future<List<Map<String, dynamic>>?> analyzeMultipleFramesForSuggestions(
    List<String> frameFiles,
  ) async {
    if (frameFiles.isEmpty) return null;

    const modelName = 'gemini-2.5-flash';
    final analyzeUrl = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey',
    );

    try {
      debugPrint('🎬 Analyzing ${frameFiles.length} frames for suggestions...');

      // Create file references
      final fileParts = frameFiles.map((file) {
        return {
          "fileData": {
            "mimeType": "image/jpeg",
            "fileUri": "https://generativelanguage.googleapis.com/v1beta/$file"
          }
        };
      }).toList();

      // Enhanced prompt for 4 suggestions
      final prompt = '''Analyze these ${frameFiles.length} frames from a screen and identify the movie or TV show.

Provide EXACTLY 4 possibilities in pure JSON format.

Requirements:
- Pure JSON array only, no markdown, no text, no backticks
- Exactly 4 objects
- Each object: {"title":"Name","year":"2020","type":"movie","confidence":"high"}
- type: must be "movie" or "tv"
- confidence: must be "high", "medium", or "low"

Example:
[{"title":"Inception","year":"2010","type":"movie","confidence":"high"},{"title":"Interstellar","year":"2014","type":"movie","confidence":"medium"},{"title":"Tenet","year":"2020","type":"movie","confidence":"medium"},{"title":"The Matrix","year":"1999","type":"movie","confidence":"low"}]

Return only the JSON array:''';

      final requestBody = {
        "contents": [
          {
            "parts": [
              ...fileParts,
              {"text": prompt}
            ]
          }
        ],
        "generationConfig": {
          "temperature": 0.4,
          "topK": 32,
          "topP": 1,
          "maxOutputTokens": 2048,
        }
      };

      final response = await http.post(
        analyzeUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        debugPrint('❌ Gemini API Error: ${response.statusCode}');
        debugPrint('Response: ${response.body}');
        return null;
      }

      final data = jsonDecode(response.body);
      
      if (data['candidates'] == null || data['candidates'].isEmpty) {
        debugPrint('❌ No candidates in response');
        return null;
      }

      final text = data['candidates'][0]['content']['parts'][0]['text'];
      debugPrint('📝 Gemini response (${text.length} chars): $text');

      // Clean and parse JSON
      String cleanText = text.trim();
      
      // Remove markdown code blocks
      if (cleanText.startsWith('```json')) {
        cleanText = cleanText.substring(7);
      } else if (cleanText.startsWith('```')) {
        cleanText = cleanText.substring(3);
      }
      
      if (cleanText.endsWith('```')) {
        cleanText = cleanText.substring(0, cleanText.length - 3);
      }
      
      cleanText = cleanText.trim();

      // ✅ Try to fix incomplete JSON
      if (!cleanText.endsWith(']')) {
        debugPrint('⚠️ JSON incomplete, attempting to fix...');
        
        // Find last complete object
        int lastCompleteIndex = cleanText.lastIndexOf('},');
        if (lastCompleteIndex > 0) {
          cleanText = cleanText.substring(0, lastCompleteIndex + 1);
          cleanText += '\n]';
          debugPrint('🔧 Fixed JSON by closing array');
        } else {
          // Try to close current object
          int lastOpenBrace = cleanText.lastIndexOf('{');
          if (lastOpenBrace > 0) {
            cleanText = cleanText.substring(0, lastOpenBrace);
            if (cleanText.endsWith(',')) {
              cleanText = cleanText.substring(0, cleanText.length - 1);
            }
            cleanText += '\n]';
            debugPrint('🔧 Fixed JSON by removing incomplete object');
          }
        }
      }

      debugPrint('🔍 Attempting to parse JSON (${cleanText.length} chars)...');

      List<dynamic> parsed;
      try {
        parsed = jsonDecode(cleanText);
      } catch (e) {
        debugPrint('❌ JSON parse failed: $e');
        debugPrint('📄 Clean text: $cleanText');
        
        // Last resort: try to extract complete objects manually
        final objects = <Map<String, dynamic>>[];
        final regex = RegExp(r'\{[^}]+\}', multiLine: true);
        final matches = regex.allMatches(cleanText);
        
        for (final match in matches) {
          try {
            final obj = jsonDecode(match.group(0)!);
            if (obj is Map && obj.containsKey('title')) {
              objects.add(Map<String, dynamic>.from(obj));
            }
          } catch (_) {}
        }
        
        if (objects.isEmpty) {
          debugPrint('❌ Could not extract any valid objects');
          return null;
        }
        
        debugPrint('✅ Extracted ${objects.length} objects manually');
        parsed = objects;
      }
      
      final List<Map<String, dynamic>> suggestions = parsed.map((item) {
        return {
          'title': item['title']?.toString() ?? 'Unknown',
          'year': item['year']?.toString() ?? '2020',
          'type': item['type']?.toString().toLowerCase() ?? 'movie',
          'confidence': item['confidence']?.toString() ?? 'medium',
        };
      }).toList();

      // Ensure we have at least 1 suggestion
      if (suggestions.isEmpty) {
        debugPrint('❌ No valid suggestions extracted');
        return null;
      }

      debugPrint('✅ Parsed ${suggestions.length} suggestions');
      for (int i = 0; i < suggestions.length; i++) {
        debugPrint('  ${i + 1}. ${suggestions[i]['title']} (${suggestions[i]['year']}) - ${suggestions[i]['confidence']}');
      }

      return suggestions;

    } catch (e, stackTrace) {
      debugPrint('❌ Error analyzing frames: $e');
      debugPrint('Stack trace: ${stackTrace.toString().split('\n').take(3).join('\n')}');
      return null;
    }
  }
}
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
  });

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
}
// frame_analyzer.dart - Frame analysis service for live detection

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../services/gemini_service.dart';

class FrameAnalyzer {
  final GeminiService geminiService;
  
  // Analysis state
  bool _isAnalyzing = false;
  Map<String, int> _detectionVotes = {};
  int _totalFramesAnalyzed = 0;
  int _frameInterval = 0;
  
  // Thresholds
  static const int minFramesToAnalyze = 2; // 🆕 En az 2 frame topla
  static const int maxFramesToAnalyze = 7; // Max 7 frame'e kadar dene
  static const int frameIntervalSeconds = 1; // 1 saniye aralık
  
  FrameAnalyzer({required this.geminiService});

  bool get isAnalyzing => _isAnalyzing;
  int get totalFramesAnalyzed => _totalFramesAnalyzed;
  int get frameInterval => _frameInterval;

  // Start frame analysis
  void startAnalysis() {
    _isAnalyzing = true;
    _detectionVotes.clear();
    _totalFramesAnalyzed = 0;
    _frameInterval = 0;
    debugPrint('🎬 Starting frame analysis...');
  }

  // Stop frame analysis
  void stopAnalysis() {
    _isAnalyzing = false;
    debugPrint('⏹️ Stopped frame analysis');
  }

  // Reset analyzer
  void reset() {
    _isAnalyzing = false;
    _detectionVotes.clear();
    _totalFramesAnalyzed = 0;
    _frameInterval = 0;
    debugPrint('🔄 Frame analyzer reset');
  }

  // Check if ready to capture next frame
  bool shouldCaptureFrame() {
    return _frameInterval >= frameIntervalSeconds;
  }

  // Increment frame interval counter
  void incrementInterval() {
    _frameInterval++;
  }

  // Reset frame interval
  void resetInterval() {
    _frameInterval = 0;
  }

  // Analyze a single frame
  Future<Map<String, dynamic>?> analyzeFrame(Uint8List frameBytes) async {
    if (!_isAnalyzing || _totalFramesAnalyzed >= maxFramesToAnalyze) {
      debugPrint('⚠️ Cannot analyze: isAnalyzing=$_isAnalyzing, framesAnalyzed=$_totalFramesAnalyzed/$maxFramesToAnalyze');
      return null;
    }

    try {
      debugPrint('📸 Analyzing frame ${_totalFramesAnalyzed + 1}/$maxFramesToAnalyze...');

      // 1. Upload frame to Gemini
      debugPrint('⬆️ Uploading frame to Gemini...');
      final fileName = 'frame_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final fileNameForModel = await geminiService.uploadVideoToGemini(
        frameBytes,
        fileName,
        'image/jpeg',
      );

      if (fileNameForModel == null) {
        debugPrint('❌ Failed to upload frame');
        return null;
      }
      debugPrint('✅ Frame uploaded: $fileNameForModel');

      // 2. Wait for processing
      debugPrint('⏳ Waiting for Gemini processing...');
      final isReady = await geminiService.waitForFileProcessing(fileNameForModel);
      if (!isReady) {
        debugPrint('❌ Frame processing failed');
        await geminiService.deleteFileFromGemini(fileNameForModel);
        return null;
      }
      debugPrint('✅ Frame ready for analysis');

      // 3. Analyze with Gemini AI
      debugPrint('🤖 Analyzing with Gemini AI...');
      final result = await geminiService.analyzeVideo(fileNameForModel, 'image/jpeg');
      
      // 4. Clean up uploaded file
      await geminiService.deleteFileFromGemini(fileNameForModel);

      if (result == null) {
        debugPrint('❌ No result from Gemini');
        return null;
      }

      debugPrint('🔍 Gemini returned: ${result.toString()}'); // 🆕 Tüm cevabı göster

      _totalFramesAnalyzed++;

      // 5. Process detection result
      final movieKey = '${result['title']}|${result['year']}';
      _detectionVotes[movieKey] = (_detectionVotes[movieKey] ?? 0) + 1;

      debugPrint('✅ Frame analyzed: ${result['title']} (${result['year']}) [Type: ${result['type']}]');
      debugPrint('📊 Current detections: $_detectionVotes');
      debugPrint('📈 Total frames analyzed: $_totalFramesAnalyzed/$maxFramesToAnalyze');

      // 6. Check if we have at least 2 frames analyzed
      if (_totalFramesAnalyzed >= minFramesToAnalyze) {
        // Get the most common detection
        final mostCommon = _getMostCommonDetection();
        if (mostCommon != null) {
          debugPrint('🎯 Movie detected after $_totalFramesAnalyzed frames!');
          return mostCommon;
        }
      }

      // 7. Check if we've reached max frames
      if (_totalFramesAnalyzed >= maxFramesToAnalyze) {
        // Return most voted result even if not confident
        final mostVoted = _getMostVotedResult();
        if (mostVoted != null) {
          debugPrint('🎯 Max frames reached, returning most common result');
          return mostVoted;
        }
        debugPrint('⚠️ Max frames reached but no clear result');
      }

      return null; // Need more frames
    } catch (e) {
      debugPrint('❌ Frame analysis error: $e');
      return null;
    }
  }

  // Get the most common detection (after at least 2 frames)
  Map<String, dynamic>? _getMostCommonDetection() {
    if (_detectionVotes.isEmpty) return null;

    // Find the most voted movie
    String? topKey;
    int maxVotes = 0;

    _detectionVotes.forEach((key, votes) {
      if (votes > maxVotes) {
        maxVotes = votes;
        topKey = key;
      }
    });

    if (topKey == null) return null;

    final parts = topKey!.split('|');
    
    // Return as Map<String, dynamic> to match expected type
    return {
      'title': parts[0],
      'year': parts[1],
      'type': 'movie', // Will be refined in TMDB search
    };
  }

  // Get the most voted detection result
  Map<String, String>? _getMostVotedResult() {
    if (_detectionVotes.isEmpty) return null;

    String? mostVotedKey;
    int maxVotes = 0;

    _detectionVotes.forEach((key, votes) {
      if (votes > maxVotes) {
        maxVotes = votes;
        mostVotedKey = key;
      }
    });

    if (mostVotedKey == null) return null;

    final parts = mostVotedKey!.split('|');
    return {
      'title': parts[0],
      'year': parts[1],
      'type': 'movie', // Default to movie, will be refined in TMDB search
    };
  }

  // Get detection progress as percentage
  double getProgress() {
    return (_totalFramesAnalyzed / maxFramesToAnalyze).clamp(0.0, 1.0);
  }

  // Get detection statistics
  Map<String, dynamic> getStatistics() {
    return {
      'framesAnalyzed': _totalFramesAnalyzed,
      'maxFrames': maxFramesToAnalyze,
      'detectionVotes': Map.from(_detectionVotes),
      'isAnalyzing': _isAnalyzing,
    };
  }

  // Get current leading detection
  String? getLeadingDetection() {
    if (_detectionVotes.isEmpty) return null;

    String? leadingKey;
    int maxVotes = 0;

    _detectionVotes.forEach((key, votes) {
      if (votes > maxVotes) {
        maxVotes = votes;
        leadingKey = key;
      }
    });

    if (leadingKey == null) return null;
    
    final parts = leadingKey!.split('|');
    return '${parts[0]} (${parts[1]})';
  }
}
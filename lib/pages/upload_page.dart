// upload_page.dart - Shazam-inspired main page with side drawers

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
import 'package:provider/provider.dart';

import '../services/tmdb_service.dart';
import '../services/auth_service.dart';
import 'info_page.dart';
import '../home_main.dart';
import '../screens/login_page.dart';

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
  final AuthService _authService = AuthService();
  late final TMDBService tmdbService;

  String get apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  String get tmdbApiKey => dotenv.env['TMDB_API_KEY'] ?? '';

  // --- UI State ---
  String status = "Ready to identify movies and TV shows";
  Map<String, dynamic>? movieData;
  List<Map<String, dynamic>> history = [];
  User? _currentUser;

  bool isPicking = false;
  bool _isAnalyzing = false;
  bool _isLoadingHistory = true;

  int _runId = 0;

  // Pulse animation for the camera button
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  static const int _historyLimit = 50;
  static const int _maxVideoMB = 100;

  // Avatar Assets
  final List<String> _avatarAssets = const [
    'assets/avatars/AAGRBT0C7xk_1765710192725.png',
    'assets/avatars/AAGRBT0C7xk_1765710192730.png',
    'assets/avatars/AAGRBT0C7xk_1765710388485.png',
    'assets/avatars/AAGRBT0C7xk_1765710388489.png',
    'assets/avatars/AAGRBT0C7xk_1765710388506.png',
    'assets/avatars/AAGRBT0C7xk_1765710568040.png',
    'assets/avatars/AAGRBT0C7xk_1765710568053.png',
    'assets/avatars/AAGRBT0C7xk_1765710568056.png',
  ];

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
    _loadUserData();

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

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    await user?.reload();

    setState(() {
      _currentUser = FirebaseAuth.instance.currentUser;
    });
  }

  String get email => _currentUser?.email ?? "Email not found.";

  String get username {
    if (_currentUser?.displayName != null &&
        _currentUser!.displayName!.isNotEmpty) {
      return _currentUser!.displayName!;
    }
    return _currentUser?.email?.split('@')[0] ?? "User";
  }

  bool get isEmailPasswordUser {
    if (_currentUser == null) return false;
    return _currentUser!.providerData.any(
      (info) => info.providerId == 'password',
    );
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

        debugPrint('✅ Film already in history, timestamp updated');
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

      debugPrint('✅ New film added to history');
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

      setState(() {
        history.removeAt(index);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Removed from history'),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFF6A0DAD),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing: $e'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDeleteConfirmation(int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        title: Text(
          'Remove from history?',
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        content: Text(
          'This will remove the movie from your recent searches.',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteFromHistory(index);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
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
        await _analyzeVideoFromFile(
          file: file,
          currentRun: currentRun,
        );
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
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=$apiKey');

      final base64Video = base64Encode(bytes);

      final requestBody = {
        "contents": [
          {
            "parts": [
              {"text": _prompt},
              {
                "inline_data": {
                  "mime_type": "video/mp4",
                  "data": base64Video,
                }
              }
            ]
          }
        ],
        "generationConfig": {
          "temperature": 0.4,
          "topK": 32,
          "topP": 1,
          "maxOutputTokens": 512,
        }
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
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=$apiKey');

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
              {"text": _prompt}
            ]
          }
        ],
        "generationConfig": {
          "temperature": 0.4,
          "topK": 32,
          "topP": 1,
          "maxOutputTokens": 512,
        }
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
      // searchMulti kullanarak ara
      final allResults = await tmdbService.searchMulti(title, limit: 20);
      
      if (currentRun != _runId || !mounted) return;

      // Sonuçları filtrele: tip ve yıl eşleşmesi
      final filtered = allResults.where((item) {
        final itemType = (item['type'] ?? '').toString().toLowerCase();
        final itemYear = (item['year'] ?? '').toString();
        
        // Tip eşleşmeli
        if (itemType != type) return false;
        
        // Yıl varsa ve eşleşiyorsa, ideal sonuç
        if (itemYear.isNotEmpty && itemYear == year) return true;
        
        // Yıl yoksa veya ±2 yıl içindeyse kabul et
        if (itemYear.isNotEmpty) {
          final yearInt = int.tryParse(year);
          final itemYearInt = int.tryParse(itemYear);
          if (yearInt != null && itemYearInt != null) {
            return (yearInt - itemYearInt).abs() <= 2;
          }
        }
        
        return true; // Yıl bilgisi yoksa da kabul et
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
  // PROFILE FUNCTIONS
  // ----------------------------

  Future<void> _updateProfilePicture(String newAssetPath) async {
    try {
      await _currentUser?.updatePhotoURL(newAssetPath);
      await _loadUserData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Profile picture updated! ✅',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Color(0xFF6A0DAD),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: $e',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showAvatarSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          "Select Profile Picture",
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            itemCount: _avatarAssets.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (context, index) {
              final assetPath = _avatarAssets[index];

              return GestureDetector(
                onTap: () async {
                  Navigator.pop(context);
                  await _updateProfilePicture(assetPath);
                },
                child: ClipOval(
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      border: Border.all(color: Colors.white24, width: 1.0),
                    ),
                    child: Image.asset(
                      assetPath,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    String currentPassword = '';
    String newPassword = '';
    String confirmPassword = '';
    String? errorMessage;
    final formKey = GlobalKey<FormState>();
    final dialogContext = context;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          title: const Text(
            "Change Password",
            style: TextStyle(color: Colors.white),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade700),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            color: Colors.red.shade300, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorMessage!,
                            style: TextStyle(
                              color: Colors.red.shade300,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                TextFormField(
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  onChanged: (value) {
                    currentPassword = value;
                    if (errorMessage != null) {
                      setState(() => errorMessage = null);
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: "Current Password",
                    labelStyle: TextStyle(color: Colors.white70),
                    hintText: "Enter current password",
                    hintStyle: TextStyle(color: Colors.white38),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF6A0DAD)),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Current password is required.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  onChanged: (value) => newPassword = value,
                  decoration: const InputDecoration(
                    labelText: "New Password",
                    labelStyle: TextStyle(color: Colors.white70),
                    hintText: "Enter new password",
                    hintStyle: TextStyle(color: Colors.white38),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF6A0DAD)),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'New password is required';
                    }
                    if (value.length < 6) {
                      return 'Password must be 6 characters minimum';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  onChanged: (value) => confirmPassword = value,
                  decoration: const InputDecoration(
                    labelText: "Confirm New Password",
                    labelStyle: TextStyle(color: Colors.white70),
                    hintText: "Confirm new password",
                    hintStyle: TextStyle(color: Colors.white38),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF6A0DAD)),
                    ),
                  ),
                  validator: (value) {
                    if (value != newPassword) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6A0DAD),
              ),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  showDialog(
                    context: dialogContext,
                    barrierDismissible: false,
                    builder: (BuildContext loadingContext) {
                      return Container(
                        color: Colors.black54,
                        child: const Center(
                          child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      );
                    },
                  );

                  try {
                    final credential = EmailAuthProvider.credential(
                      email: email,
                      password: currentPassword,
                    );

                    await _currentUser
                        ?.reauthenticateWithCredential(credential);
                    await _currentUser?.updatePassword(newPassword);

                    if (mounted) {
                      Navigator.of(dialogContext, rootNavigator: true).pop();
                      Navigator.of(dialogContext, rootNavigator: true).pop();

                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Password updated! ✅',
                              style: TextStyle(color: Colors.white)),
                          backgroundColor: Color(0xFF6A0DAD),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } on FirebaseAuthException catch (e) {
                    String newErrorMessage = 'Unknown error';

                    if (e.code == 'wrong-password' ||
                        e.code == 'invalid-credential') {
                      newErrorMessage = 'Current password is incorrect.';
                    } else if (e.code == 'weak-password') {
                      newErrorMessage = 'Password is too weak';
                    } else if (e.code == 'requires-recent-login') {
                      newErrorMessage =
                          'Please log out and log in again for security.';
                    } else {
                      newErrorMessage = 'An error occurred: ${e.message}';
                    }

                    if (mounted) {
                      Navigator.of(dialogContext, rootNavigator: true).pop();
                      setState(() {
                        errorMessage = newErrorMessage;
                      });
                    }
                  } catch (e) {
                    if (mounted) {
                      Navigator.of(dialogContext, rootNavigator: true).pop();
                      setState(() {
                        errorMessage = 'An unexpected error occurred';
                      });

                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(
                          content: Text('❌ Error: $e',
                              style: const TextStyle(color: Colors.white)),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text("Change"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Sign Out',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _authService.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  }

  // ----------------------------
  // UI BUILDERS
  // ----------------------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.black,
      endDrawer: _buildProfileDrawer(isDark),
      drawer: _buildHistoryDrawer(isDark),
      body: SafeArea(
        child: Stack(
          children: [
            // Main Content
            Column(
              children: [
                // Top Bar
                _buildTopBar(isDark),

                // Main Content Area
                Expanded(
                  child: _buildMainContent(isDark),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 0.5,
          ),
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

  Widget _buildMainContent(bool isDark) {
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
              style: TextStyle(
                fontSize: 16,
                color: Colors.white60,
              ),
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
              style: TextStyle(
                fontSize: 16,
                color: Colors.white60,
              ),
            ),
          ],

          // Movie Result Card
          if (movieData != null) ...[
            Container(
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Poster
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: movieData!['poster'] != null &&
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
                        const Icon(Icons.star,
                            color: Colors.amber, size: 18),
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
                              vertical: 14, horizontal: 20),
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

  Widget _buildHistoryDrawer(bool isDark) {
    return Drawer(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withOpacity(0.1),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.history, color: Color(0xFF6A0DAD), size: 28),
                  const SizedBox(width: 12),
                  const Text(
                    'History',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  if (history.isNotEmpty)
                    Text(
                      '${history.length}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white60,
                      ),
                    ),
                ],
              ),
            ),

            // History List
            Expanded(
              child: _isLoadingHistory
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF6A0DAD),
                      ),
                    )
                  : history.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.history,
                                size: 64,
                                color: Colors.white24,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No history yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white60,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: history.length,
                          itemBuilder: (context, index) {
                            final movie = history[index];
                            final poster = (movie['poster'] ?? '').toString();
                            final title = (movie['title'] ?? '').toString();
                            final year = (movie['year'] ?? '').toString();

                            return InkWell(
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => InfoPage(
                                      id: movie['id'],
                                      title: title,
                                      type: movie['type'] ?? 'movie',
                                    ),
                                  ),
                                );
                              },
                              onLongPress: () =>
                                  _showDeleteConfirmation(index),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    // Poster
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: SizedBox(
                                        width: 50,
                                        height: 75,
                                        child: poster.isNotEmpty
                                            ? Image.network(
                                                poster,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    Container(
                                                  color: Colors.grey.shade800,
                                                  child: const Icon(
                                                    Icons.broken_image,
                                                    color: Colors.white54,
                                                    size: 24,
                                                  ),
                                                ),
                                              )
                                            : Container(
                                                color: Colors.grey.shade800,
                                                child: const Icon(
                                                  Icons.movie,
                                                  color: Colors.white54,
                                                  size: 24,
                                                ),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // Info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                          if (year.isNotEmpty)
                                            Text(
                                              year,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Colors.white60,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
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

  Widget _buildProfileDrawer(bool isDark) {
    final photoURL = _currentUser?.photoURL;

    return Drawer(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            // Profile Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withOpacity(0.1),
                    width: 0.5,
                  ),
                ),
              ),
              child: Column(
                children: [
                  // Profile Picture
                  GestureDetector(
                    onTap: _showAvatarSelectionDialog,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: const Color(0xFF6A0DAD),
                          backgroundImage: photoURL != null &&
                                  photoURL.isNotEmpty
                              ? (photoURL.startsWith('http')
                                  ? NetworkImage(photoURL)
                                  : AssetImage(photoURL) as ImageProvider)
                              : null,
                          child: photoURL == null || photoURL.isEmpty
                              ? const Icon(Icons.person,
                                  size: 50, color: Colors.white)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFF6A0DAD),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Username
                  Text(
                    username,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Email
                  Text(
                    email,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
            ),

            // Options
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(8),
                children: [
                  // Change Password
                  if (isEmailPasswordUser)
                    ListTile(
                      leading: const Icon(Icons.lock_outline,
                          color: Colors.white70),
                      title: const Text(
                        'Change Password',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: _showChangePasswordDialog,
                    ),

                  // Dark Theme Toggle
                  ListTile(
                    leading: const Icon(Icons.dark_mode_outlined,
                        color: Colors.white70),
                    title: const Text(
                      'Dark Theme',
                      style: TextStyle(color: Colors.white),
                    ),
                    trailing: Switch(
                      value: Provider.of<ThemeProvider>(context).isDark,
                      onChanged: (_) {
                        Provider.of<ThemeProvider>(context, listen: false)
                            .toggleTheme();
                      },
                      activeColor: const Color(0xFF6A0DAD),
                    ),
                  ),
                ],
              ),
            ),

            // Sign Out Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withOpacity(0.1),
                    width: 0.5,
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _signOut,
                  child: const Text(
                    'Sign Out',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
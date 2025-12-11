import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../home_main.dart';
import 'info_page.dart';

class MovieListDetailPage extends StatefulWidget {
  final String listId;
  final String listName;

  const MovieListDetailPage({
    super.key,
    required this.listId,
    required this.listName,
  });

  @override
  State<MovieListDetailPage> createState() => _MovieListDetailPageState();
}

class _MovieListDetailPageState extends State<MovieListDetailPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get userId => _auth.currentUser?.uid ?? '';

  /// silme / seçim modu açık mı
  bool _selectionMode = false;

  /// seçili film doküman id'leri
  final Set<String> _selectedMovieDocIds = {};

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      _selectedMovieDocIds.clear();
    });
  }

  void _onMovieTap({
    required String docId,
    required int movieId,
    required String title,
    required String type,
  }) {
    if (_selectionMode) {
      // seçim modunda: sadece seç / seçimi kaldır
      setState(() {
        if (_selectedMovieDocIds.contains(docId)) {
          _selectedMovieDocIds.remove(docId);
        } else {
          _selectedMovieDocIds.add(docId);
        }
      });
    } else {
      // normal mod: InfoPage'e git
      if (movieId != 0) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InfoPage(id: movieId, title: title, type: type),
          ),
        );
      }
    }
  }

  Future<void> _deleteSelectedMovies() async {
    if (_selectedMovieDocIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select movies to delete'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        title: Text(
          'Delete selected',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          'Remove ${_selectedMovieDocIds.length} movie(s) from this list?',
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // seçili her filmi sil
      for (final docId in _selectedMovieDocIds) {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('lists')
            .doc(widget.listId)
            .collection('movies')
            .doc(docId)
            .delete();
      }

      // movieCount güncelle
      final listRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('lists')
          .doc(widget.listId);

      final listSnap = await listRef.get();
      final currentCount = (listSnap.data()?['movieCount'] ?? 0) as int;
      final newCount = (currentCount - _selectedMovieDocIds.length);
      await listRef.update({'movieCount': newCount < 0 ? 0 : newCount});

      setState(() {
        _selectionMode = false;
        _selectedMovieDocIds.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected movies removed from list'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDark;

    final backgroundColor = Colors.black; // tüm sayfa siyah
    final gridBackground =
        isDark ? const Color(0xFF1A1A1A) : Colors.grey.shade100; // poster alanı gri

    return Container(
      decoration: BoxDecoration(color: backgroundColor),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: isDark ? Colors.white : Colors.black87,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            _selectionMode
                ? '${widget.listName} (${_selectedMovieDocIds.length})'
                : widget.listName,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          actions: [
            // Çöp / Çarpı butonu
            IconButton(
              icon: Icon(
                _selectionMode ? Icons.close : Icons.delete_outline,
                color: isDark ? Colors.white : Colors.black87,
              ),
              onPressed: _toggleSelectionMode,
            ),

            // Sil onayı (sadece seçim modunda ve en az 1 seçim varsa)
            if (_selectionMode)
              IconButton(
                icon: const Icon(Icons.check),
                color: _selectedMovieDocIds.isEmpty
                    ? Colors.grey
                    : (isDark ? Colors.white : Colors.black87),
                onPressed: _selectedMovieDocIds.isEmpty
                    ? null
                    : _deleteSelectedMovies,
              ),
          ],
        ),
        body: Container(
          color: gridBackground,
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('users')
                .doc(userId)
                .collection('lists')
                .doc(widget.listId)
                .collection('movies')
                .orderBy('addedAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'An error occurred',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                // sadece ilk açılışta spinner
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFFC107)),
                );
              }

              final movies = snapshot.data?.docs ?? [];

              if (movies.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.movie_outlined,
                        size: 64,
                        color: isDark
                            ? Colors.white.withOpacity(0.7)
                            : Colors.black.withOpacity(0.6),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No movies in this list yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, // 3’lü grid
                  childAspectRatio: 0.66, // poster oranı ~2:3
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: movies.length,
                itemBuilder: (context, index) {
                  final doc = movies[index];
                  final docId = doc.id;
                  final movieData = doc.data() as Map<String, dynamic>;

                  final movieIdStr = movieData['id']?.toString() ?? '';
                  final movieId = int.tryParse(movieIdStr) ?? 0;
                  final title = movieData['title'] ?? '';
                  final posterUrl = movieData['poster'] ?? '';
                  final type = movieData['type'] ?? 'movie';

                  final isSelected = _selectedMovieDocIds.contains(docId);

                  return GestureDetector(
                    onTap: () => _onMovieTap(
                      docId: docId,
                      movieId: movieId,
                      title: title,
                      type: type,
                    ),
                    onLongPress: () {
                      if (!_selectionMode) {
                        _toggleSelectionMode();
                        setState(() {
                          _selectedMovieDocIds.add(docId);
                        });
                      }
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // POSTER
                          posterUrl.isNotEmpty
                              ? Image.network(
                                  posterUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.grey.shade800,
                                    child: const Icon(
                                      Icons.broken_image,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              : Container(
                                  color: Colors.grey.shade800,
                                  child: const Icon(
                                    Icons.movie,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),

                          // Seçim overlay’i
                          if (_selectionMode)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              color: isSelected
                                  ? Colors.white.withOpacity(0.25)
                                  : Colors.black.withOpacity(0.35),
                              child: Align(
                                alignment: Alignment.topRight,
                                child: Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: Icon(
                                    isSelected
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

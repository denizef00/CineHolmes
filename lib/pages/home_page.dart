import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/tmdb_service.dart';
import 'info_page.dart';
import 'library_provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final tmdb = TMDBService();
  final TextEditingController _searchCtrl = TextEditingController();

  bool _loadingTrending = true;
  List<Map<String, dynamic>> _trending = [];

  List<Map<String, dynamic>> _searchResults = [];
  bool _searching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadTrending();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadTrending() async {
    final data = await tmdb.fetchTrending();
    if (!mounted) return;
    setState(() {
      _trending = data;
      _loadingTrending = false;
    });
  }

  void _onSearchChanged(String value) {
    final text = value.trim();
    if (text.isEmpty) {
      setState(() {
        _searchResults = [];
        _searching = false;
      });
      return;
    }

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _searching = true);
      final results = await tmdb.searchMulti(text);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    });
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() {
      _searchResults = [];
      _searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool showingSearch =
        _searchCtrl.text.trim().isNotEmpty && _searchResults.isNotEmpty;

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search movies / TV shows...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: _clearSearch,
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          if (_searching) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: showingSearch ? _buildSearchList() : _buildTrendingGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingGrid() {
    if (_loadingTrending) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_trending.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadTrending,
        child: ListView(
          children: const [
            SizedBox(height: 200),
            Center(child: Text('No trending titles right now.')),
          ],
        ),
      );
    }

    final libraryProvider = Provider.of<LibraryProvider>(context);

    return RefreshIndicator(
      onRefresh: _loadTrending,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _trending.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.58, // Daha uzun yaparak alt metin için alan açtık
        ),
        itemBuilder: (context, index) {
          final item = _trending[index];
          final poster = item['poster'] as String? ?? '';
          final id = item['id'] as int;
          final isFav = libraryProvider.isInLibrary(id);

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InfoPage(
                    id: item['id'],
                    title: item['title'],
                    type: item['type'] ?? 'movie',
                  ),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2C),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(2, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Poster alanı - Expanded kullanarak esnek yap
                  Expanded(
                    flex: 7, // Poster için daha fazla alan
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(14),
                            ),
                            child: poster.isNotEmpty
                                ? Image.network(
                                    poster,
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
                                      Icons.broken_image,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        // Kalp ikonu - sağ üstte sabit
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () {
                              if (isFav) {
                                libraryProvider.removeFromLibrary(id);
                              } else {
                                libraryProvider.addToLibrary({
                                  'id': id,
                                  'title': item['title'],
                                  'poster': item['poster'],
                                  'type': item['type'],
                                  'year': item['year'],
                                  'rating': item['rating'],
                                });
                              }
                            },
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.black.withOpacity(0.6),
                              child: Icon(
                                isFav ? Icons.favorite : Icons.favorite_border,
                                color: isFav
                                    ? const Color(0xFF6A0DAD)
                                    : Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Alt bilgiler - Expanded ile esnek alan
                  Expanded(
                    flex: 2, // Alt bilgiler için yeterli alan
                    child: Container(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            item['title'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '⭐ ${item['rating'] ?? 'N/A'}  •  ${item['year'] ?? ''}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item['type'] == 'tv' ? 'TV Show' : 'Movie',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white38,
                            ),
                          ),
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
    );
  }

  Widget _buildSearchList() {
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final item = _searchResults[index];
        return ListTile(
          leading:
              item['poster'] != null && item['poster'].toString().isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    item['poster'],
                    width: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.broken_image),
                  ),
                )
              : const Icon(Icons.movie),
          title: Text(
            item['title'] ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${item['type'] == 'tv' ? 'TV Show' : 'Movie'} • ${item['year'] ?? ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InfoPage(
                  id: item['id'],
                  title: item['title'],
                  type: item['type'] ?? 'movie',
                ),
              ),
            );
          },
        );
      },
    );
  }
}

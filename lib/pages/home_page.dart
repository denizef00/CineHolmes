import 'dart:async';
import 'package:flutter/material.dart';

import '../services/tmdb_service.dart';
import 'info_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final tmdb = TMDBService();

  bool _loading = true;
  int _currentTabIndex = 0;

  List<Map<String, dynamic>> _movies = [];
  List<Map<String, dynamic>> _tvShows = [];

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _searching = false;
  List<Map<String, dynamic>> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _loadTrending();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTrending() async {
    final data = await tmdb.fetchTrending();
    if (!mounted) return;

    final movies = <Map<String, dynamic>>[];
    final tvs = <Map<String, dynamic>>[];

    for (final item in data) {
      final type = (item['type'] ?? '').toString();
      if (type == 'movie') {
        movies.add(item);
      } else if (type == 'tv') {
        tvs.add(item);
      }
    }

    setState(() {
      _movies = movies;
      _tvShows = tvs;
      _loading = false;
    });
  }

  void _onSearchChanged(String value) {
    final query = value.trim();

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) return;

    if (query.isEmpty) {
      setState(() {
        _searching = false;
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _searching = true;
    });

    final all = await tmdb.searchMulti(query, limit: 30);
    if (!mounted) return;

    final wantedType = _currentTabIndex == 0 ? 'movie' : 'tv';
    final filtered =
        all.where((m) => (m['type'] ?? '') == wantedType).toList();

    setState(() {
      _searchResults = filtered;
      _searching = false;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paddingTop = MediaQuery.of(context).padding.top;

    return DefaultTabController(
      length: 2,
      initialIndex: _currentTabIndex,
      child: Column(
        children: [
          // Instagram-style header with tabs
          Container(
            color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
            padding: EdgeInsets.only(top: paddingTop),
            child: Column(
              children: [
                // CineHolmes title
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
                
                // TabBar
                TabBar(
                  onTap: (index) {
                    setState(() {
                      _currentTabIndex = index;
                    });
                    final q = _searchController.text.trim();
                    if (q.isNotEmpty) {
                      _performSearch(q);
                    }
                  },
                  tabs: const [
                    Tab(text: 'Films'),
                    Tab(text: 'TV Shows'),
                  ],
                  labelColor: isDark ? Colors.white : Colors.black87,
                  unselectedLabelColor: isDark ? Colors.white70 : Colors.black54,
                  labelStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                  indicatorSize: TabBarIndicatorSize.label,
                  indicator: const UnderlineTabIndicator(
                    borderSide: BorderSide(
                      width: 3,
                      color: Color(0xFF6A0DAD),
                    ),
                    insets: EdgeInsets.symmetric(horizontal: 24),
                  ),
                  dividerColor: Colors.transparent,
                ),
              ],
            ),
          ),

          Expanded(
            child: Container(
              color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadTrending,
                      child: _buildScrollableContent(isDark),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollableContent(bool isDark) {
    final items = _currentTabIndex == 0 ? _movies : _tvShows;
    final hintText =
        _currentTabIndex == 0 ? 'Search films' : 'Search TV shows';
    final isSearching = _searchController.text.trim().isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        // Search bar
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(
                Icons.search,
                color: isDark ? Colors.white70 : Colors.black54,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
              if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                  onPressed: _clearSearch,
                  splashRadius: 18,
                ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        if (isSearching) ...[
          if (_searching)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_searchResults.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Center(
                child: Text(
                  'No results found.',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Results',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                ..._searchResults.map(_buildSearchTile),
              ],
            ),
        ] else ...[
          Text(
            'Popular this week',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40.0),
              child: Center(
                child: Text(
                  'No titles found for this week.',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.66,
              ),
              itemBuilder: (context, index) {
                final item = items[index];
                final poster = item['poster'] as String? ?? '';

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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: poster.isNotEmpty
                        ? Image.network(
                            poster,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
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
                );
              },
            ),
        ],
      ],
    );
  }

  Widget _buildSearchTile(Map<String, dynamic> item) {
    final poster = item['poster'] as String? ?? '';
    final title = (item['title'] ?? '') as String;
    final year = (item['year'] ?? '').toString();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InfoPage(
              id: item['id'],
              title: title,
              type: item['type'] ?? 'movie',
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 52,
                height: 78,
                child: poster.isNotEmpty
                    ? Image.network(
                        poster,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade800,
                          child: const Icon(
                            Icons.broken_image,
                            color: Colors.white54,
                            size: 20,
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.grey.shade800,
                        child: const Icon(
                          Icons.movie,
                          color: Colors.white54,
                          size: 20,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (year.isNotEmpty)
                    Text(
                      year,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
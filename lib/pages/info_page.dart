import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart'; // ✅ Provider ekle
import '../services/tmdb_service.dart';
import '../pages/library_provider.dart'; // ✅ LibraryProvider ekle

class InfoPage extends StatefulWidget {
  final int id;
  final String title;
  final String type; // "movie" | "tv"

  const InfoPage({
    super.key,
    required this.id,
    required this.title,
    required this.type,
  });

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  final tmdb = TMDBService();

  Map<String, dynamic>? _details;
  List<Map<String, dynamic>> _cast = [];
  List<Map<String, dynamic>> _reviews = [];
  List<Map<String, dynamic>> _similar = [];
  String? _trailer;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final detailsF = tmdb.fetchDetailsById(widget.id, widget.type);
    final castF = tmdb.fetchCast(widget.id, widget.type);
    final reviewsF = tmdb.fetchReviews(widget.id, widget.type);
    final similarF = tmdb.fetchSimilar(widget.id, widget.type);
    final trailerF = tmdb.fetchTrailer(widget.id, widget.type);

    final results = await Future.wait([
      detailsF,
      castF,
      reviewsF,
      similarF,
      trailerF,
    ]);

    if (!mounted) return;

    // similar'ı burada filtreleyelim: aynı type + poster'i var
    final rawSimilar = results[3] as List<Map<String, dynamic>>;
    final filteredSimilar = rawSimilar
        .where((s) {
          final poster = (s['poster'] ?? '').toString();
          final t = (s['type'] ?? widget.type).toString();
          return poster.isNotEmpty && t == widget.type;
        })
        .take(10)
        .toList();

    setState(() {
      _details = results[0] as Map<String, dynamic>?;
      _cast = results[1] as List<Map<String, dynamic>>;
      _reviews = results[2] as List<Map<String, dynamic>>;
      _similar = filteredSimilar;
      _trailer = results[4] as String?;
      _loading = false;
    });
  }

  Future<void> _openTrailer() async {
    if (_trailer == null) return;
    final uri = Uri.parse(_trailer!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_details == null || _details!.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(child: Text('No data found on TMDB.')),
      );
    }

    final isTv = _details!['type'] == 'tv';
    final poster = _details!['poster'] as String? ?? '';
    final genres = _details!['genres'] as List<dynamic>? ?? [];
    final rating = _details!['rating'] ?? 'N/A';
    final year = _details!['year'] ?? '';
    final overview = _details!['overview'] ?? '';
    final durationText = isTv
        ? 'Seasons: ${_details!['number_of_seasons'] ?? '-'}'
        : 'Duration: ${_details!['runtime'] ?? 0} min';

    return Scaffold(
      appBar: AppBar(
        title: Text(_details!['title'] ?? widget.title),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // POSTER
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: poster.isNotEmpty
                  ? Image.network(
                      poster,
                      height: 240,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 240,
                        color: Colors.grey.shade800,
                        child: const Icon(
                          Icons.broken_image,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : Container(
                      height: 240,
                      color: Colors.grey.shade800,
                      child: const Icon(
                        Icons.broken_image,
                        color: Colors.white,
                      ),
                    ),
            ),
            const SizedBox(height: 12),

            // TITLE
            Text(
              _details!['title'] ?? widget.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text('⭐ $rating  |  $year', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(durationText, style: theme.textTheme.bodySmall),

            // GENRES
            if (genres.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: genres
                    .map(
                      (g) => Chip(
                        label: Text(
                          g.toString(),
                          style: const TextStyle(color: Colors.white),
                        ),
                        backgroundColor: Colors.deepPurple.shade400,
                      ),
                    )
                    .toList(),
              ),
            ],

            const SizedBox(height: 14),

            // OVERVIEW
            Text(
              overview,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // CAST
            if (_cast.isNotEmpty) ...[
              _sectionTitle('Cast', theme),
              const SizedBox(height: 8),
              SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _cast.length,
                  itemBuilder: (context, index) {
                    final actor = _cast[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundImage: actor['profile'] != ''
                                ? NetworkImage(actor['profile'])
                                : null,
                            backgroundColor: Colors.grey.shade700,
                            child: actor['profile'] == ''
                                ? const Icon(Icons.person, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(height: 5),
                          SizedBox(
                            width: 70,
                            child: Text(
                              actor['name'],
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],

            // BUTTONS - ✅ DEĞİŞİKLİK BURADA
            Consumer<LibraryProvider>(
              builder: (context, libraryProvider, child) {
                final isInLibrary = libraryProvider.isInLibrary(widget.id);

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _trailer != null ? _openTrailer : null,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Watch Trailer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (isInLibrary) {
                          // Kütüphaneden çıkar
                          libraryProvider.removeFromLibrary(widget.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${_details!['title']} removed from library ❌',
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        } else {
                          // Kütüphaneye ekle
                          libraryProvider.addToLibrary({
                            'id': widget.id,
                            'title': _details!['title'] ?? widget.title,
                            'poster': poster,
                            'rating': rating.toString(),
                            'year': year.toString(),
                            'type': widget.type,
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${_details!['title']} added to library ✅',
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      icon: Icon(isInLibrary ? Icons.check : Icons.add),
                      label: Text(
                        isInLibrary ? 'In Library' : 'Add to Library',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isInLibrary ? Colors.green : null,
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            // REVIEWS
            if (_reviews.isNotEmpty) ...[
              _sectionTitle('Top Reviews', theme),
              const SizedBox(height: 8),
              ..._reviews.map((r) {
                return Card(
                  color: const Color(0xFF1E1E2C),
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r['author'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          r['content'],
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 20),
            ],

            // SIMILAR
            if (_similar.isNotEmpty) ...[
              _sectionTitle('Similar', theme),
              const SizedBox(height: 8),
              SizedBox(
                height: 190,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _similar.length,
                  itemBuilder: (context, index) {
                    final s = _similar[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => InfoPage(
                              id: s['id'],
                              title: s['title'],
                              type: s['type'] ?? widget.type,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: 120,
                        margin: const EdgeInsets.only(right: 12),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: s['poster'] != ''
                                  ? Image.network(
                                      s['poster'],
                                      height: 140,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        height: 140,
                                        color: Colors.grey.shade800,
                                        child: const Icon(
                                          Icons.broken_image,
                                          color: Colors.white,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      height: 140,
                                      color: Colors.grey.shade800,
                                      child: const Icon(
                                        Icons.broken_image,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              s['title'],
                              style: const TextStyle(fontSize: 12),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, ThemeData theme) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/*import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/tmdb_service.dart';

class InfoPage extends StatefulWidget {
  final int id;
  final String title;
  final String type; // "movie" | "tv"

  const InfoPage({
    super.key,
    required this.id,
    required this.title,
    required this.type,
  });

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  final tmdb = TMDBService();

  Map<String, dynamic>? _details;
  List<Map<String, dynamic>> _cast = [];
  List<Map<String, dynamic>> _reviews = [];
  List<Map<String, dynamic>> _similar = [];
  String? _trailer;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final detailsF = tmdb.fetchDetailsById(widget.id, widget.type);
    final castF = tmdb.fetchCast(widget.id, widget.type);
    final reviewsF = tmdb.fetchReviews(widget.id, widget.type);
    final similarF = tmdb.fetchSimilar(widget.id, widget.type);
    final trailerF = tmdb.fetchTrailer(widget.id, widget.type);

    final results = await Future.wait([
      detailsF,
      castF,
      reviewsF,
      similarF,
      trailerF,
    ]);

    if (!mounted) return;

    // similar’ı burada filtreleyelim: aynı type + poster’i var
    final rawSimilar = results[3] as List<Map<String, dynamic>>;
    final filteredSimilar = rawSimilar
        .where((s) {
          final poster = (s['poster'] ?? '').toString();
          final t = (s['type'] ?? widget.type).toString();
          return poster.isNotEmpty && t == widget.type;
        })
        .take(10)
        .toList();

    setState(() {
      _details = results[0] as Map<String, dynamic>?;
      _cast = results[1] as List<Map<String, dynamic>>;
      _reviews = results[2] as List<Map<String, dynamic>>;
      _similar = filteredSimilar;
      _trailer = results[4] as String?;
      _loading = false;
    });
  }

  Future<void> _openTrailer() async {
    if (_trailer == null) return;
    final uri = Uri.parse(_trailer!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_details == null || _details!.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(
          child: Text('No data found on TMDB.'),
        ),
      );
    }

    final isTv = _details!['type'] == 'tv';
    final poster = _details!['poster'] as String? ?? '';
    final genres = _details!['genres'] as List<dynamic>? ?? [];
    final rating = _details!['rating'] ?? 'N/A';
    final year = _details!['year'] ?? '';
    final overview = _details!['overview'] ?? '';
    final durationText = isTv
        ? 'Seasons: ${_details!['number_of_seasons'] ?? '-'}'
        : 'Duration: ${_details!['runtime'] ?? 0} min';

    return Scaffold(
      appBar: AppBar(
        title: Text(_details!['title'] ?? widget.title),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // POSTER
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: poster.isNotEmpty
                  ? Image.network(
                      poster,
                      height: 240,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 240,
                        color: Colors.grey.shade800,
                        child: const Icon(Icons.broken_image,
                            color: Colors.white),
                      ),
                    )
                  : Container(
                      height: 240,
                      color: Colors.grey.shade800,
                      child: const Icon(Icons.broken_image, color: Colors.white),
                    ),
            ),
            const SizedBox(height: 12),

            // TITLE
            Text(
              _details!['title'] ?? widget.title,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text('⭐ $rating  |  $year', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(durationText, style: theme.textTheme.bodySmall),

            // GENRES
            if (genres.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: genres
                    .map(
                      (g) => Chip(
                        label: Text(
                          g.toString(),
                          style: const TextStyle(color: Colors.white),
                        ),
                        backgroundColor: Colors.deepPurple.shade400,
                      ),
                    )
                    .toList(),
              ),
            ],

            const SizedBox(height: 14),

            // OVERVIEW
            Text(
              overview,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // CAST
            if (_cast.isNotEmpty) ...[
              _sectionTitle('Cast', theme),
              const SizedBox(height: 8),
              SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _cast.length,
                  itemBuilder: (context, index) {
                    final actor = _cast[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundImage: actor['profile'] != ''
                                ? NetworkImage(actor['profile'])
                                : null,
                            backgroundColor: Colors.grey.shade700,
                            child: actor['profile'] == ''
                                ? const Icon(Icons.person, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(height: 5),
                          SizedBox(
                            width: 70,
                            child: Text(
                              actor['name'],
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],

            // BUTTONS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _trailer != null ? _openTrailer : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Watch Trailer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Added to your library ✅'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add to Library'),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // REVIEWS
            if (_reviews.isNotEmpty) ...[
              _sectionTitle('Top Reviews', theme),
              const SizedBox(height: 8),
              ..._reviews.map((r) {
                return Card(
                  color: const Color(0xFF1E1E2C),
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r['author'],
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        const SizedBox(height: 5),
                        Text(
                          r['content'],
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 20),
            ],

            // SIMILAR
            if (_similar.isNotEmpty) ...[
              _sectionTitle('Similar', theme),
              const SizedBox(height: 8),
              SizedBox(
                height: 190,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _similar.length,
                  itemBuilder: (context, index) {
                    final s = _similar[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => InfoPage(
                              id: s['id'],
                              title: s['title'],
                              type: s['type'] ?? widget.type,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: 120,
                        margin: const EdgeInsets.only(right: 12),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: s['poster'] != ''
                                  ? Image.network(
                                      s['poster'],
                                      height: 140,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        height: 140,
                                        color: Colors.grey.shade800,
                                        child: const Icon(Icons.broken_image,
                                            color: Colors.white),
                                      ),
                                    )
                                  : Container(
                                      height: 140,
                                      color: Colors.grey.shade800,
                                      child: const Icon(Icons.broken_image,
                                          color: Colors.white),
                                    ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              s['title'],
                              style: const TextStyle(fontSize: 12),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, ThemeData theme) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style:
            theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}*/

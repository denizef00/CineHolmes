import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';

import '../services/tmdb_service.dart';
import '../pages/library_provider.dart';

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

  bool _showTopBar = false;

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

  void _handleScroll(double offset) {
    final shouldShow = offset > 140;
    if (shouldShow != _showTopBar) {
      setState(() {
        _showTopBar = shouldShow;
      });
    }
  }

  void _showLibrarySnack(
    BuildContext context,
    String message, {
    required bool added,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              added ? Icons.check_circle : Icons.remove_circle,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor:
            added ? const Color(0xFF1B5E20) : const Color(0xFFB71C1C),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: kBottomNavigationBarHeight + 16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFF202124),
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          title: Text(widget.title),
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_details == null || _details!.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF202124),
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          title: Text(widget.title),
          centerTitle: true,
        ),
        body: const Center(
          child: Text(
            'No data found on TMDB.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    final isTv = _details!['type'] == 'tv';
    final poster = _details!['poster'] as String? ?? '';
    final backdrop = _details!['backdrop'] as String? ?? '';
    final genres = _details!['genres'] as List<dynamic>? ?? [];
    final rating = _details!['rating'] ?? 'N/A';
    final year = _details!['year'] ?? '';
    final overview = _details!['overview'] ?? '';
    final durationText = isTv
        ? 'Seasons: ${_details!['number_of_seasons'] ?? '-'}'
        : 'Duration: ${_details!['runtime'] ?? 0} min';

    final titleText = _details!['title'] ?? widget.title;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF202124),
      appBar: AppBar(
        backgroundColor: _showTopBar ? Colors.black : Colors.transparent,
        elevation: _showTopBar ? 1 : 0,
        centerTitle: true,
        title: _showTopBar
            ? Text(
                titleText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        automaticallyImplyLeading: _showTopBar,
      ),
      body: SafeArea(
        top: false,
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollUpdateNotification) {
              _handleScroll(notification.metrics.pixels);
            }
            return false;
          },
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔥 HERO – ekranın %30’u, full genişlik
                _buildHeroSection(
                  context: context,
                  poster: poster,
                  backdrop: backdrop,
                ),

                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Başlık + meta
                      Text(
                        titleText,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.star,
                              color: Colors.amber, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            '$rating',
                            style: const TextStyle(color: Colors.white),
                          ),
                          if (year.toString().isNotEmpty) ...[
                            const SizedBox(width: 10),
                            Text(
                              '· $year',
                              style:
                                  const TextStyle(color: Colors.white70),
                            ),
                          ],
                          const SizedBox(width: 10),
                          Text(
                            '· $durationText',
                            style:
                                const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // Overview
                      _sectionTitle('Overview', theme,
                          icon: Icons.subject),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E2C),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.06),
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Text(
                          overview,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.4,
                            color: Colors.white70,
                          ),
                        ),
                      ),

                      // GENRE – daha belirgin
                      if (genres.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          genres.join(' · '),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // BUTONLAR
                      Consumer<LibraryProvider>(
                        builder:
                            (context, libraryProvider, child) {
                          final isInLibrary =
                              libraryProvider.isInLibrary(widget.id);

                          return Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _trailer != null
                                      ? _openTrailer
                                      : null,
                                  icon:
                                      const Icon(Icons.play_arrow),
                                  label: const Text('Watch Trailer'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        const Color(0xFFD32F2F),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    if (isInLibrary) {
                                      await libraryProvider
                                          .removeFromLibrary(
                                              widget.id);
                                      if (!mounted) return;
                                      _showLibrarySnack(
                                        context,
                                        '$titleText removed from library',
                                        added: false,
                                      );
                                    } else {
                                      await libraryProvider
                                          .addToLibrary({
                                        'id': widget.id,
                                        'title': titleText,
                                        'poster': poster,
                                        'rating':
                                            rating.toString(),
                                        'year': year.toString(),
                                        'type': widget.type,
                                      });
                                      if (!mounted) return;
                                      _showLibrarySnack(
                                        context,
                                        '$titleText added to library',
                                        added: true,
                                      );
                                    }
                                  },
                                  icon: Icon(
                                    isInLibrary
                                        ? Icons.check
                                        : Icons.add,
                                  ),
                                  label: Text(
                                    isInLibrary
                                        ? 'In Library'
                                        : 'Add to Library',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isInLibrary
                                        ? const Color(0xFF2E7D32)
                                        : Colors.grey.shade800,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 24),

                      // CAST
                      if (_cast.isNotEmpty) ...[
                        _sectionTitle('Cast', theme,
                            icon: Icons.people_alt),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 120,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _cast.length,
                            itemBuilder: (context, index) {
                              final actor = _cast[index];
                              return Container(
                                width: 80,
                                margin: const EdgeInsets.only(
                                    right: 10),
                                child: Column(
                                  children: [
                                    CircleAvatar(
                                      radius: 28,
                                      backgroundImage:
                                          actor['profile'] != ''
                                              ? NetworkImage(
                                                  actor['profile'])
                                              : null,
                                      backgroundColor:
                                          Colors.grey.shade700,
                                      child: actor['profile'] == ''
                                          ? const Icon(
                                              Icons.person,
                                              color: Colors.white,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      actor['name'],
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                      ),
                                      maxLines: 2,
                                      overflow:
                                          TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // REVIEWS
                      if (_reviews.isNotEmpty) ...[
                        _sectionTitle('Top Reviews', theme,
                            icon: Icons.rate_review),
                        const SizedBox(height: 8),
                        ..._reviews.map((r) {
                          return Card(
                            color: const Color(0xFF1E1E2C),
                            margin:
                                const EdgeInsets.symmetric(
                                    vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(10),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r['author'],
                                    style: const TextStyle(
                                      fontWeight:
                                          FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    r['content'],
                                    maxLines: 4,
                                    overflow:
                                        TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 24),
                      ],

                      // SIMILAR
                      if (_similar.isNotEmpty) ...[
                        _sectionTitle('Similar', theme,
                            icon:
                                Icons.movie_creation_outlined),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 200,
                          child: ListView.builder(
                            scrollDirection:
                                Axis.horizontal,
                            itemCount: _similar.length,
                            itemBuilder: (context, index) {
                              final s = _similar[index];
                              return GestureDetector(
                                onTap: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          InfoPage(
                                        id: s['id'],
                                        title: s['title'],
                                        type: s['type'] ??
                                            widget.type,
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  width: 130,
                                  margin:
                                      const EdgeInsets.only(
                                          right: 12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .center,
                                    children: [
                                      ClipRRect(
                                        borderRadius:
                                            BorderRadius
                                                .circular(
                                                    10),
                                        child: s['poster'] !=
                                                ''
                                            ? Image.network(
                                                s['poster'],
                                                height: 160,
                                                fit: BoxFit
                                                    .cover,
                                                errorBuilder:
                                                    (_, __,
                                                        ___) =>
                                                        Container(
                                                  height:
                                                      160,
                                                  color: Colors
                                                      .grey
                                                      .shade800,
                                                  child:
                                                      const Icon(
                                                    Icons
                                                        .broken_image,
                                                    color: Colors
                                                        .white,
                                                  ),
                                                ),
                                              )
                                            : Container(
                                                height: 160,
                                                color: Colors
                                                    .grey
                                                    .shade800,
                                                child:
                                                    const Icon(
                                                  Icons
                                                      .broken_image,
                                                  color: Colors
                                                      .white,
                                                ),
                                              ),
                                      ),
                                      const SizedBox(
                                          height: 6),
                                      Text(
                                        s['title'],
                                        style:
                                            const TextStyle(
                                          fontSize: 12,
                                          color:
                                              Colors.white,
                                        ),
                                        maxLines: 2,
                                        overflow:
                                            TextOverflow
                                                .ellipsis,
                                        textAlign:
                                            TextAlign
                                                .center,
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  // HERO – ekranın %30’u, full width, geri tuşu burada
  Widget _buildHeroSection({
    required BuildContext context,
    required String poster,
    required String backdrop,
  }) {
    final imageUrl = (backdrop.isNotEmpty) ? backdrop : poster;
    final screenHeight = MediaQuery.of(context).size.height;
    final heroHeight = screenHeight * 0.30; // <-- %30

    return SizedBox(
      height: heroHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl.isNotEmpty)
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey.shade800,
                child: const Icon(
                  Icons.broken_image,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            )
          else
            Container(
              color: Colors.grey.shade800,
              child: const Icon(
                Icons.broken_image,
                color: Colors.white,
                size: 48,
              ),
            ),

          // üst taraf için hafif karartma
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.5),
                    Colors.black.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),

          // geri butonu
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: AnimatedOpacity(
              opacity: _showTopBar ? 0 : 1,
              duration: const Duration(milliseconds: 150),
              child: CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.6),
                child: IconButton(
                  icon:
                      const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, ThemeData theme,
      {IconData? icon}) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: Colors.white70),
            const SizedBox(width: 6),
          ],
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}



import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../home_main.dart';
import 'info_page.dart';
import '../pages/library_provider.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Sayfa açılınca kütüphaneyi yükle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LibraryProvider>(context, listen: false).loadLibrary();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Silme onay dialogu
  Future<void> _showRemoveConfirmation(
    BuildContext context,
    Map<String, dynamic> item,
    LibraryProvider libraryProvider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from Library?'),
        content: Text('Remove "${item['title']}" from your library?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await libraryProvider.removeFromLibrary(item['id']);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item['title']} removed from your library.'),
            duration: const Duration(seconds: 2),
            action: SnackBarAction(label: 'OK', onPressed: () {}),
          ),
        );
      }
    }
  }

  Widget _buildEmptyState({
    required bool isMovieTab,
    required bool isDark,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isMovieTab ? Icons.movie_outlined : Icons.tv,
              size: 48,
              color: isDark
                  ? Colors.white.withOpacity(0.7)
                  : Colors.black.withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              isMovieTab
                  ? 'No movies in your library yet.'
                  : 'No TV shows in your library yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the heart icon on any title to add it to your library.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                // Ana sayfaya dön (discover gibi)
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const HomeScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.explore),
              label: const Text('Discover titles'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridView(
    List<Map<String, dynamic>> items,
    bool isDark,
    LibraryProvider libraryProvider,
    bool isMovieTab,
  ) {
    if (items.isEmpty) {
      return _buildEmptyState(isMovieTab: isMovieTab, isDark: isDark);
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.58,
      ),
      itemBuilder: (context, index) {
        final item = items[index];

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
          onLongPress: () {
            _showRemoveConfirmation(context, item, libraryProvider);
          },
          child: Container(
            decoration: BoxDecoration(
              gradient: isDark
                  ? const LinearGradient(
                      colors: [
                        Color(0xFF181827),
                        Color(0xFF1F1135),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [
                        Color(0xFFF5F3FF),
                        Color(0xFFEDE9FE),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.5)
                      : Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Poster alanı
                Expanded(
                  flex: 7,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                          child: Image.network(
                            item['poster'] ?? '',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey.shade800,
                              child: const Icon(
                                Icons.broken_image,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Kalp ikonu (kütüphanede olduğu için dolu)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.black.withOpacity(0.6),
                          child: const Icon(
                            Icons.favorite,
                            color: Color(0xFFEB4B98),
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Alt bilgiler + mini ikon satırı
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Başlık
                        Text(
                          item['title'] ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isDark ? Colors.white : Colors.black87,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Rating + Yıl + Tip
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${item['rating'] ?? 'N/A'}  •  ${item['year'] ?? ''}  •  ${item['type'] == 'tv' ? 'TV' : 'Movie'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const Spacer(),

                        // 🔹 Mini ikon satırı
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Detay ikonu
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              iconSize: 18,
                              onPressed: () {
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
                              icon: Icon(
                                Icons.info_outline,
                                color: isDark
                                    ? Colors.white70
                                    : Colors.black87,
                              ),
                              tooltip: 'Details',
                            ),

                            // “Watched” / Check ikonu (şimdilik sadece görsel)
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              iconSize: 18,
                              onPressed: () {
                                // Şimdilik sadece ufak bir feedback verelim.
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Nice choice! "${item['title']}" is in your library.',
                                    ),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                              icon: Icon(
                                Icons.check_circle_outline,
                                color: const Color(0xFF55D6C2)
                                    .withOpacity(isDark ? 0.9 : 0.8),
                              ),
                              tooltip: 'In your library',
                            ),

                            // Silme ikonu
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              iconSize: 18,
                              onPressed: () {
                                _showRemoveConfirmation(
                                  context,
                                  item,
                                  libraryProvider,
                                );
                              },
                              icon: Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent.withOpacity(0.9),
                              ),
                              tooltip: 'Remove',
                            ),
                          ],
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDark;
    final libraryProvider = Provider.of<LibraryProvider>(context);
    final allItems = libraryProvider.libraryItems;

    // Filmleri ve dizileri ayır
    final movies = allItems.where((item) => item['type'] == 'movie').toList();
    final tvShows = allItems.where((item) => item['type'] == 'tv').toList();

    return Container(
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                colors: [
                  Color(0xFF050816),
                  Color(0xFF120C24),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              )
            : const LinearGradient(
                colors: [
                  Color(0xFFF9FAFB),
                  Color(0xFFE5E7EB),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
      ),
      child: SafeArea(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            children: [
              // Başlık
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Library',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Movies & TV shows you’ve saved.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),

              // Tab Bar
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withOpacity(0.3)
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF6A0DAD),
                          Color(0xFF9D4EDD),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6A0DAD).withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: Colors.white,
                    unselectedLabelColor:
                        isDark ? Colors.white54 : Colors.black54,
                    labelStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    tabs: const [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.movie_outlined, size: 18),
                            SizedBox(width: 6),
                            Text('Movies'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.tv, size: 18),
                            SizedBox(width: 6),
                            Text('TV Shows'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Tab Bar View
              Expanded(
                child: libraryProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          // Movies Tab
                          _buildGridView(
                            movies,
                            isDark,
                            libraryProvider,
                            true,
                          ),
                          // TV Shows Tab
                          _buildGridView(
                            tvShows,
                            isDark,
                            libraryProvider,
                            false,
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

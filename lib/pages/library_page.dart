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

class _LibraryPageState extends State<LibraryPage> with SingleTickerProviderStateMixin {
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

  Widget _buildGridView(List<Map<String, dynamic>> items, bool isDark, LibraryProvider libraryProvider) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          _tabController.index == 0
              ? 'No movies in your library yet.\nStart adding some!'
              : 'No TV shows in your library yet.\nStart adding some!',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.52,
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
              color: isDark
                  ? const Color(0xFF1E1E2C)
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black54 : Colors.black12,
                  blurRadius: 4,
                  offset: const Offset(2, 2),
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
                            top: Radius.circular(14),
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
                            color: Color(0xFF6A0DAD),
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Alt bilgiler
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.all(10.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Başlık
                        Flexible(
                          child: Text(
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
                                '${item['rating'] ?? 'N/A'}  •  ${item['year'] ?? ''}  ',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ),
                          ],
                        ),
                        // ${item['type'] == 'tv' ? 'TV Show' : 'Movie'}
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

    return Scaffold(
      body: Column(
        children: [
          // Tab Bar
          Container(
            color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.black.withOpacity(0.3) : Colors.grey.shade200,
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
                unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
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
            child: TabBarView(
              controller: _tabController,
              children: [
                // Movies Tab
                _buildGridView(movies, isDark, libraryProvider),
                // TV Shows Tab
                _buildGridView(tvShows, isDark, libraryProvider),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
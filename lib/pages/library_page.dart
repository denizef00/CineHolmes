import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../home_main.dart';
import 'info_page.dart';
import '../pages/library_provider.dart'; // Provider'ı import et (dosya yoluna göre değiştir)

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  @override
  void initState() {
    super.initState();
    // Sayfa açılınca kütüphaneyi yükle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LibraryProvider>(context, listen: false).loadLibrary();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDark;
    final libraryProvider = Provider.of<LibraryProvider>(context);
    final libraryItems = libraryProvider.libraryItems;
    final isLoading = libraryProvider.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('My Library 📚'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: libraryItems.isEmpty
            ? const Center(
                child: Text(
                  'Your library is empty.\nStart adding movies and series!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              )
            : GridView.builder(
                itemCount: libraryItems.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.66,
                ),
                itemBuilder: (context, index) {
                  final item = libraryItems[index];
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
                      // Gerçekten kütüphaneden çıkar
                      libraryProvider.removeFromLibrary(item['id']);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${item['title']} removed from your library.',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E1E2C)
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(15),
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
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(15),
                              ),
                              child: Image.network(
                                item['poster'],
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
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              children: [
                                Text(
                                  item['title'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '⭐ ${item['rating']}  |  ${item['year']}',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black54,
                                    fontSize: 12,
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
    );
  }
}

/*import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../home_main.dart';
import 'info_page.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  // bu sefer id ve type var
  final List<Map<String, dynamic>> libraryItems = [
    {
      'id': 1396,
      'title': 'Breaking Bad',
      'poster':
          'https://image.tmdb.org/t/p/w500/eSzpy96DwBujGFj0xMbXBcGcfxX.jpg',
      'rating': '9.5',
      'year': '2008',
      'type': 'tv',
    },
    {
      'id': 1668,
      'title': 'Friends',
      'poster':
          'https://image.tmdb.org/t/p/w500/f496cm9enuEsZkSPzCwnTESEK5s.jpg',
      'rating': '8.4',
      'year': '1994',
      'type': 'tv',
    },
    {
      'id': 27205,
      'title': 'Inception',
      'poster':
          'https://image.tmdb.org/t/p/w500/edv5CZvWj09upOsy2Y6IwDhK8bt.jpg',
      'rating': '8.8',
      'year': '2010',
      'type': 'movie',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Library 📚'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: libraryItems.isEmpty
            ? const Center(
                child: Text(
                  'Your library is empty.\nStart adding movies and series!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              )
            : GridView.builder(
                itemCount: libraryItems.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.66,
                ),
                itemBuilder: (context, index) {
                  final item = libraryItems[index];
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              '${item['title']} removed from your library (simulation).'),
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E1E2C)
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(15),
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
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(15)),
                              child: Image.network(
                                item['poster'],
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey.shade800,
                                  child: const Icon(Icons.broken_image,
                                      color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              children: [
                                Text(
                                  item['title'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '⭐ ${item['rating']}  |  ${item['year']}',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black54,
                                    fontSize: 12,
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
    );
  }
}*/

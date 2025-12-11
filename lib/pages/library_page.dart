import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../home_main.dart';
import 'info_page.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get userId => _auth.currentUser?.uid ?? '';

  // Yeni liste oluştur
  Future<void> _createNewList(String listName) async {
    try {
      await _firestore.collection('users').doc(userId).collection('lists').add({
        'name': listName,
        'createdAt': FieldValue.serverTimestamp(),
        'movieCount': 0,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('List created: $listName'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Yeni liste dialog
  void _showCreateListDialog() {
    final TextEditingController controller = TextEditingController();
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        title: Text(
          'New List',
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        content: TextField(
          controller: controller,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: 'List name',
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: const Color(0xFFFFC107)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _createNewList(controller.text);
                Navigator.pop(context);
              }
            },
            child: Text(
              'Create',
              style: TextStyle(color: const Color(0xFFFFC107)),
            ),
          ),
        ],
      ),
    );
  }

  // Liste sil
  Future<void> _deleteList(String listId, String listName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = Provider.of<ThemeProvider>(context).isDark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          title: Text(
            'Delete List',
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
          content: Text(
            'Are you sure you want to delete "$listName"?',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('lists')
            .doc(listId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$listName deleted'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  // Liste seçenekleri menüsü
  void _showListOptions(String listId, String listName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Provider.of<ThemeProvider>(context).isDark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Icon(
                  Icons.edit,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                title: Text(
                  'Edit List Name',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Düzenleme fonksiyonu eklenebilir
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete List',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteList(listId, listName);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({required bool isDark}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.list_alt_outlined,
              size: 64,
              color: isDark
                  ? Colors.white.withOpacity(0.7)
                  : Colors.black.withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'No lists yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create lists to organize your movies.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDark;

    return Container(
      decoration: BoxDecoration(color: isDark ? Colors.black : Colors.white),
      child: SafeArea(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            children: [
              // Başlık ve Sort butonu
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      'Lists',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.sort,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      onPressed: () {
                        // Sort fonksiyonu eklenebilir
                      },
                    ),
                  ],
                ),
              ),

              // Yeni Liste Oluştur Butonu
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: GestureDetector(
                  onTap: _showCreateListDialog,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC107),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        'CREATE A NEW LIST',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Listeler
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('users')
                      .doc(userId)
                      .collection('lists')
                      .orderBy('createdAt', descending: true)
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

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFFC107),
                        ),
                      );
                    }

                    final lists = snapshot.data?.docs ?? [];

                    if (lists.isEmpty) {
                      return _buildEmptyState(isDark: isDark);
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: lists.length,
                      itemBuilder: (context, index) {
                        final listData =
                            lists[index].data() as Map<String, dynamic>;
                        final listId = lists[index].id;
                        final listName = listData['name'] ?? 'Unnamed List';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: _buildListCard(listId, listName, isDark),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListCard(String listId, String listName, bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('users')
          .doc(userId)
          .collection('lists')
          .doc(listId)
          .collection('movies')
          .limit(4)
          .snapshots(),
      builder: (context, snapshot) {
        final movies = snapshot.data?.docs ?? [];

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    MovieListDetailPage(listId: listId, listName: listName),
              ),
            );
          },
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                // Movie posters grid
                if (movies.isNotEmpty)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 1.5,
                            ),
                        itemCount: movies.length > 4 ? 4 : movies.length,
                        itemBuilder: (context, index) {
                          final movieData =
                              movies[index].data() as Map<String, dynamic>;
                          final posterUrl = movieData['poster'] ?? '';

                          return Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isDark ? Colors.black : Colors.white,
                                width: 0.5,
                              ),
                            ),
                            child: posterUrl.isNotEmpty
                                ? Image.network(
                                    posterUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: Colors.grey.shade800,
                                      child: const Icon(
                                        Icons.movie,
                                        color: Colors.white54,
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: Colors.grey.shade800,
                                    child: const Icon(
                                      Icons.movie,
                                      color: Colors.white54,
                                    ),
                                  ),
                          );
                        },
                      ),
                    ),
                  )
                else
                  // Empty state
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF2C2C2E)
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.movie_outlined,
                          size: 48,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),

                // Gradient overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                ),

                // Liste adı
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 56,
                  child: Text(
                    listName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Üç nokta menü butonu
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => _showListOptions(listId, listName),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.more_horiz,
                        color: Colors.white,
                        size: 20,
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
  }
}

// Liste Detay Sayfası
class MovieListDetailPage extends StatelessWidget {
  final String listId;
  final String listName;

  const MovieListDetailPage({
    super.key,
    required this.listId,
    required this.listName,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDark;
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Container(
      decoration: BoxDecoration(color: isDark ? Colors.black : Colors.white),
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
            listName,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('lists')
              .doc(listId)
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

            if (snapshot.connectionState == ConnectionState.waiting) {
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
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.58,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: movies.length,
              itemBuilder: (context, index) {
                final movieData = movies[index].data() as Map<String, dynamic>;
                final movieIdStr = movieData['id']?.toString() ?? '';
                final movieId = int.tryParse(movieIdStr) ?? 0;
                final title = movieData['title'] ?? '';
                final posterUrl = movieData['poster'] ?? '';
                final rating = movieData['rating'] ?? 'N/A';
                final year = movieData['year'] ?? '';
                final type = movieData['type'] ?? 'movie';

                return GestureDetector(
                  onTap: () {
                    if (movieId != 0) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              InfoPage(id: movieId, title: title, type: type),
                        ),
                      );
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1C1C1E)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 7,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                            child: posterUrl.isNotEmpty
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
                                      size: 48,
                                    ),
                                  ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                    height: 1.2,
                                  ),
                                ),
                                const Spacer(),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$rating  •  $year',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.black54,
                                      ),
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
          },
        ),
      ),
    );
  }
}

/*import 'package:cineholmes/pages/list_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../home_main.dart';
import 'info_page.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get userId => _auth.currentUser?.uid ?? '';

  // Yeni liste oluştur
  Future<void> _createNewList(String listName) async {
    try {
      await _firestore.collection('users').doc(userId).collection('lists').add({
        'name': listName,
        'createdAt': FieldValue.serverTimestamp(),
        'movieCount': 0,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('List created: $listName'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Yeni liste dialog
  void _showCreateListDialog() {
    final TextEditingController controller = TextEditingController();
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        title: Text(
          'New List',
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        content: TextField(
          controller: controller,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: 'List Name',
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: const Color(0xFFFFC107)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _createNewList(controller.text);
                Navigator.pop(context);
              }
            },
            child: Text(
              'Create',
              style: TextStyle(color: const Color(0xFFFFC107)),
            ),
          ),
        ],
      ),
    );
  }

  // Liste sil
  Future<void> _deleteList(String listId, String listName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = Provider.of<ThemeProvider>(context).isDark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          title: Text(
            'Dekete List',
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
          content: Text(
            'Are you sure delete this list: "$listName" ',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('lists')
            .doc(listId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$listName deleted'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  // Liste seçenekleri menüsü
  void _showListOptions(String listId, String listName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Provider.of<ThemeProvider>(context).isDark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Icon(
                  Icons.edit,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                title: Text(
                  'Rename List',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Düzenleme fonksiyonu eklenebilir
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete List',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteList(listId, listName);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({required bool isDark}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.list_alt_outlined,
              size: 64,
              color: isDark
                  ? Colors.white.withOpacity(0.7)
                  : Colors.black.withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'You have no lists!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a list to get started',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDark;

    return Container(
      decoration: BoxDecoration(color: isDark ? Colors.black : Colors.white),
      child: SafeArea(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            children: [
              // Başlık ve Sort butonu
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Lists',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.sort,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      onPressed: () {
                        // Sort fonksiyonu eklenebilir
                      },
                    ),
                  ],
                ),
              ),

              // Yeni Liste Oluştur Butonu
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: GestureDetector(
                  onTap: _showCreateListDialog,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC107),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        'CREATE A NEW LIST',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Listeler
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('users')
                      .doc(userId)
                      .collection('lists')
                      .orderBy('createdAt', descending: true)
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

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFFC107),
                        ),
                      );
                    }

                    final lists = snapshot.data?.docs ?? [];

                    if (lists.isEmpty) {
                      return _buildEmptyState(isDark: isDark);
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: lists.length,
                      itemBuilder: (context, index) {
                        final listData =
                            lists[index].data() as Map<String, dynamic>;
                        final listId = lists[index].id;
                        final listName = listData['name'] ?? 'Untitled List';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: _buildListCard(listId, listName, isDark),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListCard(String listId, String listName, bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      // liste kapak resmi
      stream: _firestore
          .collection('users')
          .doc(userId)
          .collection('lists')
          .doc("favoriler") //normalde listId yazıyor burada
          .collection('Favoriler')
          .limit(4)
          .snapshots(),
      builder: (context, snapshot) {
        final movies = snapshot.data?.docs ?? [];

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    MovieListDetailPage(listId: listId, listName: listName),
              ),
            );
          },
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                // Movie posters grid
                if (movies.isNotEmpty)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 1.5,
                            ),
                        itemCount: movies.length > 4 ? 4 : movies.length,
                        itemBuilder: (context, index) {
                          final movieData =
                              movies[index].data() as Map<String, dynamic>;
                          final posterUrl = movieData['poster'] ?? '';

                          return Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isDark ? Colors.black : Colors.white,
                                width: 0.5,
                              ),
                            ),
                            child: posterUrl.isNotEmpty
                                ? Image.network(
                                    posterUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: Colors.grey.shade800,
                                      child: const Icon(
                                        Icons.movie,
                                        color: Colors.white54,
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: Colors.grey.shade800,
                                    child: const Icon(
                                      Icons.movie,
                                      color: Colors.white54,
                                    ),
                                  ),
                          );
                        },
                      ),
                    ),
                  )
                else
                  // Empty state
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF2C2C2E)
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.movie_outlined,
                          size: 48,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),

                // Gradient overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                ),

                // Liste adı
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 56,
                  child: Text(
                    listName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Üç nokta menü butonu
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => _showListOptions(listId, listName),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.more_horiz,
                        color: Colors.white,
                        size: 20,
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
  }
}
*/

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../home_main.dart';
import 'list_view.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get userId => _auth.currentUser?.uid ?? '';

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
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showCreateListDialog() {
    final TextEditingController controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          decoration: const InputDecoration(
            hintText: 'List name',
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF6A0DAD)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _createNewList(controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text(
              'Create',
              style: TextStyle(color: Color(0xFF6A0DAD)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteList(String listId, String listName) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
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
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
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
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _showListOptions(String listId, String listName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
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
              Icons.video_library_outlined,
              size: 80,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
            const SizedBox(height: 16),
            Text(
              'No lists yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first list to organize your favorite movies and TV shows',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paddingTop = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : Colors.white,
      body: Column(
        children: [
          // Instagram-style header with CineHolmes title (matching HomePage)
          Container(
            color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
            padding: EdgeInsets.only(top: paddingTop),
            child: Column(
              children: [
                // CineHolmes title (same as HomePage)
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
                
                // Section title
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'My Lists',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6A0DAD), Color(0xFF9D4EDD)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _showCreateListDialog,
                            borderRadius: BorderRadius.circular(20),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'New List',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Divider
                Divider(
                  height: 1,
                  thickness: 0.5,
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.1),
                ),
              ],
            ),
          ),

          // Lists
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
                      color: Color(0xFF6A0DAD),
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
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

                // List name
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

                // More options button
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
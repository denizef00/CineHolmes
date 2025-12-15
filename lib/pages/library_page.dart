import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  void _needLoginSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please log in first.'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // -----------------------------
  // CREATE LIST
  // -----------------------------
  Future<void> _createNewList(String listName) async {
    if (userId.isEmpty) {
      if (mounted) _needLoginSnack();
      return;
    }

    try {
      await _firestore.collection('users').doc(userId).collection('lists').add({
        'name': listName.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'movieCount': 0,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('List created: ${listName.trim()}'),
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
    final controller = TextEditingController();
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
            enabledBorder:
                UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
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
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                _createNewList(name);
                Navigator.pop(context);
              }
            },
            child: const Text('Create',
                style: TextStyle(color: Color(0xFF6A0DAD))),
          ),
        ],
      ),
    );
  }

  // -----------------------------
  // RENAME LIST
  // -----------------------------
  Future<void> _renameList(String listId, String currentName) async {
    if (userId.isEmpty) {
      if (mounted) _needLoginSnack();
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = TextEditingController(text: currentName);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        title: Text(
          'Edit List Name',
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: const InputDecoration(
            hintText: 'New list name',
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder:
                UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF6A0DAD)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              final v = controller.text.trim();
              Navigator.pop(context, v.isEmpty ? null : v);
            },
            child:
                const Text('Save', style: TextStyle(color: Color(0xFF6A0DAD))),
          ),
        ],
      ),
    );

    if (newName == null || newName == currentName) return;

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('lists')
          .doc(listId)
          .update({'name': newName});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('List name updated ✅'),
            duration: Duration(seconds: 2),
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

  // -----------------------------
  // DELETE LIST
  // -----------------------------
  Future<void> _deleteList(String listId, String listName) async {
    if (userId.isEmpty) {
      if (mounted) _needLoginSnack();
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          title: Text('Delete List',
              style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
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

  // -----------------------------
  // LIST OPTIONS (BOTTOM SHEET)
  // -----------------------------
  void _showListOptions(String listId, String listName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (sheetContext) {
        final bottomInset = MediaQuery.of(sheetContext).padding.bottom;

        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
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
                  const SizedBox(height: 8),

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
                      Navigator.pop(sheetContext);
                      _renameList(listId, listName);
                    },
                  ),

                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text('Delete List',
                        style: TextStyle(color: Colors.red)),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _deleteList(listId, listName);
                    },
                  ),

                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // -----------------------------
  // UI HELPERS
  // -----------------------------
  Widget _buildEmptyState({required bool isDark}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library_outlined,
                size: 80, color: isDark ? Colors.white24 : Colors.black26),
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

  // -----------------------------
  // BUILD
  // -----------------------------
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paddingTop = MediaQuery.of(context).padding.top;

    if (userId.isEmpty) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0A0A0A) : Colors.white,
        body: Center(
          child: Text(
            'Please log in to see your lists.',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : Colors.white,
      body: Column(
        children: [
          // Header
          Container(
            color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
            padding: EdgeInsets.only(top: paddingTop),
            child: Column(
              children: [
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
                      ),
                    ),
                  ),
                ),
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
                                  horizontal: 16, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add,
                                      color: Colors.white, size: 20),
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
                          color: isDark ? Colors.white : Colors.black87),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF6A0DAD)),
                  );
                }

                final lists = snapshot.data?.docs ?? [];
                if (lists.isEmpty) return _buildEmptyState(isDark: isDark);

                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: lists.length,
                  itemBuilder: (context, index) {
                    final listData =
                        lists[index].data() as Map<String, dynamic>;
                    final listId = lists[index].id;
                    final listName =
                        (listData['name'] ?? 'Unnamed List').toString();

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

  // -----------------------------
  // LIST CARD + COVER COLLAGE
  // -----------------------------
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
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.32 : 0.10),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  // Collage / Empty
                  Positioned.fill(
                    child: movies.isNotEmpty
                        ? _buildCoverCollage(movies, isDark)
                        : Container(
                            color: isDark
                                ? const Color(0xFF2C2C2E)
                                : Colors.grey.shade200,
                            child: Center(
                              child: Icon(
                                Icons.movie_outlined,
                                size: 48,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                  ),

                  // Gradient overlay for readability
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.18),
                            Colors.black.withOpacity(0.05),
                            Colors.black.withOpacity(0.75),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // List name
                  Positioned(
                    bottom: 14,
                    left: 14,
                    right: 64,
                    child: Text(
                      listName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),

                  // More button
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Material(
                      color: Colors.black.withOpacity(0.35),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _showListOptions(listId, listName),
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(
                            Icons.more_vert,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCoverCollage(List<QueryDocumentSnapshot> movies, bool isDark) {
    // Always render 4 tiles (missing ones => placeholder)
    final items = List.generate(4, (i) => i < movies.length ? movies[i] : null);

    return LayoutBuilder(
      builder: (context, constraints) {
        final ratio = (constraints.maxWidth <= 0 || constraints.maxHeight <= 0)
            ? 1.0
            : (constraints.maxWidth / constraints.maxHeight);

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: ratio,
          ),
          itemCount: 4,
          itemBuilder: (context, index) {
            final doc = items[index];

            if (doc == null) {
              return Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade300,
                  border: Border.all(
                    color: isDark ? Colors.black.withOpacity(0.6) : Colors.white,
                    width: 0.5,
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.movie, color: Colors.white38, size: 28),
                ),
              );
            }

            final data = doc.data() as Map<String, dynamic>;

            // Use backdrop if you store it, else fallback to poster
            final backdrop = (data['backdrop'] ?? '').toString();
            final poster = (data['poster'] ?? '').toString();
            final imageUrl = backdrop.isNotEmpty ? backdrop : poster;

            return Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: isDark ? Colors.black.withOpacity(0.6) : Colors.white,
                  width: 0.5,
                ),
              ),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: isDark
                              ? const Color(0xFF2C2C2E)
                              : Colors.grey.shade300,
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        color: isDark
                            ? const Color(0xFF2C2C2E)
                            : Colors.grey.shade300,
                        child: const Center(
                          child: Icon(Icons.broken_image,
                              color: Colors.white38, size: 28),
                        ),
                      ),
                    )
                  : Container(
                      color: isDark
                          ? const Color(0xFF2C2C2E)
                          : Colors.grey.shade300,
                      child: const Center(
                        child:
                            Icon(Icons.movie, color: Colors.white38, size: 28),
                      ),
                    ),
            );
          },
        );
      },
    );
  }
}

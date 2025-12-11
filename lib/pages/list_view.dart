import 'package:cineholmes/pages/info_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../home_main.dart';

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
              .collection("Collection")
              .orderBy('addedAt', descending: true)
              .snapshots(),
          /*.collection('users')
              .doc(userId)
              .collection('lists')
              .doc(listId)
              .collection(listId)
              .orderBy('addedAt', descending: true)
              .snapshots(),*/
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
                      'List is empty',
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
                final movieId = movieData['id'] ?? '';
                final title = movieData['title'] ?? '';
                final posterUrl = movieData['poster'] ?? '';
                final rating = movieData['rating'] ?? 'N/A';
                final year = movieData['year'] ?? '';
                final type = movieData['type'] ?? 'movie';

                return GestureDetector(
                  onTap: () {
                    if (movieId.isNotEmpty) {
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

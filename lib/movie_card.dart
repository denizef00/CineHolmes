import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MovieCard extends StatefulWidget {
  final String posterUrl;
  final String movieId;
  final String title; // 🎬 Ek: başlık da kaydedelim

  const MovieCard({
    Key? key,
    required this.posterUrl,
    required this.movieId,
    required this.title,
  }) : super(key: key);

  @override
  _MovieCardState createState() => _MovieCardState();
}

class _MovieCardState extends State<MovieCard> {
  bool isFavorite = false;

  @override
  void initState() {
    super.initState();
    _checkIfFavorite();
  }

  Future<void> _checkIfFavorite() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('library')
        .doc(widget.movieId)
        .get();

    if (doc.exists) {
      setState(() => isFavorite = true);
    }
  }

  Future<void> toggleFavorite() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('library')
        .doc(widget.movieId);

    if (isFavorite) {
      await docRef.delete();
      setState(() => isFavorite = false);
    } else {
      await docRef.set({
        'id': widget.movieId,
        'title': widget.title,
        'posterUrl': widget.posterUrl,
        'addedAt': FieldValue.serverTimestamp(),
      });
      setState(() => isFavorite = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2 / 3, // 🎬 poster oranı sabit
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Poster tam otursun
            Positioned.fill(
              child: Image.network(
                widget.posterUrl,
                fit: BoxFit.fill,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.broken_image, size: 100),
              ),
            ),
            // Sağ üst köşede kalp
            Positioned(
              top: 8,
              right: 8,
              child: CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.6),
                child: IconButton(
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? const Color(0xFF6A0DAD) : Colors.white,
                  ),
                  onPressed: toggleFavorite,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

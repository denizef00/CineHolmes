//import 'dart:io'; backennde lazım olacak 
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/tmdb_service.dart';
import 'info_page.dart';

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final picker = ImagePicker();
  final tmdbService = TMDBService();

  String status = "No video selected yet.";
  Map<String, dynamic>? movieData;
  bool isPicking = false;

  Future<void> _pickVideo() async {
    if (isPicking) return;
    setState(() => isPicking = true);

    final XFile? file =
        await picker.pickVideo(source: ImageSource.gallery).catchError((_) {
      return null;
    });

    if (!mounted) return;
    if (file == null) {
      setState(() {
        isPicking = false;
        status = "No video selected.";
      });
      return;
    }

    // Şimdilik sadece seçtiğini gösteriyoruz.
    setState(() {
      status = "Video selected: ${file.name}";
      isPicking = false;
      movieData = null;
    });

    // burada ileride backend'den title/id alıp:
    // final res = await tmdbService.fetchMovieDetailsById(...);
    // setState(() => movieData = res);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.upload),
            label: Text(isPicking ? "Opening gallery..." : "Upload and identify"),
            onPressed: isPicking ? null : _pickVideo,
          ),
          const SizedBox(height: 20),
          Text(
            status,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          if (movieData != null) ...[
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                movieData!['poster'] ?? '',
                height: 250,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.broken_image, size: 100),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              movieData!['title'] ?? 'Unknown Title',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              textAlign: TextAlign.center,
            ),
            Text(
              "⭐ ${movieData!['rating']}  |  ${movieData!['year']}",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Text(
              movieData!['overview'] ?? "No overview available.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.info_outline),
              label: const Text("View Full Details"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InfoPage(
                      id: movieData!['id'],
                      title: movieData!['title'],
                      type: movieData!['type'] ?? 'movie',
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

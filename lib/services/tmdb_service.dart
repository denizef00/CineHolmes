import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class TMDBService {
  final String _baseUrl = 'https://api.themoviedb.org/3';
  final String _imageBase = 'https://image.tmdb.org/t/p/w500';

  String get _apiKey => Config.tmdbApiKey;

  // ===============================
  // 1) SEARCH (HomePage burayı kullanıyor)
  // ===============================
  Future<List<Map<String, dynamic>>> searchMulti(String query, {int limit = 8}) async {
    if (query.trim().isEmpty) return [];

    try {
      final movieUrl =
          Uri.parse('$_baseUrl/search/movie?api_key=$_apiKey&query=$query');
      final tvUrl =
          Uri.parse('$_baseUrl/search/tv?api_key=$_apiKey&query=$query');

      final responses = await Future.wait([
        http.get(movieUrl),
        http.get(tvUrl),
      ]);

      final movieResults =
          jsonDecode(responses[0].body)['results'] as List<dynamic>? ?? [];
      final tvResults =
          jsonDecode(responses[1].body)['results'] as List<dynamic>? ?? [];

      // hepsini birleştir
      final combined = <Map<String, dynamic>>[
        ...movieResults.map((m) => _mapSearchItem(m, 'movie')),
        ...tvResults.map((t) => _mapSearchItem(t, 'tv')),
      ];

      // popülerliğe göre sırala
      combined.sort(
        (a, b) =>
            (b['popularity'] as num).compareTo(a['popularity'] as num),
      );

      return combined.take(limit).toList();
    } catch (e) {
      return [];
    }
  }

  // istersen eski adıyla da kullan diye bırakıyorum
  Future<List<Map<String, dynamic>>> searchTitles(String query, {int limit = 8}) {
    return searchMulti(query, limit: limit);
  }

  Map<String, dynamic> _mapSearchItem(dynamic data, String forcedType) {
    final isMovie = forcedType == 'movie';
    return {
      'id': data['id'],
      'title': isMovie ? (data['title'] ?? '') : (data['name'] ?? ''),
      'overview': data['overview'] ?? '',
      'poster': data['poster_path'] != null
          ? '$_imageBase${data['poster_path']}'
          : '',
      'year': (data['release_date'] ?? data['first_air_date'] ?? '')
          .toString()
          .split('-')
          .first,
      'rating': (data['vote_average'] ?? 0).toString(),
      'type': forcedType,
      'popularity': data['popularity'] ?? 0,
    };
  }

  // ===============================
  // 2) DETAY
  // ===============================
  Future<Map<String, dynamic>> fetchDetailsById(int id, String type) async {
    try {
      final url = Uri.parse('$_baseUrl/$type/$id?api_key=$_apiKey');
      final res = await http.get(url);
      if (res.statusCode != 200) return {};

      final data = jsonDecode(res.body);

      return {
        'id': data['id'],
        'title': data['title'] ?? data['name'] ?? '',
        'overview': data['overview'] ?? '',
        'poster': data['poster_path'] != null
            ? '$_imageBase${data['poster_path']}'
            : '',
        'year': (data['release_date'] ?? data['first_air_date'] ?? '')
            .toString()
            .split('-')
            .first,
        'rating': (data['vote_average'] ?? 0).toString(),
        'genres': (data['genres'] as List<dynamic>? ?? [])
            .map((g) => g['name'].toString())
            .toList(),
        // film ise runtime, dizi ise season
        'runtime': data['runtime'], // movie
        'number_of_seasons': data['number_of_seasons'], // tv
        'type': type,
      };
    } catch (e) {
      return {};
    }
  }

  // ===============================
  // 3) CAST
  // ===============================
  Future<List<Map<String, dynamic>>> fetchCast(int id, String type) async {
    try {
      final url =
          Uri.parse('$_baseUrl/$type/$id/credits?api_key=$_apiKey');
      final res = await http.get(url);
      if (res.statusCode != 200) return [];

      final data = jsonDecode(res.body);
      final cast = data['cast'] as List<dynamic>? ?? [];

      return cast.take(8).map((c) {
        return {
          'name': c['name'] ?? '',
          'character': c['character'] ?? '',
          'profile': c['profile_path'] != null
              ? '$_imageBase${c['profile_path']}'
              : '',
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // ===============================
  // 4) REVIEWS
  // ===============================
  Future<List<Map<String, dynamic>>> fetchReviews(int id, String type) async {
    try {
      final url =
          Uri.parse('$_baseUrl/$type/$id/reviews?api_key=$_apiKey');
      final res = await http.get(url);
      if (res.statusCode != 200) return [];

      final data = jsonDecode(res.body);
      final reviews = data['results'] as List<dynamic>? ?? [];

      return reviews.take(3).map((r) {
        return {
          'author': r['author'] ?? 'Anonymous',
          'content': r['content'] ?? '',
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // ===============================
  // 5) TRAILER
  // ===============================
  Future<String?> fetchTrailer(int id, String type) async {
    try {
      final url =
          Uri.parse('$_baseUrl/$type/$id/videos?api_key=$_apiKey');
      final res = await http.get(url);
      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body);
      final List vids = data['results'] ?? [];
      if (vids.isEmpty) return null;

      final yt = vids.firstWhere(
        (v) => v['site'] == 'YouTube',
        orElse: () => null,
      );
      if (yt == null) return null;

      return 'https://www.youtube.com/watch?v=${yt['key']}';
    } catch (e) {
      return null;
    }
  }

  // ===============================
  // 6) SİMİLAR
  // ===============================
  Future<List<Map<String, dynamic>>> fetchSimilar(int id, String type) async {
    try {
      final url =
          Uri.parse('$_baseUrl/$type/$id/similar?api_key=$_apiKey');
      final res = await http.get(url);
      if (res.statusCode != 200) return [];

      final data = jsonDecode(res.body);
      final results = data['results'] as List<dynamic>? ?? [];

      return results.take(10).map((m) {
        // bazen similar endpoint media_type dönmez, o yüzden fallback
        final detectedType = m['media_type'];
        return {
          'id': m['id'],
          'title': m['title'] ?? m['name'] ?? '',
          'poster': m['poster_path'] != null
              ? '$_imageBase${m['poster_path']}'
              : '',
          'type': detectedType != null
              ? (detectedType == 'tv' ? 'tv' : 'movie')
              : type,
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // ===============================
  // 7) TRENDING
  // ===============================
  Future<List<Map<String, dynamic>>> fetchTrending() async {
    try {
      final url =
          Uri.parse('$_baseUrl/trending/all/week?api_key=$_apiKey');
      final res = await http.get(url);
      if (res.statusCode != 200) return [];

      final data = jsonDecode(res.body);
      final results = data['results'] as List<dynamic>? ?? [];

      return results.map((m) {
        return {
          'id': m['id'],
          'title': m['title'] ?? m['name'] ?? 'Unknown',
          'poster': m['poster_path'] != null
              ? '$_imageBase${m['poster_path']}'
              : '',
          'rating': (m['vote_average'] ?? 0).toString(),
          'year': (m['release_date'] ?? m['first_air_date'] ?? '')
              .toString()
              .split('-')
              .first,
          'type': m['media_type'] == 'tv' ? 'tv' : 'movie',
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class MovieService {
  static const String apiKey = '69abe1f632bae973c9d1e5e43e86adf9';
  static const String baseUrl = 'https://api.themoviedb.org/3';
  static const String imageBaseUrl = 'https://image.tmdb.org/t/p/w342';

  final http.Client _client = http.Client();

  static final BaseCacheManager imageCacheManager = CacheManager(
    Config(
      'movieImageCache',
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 200,
      repo: JsonCacheInfoRepository(databaseName: 'movieImageCache'),
      fileService: HttpFileService(),
    ),
  );

  Future<T> _getWithRetries<T>(
    Uri uri,
    T Function(String) parser, {
    int retries = 2,
  }) async {
    int attempt = 0;

    while (true) {
      attempt++;
      try {
        final response = await _client
            .get(uri)
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          if (kIsWeb) {
            return parser(response.body);
          } else {
            // Pass to background isolate safely
            return compute<Map<String, Object?>, T>(
              _backgroundParse<T>,
              {'body': response.body, 'parser': parser},
            );
          }
        } else {
          if (attempt > retries) {
            return Future.error(
                'HTTP ${response.statusCode}: ${response.reasonPhrase}');
          }
        }
      } on SocketException catch (e) {
        if (attempt > retries) return Future.error('Network error: $e');
        await Future.delayed(
            Duration(milliseconds: 300 * (1 << attempt))); // removed const
      } on http.ClientException catch (e) {
        if (attempt > retries) return Future.error('Client error: $e');
        await Future.delayed(Duration(milliseconds: 300 * attempt)); // removed const
      } on TimeoutException catch (e) {
        if (attempt > retries) return Future.error('Timeout: $e');
      } catch (e) {
        return Future.error(e.toString());
      }
    }
  }

  /// Background isolate parsing (must be top-level or static)
  static T _backgroundParse<T>(Map<String, Object?> args) {
    final String body = args['body'] as String;
    final parser = args['parser'] as T Function(String)?;
    if (parser != null) {
      return parser(body);
    }
    return json.decode(body) as T;
  }

  Future<List<Map<String, dynamic>>> _fetchMovies(String url) async {
    final uri = Uri.parse(url);
    try {
      final parsed = await _getWithRetries(uri, (body) {
        final data = json.decode(body);
        final List<dynamic> results = data['results'] ?? [];
        return List<Map<String, dynamic>>.from(results);
      });
      if (parsed is List) {
        return List<Map<String, dynamic>>.from(parsed);
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching movies: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchTopRated() async {
    return _fetchMovies(
        '$baseUrl/movie/top_rated?api_key=$apiKey&language=en-US&page=1');
  }

  Future<List<Map<String, dynamic>>> fetchMindBending() async {
    return _fetchMovies(
        '$baseUrl/discover/movie?api_key=$apiKey&with_genres=53,878&sort_by=popularity.desc&page=1');
  }

  Future<List<Map<String, dynamic>>> fetchTrending() async {
    return _fetchMovies('$baseUrl/trending/movie/week?api_key=$apiKey');
  }

  Future<List<Map<String, dynamic>>> fetchPopular() async {
    return _fetchMovies(
        '$baseUrl/movie/popular?api_key=$apiKey&language=en-US&page=1');
  }

  Future<List<Map<String, dynamic>>> fetchUpcoming() async {
    return _fetchMovies(
        '$baseUrl/movie/upcoming?api_key=$apiKey&language=en-US&page=1');
  }

  Future<List<Map<String, dynamic>>> searchMovies(String query) async {
    final url =
        '$baseUrl/search/movie?api_key=$apiKey&query=${Uri.encodeComponent(query)}&language=en-US&page=1&include_adult=false';
    return _fetchMovies(url);
  }

  Future<Map<String, dynamic>> fetchMovieDetail(int id) async {
    final uri = Uri.parse('$baseUrl/movie/$id?api_key=$apiKey&language=en-US');
    try {
      final parsed = await _getWithRetries(uri, (body) => json.decode(body));
      if (parsed is Map) return Map<String, dynamic>.from(parsed);
      return {};
    } catch (e) {
      debugPrint('Failed to fetch movie detail: $e');
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> fetchMovieVideos(int id) async {
    final uri =
        Uri.parse('$baseUrl/movie/$id/videos?api_key=$apiKey&language=en-US');
    try {
      final parsed = await _getWithRetries(uri, (body) {
        final data = json.decode(body);
        return List<Map<String, dynamic>>.from(data['results'] ?? []);
      });
      if (parsed is List) return List<Map<String, dynamic>>.from(parsed);
      return [];
    } catch (e) {
      debugPrint('Error fetching movie videos: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchMovieCast(int id) async {
    final uri =
        Uri.parse('$baseUrl/movie/$id/credits?api_key=$apiKey&language=en-US');
    try {
      final parsed = await _getWithRetries(uri, (body) {
        final data = json.decode(body);
        return List<Map<String, dynamic>>.from(data['cast'] ?? []);
      });
      if (parsed is List) return List<Map<String, dynamic>>.from(parsed);
      return [];
    } catch (e) {
      debugPrint('Error fetching cast: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchMovieImages(int id) async {
    final uri = Uri.parse('$baseUrl/movie/$id/images?api_key=$apiKey');
    try {
      final parsed = await _getWithRetries(uri, (body) {
        final data = json.decode(body);
        final List<Map<String, dynamic>> images = [];
        if (data['posters'] != null) {
          images.addAll(List<Map<String, dynamic>>.from(data['posters']));
        }
        if (data['backdrops'] != null) {
          images.addAll(List<Map<String, dynamic>>.from(data['backdrops']));
        }
        return images;
      });
      if (parsed is List) return List<Map<String, dynamic>>.from(parsed);
      return [];
    } catch (e) {
      debugPrint('Error fetching movie images: $e');
      return [];
    }
  }

  String getPosterUrl(String path) => '$imageBaseUrl$path';

  void dispose() {
    _client.close();
  }
}

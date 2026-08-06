import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/track.dart';

class ApiService {
  static const String baseUrl = 'https://melody-beqg.onrender.com/api';
  final Map<String, _CacheEntry<List<Track>>> _songCache = {};
  final Map<String, _CacheEntry<List<String>>> _suggestCache = {};
  final Map<String, _CacheEntry<List<Map<String, dynamic>>>> _playlistCache = {};

  Future<List<Track>> searchSongs(String query, {int page = 1, int limit = 30}) async {
    final cacheKey = 'search:$query:$page:$limit';
    final cached = _songCache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return cached.value;
    }
    final uri = Uri.parse('$baseUrl/music/search').replace(queryParameters: {
      'query': query,
      'page': '$page',
      'limit': '$limit',
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 18));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Search failed (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>?;
    final results = (data?['results'] as List?) ?? const [];
    final tracks = results.whereType<Map<String, dynamic>>().map(Track.fromApi).toList();
    _songCache[cacheKey] = _CacheEntry(tracks);
    return tracks;
  }

  Future<Track?> getSongById(String songId) async {
    final uri = Uri.parse('$baseUrl/music/song/$songId');
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      // Handle both wrapped and direct responses from JioSaavn
      if (decoded.containsKey('id') || decoded.containsKey('title')) {
        return Track.fromApi(decoded);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<String>> suggest(String query) async {
    if (query.trim().length < 2) return const [];
    final cacheKey = query.trim().toLowerCase();
    final cached = _suggestCache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return cached.value;
    }
    final uri = Uri.parse('$baseUrl/music/suggest').replace(queryParameters: {'query': query});
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode < 200 || response.statusCode >= 300) return const [];
    final decoded = jsonDecode(response.body);
    if (decoded is List) {
      final suggestions = decoded.map((e) => e.toString()).toList();
      _suggestCache[cacheKey] = _CacheEntry(suggestions);
      return suggestions;
    }
    return const [];
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final uri = Uri.parse('$baseUrl/auth/login');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 15));

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(decoded['message'] ?? 'Login failed');
    }
    return decoded;
  }

  Future<void> signup(String email, String password) async {
    final uri = Uri.parse('$baseUrl/auth/register');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(decoded['message'] ?? 'Signup failed');
    }
  }

  Future<Map<String, dynamic>> getMe(String token) async {
    final uri = Uri.parse('$baseUrl/auth/me');
    final response = await http.get(uri, headers: {
      'Authorization': 'Bearer $token',
    }).timeout(const Duration(seconds: 15));

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(decoded['message'] ?? 'Failed to fetch profile');
    }
    return decoded;
  }

  Future<void> pushRecent(String token, Track track) async {
    final uri = Uri.parse('$baseUrl/auth/recent');
    await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'track': track.toJson()}),
        )
        .timeout(const Duration(seconds: 10));
  }

  Future<List<Map<String, dynamic>>> getPlaylists(String token) async {
    final cached = _playlistCache[token];
    if (cached != null && !cached.isExpired) {
      return cached.value;
    }
    final uri = Uri.parse('$baseUrl/playlists');
    final response = await http.get(uri, headers: {
      'Authorization': 'Bearer $token',
    }).timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const [];
    }

    final decoded = jsonDecode(response.body);
    if (decoded is List) {
      final playlists = decoded.whereType<Map<String, dynamic>>().toList();
      _playlistCache[token] = _CacheEntry(playlists);
      return playlists;
    }
    return const [];
  }

  Future<Map<String, dynamic>> createPlaylist(String token, String name) async {
    final uri = Uri.parse('$baseUrl/playlists');
    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'name': name}),
        )
        .timeout(const Duration(seconds: 15));

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(decoded['message'] ?? 'Failed to create playlist');
    }
    _playlistCache.remove(token);
    return decoded;
  }

  Future<void> addTrackToPlaylist(String token, String playlistId, Track track) async {
    final uri = Uri.parse('$baseUrl/playlists/$playlistId/tracks');
    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'track': track.toJson()}),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
      throw Exception(decoded?['message'] ?? 'Failed to add track');
    }
    _playlistCache.remove(token);
  }

  Future<void> removeTrackFromPlaylist(String token, String playlistId, String trackId) async {
    final uri = Uri.parse('$baseUrl/playlists/$playlistId/tracks/$trackId');
    final response = await http.delete(uri, headers: {
      'Authorization': 'Bearer $token',
    }).timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
      throw Exception(decoded?['message'] ?? 'Failed to remove track');
    }
    _playlistCache.remove(token);
  }

  Future<void> deletePlaylist(String token, String playlistId) async {
    final uri = Uri.parse('$baseUrl/playlists/$playlistId');
    final response = await http.delete(uri, headers: {
      'Authorization': 'Bearer $token',
    }).timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
      throw Exception(decoded?['message'] ?? 'Failed to delete playlist');
    }
    _playlistCache.remove(token);
  }

  Future<void> changePassword(String token, String currentPassword, String newPassword) async {
    final uri = Uri.parse('$baseUrl/auth/change-password');
    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'currentPassword': currentPassword,
            'newPassword': newPassword,
          }),
        )
        .timeout(const Duration(seconds: 15));

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(decoded['message'] ?? 'Failed to change password');
    }
  }

  void clearCaches() {
    _songCache.clear();
    _suggestCache.clear();
    _playlistCache.clear();
  }

  Future<List<Track>> generatePlaylist(String description) async {
    final uri = Uri.parse('$baseUrl/ai/generate-playlist');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'description': description}),
        )
        .timeout(const Duration(minutes: 1));

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(decoded['message'] ?? 'Failed to generate playlist');
    }

    final tracks = (decoded['tracks'] as List?) ?? const [];
    return tracks.whereType<Map<String, dynamic>>().map(Track.fromApi).toList();
  }

  Future<List<Track>> resolveSongs(List<String> songNames) async {
    final uri = Uri.parse('$baseUrl/ai/resolve-songs');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'songNames': songNames}),
        )
        .timeout(const Duration(minutes: 1));

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(decoded['message'] ?? 'Failed to resolve songs');
    }

    final tracks = (decoded['tracks'] as List?) ?? const [];
    return tracks.whereType<Map<String, dynamic>>().map(Track.fromApi).toList();
  }
}

class _CacheEntry<T> {
  final T value;
  final DateTime createdAt = DateTime.now();

  _CacheEntry(this.value);

  bool get isExpired => DateTime.now().difference(createdAt) > const Duration(minutes: 15);
}

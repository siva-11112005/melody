import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/track.dart';

class ApiService {
  static const String baseUrl = 'https://melody-beqg.onrender.com/api';

  Future<List<Track>> searchSongs(String query, {int page = 1, int limit = 30}) async {
    final uri = Uri.parse('$baseUrl/music/search').replace(queryParameters: {
      'query': query,
      'page': '$page',
      'limit': '$limit',
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Search failed (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>?;
    final results = (data?['results'] as List?) ?? const [];
    return results.whereType<Map<String, dynamic>>().map(Track.fromApi).toList();
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
    final uri = Uri.parse('$baseUrl/music/suggest').replace(queryParameters: {'query': query});
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode < 200 || response.statusCode >= 300) return const [];
    final decoded = jsonDecode(response.body);
    if (decoded is List) {
      return decoded.map((e) => e.toString()).toList();
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
    final uri = Uri.parse('$baseUrl/playlists');
    final response = await http.get(uri, headers: {
      'Authorization': 'Bearer $token',
    }).timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const [];
    }

    final decoded = jsonDecode(response.body);
    if (decoded is List) {
      return decoded.whereType<Map<String, dynamic>>().toList();
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

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/track.dart';
import '../utils/des_cipher.dart';

class ApiService {
  static const String baseUrl = 'https://melody-beqg.onrender.com/api';
  static const String jiosaavnBase = 'https://www.jiosaavn.com/api.php';

  final Map<String, _CacheEntry<List<Track>>> _songCache = {};
  final Map<String, _CacheEntry<List<String>>> _suggestCache = {};
  final Map<String, _CacheEntry<List<Map<String, dynamic>>>> _playlistCache = {};

  // ---------------------------------------------------------------------------
  // TRENDING & ERA BASED DISCOVERY
  // ---------------------------------------------------------------------------
  /// Fetches top chartbusters & genuine high-play hits.
  /// Uses official JioSaavn Top 50 Charts and Era playlists with instant direct parsing.
  Future<List<Track>> getTrendingSongs({
    String era = 'default',
    List<String>? languages,
    int limit = 40,
  }) async {
    final cacheKey = 'trending:$era:${(languages ?? ['tamil']).join(',')}:$limit';
    final cached = _songCache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return cached.value;
    }

    List<Track> tracks = [];

    try {
      // Pick curated top playlists by Era
      switch (era.toLowerCase()) {
        case '80s':
          // 80s Tamil Hits: "Tamil 1980s" (901538755) & "Decade Of Singers 1980s" (832228324)
          tracks = await _fetchJioSaavnPlaylist('901538755');
          if (tracks.length < 15) {
            final extra = await _fetchJioSaavnPlaylist('832228324');
            tracks.addAll(extra);
          }
          break;

        case '90s':
          // 90s Tamil Classics: "Best Of 90s - Tamil" (801896864) & "Ilaiyaraaja 90s Hits" (2841421)
          tracks = await _fetchJioSaavnPlaylist('801896864');
          if (tracks.length < 15) {
            final extra = await _fetchJioSaavnPlaylist('2841421');
            tracks.addAll(extra);
          }
          break;

        case '2000s':
          // 2000s Tamil Hits: "Tamil 2000s" (1170578783) & "2000s Romance" (742996492)
          tracks = await _fetchJioSaavnPlaylist('1170578783');
          if (tracks.length < 15) {
            final extra = await _fetchJioSaavnPlaylist('742996492');
            tracks.addAll(extra);
          }
          break;

        case '2010s':
          // 2010s Tamil Top Hits (Anirudh, Dhanush, Vijay era)
          tracks = await _fetchJioSaavnPlaylist('809058495');
          if (tracks.length < 15) {
            final searchExtra = await _directJioSaavnSearch('2010s tamil superhits', limit: 25);
            tracks.addAll(searchExtra);
          }
          break;

        case 'latest':
        case 'default':
        default:
          // Official JioSaavn "Tamil: India Superhits Top 50" (1134651042)
          // 50 full-length, highest-played viral hits!
          tracks = await _fetchJioSaavnPlaylist('1134651042');
          if (tracks.length < 20) {
            final trendingExtra = await _fetchJioSaavnPlaylist('1268500351'); // Trending Tamil Songs
            tracks.addAll(trendingExtra);
          }
          break;
      }
    } catch (e) {
      debugPrint('Trending fetch error: $e');
    }

    // Fallback if playlist fetch failed: direct search
    if (tracks.isEmpty) {
      try {
        final query = era == '80s'
            ? '80s tamil classic old hit songs'
            : era == '90s'
                ? '90s tamil superhit evergreen songs'
                : era == '2000s'
                    ? '2000s tamil superhit songs'
                    : 'top tamil chart hits 2025 2026';
        tracks = await _directJioSaavnSearch(query, limit: limit);
      } catch (_) {}
    }

    // Deduplicate & filter out short cut clips (< 95 sec) or promotional versions
    final seen = <String>{};
    final cleaned = <Track>[];
    for (final t in tracks) {
      if (t.id.isEmpty) continue;
      if (seen.contains(t.id)) continue;
      if (_isShortOrLowQuality(t)) continue;
      seen.add(t.id);
      cleaned.add(t);
    }

    final result = cleaned.take(limit).toList();
    _songCache[cacheKey] = _CacheEntry(result);
    return result;
  }

  // ---------------------------------------------------------------------------
  // SEARCH SONGS (FAST DUAL-ENGINE: BACKEND + INSTANT JIOSAAVN FALLBACK)
  // ---------------------------------------------------------------------------
  Future<List<Track>> searchSongs(String query, {int page = 1, int limit = 30}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final cacheKey = 'search:$trimmed:$page:$limit';
    final cached = _songCache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return cached.value;
    }

    List<Track> tracks = [];

    // Try backend with a fast 3.5-second timeout
    try {
      final uri = Uri.parse('$baseUrl/music/search').replace(queryParameters: {
        'query': trimmed,
        'page': '$page',
        'limit': '$limit',
      });
      final response = await http.get(uri).timeout(const Duration(milliseconds: 3500));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded['data'] as Map<String, dynamic>?;
        final results = (data?['results'] as List?) ?? const [];
        tracks = results
            .whereType<Map<String, dynamic>>()
            .map(Track.fromApi)
            .where((t) => !_isShortOrLowQuality(t))
            .toList();
      }
    } catch (_) {
      // Backend asleep or slow -> immediately fall through to direct JioSaavn search!
    }

    // Direct JioSaavn fallback (responds in 200ms!)
    if (tracks.isEmpty) {
      try {
        tracks = await _directJioSaavnSearch(trimmed, page: page, limit: limit);
      } catch (e) {
        debugPrint('Direct JioSaavn search error: $e');
      }
    }

    _songCache[cacheKey] = _CacheEntry(tracks);
    return tracks;
  }

  // ---------------------------------------------------------------------------
  // GET SONG BY ID (WITH DIRECT JIOSAAVN FALLBACK & FRESH URL DECRYPTION)
  // ---------------------------------------------------------------------------
  Future<Track?> getSongById(String songId) async {
    if (songId.trim().isEmpty) return null;

    // Try backend first with 2.5s timeout
    try {
      final uri = Uri.parse('$baseUrl/music/song/$songId');
      final response = await http.get(uri).timeout(const Duration(milliseconds: 2500));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        if (decoded.containsKey('id') || decoded.containsKey('title')) {
          final t = Track.fromApi(decoded);
          if (t.url != null && t.url!.isNotEmpty) return t;
        }
      }
    } catch (_) {}

    // Direct JioSaavn API fallback
    try {
      final uri = Uri.parse(jiosaavnBase).replace(queryParameters: {
        '__call': 'song.getDetails',
        'cc': 'in',
        '_marker': '0',
        '_format': 'json',
        'pids': songId,
      });
      final response = await http.get(uri, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 6));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        Map<String, dynamic>? songData;
        if (decoded is Map<String, dynamic>) {
          if (decoded.containsKey('songs') && decoded['songs'] is List && (decoded['songs'] as List).isNotEmpty) {
            songData = (decoded['songs'] as List).first as Map<String, dynamic>?;
          } else if (decoded.containsKey(songId)) {
            songData = decoded[songId] as Map<String, dynamic>?;
          }
        }
        if (songData != null) {
          return _parseJioSaavnSong(songData);
        }
      }
    } catch (e) {
      debugPrint('Direct getSongById error: $e');
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // AUTOCOMPLETE SUGGESTIONS
  // ---------------------------------------------------------------------------
  Future<List<String>> suggest(String query) async {
    if (query.trim().length < 2) return const [];
    final cacheKey = query.trim().toLowerCase();
    final cached = _suggestCache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return cached.value;
    }

    // Try JioSaavn direct autocomplete API
    try {
      final uri = Uri.parse(jiosaavnBase).replace(queryParameters: {
        '__call': 'autocomplete.get',
        '_format': 'json',
        '_marker': '0',
        'ctx': 'web6dot0',
        'query': query.trim(),
      });
      final response = await http.get(uri, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      }).timeout(const Duration(seconds: 4));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
        final suggestions = <String>[];
        if (decoded?['songs']?['data'] is List) {
          for (final s in decoded!['songs']['data']) {
            if (s['title'] != null) suggestions.add(_decodeHtml(s['title'].toString()));
          }
        }
        if (decoded?['artists']?['data'] is List) {
          for (final a in decoded!['artists']['data']) {
            if (a['title'] != null) suggestions.add(_decodeHtml(a['title'].toString()));
          }
        }
        final unique = suggestions.toSet().take(8).toList();
        _suggestCache[cacheKey] = _CacheEntry(unique);
        return unique;
      }
    } catch (_) {}

    return const [];
  }

  // ---------------------------------------------------------------------------
  // AUTHENTICATION
  // ---------------------------------------------------------------------------
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
    try {
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
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  Future<void> saveOnboarding(String token, List<String> languages, List<String> artists) async {
    try {
      final uri = Uri.parse('$baseUrl/auth/onboarding');
      await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'languages': languages, 'artists': artists}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // PLAYLISTS (OFFLINE-FIRST + INSTANT RESPONSIVE + BACKEND SYNC)
  // ---------------------------------------------------------------------------
  static const String _playlistsLocalKey = 'user_playlists_cache_v2';

  Future<List<Map<String, dynamic>>> getPlaylists(String token) async {
    final cached = _playlistCache[token];
    if (cached != null && !cached.isExpired) {
      return cached.value;
    }

    // 1. Load from local cache first (instant response)
    List<Map<String, dynamic>> localPlaylists = await _loadLocalPlaylists();

    // 2. Sync with backend if token available
    if (token.isNotEmpty) {
      try {
        final uri = Uri.parse('$baseUrl/playlists');
        final response = await http.get(uri, headers: {
          'Authorization': 'Bearer $token',
        }).timeout(const Duration(milliseconds: 4000));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(response.body);
          if (decoded is List) {
            final remote = decoded.whereType<Map<String, dynamic>>().toList();
            // Merge remote with any newly added local playlists
            final merged = _mergePlaylists(localPlaylists, remote);
            await _saveLocalPlaylists(merged);
            _playlistCache[token] = _CacheEntry(merged);
            return merged;
          }
        }
      } catch (e) {
        debugPrint('Playlists backend sync failed (using local): $e');
      }
    }

    _playlistCache[token] = _CacheEntry(localPlaylists);
    return localPlaylists;
  }

  Future<Map<String, dynamic>> createPlaylist(String token, String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) throw Exception('Playlist name is required');

    final newId = 'pl_${DateTime.now().millisecondsSinceEpoch}';
    final newPl = {
      'id': newId,
      '_id': newId,
      'name': trimmedName,
      'tracks': <Map<String, dynamic>>[],
      'createdAt': DateTime.now().toIso8601String(),
    };

    // Update local immediately (zero delay!)
    final local = await _loadLocalPlaylists();
    local.insert(0, newPl);
    await _saveLocalPlaylists(local);
    _playlistCache.remove(token);

    // Sync to backend
    if (token.isNotEmpty) {
      try {
        final uri = Uri.parse('$baseUrl/playlists');
        final response = await http
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode({'name': trimmedName}),
            )
            .timeout(const Duration(seconds: 8));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          final remoteId = (decoded['_id'] ?? decoded['id'])?.toString();
          if (remoteId != null && remoteId.isNotEmpty) {
            // Replace local temporary id with remote id
            newPl['id'] = remoteId;
            newPl['_id'] = remoteId;
            await _saveLocalPlaylists(local);
          }
          return decoded;
        }
      } catch (e) {
        debugPrint('Backend create playlist failed, saved locally: $e');
      }
    }

    return newPl;
  }

  Future<void> addTrackToPlaylist(String token, String playlistId, Track track) async {
    // 1. Immediately update local playlist
    final local = await _loadLocalPlaylists();
    for (final pl in local) {
      final pid = (pl['_id'] ?? pl['id'])?.toString();
      if (pid == playlistId) {
        final tracks = (pl['tracks'] as List?) ?? [];
        final alreadyHas = tracks.any((t) => (t is Map) && t['id'] == track.id);
        if (!alreadyHas) {
          tracks.add(track.toJson());
          pl['tracks'] = tracks;
        }
        break;
      }
    }
    await _saveLocalPlaylists(local);
    _playlistCache.remove(token);

    // 2. Sync to backend
    if (token.isNotEmpty && !playlistId.startsWith('pl_')) {
      try {
        final uri = Uri.parse('$baseUrl/playlists/$playlistId/tracks');
        await http
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode({'track': track.toJson()}),
            )
            .timeout(const Duration(seconds: 8));
      } catch (e) {
        debugPrint('Backend add track sync warning: $e');
      }
    }
  }

  Future<void> removeTrackFromPlaylist(String token, String playlistId, String trackId) async {
    // 1. Immediately update local playlist
    final local = await _loadLocalPlaylists();
    for (final pl in local) {
      final pid = (pl['_id'] ?? pl['id'])?.toString();
      if (pid == playlistId) {
        final tracks = (pl['tracks'] as List?) ?? [];
        tracks.removeWhere((t) => (t is Map) && t['id'] == trackId);
        pl['tracks'] = tracks;
        break;
      }
    }
    await _saveLocalPlaylists(local);
    _playlistCache.remove(token);

    // 2. Sync to backend
    if (token.isNotEmpty && !playlistId.startsWith('pl_')) {
      try {
        final uri = Uri.parse('$baseUrl/playlists/$playlistId/tracks/$trackId');
        await http.delete(uri, headers: {
          'Authorization': 'Bearer $token',
        }).timeout(const Duration(seconds: 8));
      } catch (e) {
        debugPrint('Backend remove track sync warning: $e');
      }
    }
  }

  Future<void> deletePlaylist(String token, String playlistId) async {
    // 1. Immediately remove from local
    final local = await _loadLocalPlaylists();
    local.removeWhere((pl) {
      final pid = (pl['_id'] ?? pl['id'])?.toString();
      return pid == playlistId;
    });
    await _saveLocalPlaylists(local);
    _playlistCache.remove(token);

    // 2. Sync to backend
    if (token.isNotEmpty && !playlistId.startsWith('pl_')) {
      try {
        final uri = Uri.parse('$baseUrl/playlists/$playlistId');
        await http.delete(uri, headers: {
          'Authorization': 'Bearer $token',
        }).timeout(const Duration(seconds: 8));
      } catch (e) {
        debugPrint('Backend delete playlist sync warning: $e');
      }
    }
  }

  Future<List<Map<String, dynamic>>> _loadLocalPlaylists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_playlistsLocalKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List;
        return decoded.whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> _saveLocalPlaylists(List<Map<String, dynamic>> playlists) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_playlistsLocalKey, jsonEncode(playlists));
    } catch (_) {}
  }

  List<Map<String, dynamic>> _mergePlaylists(List<Map<String, dynamic>> local, List<Map<String, dynamic>> remote) {
    final map = <String, Map<String, dynamic>>{};
    for (final r in remote) {
      final id = (r['_id'] ?? r['id'])?.toString() ?? '';
      if (id.isNotEmpty) map[id] = r;
    }
    for (final l in local) {
      final id = (l['_id'] ?? l['id'])?.toString() ?? '';
      if (id.isNotEmpty && !map.containsKey(id)) {
        map[id] = l;
      }
    }
    return map.values.toList();
  }

  // ---------------------------------------------------------------------------
  // PROFILE & SETTINGS
  // ---------------------------------------------------------------------------
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

  // ---------------------------------------------------------------------------
  // AI PLAYLIST GENERATOR
  // ---------------------------------------------------------------------------
  Future<List<Track>> generatePlaylist(String description) async {
    try {
      final uri = Uri.parse('$baseUrl/ai/generate-playlist');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'description': description}),
          )
          .timeout(const Duration(seconds: 40));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final tracks = (decoded['tracks'] as List?) ?? const [];
        final parsed = tracks.whereType<Map<String, dynamic>>().map(Track.fromApi).toList();
        if (parsed.isNotEmpty) return parsed;
      }
    } catch (_) {}

    // Fallback: Use direct search with prompt keywords
    return searchSongs(description, limit: 15);
  }

  Future<List<Track>> resolveSongs(List<String> songNames) async {
    final results = <Track>[];
    for (final name in songNames.take(15)) {
      final found = await searchSongs(name, limit: 1);
      if (found.isNotEmpty) {
        results.add(found.first);
      }
    }
    return results;
  }

  // ---------------------------------------------------------------------------
  // INTERNAL DIRECT JIOSAAVN HELPERS
  // ---------------------------------------------------------------------------
  Future<List<Track>> _fetchJioSaavnPlaylist(String listId) async {
    try {
      final uri = Uri.parse(jiosaavnBase).replace(queryParameters: {
        '__call': 'playlist.getDetails',
        '_format': 'json',
        '_marker': '0',
        'api_version': '4',
        'ctx': 'web6dot0',
        'listid': listId,
      });

      final response = await http.get(uri, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 8));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
        final list = (decoded?['list'] as List?) ?? const [];
        final tracks = <Track>[];
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            final t = _parseJioSaavnSong(item);
            if (t != null && !_isShortOrLowQuality(t)) {
              tracks.add(t);
            }
          }
        }
        return tracks;
      }
    } catch (e) {
      debugPrint('Playlist fetch direct error for $listId: $e');
    }
    return const [];
  }

  Future<List<Track>> _directJioSaavnSearch(String query, {int page = 1, int limit = 30}) async {
    try {
      final uri = Uri.parse(jiosaavnBase).replace(queryParameters: {
        '__call': 'search.getResults',
        '_format': 'json',
        '_marker': '0',
        'api_version': '4',
        'ctx': 'web6dot0',
        'n': '$limit',
        'p': '$page',
        'q': query,
      });

      final response = await http.get(uri, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 8));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
        final results = (decoded?['results'] as List?) ?? const [];
        final tracks = <Track>[];
        for (final item in results) {
          if (item is Map<String, dynamic>) {
            final t = _parseJioSaavnSong(item);
            if (t != null && !_isShortOrLowQuality(t)) {
              tracks.add(t);
            }
          }
        }
        return tracks;
      }
    } catch (e) {
      debugPrint('JioSaavn direct search error: $e');
    }
    return const [];
  }

  Track? _parseJioSaavnSong(Map<String, dynamic> song) {
    try {
      final id = (song['id'] ?? '').toString();
      if (id.isEmpty) return null;

      final title = _decodeHtml((song['title'] ?? song['song'] ?? song['name'] ?? 'Unknown').toString());
      final moreInfo = song['more_info'] as Map<String, dynamic>? ?? {};

      // Resolve artists
      String artist = '';
      if (moreInfo['artistMap']?['primary_artists'] is List) {
        final names = (moreInfo['artistMap']['primary_artists'] as List)
            .whereType<Map>()
            .map((a) => (a['name'] ?? '').toString().trim())
            .where((n) => n.isNotEmpty)
            .toList();
        if (names.isNotEmpty) artist = names.join(', ');
      }
      if (artist.isEmpty) {
        artist = (moreInfo['primary_artists'] ?? song['primary_artists'] ?? song['subtitle'] ?? 'Unknown').toString();
      }
      artist = _decodeHtml(artist);

      // Duration in milliseconds
      final durSec = int.tryParse('${moreInfo['duration'] ?? song['duration'] ?? 0}') ?? 0;
      final durationMs = durSec * 1000;

      // High-res Artwork
      final rawImage = (song['image'] ?? '').toString();
      final artwork = rawImage.isNotEmpty
          ? rawImage.replaceAll('150x150', '500x500').replaceAll('50x50', '500x500')
          : null;

      // Stream URL decryption
      final encUrl = (moreInfo['encrypted_media_url'] ?? '').toString();
      String streamUrl = '';
      if (encUrl.isNotEmpty) {
        final decrypted = DesCipher.decryptMediaUrl(encUrl);
        if (decrypted != null && decrypted.isNotEmpty) {
          // Default to 160kbps AAC for crystal-clear, buffer-free playback
          streamUrl = decrypted.replaceAll('_96.mp4', '_160.mp4').replaceAll('_320.mp4', '_160.mp4');
        }
      }

      if (streamUrl.isEmpty) {
        final preview = (moreInfo['media_preview_url'] ?? '').toString();
        if (preview.isNotEmpty) {
          streamUrl = preview.replaceAll('preview', 'aac').replaceAll('_96_p.mp4', '_160.mp4');
        }
      }

      final downloadUrls = <Map<String, String>>[];
      if (streamUrl.isNotEmpty) {
        downloadUrls.add({
          'quality': '96kbps',
          'url': streamUrl.replaceAll('_160.mp4', '_96.mp4').replaceAll('_320.mp4', '_96.mp4'),
        });
        downloadUrls.add({
          'quality': '160kbps',
          'url': streamUrl,
        });
        downloadUrls.add({
          'quality': '320kbps',
          'url': streamUrl.replaceAll('_96.mp4', '_320.mp4').replaceAll('_160.mp4', '_320.mp4'),
        });
      }

      return Track(
        id: id,
        title: title,
        artist: artist,
        album: _decodeHtml((moreInfo['album'] ?? song['album'] ?? '').toString()),
        language: (song['language'] ?? moreInfo['language'] ?? '').toString(),
        artwork: artwork,
        url: streamUrl.isNotEmpty ? streamUrl : null,
        durationMs: durationMs,
        downloadUrl: downloadUrls,
      );
    } catch (_) {
      return null;
    }
  }

  bool _isShortOrLowQuality(Track track) {
    // Filter out clips < 95 seconds (promo / reel cuts / 60s teaser clips)
    if (track.durationMs > 0 && track.durationMs < 95000) return true;
    final lower = track.title.toLowerCase();
    if (RegExp(r'\b(promo|teaser|trailer|preview|clip|reel|shorts?|ringtone|status|interview|dialogue|speech|announcement|bgm|theme|trending version|cut song)\b')
        .hasMatch(lower)) {
      return true;
    }
    return false;
  }

  String _decodeHtml(String text) {
    return text
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&#039;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }
}

class _CacheEntry<T> {
  final T value;
  final DateTime createdAt = DateTime.now();

  _CacheEntry(this.value);

  bool get isExpired => DateTime.now().difference(createdAt) > const Duration(minutes: 20);
}

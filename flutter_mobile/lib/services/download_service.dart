import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/track.dart';

class DownloadService {
  static const _downloadsKey = 'downloads';
  List<Track>? _cachedDownloads;

  String trackKey(Track track) {
    return _normalize('${track.title} ${track.artist}');
  }

  String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  Future<List<Track>> getDownloads() async {
    if (_cachedDownloads != null) {
      return List<Track>.unmodifiable(_cachedDownloads!);
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_downloadsKey);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw) as List;
    final items = decoded
        .whereType<Map<String, dynamic>>()
        .map((e) => Track.fromJson(e))
        .toList();
    _cachedDownloads = items;
    return List<Track>.unmodifiable(items);
  }

  Future<Track?> findDownloadedTrack(String trackId) async {
    final tracks = await getDownloads();
    for (final track in tracks) {
      if (track.id == trackId) {
        if (track.localUri != null) {
          final file = File(track.localUri!);
          if (await file.exists()) {
            return track;
          }
        }
        break;
      }
    }
    return null;
  }

  Future<Track?> findDownloadedTrackFor(Track track) async {
    final tracks = await getDownloads();
    final key = trackKey(track);
    for (final item in tracks) {
      final matchesById = item.id == track.id;
      final matchesByFingerprint = item.fingerprint != null && item.fingerprint == key;
      final matchesBySong = trackKey(item) == key;
      if (matchesById || matchesByFingerprint || matchesBySong) {
        if (item.localUri != null) {
          final file = File(item.localUri!);
          if (await file.exists()) {
            return item;
          }
        }
      }
    }
    return null;
  }

  Future<bool> isDownloaded(String trackId) async {
    return (await findDownloadedTrack(trackId)) != null;
  }

  Future<bool> isDownloadedTrack(Track track) async {
    return (await findDownloadedTrackFor(track)) != null;
  }

  Future<Set<String>> getDownloadedIds() async {
    final tracks = await getDownloads();
    final validIds = <String>{};
    for (final track in tracks) {
      if (track.localUri == null) continue;
      final file = File(track.localUri!);
      if (await file.exists()) {
        if (track.id.isNotEmpty) validIds.add(track.id);
        validIds.add(trackKey(track));
      }
    }
    return validIds;
  }

  Future<void> removeDownload(String trackId) async {
    final tracks = await getDownloads();
    Track? target;
    for (final t in tracks) {
      if (t.id == trackId) {
        target = t;
        break;
      }
    }
    if (target?.localUri != null) {
      final file = File(target!.localUri!);
      if (await file.exists()) {
        await file.delete();
      }
    }
    final updated = tracks.where((e) => e.id != trackId).toList();
    await _save(updated);
  }

  Future<Track> downloadTrack(Track track) async {
    final existing = await getDownloads();
    Track? found;
    for (final t in existing) {
      if (t.id == track.id && t.localUri != null) {
        found = t;
        break;
      }
    }
    if (found != null) {
      final file = File(found.localUri!);
      if (await file.exists()) return found;
    }

    final url = _resolveBestUrl(track);
    if (url == null) throw Exception('No download URL available');

    final dir = await getApplicationDocumentsDirectory();
    final safeTitle = track.title.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    final ext = url.toLowerCase().contains('.m4a') ? 'm4a' : 'mp4';
    final path = '${dir.path}/${track.id}_$safeTitle.$ext';

    final response = await http.get(Uri.parse(url), headers: {
      'User-Agent': 'Mozilla/5.0',
      'Referer': 'https://www.jiosaavn.com/',
    }).timeout(const Duration(seconds: 45));

    if (response.statusCode < 200 || response.statusCode >= 300 || response.bodyBytes.length < 10000) {
      throw Exception('Download failed');
    }

    final file = File(path);
    await file.writeAsBytes(response.bodyBytes);

    final downloaded = track.copyWith(
      url: path,
      localUri: path,
      fingerprint: trackKey(track),
    );
    final withoutCurrent = existing.where((e) {
      final sameId = e.id == track.id;
      final sameFingerprint = e.fingerprint != null && e.fingerprint == downloaded.fingerprint;
      final sameSong = trackKey(e) == downloaded.fingerprint;
      return !(sameId || sameFingerprint || sameSong);
    }).toList();
    await _save([...withoutCurrent, downloaded]);
    return downloaded;
  }

  String? _resolveBestUrl(Track track) {
    if (track.localUri != null) return track.localUri;
    if (track.url != null && track.url!.startsWith('http')) return track.url;
    for (final item in track.downloadUrl.reversed) {
      if (item is Map && item['url'] is String) {
        return item['url'] as String;
      }
      if (item is String && item.startsWith('http')) {
        return item;
      }
    }
    return null;
  }

  Future<void> _save(List<Track> tracks) async {
    _cachedDownloads = List<Track>.from(tracks);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _downloadsKey,
      jsonEncode(tracks.map((e) => e.toJson()).toList()),
    );
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/track.dart';

class DownloadService {
  static const _downloadsKey = 'downloads';

  Future<List<Track>> getDownloads() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_downloadsKey);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw) as List;
    return decoded
        .whereType<Map<String, dynamic>>()
        .map((e) => Track.fromJson(e))
        .toList();
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

    final downloaded = track.copyWith(url: path, localUri: path);
    final withoutCurrent = existing.where((e) => e.id != track.id).toList();
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _downloadsKey,
      jsonEncode(tracks.map((e) => e.toJson()).toList()),
    );
  }
}

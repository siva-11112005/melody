import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/track.dart';
import '../services/api_service.dart';

class LibraryState extends ChangeNotifier {
  final ApiService _api;

  LibraryState(this._api);

  List<Track> recentlyPlayed = [];
  List<Track> likedSongs = [];
  List<String> recentSearches = [];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final recentRaw = prefs.getString('recentlyPlayed');
    final likedRaw = prefs.getString('likedSongs');

    if (recentRaw != null && recentRaw.isNotEmpty) {
      final parsed = jsonDecode(recentRaw) as List;
      recentlyPlayed = parsed.whereType<Map<String, dynamic>>().map(Track.fromJson).toList();
    }
    if (likedRaw != null && likedRaw.isNotEmpty) {
      final parsed = jsonDecode(likedRaw) as List;
      likedSongs = parsed.whereType<Map<String, dynamic>>().map(Track.fromJson).toList();
    }
    recentSearches = prefs.getStringList('recentSearches') ?? [];
    notifyListeners();
  }

  Future<void> addRecentSearch(String query) async {
    final cleaned = query.trim();
    if (cleaned.isEmpty) return;
    recentSearches = [cleaned, ...recentSearches.where((e) => e != cleaned)].take(10).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('recentSearches', recentSearches);
    notifyListeners();
  }

  Future<void> addRecentlyPlayed(Track track, {String? token}) async {
    recentlyPlayed = [track, ...recentlyPlayed.where((e) => e.id != track.id)].take(20).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('recentlyPlayed', jsonEncode(recentlyPlayed.map((e) => e.toJson()).toList()));
    notifyListeners();

    if (token != null && token.isNotEmpty) {
      try {
        await _api.pushRecent(token, track);
      } catch (_) {
        // Keep local state as source of truth on network failure.
      }
    }
  }

  Future<void> toggleLike(Track track) async {
    final exists = likedSongs.any((e) => e.id == track.id);
    if (exists) {
      likedSongs = likedSongs.where((e) => e.id != track.id).toList();
    } else {
      likedSongs = [track, ...likedSongs.where((e) => e.id != track.id)];
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('likedSongs', jsonEncode(likedSongs.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  bool isLiked(String trackId) => likedSongs.any((e) => e.id == trackId);
}

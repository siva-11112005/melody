import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';

class AuthState extends ChangeNotifier {
  final ApiService _api;

  AuthState(this._api);

  bool isReady = false;
  bool onboardingComplete = false;
  bool get isLoggedIn => token != null;

  String? token;
  Map<String, dynamic>? user;

  String _onboardingKey([Map<String, dynamic>? profile]) {
    final email = (profile?['email'] ?? user?['email'] ?? '').toString().trim().toLowerCase();
    if (email.isNotEmpty) {
      return 'onboardingComplete_$email';
    }
    final userId = (profile?['id'] ?? profile?['_id'] ?? user?['id'] ?? user?['_id'] ?? '').toString().trim();
    if (userId.isNotEmpty) {
      return 'onboardingComplete_$userId';
    }
    return 'onboardingComplete';
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token');
    final userRaw = prefs.getString('user');
    if (userRaw != null && userRaw.isNotEmpty) {
      user = jsonDecode(userRaw) as Map<String, dynamic>;
    }

    // First check server-side onboarding status if logged in
    if (token != null && token!.isNotEmpty) {
      try {
        final meData = await _api.getMe(token!);
        final serverUser = meData['user'] as Map<String, dynamic>?;
        if (serverUser != null) {
          final serverOnboarded = serverUser['onboardingComplete'] as bool? ?? false;
          if (serverOnboarded) {
            // Restore onboarding from server — survives reinstall
            final langs = (serverUser['preferredLanguages'] as List?)?.cast<String>() ?? [];
            final artists = (serverUser['favoriteArtists'] as List?)?.cast<String>() ?? [];
            await prefs.setStringList('preferredLanguages', langs);
            await prefs.setStringList('favoriteArtists', artists);
            await prefs.setBool(_onboardingKey(serverUser), true);
            user = serverUser;
            await prefs.setString('user', jsonEncode(serverUser));
            onboardingComplete = true;
            isReady = true;
            notifyListeners();
            return;
          }
        }
      } catch (_) {
        // Server check failed — fall back to local SharedPreferences
      }
    }

    // Local fallback check
    final language = prefs.getStringList('preferredLanguages') ?? const [];
    final artists = prefs.getStringList('favoriteArtists') ?? const [];
    onboardingComplete = prefs.getBool(_onboardingKey()) ?? (language.isNotEmpty && artists.isNotEmpty);

    isReady = true;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final result = await _api.login(email, password);
    token = result['token']?.toString();
    user = result['user'] as Map<String, dynamic>?;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token ?? '');
    await prefs.setString('user', jsonEncode(user ?? <String, dynamic>{}));

    // Server returns onboarding status — restore without asking user again
    final serverOnboarded = user?['onboardingComplete'] as bool? ?? false;
    if (serverOnboarded) {
      final langs = (user?['preferredLanguages'] as List?)?.cast<String>() ?? [];
      final arts = (user?['favoriteArtists'] as List?)?.cast<String>() ?? [];
      await prefs.setStringList('preferredLanguages', langs);
      await prefs.setStringList('favoriteArtists', arts);
      await prefs.setBool(_onboardingKey(user), true);
      onboardingComplete = true;
    } else {
      onboardingComplete = prefs.getBool(_onboardingKey(user)) ?? false;
    }
    notifyListeners();
  }

  Future<void> signup(String email, String password) async {
    await _api.signup(email, password);
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    if (token == null || token!.isEmpty) {
      throw Exception('Please log in again');
    }
    await _api.changePassword(token!, currentPassword, newPassword);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
    token = null;
    user = null;
    notifyListeners();
  }

  Future<void> completeOnboarding(List<String> languages, List<String> artists) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('preferredLanguages', languages);
    await prefs.setStringList('favoriteArtists', artists);
    await prefs.setBool(_onboardingKey(), true);
    onboardingComplete = true;
    notifyListeners();

    // Also save to server in background so reinstall doesn't ask again
    if (token != null && token!.isNotEmpty) {
      _api.saveOnboarding(token!, languages, artists);
    }
  }

  Future<void> updateUserName(String name) async {
    final updated = <String, dynamic>{...?user, 'name': name};
    user = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(updated));
    notifyListeners();
  }

  Future<void> clearAppCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('recentSearches');
    await prefs.remove('recentlyPlayed');
    await prefs.remove('likedSongs');
    notifyListeners();
  }
}

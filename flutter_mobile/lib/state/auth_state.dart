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
    onboardingComplete = prefs.getBool(_onboardingKey(user)) ?? false;
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

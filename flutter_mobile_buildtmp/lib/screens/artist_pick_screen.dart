import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_state.dart';

const Map<String, List<Map<String, String>>> artistsByLanguage = {
  'tamil': [
    {'name': 'Anirudh Ravichander', 'color': '#FF6B6B'},
    {'name': 'A.R. Rahman', 'color': '#6C5CE7'},
    {'name': 'Sid Sriram', 'color': '#00B894'},
    {'name': 'Yuvan Shankar Raja', 'color': '#FDCB6E'},
    {'name': 'D. Imman', 'color': '#E17055'},
    {'name': 'Harris Jayaraj', 'color': '#0984E3'},
    {'name': 'GV Prakash Kumar', 'color': '#E84393'},
    {'name': 'Ilaiyaraaja', 'color': '#00CEC9'},
    {'name': 'SPB', 'color': '#FAB1A0'},
    {'name': 'Shreya Ghoshal', 'color': '#a29bfe'},
  ],
  'hindi': [
    {'name': 'Arijit Singh', 'color': '#6C5CE7'},
    {'name': 'Shreya Ghoshal', 'color': '#E84393'},
    {'name': 'Pritam', 'color': '#00B894'},
    {'name': 'Vishal Mishra', 'color': '#FDCB6E'},
    {'name': 'Jubin Nautiyal', 'color': '#0984E3'},
    {'name': 'Neha Kakkar', 'color': '#FF6B6B'},
    {'name': 'KK', 'color': '#FAB1A0'},
    {'name': 'Atif Aslam', 'color': '#00CEC9'},
    {'name': 'Sonu Nigam', 'color': '#a29bfe'},
    {'name': 'Lata Mangeshkar', 'color': '#E17055'},
  ],
  'english': [
    {'name': 'Ed Sheeran', 'color': '#FF6B6B'},
    {'name': 'Taylor Swift', 'color': '#E84393'},
    {'name': 'The Weeknd', 'color': '#6C5CE7'},
    {'name': 'Dua Lipa', 'color': '#00B894'},
    {'name': 'Billie Eilish', 'color': '#FDCB6E'},
    {'name': 'Post Malone', 'color': '#0984E3'},
    {'name': 'Justin Bieber', 'color': '#E17055'},
    {'name': 'Drake', 'color': '#00CEC9'},
    {'name': 'Ariana Grande', 'color': '#a29bfe'},
    {'name': 'Bruno Mars', 'color': '#FAB1A0'},
  ],
  'telugu': [
    {'name': 'SS Thaman', 'color': '#FF6B6B'},
    {'name': 'Devi Sri Prasad', 'color': '#6C5CE7'},
    {'name': 'Sid Sriram', 'color': '#00B894'},
    {'name': 'Anurag Kulkarni', 'color': '#FDCB6E'},
    {'name': 'Armaan Malik', 'color': '#0984E3'},
    {'name': 'SP Balasubrahmanyam', 'color': '#E84393'},
  ],
  'kannada': [
    {'name': 'Vijay Prakash', 'color': '#FF6B6B'},
    {'name': 'Sonu Nigam', 'color': '#6C5CE7'},
    {'name': 'Haricharan', 'color': '#00B894'},
    {'name': 'Armaan Malik', 'color': '#0984E3'},
    {'name': 'Shankar Mahadevan', 'color': '#FDCB6E'},
  ],
  'malayalam': [
    {'name': 'KJ Yesudas', 'color': '#6C5CE7'},
    {'name': 'Vineeth Sreenivasan', 'color': '#00B894'},
    {'name': 'Sushin Shyam', 'color': '#FF6B6B'},
    {'name': 'Sid Sriram', 'color': '#FDCB6E'},
  ],
  'punjabi': [
    {'name': 'AP Dhillon', 'color': '#FF6B6B'},
    {'name': 'Diljit Dosanjh', 'color': '#6C5CE7'},
    {'name': 'Sidhu Moose Wala', 'color': '#00B894'},
    {'name': 'Karan Aujla', 'color': '#0984E3'},
    {'name': 'Guru Randhawa', 'color': '#E84393'},
  ],
  'bengali': [
    {'name': 'Arijit Singh', 'color': '#6C5CE7'},
    {'name': 'Anupam Roy', 'color': '#00B894'},
    {'name': 'Shreya Ghoshal', 'color': '#E84393'},
  ],
  'marathi': [
    {'name': 'Ajay-Atul', 'color': '#FF6B6B'},
    {'name': 'Shankar Mahadevan', 'color': '#6C5CE7'},
  ],
  'other': [
    {'name': 'Ed Sheeran', 'color': '#FF6B6B'},
    {'name': 'Arijit Singh', 'color': '#6C5CE7'},
    {'name': 'A.R. Rahman', 'color': '#00B894'},
    {'name': 'Anirudh Ravichander', 'color': '#FDCB6E'},
  ],
};

Color _parseColor(String hex) {
  return Color(int.parse(hex.replaceFirst('#', '0xFF')));
}

String _getInitials(String name) {
  return name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').join('').toUpperCase().substring(0, name.split(' ').length >= 2 ? 2 : 1);
}

class ArtistPickScreen extends StatefulWidget {
  const ArtistPickScreen({super.key});

  @override
  State<ArtistPickScreen> createState() => _ArtistPickScreenState();
}

class _ArtistPickScreenState extends State<ArtistPickScreen> {
  final Set<String> selectedArtists = {};
  List<Map<String, String>> artists = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (artists.isEmpty) {
      _loadArtists();
    }
  }

  void _loadArtists() {
    final languages = (ModalRoute.of(context)?.settings.arguments as List?)?.cast<String>() ?? ['english', 'hindi'];
    final seen = <String>{};
    final all = <Map<String, String>>[];
    for (final lang in languages) {
      for (final artist in (artistsByLanguage[lang] ?? [])) {
        if (!seen.contains(artist['name'])) {
          seen.add(artist['name']!);
          all.add(artist);
        }
      }
    }
    setState(() => artists = all);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF121212), Color(0xFF1a1a2e)],
          ),
        ),
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.only(top: 70, left: 20, right: 20, bottom: 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pick Your Artists', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Choose at least 3 artists you love', style: TextStyle(color: Color(0xFFb3b3b3), fontSize: 15)),
                  const SizedBox(height: 30),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    alignment: WrapAlignment.spaceBetween,
                    children: artists.map((artist) {
                      final name = artist['name']!;
                      final color = _parseColor(artist['color']!);
                      final isSelected = selectedArtists.contains(name);

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              selectedArtists.remove(name);
                            } else {
                              selectedArtists.add(name);
                            }
                          });
                        },
                        child: SizedBox(
                          width: 100,
                          child: Column(
                            children: [
                              Container(
                                width: 85,
                                height: 85,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: color,
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF1DB954) : Colors.transparent,
                                    width: 3,
                                  ),
                                ),
                                child: Center(
                                  child: isSelected
                                      ? const Icon(Icons.check, color: Colors.white, size: 30)
                                      : Text(
                                          _getInitials(name),
                                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                name,
                                style: TextStyle(
                                  color: isSelected ? const Color(0xFF1DB954) : const Color(0xFFCCCCCC),
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            // Bottom bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 40, top: 15),
                color: const Color(0xFF121212),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${selectedArtists.length} selected ${selectedArtists.length < 3 ? '(min 3)' : ''}',
                      style: const TextStyle(color: Color(0xFFb3b3b3), fontSize: 14),
                    ),
                    GestureDetector(
                      onTap: selectedArtists.length < 3 ? null : () async {
                        final languages = (ModalRoute.of(context)?.settings.arguments as List?)?.cast<String>() ?? ['Tamil'];
                        final auth = context.read<AuthState>();
                        final navigator = Navigator.of(context);
                        await auth.completeOnboarding(languages, selectedArtists.toList());
                        if (!mounted) return;
                        navigator.pushNamedAndRemoveUntil('/login', (route) => false);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(25),
                          gradient: LinearGradient(
                            colors: selectedArtists.length >= 3
                                ? [const Color(0xFF1DB954), const Color(0xFF1ed760)]
                                : [const Color(0xFF333333), const Color(0xFF444444)],
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text("Let's Go!", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

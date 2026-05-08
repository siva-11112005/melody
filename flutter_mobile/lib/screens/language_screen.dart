import 'package:flutter/material.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  final Set<String> selected = {};

  static const List<Map<String, dynamic>> languages = [
    {'id': 'tamil', 'label': 'Tamil', 'icon': Icons.music_note, 'gradient': [Color(0xFFFF6B6B), Color(0xFFee5a24)]},
    {'id': 'hindi', 'label': 'Hindi', 'icon': Icons.audiotrack, 'gradient': [Color(0xFF6C5CE7), Color(0xFFa29bfe)]},
    {'id': 'english', 'label': 'English', 'icon': Icons.headset, 'gradient': [Color(0xFF00B894), Color(0xFF55efc4)]},
    {'id': 'telugu', 'label': 'Telugu', 'icon': Icons.mic, 'gradient': [Color(0xFFFDCB6E), Color(0xFFf39c12)]},
    {'id': 'kannada', 'label': 'Kannada', 'icon': Icons.campaign, 'gradient': [Color(0xFFE17055), Color(0xFFd63031)]},
    {'id': 'malayalam', 'label': 'Malayalam', 'icon': Icons.hearing, 'gradient': [Color(0xFF0984E3), Color(0xFF74b9ff)]},
    {'id': 'punjabi', 'label': 'Punjabi', 'icon': Icons.album, 'gradient': [Color(0xFFE84393), Color(0xFFfd79a8)]},
    {'id': 'bengali', 'label': 'Bengali', 'icon': Icons.radio, 'gradient': [Color(0xFF00CEC9), Color(0xFF81ecec)]},
    {'id': 'marathi', 'label': 'Marathi', 'icon': Icons.volume_up, 'gradient': [Color(0xFFFAB1A0), Color(0xFFe17055)]},
    {'id': 'other', 'label': 'Other', 'icon': Icons.language, 'gradient': [Color(0xFF636E72), Color(0xFFb2bec3)]},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
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
                  const Text('Choose Your Languages', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Select the languages you enjoy listening to', style: TextStyle(color: Color(0xFFb3b3b3), fontSize: 16)),
                  const SizedBox(height: 30),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: languages.map((lang) {
                      final id = lang['id'] as String;
                      final label = lang['label'] as String;
                      final icon = lang['icon'] as IconData;
                      final gradient = lang['gradient'] as List<Color>;
                      final isSelected = selected.contains(id);

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              selected.remove(id);
                            } else {
                              selected.add(id);
                            }
                          });
                        },
                        child: Container(
                          width: 105,
                          height: 105,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: isSelected ? gradient : [const Color(0xFF2a2a2a), const Color(0xFF333333)],
                            ),
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(icon, color: Colors.white, size: 32),
                                    const SizedBox(height: 6),
                                    Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: Colors.black38,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.check, color: Colors.white, size: 14),
                                  ),
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
                      '${selected.length} language${selected.length != 1 ? 's' : ''} selected',
                      style: const TextStyle(color: Color(0xFFb3b3b3), fontSize: 14),
                    ),
                    GestureDetector(
                      onTap: selected.isEmpty ? null : () {
                        Navigator.pushNamed(context, '/artist-pick', arguments: selected.toList());
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(25),
                          gradient: LinearGradient(
                            colors: selected.isNotEmpty
                                ? [const Color(0xFF1DB954), const Color(0xFF1ed760)]
                                : [const Color(0xFF333333), const Color(0xFF444444)],
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Continue', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward, color: Colors.white, size: 20),
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

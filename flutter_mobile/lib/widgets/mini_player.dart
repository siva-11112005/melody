import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/library_state.dart';
import '../state/player_state.dart';
import '../utils/text_utils.dart';

class MiniPlayer extends StatelessWidget {
  final VoidCallback onTap;

  const MiniPlayer({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Consumer2<PlayerState, LibraryState>(
      builder: (context, player, library, child) {
        final track = player.currentTrack;
        if (track == null) return const SizedBox.shrink();

        final progress = player.durationMs > 0
            ? (player.positionMs / player.durationMs).clamp(0.0, 1.0)
            : 0.0;

        return Positioned(
          left: 8,
          right: 8,
          bottom: 8,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFF282828),
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, -2)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 2,
                    child: LinearProgressIndicator(
                      value: progress,
                      color: const Color(0xFF1DB954),
                      backgroundColor: const Color(0xFF444444),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: track.artwork != null
                              ? Image.network(track.artwork!, width: 46, height: 46, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(width: 46, height: 46, color: const Color(0xFF121212), child: const Icon(Icons.music_note, color: Colors.white30)))
                              : Container(
                                  width: 46,
                                  height: 46,
                                  color: const Color(0xFF121212),
                                  child: const Icon(Icons.music_note, color: Colors.white30),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(TextUtils.cleanSongTitle(track.title), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(TextUtils.cleanSongTitle(track.artist), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFb3b3b3), fontSize: 12)),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => library.toggleLike(track),
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(4),
                              icon: Icon(
                                library.isLiked(track.id) ? Icons.favorite : Icons.favorite_border,
                                size: 22,
                                color: library.isLiked(track.id) ? const Color(0xFF1DB954) : const Color(0xFFb3b3b3),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                color: Color(0xFF1DB954),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                onPressed: () {
                                  if (player.isPlaying) {
                                    player.pause();
                                  } else {
                                    player.resume();
                                  }
                                },
                                icon: Icon(player.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.black, size: 24),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

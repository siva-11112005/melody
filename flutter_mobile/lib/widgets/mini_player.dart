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

        return GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFF242424),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: const [
                BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, -3)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 2.5,
                  child: LinearProgressIndicator(
                    value: progress,
                    color: const Color(0xFF1DB954),
                    backgroundColor: const Color(0xFF383838),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      // Artwork with subtle radius
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: track.artwork != null && track.artwork!.isNotEmpty
                            ? Image.network(
                                track.artwork!,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, st) => Container(
                                  width: 44,
                                  height: 44,
                                  color: const Color(0xFF181818),
                                  child: const Icon(Icons.music_note, color: Colors.white30, size: 20),
                                ),
                              )
                            : Container(
                                width: 44,
                                height: 44,
                                color: const Color(0xFF181818),
                                child: const Icon(Icons.music_note, color: Colors.white30, size: 20),
                              ),
                      ),
                      const SizedBox(width: 10),

                      // Track details + Sleep Timer indicator
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    TextUtils.cleanSongTitle(track.title),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                                  ),
                                ),
                                if (player.sleepTimerMinutes != null) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1DB954).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFF1DB954).withValues(alpha: 0.4)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.timer, color: Color(0xFF1DB954), size: 10),
                                        const SizedBox(width: 2),
                                        Text(
                                          '${player.sleepTimerMinutes}m',
                                          style: const TextStyle(color: Color(0xFF1DB954), fontSize: 9, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              TextUtils.cleanSongTitle(track.artist),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 11),
                            ),
                          ],
                        ),
                      ),

                      // Controls: Like, Previous, Play/Pause, Next
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Like Button
                          IconButton(
                            onPressed: () => library.toggleLike(track),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(5),
                            icon: Icon(
                              library.isLiked(track.id) ? Icons.favorite : Icons.favorite_border,
                              size: 20,
                              color: library.isLiked(track.id) ? const Color(0xFF1DB954) : Colors.white60,
                            ),
                          ),

                          // Previous Button
                          IconButton(
                            onPressed: () => player.playPrevious(),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(5),
                            icon: const Icon(Icons.skip_previous, color: Colors.white, size: 22),
                          ),

                          // Play / Pause Button
                          Container(
                            width: 34,
                            height: 34,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
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
                              icon: Icon(player.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.black, size: 22),
                            ),
                          ),

                          // Next Button
                          IconButton(
                            onPressed: () => player.playNext(),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(5),
                            icon: const Icon(Icons.skip_next, color: Colors.white, size: 22),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

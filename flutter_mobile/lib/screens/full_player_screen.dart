import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/track.dart';
import '../services/api_service.dart';
import '../services/download_service.dart';
import '../state/auth_state.dart';
import '../state/library_state.dart';
import '../state/player_state.dart';
import '../utils/text_utils.dart';

class FullPlayerScreen extends StatefulWidget {
  const FullPlayerScreen({super.key});

  @override
  State<FullPlayerScreen> createState() => _FullPlayerScreenState();
}

class _FullPlayerScreenState extends State<FullPlayerScreen> {
  bool downloading = false;
  bool loadingPlaylists = false;
  bool _saved = false;
  String? _savedTrackId;
  final DownloadService _downloadService = DownloadService();
  final ApiService _api = ApiService();
  final TextEditingController _playlistName = TextEditingController();
  List<Map<String, dynamic>> _playlists = [];

  @override
  void dispose() {
    _playlistName.dispose();
    super.dispose();
  }

  Future<void> _syncSavedStatus(Track track) async {
    final saved = await _downloadService.isDownloadedTrack(track);
    if (!mounted) return;
    if (_savedTrackId != track.id) return;
    setState(() => _saved = saved);
  }

  Future<void> _loadPlaylists(BuildContext context) async {
    final token = context.read<AuthState>().token;
    if (token == null || token.isEmpty) return;
    setState(() => loadingPlaylists = true);
    try {
      _playlists = await _api.getPlaylists(token);
    } finally {
      if (mounted) setState(() => loadingPlaylists = false);
    }
  }

  Future<void> _addToPlaylist(BuildContext context, String playlistId, Track track) async {
    final token = context.read<AuthState>().token;
    if (token == null || token.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    await _api.addTrackToPlaylist(token, playlistId, track);
    if (!mounted) return;
    messenger.showSnackBar(const SnackBar(content: Text('Added to playlist')));
  }

  Future<void> _createPlaylistAndAdd(BuildContext context, Track track) async {
    final name = _playlistName.text.trim();
    if (name.isEmpty) return;
    final token = context.read<AuthState>().token;
    if (token == null || token.isEmpty) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final created = await _api.createPlaylist(token, name);
    final playlistId = created['_id']?.toString() ?? created['id']?.toString();
    if (playlistId != null && playlistId.isNotEmpty) {
      await _api.addTrackToPlaylist(token, playlistId, track);
    }
    if (!mounted) return;
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text('Created "$name"')));
  }

  void _openPlaylistSheet(BuildContext context, Track track) {
    _playlistName.clear();
    _loadPlaylists(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(sheetContext),
                    child: const Row(
                      children: [
                        Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 28),
                        SizedBox(width: 4),
                        Text('Close', style: TextStyle(color: Color(0xFF1DB954), fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const Expanded(
                    child: Text('Add to Playlist', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(sheetContext),
                    child: const Text('Cancel', style: TextStyle(color: Color(0xFF1DB954), fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                '${TextUtils.cleanSongTitle(track.title)} - ${TextUtils.cleanSongTitle(track.artist)}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _playlistName,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'New playlist name',
                        hintStyle: TextStyle(color: Color(0xFF666666)),
                        filled: false,
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1DB954),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async => _createPlaylistAndAdd(sheetContext, track),
                    child: const Text('Create + Add', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (loadingPlaylists)
                const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Color(0xFF1DB954))))
              else if (_playlists.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Text('No playlists yet', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
                )
              else
                ..._playlists.map((playlist) {
                  final tracks = (playlist['tracks'] as List?) ?? const [];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF181818),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFF2A2A2A)),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.queue_music, color: Color(0xFF1DB954)),
                        title: Text((playlist['name'] ?? 'Playlist').toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        subtitle: Text('${tracks.length} songs', style: const TextStyle(color: Colors.white70)),
                        trailing: const Icon(Icons.add_circle, color: Color(0xFF1DB954)),
                        onTap: () async {
                          final id = (playlist['_id'] ?? playlist['id'])?.toString();
                          if (id != null && id.isNotEmpty) {
                            final nav = Navigator.of(sheetContext);
                            final messenger = ScaffoldMessenger.of(context);
                            await _addToPlaylist(sheetContext, id, track);
                            nav.pop();
                            messenger.showSnackBar(const SnackBar(content: Text('Added to playlist')));
                          }
                        },
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  void _openQueueSheet(BuildContext context, PlayerState player) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (sheetContext) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(sheetContext),
                  child: const Row(
                    children: [
                      Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 28),
                      SizedBox(width: 4),
                      Text('Close', style: TextStyle(color: Color(0xFF1DB954), fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const Expanded(
                  child: Text('Up Next', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(sheetContext),
                  child: const Text('Done', style: TextStyle(color: Color(0xFF1DB954), fontSize: 14, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (player.queue.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text('No songs in queue', style: TextStyle(color: Colors.white54))))
            else
              ...player.queue.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final active = index == player.currentIndex;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: active ? const Color(0xFF202020) : const Color(0xFF181818),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: active ? const Color(0xFF1DB954) : const Color(0xFF2A2A2A)),
                    ),
                    child: ListTile(
                      leading: item.artwork != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(item.artwork!, width: 44, height: 44, fit: BoxFit.cover),
                            )
                          : Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(color: const Color(0xFF282828), borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.music_note, color: Colors.white70),
                            ),
                      title: Text(item.title, style: TextStyle(color: active ? const Color(0xFF1DB954) : Colors.white, fontWeight: FontWeight.w700)),
                      subtitle: Text(item.artist, style: const TextStyle(color: Colors.white70)),
                      trailing: active
                          ? const Icon(Icons.volume_up, color: Color(0xFF1DB954))
                          : IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                              onPressed: () => player.removeFromQueue(item.id),
                            ),
                      onTap: () => player.playTrack(item, contextQueue: player.queue),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerState>();
    final library = context.watch<LibraryState>();
    final track = player.currentTrack;
    if (track == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(child: Text('No track selected', style: TextStyle(color: Colors.white70))),
      );
    }

    final progress = player.durationMs > 0 ? player.positionMs.clamp(0, player.durationMs).toDouble() : 0.0;
    final isDownloaded = track.localUri != null || _saved;
    if (_savedTrackId != track.id) {
      _savedTrackId = track.id;
      _saved = false;
      _syncSavedStatus(track);
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2d1b4e), Color(0xFF1a1a2e), Color(0xFF121212)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 28),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1DB954).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.music_note, color: Color(0xFF1DB954), size: 20),
                        ),
                        const Text('Now Playing', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.list, color: Colors.white, size: 24),
                      onPressed: () => _openQueueSheet(context, player),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                  children: [
                    Center(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 30, offset: Offset(0, 18))],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: track.artwork != null
                              ? Image.network(track.artwork!, width: 300, height: 300, fit: BoxFit.cover)
                              : Container(
                                  width: 300,
                                  height: 300,
                                  color: const Color(0xFF2A2A2A),
                                  child: const Icon(Icons.music_note, color: Colors.white70, size: 60),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(TextUtils.cleanSongTitle(track.title), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(TextUtils.cleanSongTitle(track.artist), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 16)),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => library.toggleLike(track),
                            icon: Icon(
                              library.isLiked(track.id) ? Icons.favorite : Icons.favorite_border,
                              color: library.isLiked(track.id) ? const Color(0xFF1DB954) : const Color(0xFFb3b3b3),
                              size: 28,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Slider(
                      activeColor: const Color(0xFF1DB954),
                      inactiveColor: const Color(0xFF3A3A3A),
                      value: progress,
                      max: player.durationMs > 0 ? player.durationMs.toDouble() : 1,
                      onChanged: (value) => player.seekTo(value.toInt()),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatTime(player.positionMs), style: const TextStyle(color: Colors.white60)),
                        Text(_formatTime(player.durationMs), style: const TextStyle(color: Colors.white60)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          onPressed: player.toggleShuffle,
                          icon: Icon(Icons.shuffle, color: player.shuffleEnabled ? const Color(0xFF1DB954) : Colors.white70),
                        ),
                        IconButton(
                          onPressed: player.playPrevious,
                          icon: const Icon(Icons.skip_previous, color: Colors.white, size: 34),
                        ),
                        Container(
                          width: 66,
                          height: 66,
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: IconButton(
                            onPressed: () => player.isPlaying ? player.pause() : player.resume(),
                            icon: Icon(player.isPlaying ? Icons.pause : Icons.play_arrow, size: 36, color: Colors.black),
                          ),
                        ),
                        IconButton(
                          onPressed: player.playNext,
                          icon: const Icon(Icons.skip_next, color: Colors.white, size: 34),
                        ),
                        IconButton(
                          onPressed: player.toggleRepeat,
                          icon: Icon(Icons.repeat, color: player.repeatEnabled ? const Color(0xFF1DB954) : Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildPlayerAction(
                          icon: isDownloaded
                              ? Icons.check_circle
                              : downloading
                                  ? Icons.cloud_download
                                  : Icons.download_outlined,
                          label: isDownloaded
                              ? 'Saved'
                              : downloading
                                  ? 'Saving...'
                                  : 'Download',
                          color: isDownloaded || downloading ? const Color(0xFF1DB954) : const Color(0xFFb3b3b3),
                          onTap: (downloading || isDownloaded) ? null : () async {
                            setState(() => downloading = true);
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              await _downloadService.downloadTrack(track);
                              if (mounted) {
                                setState(() => _saved = true);
                              }
                              if (mounted) messenger.showSnackBar(SnackBar(content: Text('Downloaded ${track.title}')));
                            } catch (e) {
                              if (mounted) messenger.showSnackBar(SnackBar(content: Text(e.toString())));
                            } finally {
                              if (mounted) setState(() => downloading = false);
                            }
                          },
                        ),
                        _buildPlayerAction(
                          icon: Icons.share_outlined,
                          label: 'Share',
                          onTap: () async {
                            final text = 'Listen to "${TextUtils.cleanSongTitle(track.title)}" by ${TextUtils.cleanSongTitle(track.artist)}';
                            final messenger = ScaffoldMessenger.of(context);
                            await Clipboard.setData(ClipboardData(text: text));
                            messenger.showSnackBar(const SnackBar(content: Text('Song info copied')));
                          },
                        ),
                        _buildPlayerAction(
                          icon: Icons.playlist_add,
                          label: 'Playlist',
                          onTap: () => _openPlaylistSheet(context, track),
                        ),
                        _buildPlayerAction(
                          icon: Icons.radio_outlined,
                          label: 'Radio',
                          onTap: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (player.queue.length > 1)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF181818),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFF2A2A2A)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.queue_music, color: Color(0xFF1DB954), size: 18),
                            const SizedBox(width: 8),
                            Text('${player.currentIndex + 1} of ${player.queue.length} songs in queue', style: const TextStyle(color: Colors.white70)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(int millis) {
    if (millis <= 0) return '0:00';
    final totalSeconds = (millis / 1000).floor();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildPlayerAction({required IconData icon, required String label, Color color = const Color(0xFFb3b3b3), VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}

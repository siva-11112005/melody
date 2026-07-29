import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/track.dart';
import '../services/api_service.dart';
import '../services/download_service.dart';
import '../state/auth_state.dart';
import '../state/library_state.dart';
import '../state/player_state.dart';
import '../utils/text_utils.dart';

const List<String> _defaultQuickSearches = [
  'Anirudh',
  'A.R. Rahman',
  'Yuvan',
  'Sid Sriram',
  'Ilaiyaraaja',
  'Hip Hop Tamizha',
];

final _remixNoiseWords = RegExp(r'\b(remix|version|ver|live|karaoke|slowed|reverb|mashup|dj|mix|edit|cover)\b', caseSensitive: false);

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _playlistNameController = TextEditingController();
  final ApiService _api = ApiService();
  final DownloadService _downloadService = DownloadService();

  List<Track> _results = [];
  List<String> _suggestions = [];
  List<String> _quickSearches = _defaultQuickSearches;
  List<Map<String, dynamic>> _playlists = [];
  Set<String> _downloadedIds = {};

  bool _loading = false;
  bool _searched = false;
  bool _showPlaylistSheet = false;
  bool _loadingPlaylists = false;

  Track? _selectedTrack;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _loadDownloads();
  }

  @override
  void dispose() {
    _controller.dispose();
    _playlistNameController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('favoriteArtists');
    if (data == null) return;
    try {
      final artists = (jsonDecode(data) as List).map((e) => e.toString()).where((e) => e.trim().isNotEmpty).take(8).toList();
      if (!mounted || artists.isEmpty) return;
      setState(() => _quickSearches = artists);
    } catch (_) {}
  }

  Future<void> _loadDownloads() async {
    final ids = await _downloadService.getDownloadedIds();
    if (!mounted) return;
    setState(() => _downloadedIds = ids);
  }

  String _sanitizeQuery(String value) {
    return value
        .replaceAll(RegExp(r"[^\p{L}\p{N}\s\.'&-]", unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _enrichQuery(String query) {
    final q = query.trim();
    final lower = q.toLowerCase();
    if (lower.contains('tamil')) return q;
    if (RegExp(r'^\d{4}\b').hasMatch(lower) || RegExp(r'\b(song|songs|melody|hit|hits|movie|film|kuthu|mass)\b', caseSensitive: false).hasMatch(lower)) {
      return '$q tamil';
    }
    return q;
  }

  String _songKey(Track track) {
    final title = TextUtils.cleanSongTitle(track.title).toLowerCase().trim();
    return title
        .replaceAll(RegExp(r'\s*\(from\s+.*?\)\s*', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s*\(.*?\)\s*'), ' ')
        .replaceAll(RegExp(r'\s*-\s*.*$', caseSensitive: false), '')
        .replaceAll(_remixNoiseWords, '')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String _artistKey(Track track) {
    return TextUtils.cleanSongTitle(track.artist).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  List<Track> _dedupeTracks(List<Track> tracks) {
    final seen = <String>{};
    final output = <Track>[];
    for (final track in tracks) {
      final key = '${_songKey(track)}:${_artistKey(track)}';
      if (key == ':') continue;
      if (seen.contains(key)) continue;
      seen.add(key);
      output.add(track);
    }
    return output;
  }

  List<Track> _mapSearchTracks(List<Track> tracks) {
    return tracks.map((track) {
      return Track(
        id: track.id,
        title: TextUtils.cleanSongTitle(track.title),
        artist: TextUtils.cleanSongTitle(track.artist),
        artwork: track.artwork,
        url: track.url,
        durationMs: track.durationMs,
        downloadUrl: track.downloadUrl,
        localUri: track.localUri,
      );
    }).toList();
  }

  Future<void> _search([String? queryOverride]) async {
    final rawInput = queryOverride ?? _controller.text;
    final q = _sanitizeQuery(rawInput);
    if (q.isEmpty) return;

    setState(() {
      _loading = true;
      _searched = true;
      _suggestions = [];
    });

    if (queryOverride == null) {
      _controller.text = q;
    }

    final variants = <String>[
      _enrichQuery(q),
      q,
      '$q tamil full song',
      '$q audio song',
      '$q jukebox',
      '${q.split(' ').take(4).join(' ')} tamil',
    ].toSet().toList();

    final merged = <Track>[];
    for (final variant in variants) {
      try {
        final tracks = await _api.searchSongs(variant, limit: 25);
        merged.addAll(tracks);
        if (_dedupeTracks(merged).length >= 40) {
          break;
        }
      } catch (_) {}
    }

    final results = _mapSearchTracks(_dedupeTracks(merged));
    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
    });

    if (results.isNotEmpty && queryOverride == null) {
      await context.read<LibraryState>().addRecentSearch(q);
    }
  }

  Future<void> _loadSuggestions(String text) async {
    if (text.trim().length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    try {
      final suggestions = await _api.suggest(text);
      if (!mounted) return;
      setState(() => _suggestions = suggestions.take(6).toList());
    } catch (_) {
      if (!mounted) return;
      setState(() => _suggestions = []);
    }
  }

  Future<void> _loadPlaylists() async {
    final token = context.read<AuthState>().token;
    if (token == null || token.isEmpty) return;
    setState(() => _loadingPlaylists = true);
    try {
      final items = await _api.getPlaylists(token);
      if (!mounted) return;
      setState(() => _playlists = items);
    } catch (_) {
      if (!mounted) return;
      setState(() => _playlists = []);
    } finally {
      if (mounted) setState(() => _loadingPlaylists = false);
    }
  }

  Future<void> _addToPlaylist(String playlistId, Track track) async {
    final token = context.read<AuthState>().token;
    if (token == null || token.isEmpty) return;
    await _api.addTrackToPlaylist(token, playlistId, track);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to playlist!')));
  }

  Future<void> _createPlaylistAndAdd(Track track) async {
    final token = context.read<AuthState>().token;
    if (token == null || token.isEmpty) return;
    final name = _playlistNameController.text.trim();
    if (name.isEmpty) return;

    final created = await _api.createPlaylist(token, name);
    final playlistId = (created['_id'] ?? created['id'])?.toString();
    if (playlistId != null && playlistId.isNotEmpty) {
      await _api.addTrackToPlaylist(token, playlistId, track);
    }
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Created "$name"')));
  }

  Future<void> _handlePlay(Track track) async {
    final auth = context.read<AuthState>();
    final library = context.read<LibraryState>();
    await context.read<PlayerState>().playTrack(track, contextQueue: _results);
    await library.addRecentlyPlayed(track, token: auth.token);
  }

  void _openPlaylistSheet(Track track) {
    _selectedTrack = track;
    _playlistNameController.clear();
    _loadPlaylists();
    setState(() => _showPlaylistSheet = true);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (sheetContext) {
        return _PlaylistSheet(
          selectedTrack: track,
          playlists: _playlists,
          loading: _loadingPlaylists,
          playlistNameController: _playlistNameController,
          onCreateAndAdd: () => _createPlaylistAndAdd(track),
          onAddToPlaylist: (playlistId) => _addToPlaylist(playlistId, track),
          onRefresh: _loadPlaylists,
        );
      },
    ).whenComplete(() {
      if (mounted) {
        setState(() => _showPlaylistSheet = false);
      }
    });
  }

  Widget _buildTrackItem(Track track) {
    final durationText = track.durationMs > 0 ? ' - ${_formatDuration(track.durationMs ~/ 1000)}' : '';
    return GestureDetector(
      onTap: () => _handlePlay(track),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 52,
                height: 52,
                child: Image.network(
                  track.artwork ?? 'https://placehold.co/52x52/282828/fff?text=music',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFF282828),
                    child: const Icon(Icons.music_note, color: Colors.white70, size: 24),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    TextUtils.cleanSongTitle(track.title),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${TextUtils.cleanSongTitle(track.artist)}$durationText',
                    style: const TextStyle(color: Color(0xFFb3b3b3), fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (_downloadedIds.contains(track.id) || _downloadedIds.contains(_downloadService.trackKey(track)))
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1DB954).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Saved',
                  style: TextStyle(
                    color: Color(0xFF1DB954),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            GestureDetector(
              onTap: () => _openPlaylistSheet(track),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.add_circle_outline, color: Color(0xFFb3b3b3), size: 24),
              ),
            ),
            const Icon(Icons.play_circle_outline, color: Color(0xFF1DB954), size: 28),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recent = context.watch<LibraryState>().recentSearches;

    return Container(
      color: const Color(0xFF121212),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 140),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 60, bottom: 5),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1DB954).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.music_note, color: Color(0xFF1DB954), size: 24),
                ),
                const SizedBox(width: 10),
                const Text('Tamil Music', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 20, bottom: 15),
            child: Text('Search', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF2a2a2a),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 15, right: 10),
                    child: Icon(Icons.search, color: Color(0xFFb3b3b3), size: 20),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      onChanged: (text) {
                        _loadSuggestions(text);
                        if (text.isEmpty) {
                          setState(() {
                            _searched = false;
                            _results = [];
                          });
                        }
                      },
                      onSubmitted: _search,
                      textInputAction: TextInputAction.search,
                      decoration: const InputDecoration(
                        hintText: 'Song, artist, or movie name...',
                        hintStyle: TextStyle(color: Color(0xFF777777)),
                        border: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                    ),
                  ),
                  if (_controller.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _controller.clear();
                        setState(() {
                          _results = [];
                          _searched = false;
                          _suggestions = [];
                        });
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(Icons.cancel, color: Color(0xFF777777), size: 20),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (_suggestions.isNotEmpty && !_searched)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF1e1e1e),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: _suggestions.map((suggestion) {
                  return GestureDetector(
                    onTap: () {
                      _controller.text = suggestion;
                      _search(suggestion);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Color(0xFF333333), width: 0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search_outlined, color: Color(0xFF888888), size: 16),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              suggestion,
                              style: const TextStyle(color: Color(0xFFDDDDDD), fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.arrow_forward, color: Color(0xFF555555), size: 14),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          if (!_searched && _suggestions.isEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(left: 20, top: 10, bottom: 12),
              child: Text('Quick Picks', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _quickSearches.map((query) {
                  return GestureDetector(
                    onTap: () {
                      _controller.text = query;
                      _search(query);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2a2a2a),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(query, style: const TextStyle(color: Colors.white, fontSize: 14)),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 15),
            if (recent.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(left: 20, top: 10, bottom: 12),
                child: Text('Recent Searches', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              ...recent.take(5).map((query) {
                return GestureDetector(
                  onTap: () {
                    _controller.text = query;
                    _search(query);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time_outlined, color: Color(0xFFb3b3b3), size: 20),
                        const SizedBox(width: 12),
                        Expanded(child: Text(query, style: const TextStyle(color: Color(0xFFDDDDDD), fontSize: 15))),
                        const Icon(Icons.arrow_forward, color: Color(0xFF555555), size: 16),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ],
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 50),
              child: Center(child: CircularProgressIndicator(color: Color(0xFF1DB954))),
            )
          else if (_searched) ...[
            if (_results.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Column(
                  children: [
                    Icon(Icons.search_outlined, color: Colors.white.withValues(alpha: 0.2), size: 60),
                    const SizedBox(height: 12),
                    const Text('No results found', style: TextStyle(color: Color(0xFF555555), fontSize: 16)),
                  ],
                ),
              )
            else
              ..._results.map(_buildTrackItem),
          ],
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secondsPart = seconds % 60;
    return '$minutes:${secondsPart < 10 ? '0' : ''}$secondsPart';
  }
}

class _PlaylistSheet extends StatefulWidget {
  const _PlaylistSheet({
    required this.selectedTrack,
    required this.playlists,
    required this.loading,
    required this.playlistNameController,
    required this.onCreateAndAdd,
    required this.onAddToPlaylist,
    required this.onRefresh,
  });

  final Track selectedTrack;
  final List<Map<String, dynamic>> playlists;
  final bool loading;
  final TextEditingController playlistNameController;
  final Future<void> Function() onCreateAndAdd;
  final Future<void> Function(String playlistId) onAddToPlaylist;
  final Future<void> Function() onRefresh;

  @override
  State<_PlaylistSheet> createState() => _PlaylistSheetState();
}

class _PlaylistSheetState extends State<_PlaylistSheet> {
  @override
  void initState() {
    super.initState();
    widget.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        shrinkWrap: true,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Row(
                  children: [
                    Icon(Icons.arrow_back, color: Colors.white, size: 24),
                    SizedBox(width: 4),
                    Text('Back', style: TextStyle(color: Color(0xFF1DB954), fontSize: 14, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const Expanded(
                child: Text('Add to Playlist', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF1DB954), fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '${TextUtils.cleanSongTitle(widget.selectedTrack.title)} - ${TextUtils.cleanSongTitle(widget.selectedTrack.artist)}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFb3b3b3), fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2a2a2a),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: widget.playlistNameController,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: const InputDecoration(
                      hintText: 'New playlist name...',
                      hintStyle: TextStyle(color: Color(0xFF666666)),
                      border: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.symmetric(horizontal: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => widget.onCreateAndAdd(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1DB954),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          if (widget.loading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator(color: Color(0xFF1DB954))),
            )
          else if (widget.playlists.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Text('No playlists yet. Create one above!', style: TextStyle(color: Color(0xFF666666), fontSize: 14), textAlign: TextAlign.center),
            )
          else
            SizedBox(
              height: 250,
              child: ListView.builder(
                itemCount: widget.playlists.length,
                itemBuilder: (context, index) {
                  final playlist = widget.playlists[index];
                  final playlistId = (playlist['_id'] ?? playlist['id'])?.toString() ?? '';
                  final tracks = (playlist['tracks'] as List?) ?? const [];
                  return GestureDetector(
                    onTap: playlistId.isEmpty
                        ? null
                        : () async {
                            await widget.onAddToPlaylist(playlistId);
                            if (mounted) {
                              Navigator.pop(context);
                            }
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Color(0xFF333333), width: 0.5)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text((playlist['name'] ?? '').toString(), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
                                const SizedBox(height: 2),
                                Text('${tracks.length} songs', style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
                              ],
                            ),
                          ),
                          const Icon(Icons.add_circle, color: Color(0xFF1DB954), size: 22),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

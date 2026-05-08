import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track.dart';
import '../services/api_service.dart';
import '../state/auth_state.dart';
import '../state/library_state.dart';
import '../state/player_state.dart';
import '../utils/text_utils.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final ApiService _api = ApiService();
  List<Track> _results = [];
  List<String> _suggestions = [];
  bool _loading = false;
  bool _searched = false;

  static const List<String> _defaultQuickSearches = [
    'Anirudh', 'A.R. Rahman', 'Yuvan', 'Sid Sriram', 'Ilaiyaraaja', 'Hip Hop Tamizha'
  ];

  String _enrichQuery(String query) {
    final q = query.trim();
    final lower = q.toLowerCase();
    if (lower.contains('tamil')) return q;
    if (RegExp(r'^\d{4}\b').hasMatch(lower) || RegExp(r'\b(song|songs|melody|hit|hits|movie|film|kuthu|mass)\b', caseSensitive: false).hasMatch(lower)) {
      return '$q tamil';
    }
    return q;
  }

  String? _extractSongId(String input) {
    final urlMatch = RegExp(r'/song/[^/]+/([a-zA-Z0-9]+)').firstMatch(input);
    if (urlMatch != null) return urlMatch.group(1);
    if (RegExp(r'^[a-zA-Z0-9]{8,}$').hasMatch(input.trim())) return input.trim();
    return null;
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _searched = true;
      _suggestions = [];
    });

    final songId = _extractSongId(query);
    List<Track> tracks = [];

    if (songId != null) {
      final song = await _api.getSongById(songId);
      tracks = song != null ? [song] : [];
    } else {
      final enriched = _enrichQuery(query);
      tracks = await _api.searchSongs(enriched, limit: 30);
    }

    if (!mounted) return;
    setState(() {
      _results = tracks;
      _loading = false;
    });
    if (songId == null) {
      await context.read<LibraryState>().addRecentSearch(query);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('favoriteArtists');
    if (data != null) {
      try {
        final List<dynamic> artists = jsonDecode(data);
        if (artists.isNotEmpty) {
          setState(() {
            _quickSearches = artists.map((e) => e.toString()).take(8).toList();
          });
        }
      } catch (_) {}
    }
  }

  List<String> _quickSearches = _defaultQuickSearches;

  Future<void> _loadSuggestions(String text) async {
    if (text.length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    final suggestions = await _api.suggest(text);
    if (!mounted) return;
    setState(() => _suggestions = suggestions);
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '$mins:${secs < 10 ? '0' : ''}$secs';
  }

  @override
  Widget build(BuildContext context) {
    final recent = context.watch<LibraryState>().recentSearches;

    return Container(
      color: const Color(0xFF121212),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 140),
        children: [
          // Top branding
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 60, bottom: 5),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.music_note, color: Color(0xFF1DB954), size: 24),
                ),
                const SizedBox(width: 10),
                const Text('Tamil Music', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 20, bottom: 15),
            child: Text('Search', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          ),

          // Search bar
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
                      onChanged: (t) {
                        _loadSuggestions(t);
                        if (t.isEmpty) {
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

          // Autocomplete suggestions
          if (_suggestions.isNotEmpty && !_searched)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF1e1e1e),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: _suggestions.take(6).map((s) {
                  return GestureDetector(
                    onTap: () {
                      _controller.text = s;
                      _search(s);
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
                            child: Text(s, style: const TextStyle(color: Color(0xFFDDDDDD), fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          const Icon(Icons.arrow_forward, color: Color(0xFF555555), size: 14),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          // Quick Picks
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
                children: _defaultQuickSearches.map((q) {
                  return GestureDetector(
                    onTap: () {
                      _controller.text = q;
                      _search(q);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2a2a2a),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(q, style: const TextStyle(color: Colors.white, fontSize: 14)),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 15),

            // Recent Searches
            if (recent.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(left: 20, top: 10, bottom: 12),
                child: Text('Recent Searches', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              ...recent.take(5).map((q) {
                return GestureDetector(
                  onTap: () {
                    _controller.text = q;
                    _search(q);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time_outlined, color: Color(0xFFb3b3b3), size: 20),
                        const SizedBox(width: 12),
                        Expanded(child: Text(q, style: const TextStyle(color: Color(0xFFDDDDDD), fontSize: 15))),
                        const Icon(Icons.arrow_forward, color: Color(0xFF555555), size: 16),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ],

          // Results
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
              ..._results.map((track) => _trackItem(track)),
          ],
        ],
      ),
    );
  }

  Widget _trackItem(Track track) {
    return GestureDetector(
      onTap: () async {
        final auth = context.read<AuthState>();
        final library = context.read<LibraryState>();
        await context.read<PlayerState>().playTrack(track, contextQueue: _results);
        await library.addRecentlyPlayed(track, token: auth.token);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: track.artwork != null
                  ? Image.network(track.artwork!, width: 52, height: 52, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _artworkPlaceholder())
                  : _artworkPlaceholder(),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(track.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(
                    '${track.artist}${track.durationMs > 0 ? ' • ${_formatDuration(track.durationMs ~/ 1000)}' : ''}',
                    style: const TextStyle(color: Color(0xFFb3b3b3), fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _showPlaylistModal(context, track),
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

  Widget _artworkPlaceholder() {
    return Container(
      width: 52, height: 52,
      color: const Color(0xFF282828),
      child: const Icon(Icons.music_note, color: Colors.white70, size: 24),
    );
  }

  void _showPlaylistModal(BuildContext context, Track track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      isScrollControlled: true,
      builder: (ctx) => _PlaylistModal(track: track),
    );
  }
}

class _PlaylistModal extends StatefulWidget {
  final Track track;
  const _PlaylistModal({required this.track});

  @override
  State<_PlaylistModal> createState() => _PlaylistModalState();
}

class _PlaylistModalState extends State<_PlaylistModal> {
  final ApiService _api = ApiService();
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _playlists = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchPlaylists();
  }

  Future<void> _fetchPlaylists() async {
    final token = context.read<AuthState>().token;
    if (token == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final list = await _api.getPlaylists(token);
      setState(() {
        _playlists = list;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _addToPlaylist(String playlistId) async {
    final token = context.read<AuthState>().token;
    if (token == null) return;
    try {
      await _api.addTrackToPlaylist(token, playlistId, widget.track);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to playlist!')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _createAndAdd() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    final token = context.read<AuthState>().token;
    if (token == null) return;
    try {
      final pl = await _api.createPlaylist(token, name);
      final id = pl['_id'] ?? pl['id'];
      if (id != null) {
        await _addToPlaylist(id);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
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
                child: Text('Add to Playlist', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF1DB954), fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            '${widget.track.title} — ${widget.track.artist}',
            style: const TextStyle(color: Color(0xFFb3b3b3), fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 15),

          // New playlist row
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
                    controller: _controller,
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
                onTap: _createAndAdd,
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

          // Existing playlists
          if (_loading)
            const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Color(0xFF1DB954)))
          else if (_playlists.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Text('No playlists yet. Create one above!', style: TextStyle(color: Color(0xFF666666), fontSize: 14)),
            )
          else
            SizedBox(
              height: 250,
              child: ListView.builder(
                itemCount: _playlists.length,
                itemBuilder: (ctx, i) {
                  final p = _playlists[i];
                  return GestureDetector(
                    onTap: () => _addToPlaylist(p['_id'] ?? p['id']),
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
                                Text(p['name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
                                const SizedBox(height: 2),
                                Text('${(p['tracks'] as List?)?.length ?? 0} songs', style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
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

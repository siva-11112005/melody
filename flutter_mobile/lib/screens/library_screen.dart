import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../models/track.dart';
import '../services/download_service.dart';
import '../state/auth_state.dart';
import '../state/library_state.dart';
import '../state/player_state.dart';
import '../utils/text_utils.dart';
import '../widgets/expo_skeleton.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final ApiService _api = ApiService();
  final DownloadService _downloadService = DownloadService();
  List<Track> downloads = [];
  List<Map<String, dynamic>> playlists = [];
  bool loadingPlaylists = false;
  String? expandedPlaylistId;
  final TextEditingController _playlistNameController = TextEditingController();
  final TextEditingController _playlistPromptController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _tabs.addListener(() {
      if (mounted) setState(() {});
    });
    _loadDownloads();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadPlaylists();
      }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _playlistNameController.dispose();
    _playlistPromptController.dispose();
    super.dispose();
  }

  Future<void> _loadDownloads() async {
    final items = await _downloadService.getDownloads();
    if (!mounted) return;
    setState(() => downloads = items);
  }

  Future<void> _loadPlaylists() async {
    final token = context.read<AuthState>().token;
    if (token == null || token.isEmpty) return;
    setState(() => loadingPlaylists = true);
    try {
      final items = await _api.getPlaylists(token);
      if (!mounted) return;
      setState(() => playlists = items);
    } finally {
      if (mounted) setState(() => loadingPlaylists = false);
    }
  }



  Future<void> _deletePlaylist(String id) async {
    final token = context.read<AuthState>().token;
    if (token == null || token.isEmpty) return;
    await _api.deletePlaylist(token, id);
    await _loadPlaylists();
  }

  Future<void> _removeTrackFromPlaylist(String playlistId, String trackId) async {
    final token = context.read<AuthState>().token;
    if (token == null || token.isEmpty) return;
    await _api.removeTrackFromPlaylist(token, playlistId, trackId);
    await _loadPlaylists();
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryState>();
    final recentTab = _trackList(
      library.recentlyPlayed,
      emptyMessage: 'No recently played songs',
      emptyIcon: Icons.access_time,
    );
    final downloadsTab = _trackList(
      downloads,
      emptyMessage: 'No downloaded songs',
      emptyIcon: Icons.download,
      onRemoveDownload: (id) async {
        await _downloadService.removeDownload(id);
        await _loadDownloads();
      },
    );
    final likedTab = _trackList(
      library.likedSongs,
      emptyMessage: 'No liked songs yet',
      emptyIcon: Icons.favorite_outline,
      onRemoveLiked: (track) => context.read<LibraryState>().toggleLike(track),
    );

    return Container(
      color: const Color(0xFF121212),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 60, bottom: 5),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1DB954).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.music_note,
                    color: Color(0xFF1DB954),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Tamil Music',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 20, bottom: 15),
            child: Text(
              'Your Library',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 15, right: 15, bottom: 15),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTab('Playlists', 0, Icons.list),
                  const SizedBox(width: 8),
                  _buildTab('Recent', 1, Icons.access_time),
                  const SizedBox(width: 8),
                  _buildTab('Downloads', 2, Icons.download),
                  const SizedBox(width: 8),
                  _buildTab('Liked', 3, Icons.favorite),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _playlistTab(),
                recentTab,
                downloadsTab,
                likedTab,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index, IconData icon) {
    final isActive = _tabs.index == index;
    return GestureDetector(
      onTap: () {
        _tabs.animateTo(index);
        if (index == 0) {
          _loadPlaylists();
        } else if (index == 2) {
          _loadDownloads();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF1DB954) : const Color(0xFF2a2a2a),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? Colors.white : const Color(0xFF888888),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : const Color(0xFF888888),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _playlistTab() {
    final createOptionWidth = (MediaQuery.of(context).size.width - 60) / 4;

    return RefreshIndicator(
      onRefresh: _loadPlaylists,
      color: const Color(0xFF1DB954),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildExpoCreateBtn(
                  icon: Icons.add,
                  label: 'Empty\nPlaylist',
                  color: const Color(0xFF1DB954),
                  width: createOptionWidth,
                  onTap: () => _showCreateDialog('manual'),
                ),
                _buildExpoCreateBtn(
                  icon: Icons.search,
                  label: 'Search\n& Add',
                  color: const Color(0xFF6c5ce7),
                  width: createOptionWidth,
                  onTap: () => _showCreateDialog('search'),
                ),
                _buildExpoCreateBtn(
                  icon: Icons.list,
                  label: 'Song\nNames',
                  color: const Color(0xFFe17055),
                  width: createOptionWidth,
                  onTap: () => _showCreateDialog('csv'),
                ),
                _buildExpoCreateBtn(
                  icon: Icons.auto_awesome,
                  label: 'AI\nPlaylist',
                  color: const Color(0xFFfd79a8),
                  width: createOptionWidth,
                  onTap: () => _showCreateDialog('ai'),
                ),
              ],
            ),
          ),

          if (loadingPlaylists)
            Column(
              children: [
                ExpoSkeleton.listTile(),
                ExpoSkeleton.listTile(),
                ExpoSkeleton.listTile(),
                ExpoSkeleton.listTile(),
              ],
            )
          else if (playlists.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: Column(children: [Icon(Icons.list_alt, size: 60, color: Colors.white10), SizedBox(height: 12), Text('No playlists yet. Pull down to refresh!', style: TextStyle(color: Colors.white38)) ])))
          else
          ...playlists.map((playlist) {
            final id = (playlist['_id'] ?? playlist['id'])?.toString() ?? '';
            final tracks = (playlist['tracks'] as List?) ?? const [];
            final expanded = expandedPlaylistId == id;
            return Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF222222), width: 0.5)),
              ),
              child: Column(
                children: [
                  InkWell(
                    onTap: () => setState(() => expandedPlaylistId = expanded ? null : id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text((playlist['name'] ?? 'Playlist').toString(), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text('${tracks.length} songs', style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
                              ],
                            ),
                          ),
                          Icon(expanded ? Icons.expand_less : Icons.expand_more, color: const Color(0xFF888888), size: 20),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: id.isEmpty ? null : () => _deletePlaylist(id),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6B6B).withValues(alpha: 0.1),
                                border: Border.all(color: const Color(0xFFFF6B6B).withValues(alpha: 0.2)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.delete, color: Color(0xFFFF6B6B), size: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (expanded)
                    Container(
                      color: const Color(0xFF181818),
                      child: Column(
                        children: [
                          if (tracks.isEmpty)
                            const Padding(padding: EdgeInsets.all(20), child: Text('No songs yet. Add some below!', style: TextStyle(color: Colors.white24, fontSize: 13)))
                          else
                            ...tracks.map((item) {
                              final track = Track.fromJson(Map<String, dynamic>.from(item as Map));
                              return ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: track.artwork != null 
                                    ? Image.network(track.artwork!, width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _artworkPlaceholder()) 
                                    : _artworkPlaceholder(),
                                ),
                                title: Text(TextUtils.cleanSongTitle(track.title), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Text(TextUtils.cleanSongTitle(track.artist), style: const TextStyle(color: Color(0xFFb3b3b3), fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFFF6B6B), size: 18),
                                      onPressed: () => _removeTrackFromPlaylist(id, track.id),
                                    ),
                                    const Icon(Icons.play_circle_fill, color: Color(0xFF1DB954), size: 24),
                                  ],
                                ),
                                onTap: () async {
                                  final auth = context.read<AuthState>();
                                  final trackList = tracks.map((t) => Track.fromJson(Map<String, dynamic>.from(t as Map))).toList();
                                  await context.read<PlayerState>().playTrack(track, contextQueue: trackList);
                                  await context.read<LibraryState>().addRecentlyPlayed(track, token: auth.token);
                                },
                              );
                            }),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
                            child: Row(
                              children: [
                                _buildInlineAddBtn(Icons.search, 'Search', const Color(0xFF6c5ce7), () => _showCreateDialog('search', targetPlaylistId: id)),
                                const SizedBox(width: 8),
                                _buildInlineAddBtn(Icons.list, 'Names', const Color(0xFFe17055), () => _showCreateDialog('csv', targetPlaylistId: id)),
                                const SizedBox(width: 8),
                                _buildInlineAddBtn(Icons.auto_awesome, 'AI Add', const Color(0xFFfd79a8), () => _showCreateDialog('ai', targetPlaylistId: id)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildExpoCreateBtn({required IconData icon, required String label, required Color color, required double width, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineAddBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 5),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }



  Widget _trackList(
    List<Track> tracks, {
    required String emptyMessage,
    required IconData emptyIcon,
    Future<void> Function(String)? onRemoveDownload,
    Future<void> Function(Track)? onRemoveLiked,
  }) {
    if (tracks.isEmpty) return _renderEmpty(emptyMessage, emptyIcon);
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 140),
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        return _renderTrackItem(
          track,
          onRemoveDownload: onRemoveDownload != null ? () => onRemoveDownload(track.id) : null,
          onRemoveLiked: onRemoveLiked != null ? () => onRemoveLiked(track) : null,
        );
      },
    );
  }

  Widget _renderTrackItem(
    Track track, {
    VoidCallback? onRemoveDownload,
    VoidCallback? onRemoveLiked,
  }) {
    return GestureDetector(
      onTap: () async {
        final auth = context.read<AuthState>();
        final library = context.read<LibraryState>();
        await context.read<PlayerState>().playTrack(track);
        await library.addRecentlyPlayed(track, token: auth.token);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: track.artwork != null
                  ? Image.network(track.artwork!, width: 48, height: 48, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _artworkPlaceholder())
                  : _artworkPlaceholder(),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(TextUtils.cleanSongTitle(track.title), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(TextUtils.cleanSongTitle(track.artist), style: const TextStyle(color: Color(0xFFb3b3b3), fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (onRemoveLiked != null)
              IconButton(
                onPressed: onRemoveLiked,
                icon: const Icon(Icons.favorite_border, color: Color(0xFFE74C3C), size: 20),
              ),
            if (onRemoveDownload != null)
              IconButton(
                onPressed: onRemoveDownload,
                icon: const Icon(Icons.delete_outline, color: Color(0xFFE74C3C), size: 20),
              ),
            const Icon(Icons.play_circle_outline, color: Color(0xFF1DB954), size: 26),
          ],
        ),
      ),
    );
  }

  Widget _renderEmpty(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: const Color(0xFF333333)),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: Color(0xFF555555), fontSize: 16)),
        ],
      ),
    );
  }

  Widget _artworkPlaceholder() {
    return Container(
      width: 48, height: 48,
      color: const Color(0xFF282828),
      child: const Icon(Icons.music_note, color: Colors.white70, size: 24),
    );
  }

  Future<void> _showCreateDialog(String mode, {String? targetPlaylistId}) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => _CreatePlaylistModal(
        mode: mode,
        targetPlaylistId: targetPlaylistId,
        onCreated: () {
          _loadPlaylists();
          Navigator.pop(ctx);
        },
      ),
    );
  }
}

class _CreatePlaylistModal extends StatefulWidget {
  final String mode;
  final String? targetPlaylistId;
  final VoidCallback onCreated;

  const _CreatePlaylistModal({required this.mode, this.targetPlaylistId, required this.onCreated});

  @override
  State<_CreatePlaylistModal> createState() => _CreatePlaylistModalState();
}

class _CreatePlaylistModalState extends State<_CreatePlaylistModal> {
  final ApiService _api = ApiService();
  final _nameController = TextEditingController();
  final _inputController = TextEditingController();
  final _searchController = TextEditingController();
  
  List<Track> _results = [];
  List<Track> _selectedTracks = [];
  bool _loading = false;
  bool _showResults = false;

  @override
  void dispose() {
    _nameController.dispose();
    _inputController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchSongs() async {
    final q = _searchController.text.trim();
    if (q.isEmpty) return;
    setState(() => _loading = true);
    try {
      final tracks = await _api.searchSongs(q);
      setState(() => _results = tracks);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Search failed: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _generate() async {
    final input = _inputController.text.trim();
    if (input.isEmpty) return;
    setState(() => _loading = true);
    try {
      List<Track> tracks = [];
      if (widget.mode == 'ai') {
        tracks = await _api.generatePlaylist(input);
      } else if (widget.mode == 'csv') {
        final names = input.split(RegExp(r'[\n,]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        tracks = await _api.resolveSongs(names);
      }
      setState(() {
        _results = tracks;
        _selectedTracks = List.from(tracks);
        _showResults = true;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to find songs: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final token = context.read<AuthState>().token;
    if (token == null) return;

    if (widget.targetPlaylistId == null && name.isEmpty) return;

    setState(() => _loading = true);
    try {
      String? playlistId = widget.targetPlaylistId;
      if (playlistId == null) {
        final pl = await _api.createPlaylist(token, name);
        playlistId = (pl['_id'] ?? pl['id'])?.toString();
      }

      if (playlistId != null) {
        for (final t in _selectedTracks) {
          await _api.addTrackToPlaylist(token, playlistId, t);
        }
      }
      widget.onCreated();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
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
                    Text('Back', style: TextStyle(color: Color(0xFF1DB954), fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: Text(
                  widget.targetPlaylistId != null
                      ? (widget.mode == 'search' ? 'Search & Add' : widget.mode == 'csv' ? 'Add by Names' : 'AI Add')
                      : (widget.mode == 'manual' ? 'Create Playlist' : widget.mode == 'search' ? 'Search & Add' : widget.mode == 'csv' ? 'Add by Song Names' : 'AI Playlist'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF1DB954), fontSize: 14, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (widget.targetPlaylistId == null)
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Playlist name',
                hintStyle: TextStyle(color: Color(0xFF666666)),
                filled: false,
                border: InputBorder.none,
              ),
            ),
          const SizedBox(height: 15),
          if (widget.mode == 'manual') ...[
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1DB954),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
              onPressed: _submit,
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.black)
                  : const Text('Create Empty Playlist', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ] else if (widget.mode == 'search' && !_showResults) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _searchSongs(),
                    decoration: const InputDecoration(
                      hintText: 'Search songs...',
                      hintStyle: TextStyle(color: Color(0xFF666666)),
                      filled: false,
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(onPressed: _searchSongs, icon: const Icon(Icons.search, color: Color(0xFF1DB954))),
              ],
            ),
            const SizedBox(height: 10),
            if (_loading) const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())) else
            if (_results.isEmpty && _searchController.text.isNotEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No results found. Try a different query.', style: TextStyle(color: Colors.white54))))
            else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _results.length,
                itemBuilder: (ctx, i) {
                  final t = _results[i];
                  final isSel = _selectedTracks.any((e) => e.id == t.id);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: ClipRRect(borderRadius: BorderRadius.circular(6), child: t.artwork != null ? Image.network(t.artwork!, width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _artworkPlaceholder()) : _artworkPlaceholder()),
                    title: Text(TextUtils.cleanSongTitle(t.title), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(TextUtils.cleanSongTitle(t.artist), style: const TextStyle(color: Colors.white70, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Icon(isSel ? Icons.check_circle : Icons.add_circle_outline, color: isSel ? const Color(0xFF1DB954) : Colors.white30),
                    onTap: () => setState(() {
                      if (isSel) _selectedTracks.removeWhere((e) => e.id == t.id);
                      else _selectedTracks.add(t);
                    }),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            if (_selectedTracks.isNotEmpty)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1DB954),
                  minimumSize: const Size(double.infinity, 45),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _submit, 
                child: Text(_loading ? 'Creating...' : 'Add ${_selectedTracks.length} selected songs', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
          ] else if (_showResults) ...[
            if (_results.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: Text('No songs found for this prompt.', style: TextStyle(color: Colors.white38))),
              )
            else ...[
              const Text('Confirm songs for your playlist:', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 10),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (ctx, i) {
                    final t = _results[i];
                    final isSel = _selectedTracks.any((e) => e.id == t.id);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ClipRRect(borderRadius: BorderRadius.circular(6), child: t.artwork != null ? Image.network(t.artwork!, width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _artworkPlaceholder()) : _artworkPlaceholder()),
                      title: Text(TextUtils.cleanSongTitle(t.title), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(TextUtils.cleanSongTitle(t.artist), style: const TextStyle(color: Colors.white70, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Icon(isSel ? Icons.check_circle : Icons.add_circle_outline, color: isSel ? const Color(0xFF1DB954) : Colors.white30),
                      onTap: () => setState(() {
                        if (isSel) _selectedTracks.removeWhere((e) => e.id == t.id);
                        else _selectedTracks.add(t);
                      }),
                    );
                  },
                ),
              ),
              const SizedBox(height: 15),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1DB954),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _submit, 
                child: Text(_loading ? 'Creating...' : 'Create with ${_selectedTracks.length} songs', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          ] else ...[
            TextField(
              controller: _inputController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _generate(),
              decoration: InputDecoration(
                hintText: widget.mode == 'ai' ? 'Describe the playlist (e.g. 90s Rahman hits)' : 'Enter song names separated by commas or lines',
                hintStyle: const TextStyle(color: Color(0xFF666666)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 15),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1DB954),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _generate, 
              child: _loading ? const CircularProgressIndicator(color: Colors.black) : const Text('Find Songs', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _artworkPlaceholder() {
    return Container(
      width: 44, height: 44,
      color: const Color(0xFF282828),
      child: const Icon(Icons.music_note, color: Colors.white30, size: 20),
    );
  }
}


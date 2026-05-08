import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/track.dart';
import '../services/api_service.dart';
import '../state/auth_state.dart';
import '../state/library_state.dart';
import '../state/player_state.dart';
import '../widgets/app_backdrop.dart';
import '../utils/text_utils.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _api = ApiService();

  final Map<String, List<Track>> _sections = {};
  final Map<String, List<String>> _sectionQueries = {};
  final Map<String, int> _sectionPage = {};
  final Map<String, int> _sectionQueryIndex = {};
  final Map<String, bool> _sectionHasMore = {};
  final Map<String, bool> _sectionLoadingMore = {};
  final Map<String, ScrollController> _sectionControllers = {};

  bool _loading = true;
  bool _extraLoaded = false;
  bool _loadingExtra = false;
  List<Map<String, dynamic>> _dynamicSections = [];

  static const int initialLoadSize = 16;
  static const int pageSize = 8;

  static const List<Map<String, dynamic>> primarySections = [
    {'title': 'Trending in Tamil', 'icon': Icons.local_fire_department, 'queries': ['trending tamil songs', 'top tamil hits 2024', 'popular tamil songs']},
    {'title': 'Latest Tamil Releases', 'icon': Icons.auto_awesome, 'queries': ['latest new tamil songs 2025', 'new tamil movie songs', 'recent tamil hits']},
    {'title': 'Romantic Tamil Songs', 'icon': Icons.favorite, 'queries': ['romantic tamil love songs', 'tamil love melody', 'tamil kadhal songs']},
    {'title': 'Mass / Energy Tamil Songs', 'icon': Icons.flash_on, 'queries': ['tamil mass kuthu dance songs', 'tamil mass entry songs', 'tamil kuthu party']},
    {'title': 'Anirudh Hits', 'icon': Icons.headset, 'queries': ['anirudh ravichander tamil hits', 'anirudh latest songs', 'anirudh dance songs']},
    {'title': 'A.R. Rahman Hits', 'icon': Icons.headset, 'queries': ['ar rahman tamil hits', 'ar rahman best songs', 'ar rahman oscar songs']},
    {'title': 'Chill Tamil Vibes', 'icon': Icons.local_cafe, 'queries': ['chill tamil melody songs', 'tamil soft melody', 'relaxing tamil songs']},
    {'title': 'Sad Tamil Songs', 'icon': Icons.water_drop, 'queries': ['sad tamil songs emotional', 'tamil sad melody songs', 'heartbreak tamil songs']},
  ];

  static const List<Map<String, dynamic>> extraSections = [
    {'title': '90s Tamil Classics', 'icon': Icons.radio, 'queries': ['90s tamil classic old songs', 'ilayaraja 90s hits tamil', 'old tamil golden songs']},
    {'title': 'Yuvan Shankar Raja Hits', 'icon': Icons.album, 'queries': ['yuvan shankar raja tamil hits', 'yuvan love songs tamil', 'yuvan best melodies']},
    {'title': 'Ilaiyaraaja Classics', 'icon': Icons.star, 'queries': ['ilaiyaraaja tamil classic songs', 'ilayaraja evergreen hits', 'ilayaraja melody songs']},
    {'title': 'Sid Sriram Tamil Hits', 'icon': Icons.mic, 'queries': ['sid sriram tamil songs', 'sid sriram melody songs', 'sid sriram latest']},
    {'title': 'Tamil Hip Hop & Rap', 'icon': Icons.volume_up, 'queries': ['tamil hip hop rap songs', 'tamil rap independent', 'tamil gaana songs']},
    {'title': 'Tamil Duet Songs', 'icon': Icons.people, 'queries': ['tamil duet love songs', 'tamil romantic duet hits', 'tamil male female duets']},
    {'title': 'Tamil Workout Beats', 'icon': Icons.fitness_center, 'queries': ['tamil gym workout motivational songs', 'tamil fast beat songs', 'tamil energy songs workout']},
    {'title': 'Tamil Devotional', 'icon': Icons.eco, 'queries': ['tamil devotional songs murugan', 'tamil god songs vinayagar', 'tamil bhakti songs']},
    {'title': 'Tamil Independent Music', 'icon': Icons.mic_external_on, 'queries': ['tamil independent indie album songs', 'tamil indie band songs', 'tamil album songs love']},
    {'title': 'Tamil Kids & Fun', 'icon': Icons.mood, 'queries': ['tamil kids fun songs', 'tamil children rhymes songs', 'tamil animated kids songs']},
  ];

  @override
  void initState() {
    super.initState();
    _loadHome();
  }

  @override
  void dispose() {
    for (final c in _sectionControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadHome() async {
    setState(() {
      _loading = true;
      _extraLoaded = false;
      _loadingExtra = false;
      _dynamicSections = [];
      _sections.clear();
      _sectionQueries.clear();
      _sectionPage.clear();
      _sectionQueryIndex.clear();
      _sectionHasMore.clear();
      _sectionLoadingMore.clear();
    });

    for (final section in primarySections) {
      await _loadInitialSection(
        title: section['title'] as String,
        queries: (section['queries'] as List).cast<String>(),
      );
      await Future.delayed(const Duration(milliseconds: 60));
    }

    await _generateDynamicSections();

    if (mounted) {
      setState(() => _loading = false);
      Future.delayed(const Duration(seconds: 2), _loadExtraSections);
    }
  }

  Future<void> _generateDynamicSections() async {
    if (!mounted) return;
    final library = context.read<LibraryState>();
    final recentArtists = <String>{};

    for (final track in library.recentlyPlayed.take(20)) {
      final artist = track.artist.trim();
      if (artist.isNotEmpty && artist.length > 2) {
        recentArtists.add(artist);
      }
    }

    if (recentArtists.isEmpty) return;

    final shuffled = recentArtists.toList()..shuffle();
    final dynamicSections = <Map<String, dynamic>>[];
    for (final artist in shuffled.take(2)) {
      dynamicSections.add({
        'title': 'Because you listened to $artist',
        'icon': '✨',
        'queries': ['$artist tamil songs', 'best of $artist tamil', '$artist hits']
      });
    }

    if (mounted) {
      setState(() => _dynamicSections = dynamicSections);
    }

    for (final section in dynamicSections) {
      await _loadInitialSection(
        title: section['title'] as String,
        queries: (section['queries'] as List).cast<String>(),
      );
    }
  }

  Future<void> _loadExtraSections() async {
    if (!mounted || _extraLoaded || _loadingExtra) return;
    setState(() => _loadingExtra = true);

    for (final section in extraSections) {
      await _loadInitialSection(
        title: section['title'] as String,
        queries: (section['queries'] as List).cast<String>(),
      );
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (mounted) {
      setState(() {
        _extraLoaded = true;
        _loadingExtra = false;
      });
    }
  }

  Future<void> _loadInitialSection({required String title, required List<String> queries}) async {
    _sectionQueries[title] = queries;
    _sectionPage[title] = 1;
    _sectionQueryIndex[title] = 0;
    _sectionHasMore[title] = true;
    _sectionLoadingMore[title] = false;

    final all = <Track>[];
    final seen = <String>{};
    int usedQueryIndex = 0;

    for (int i = 0; i < queries.length; i++) {
      try {
        final fetched = await _api.searchSongs(queries[i], page: 1, limit: 30);
        if (fetched.isEmpty) continue;

        final unique = _dedupe(fetched, seen);
        if (unique.isNotEmpty) {
          all.addAll(unique);
          usedQueryIndex = i;
        }
        if (all.length >= initialLoadSize) break;
      } catch (_) {
        // Keep trying other query variants.
      }
    }

    all.shuffle();
    final sliced = all.take(initialLoadSize).toList();

    if (!mounted) return;
    setState(() {
      _sections[title] = sliced;
      _sectionQueryIndex[title] = usedQueryIndex;
      _sectionHasMore[title] = sliced.length >= pageSize;
    });

    _maybeAutoLoad(title);
  }

  List<Track> _dedupe(List<Track> tracks, Set<String> seen) {
    final out = <Track>[];
    for (final t in tracks) {
      final key = t.id.isNotEmpty ? t.id : '${t.title}_${t.artist}'.toLowerCase();
      if (seen.contains(key)) continue;
      seen.add(key);
      out.add(t);
    }
    return out;
  }

  Future<void> _loadMoreForSection(String title) async {
    if (_sectionLoadingMore[title] == true) return;
    if (_sectionHasMore[title] == false) return;

    final queries = _sectionQueries[title];
    if (queries == null || queries.isEmpty) return;

    final current = _sections[title] ?? const <Track>[];
    if (current.isEmpty) return;

    setState(() => _sectionLoadingMore[title] = true);

    final seen = <String>{
      ...current.map((t) => t.id.isNotEmpty ? t.id : '${t.title}_${t.artist}'.toLowerCase()),
    };

    int attempts = 0;
    int queryIndex = _sectionQueryIndex[title] ?? 0;
    int page = _sectionPage[title] ?? 1;
    List<Track> appended = const [];

    while (attempts < queries.length && appended.isEmpty) {
      final qIndex = (queryIndex + attempts) % queries.length;
      final pageToUse = attempts == 0 ? page + 1 : 1;

      try {
        final fetched = await _api.searchSongs(queries[qIndex], page: pageToUse, limit: 40);
        final unique = _dedupe(fetched, seen);
        if (unique.isNotEmpty) {
          unique.shuffle();
          appended = unique.take(pageSize).toList();
          queryIndex = qIndex;
          page = pageToUse;
          break;
        }
      } catch (_) {
        // Try next variant.
      }

      attempts += 1;
    }

    if (!mounted) return;

    if (appended.isEmpty) {
      setState(() {
        _sectionLoadingMore[title] = false;
        _sectionHasMore[title] = false;
      });
      return;
    }

    setState(() {
      _sections[title] = [...current, ...appended];
      _sectionLoadingMore[title] = false;
      _sectionHasMore[title] = true;
      _sectionQueryIndex[title] = queryIndex;
      _sectionPage[title] = page;
    });

    _maybeAutoLoad(title);
  }

  ScrollController _controllerFor(String title) {
    return _sectionControllers.putIfAbsent(title, () {
      final controller = ScrollController();
      controller.addListener(() {
        if (!controller.hasClients) return;
        final nearEnd = controller.position.pixels >= controller.position.maxScrollExtent - 80;
        if (nearEnd) {
          _loadMoreForSection(title);
        }
      });
      return controller;
    });
  }

  void _maybeAutoLoad(String title) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = _sectionControllers[title];
      if (controller == null || !controller.hasClients) return;
      final noScrollableContent = controller.position.maxScrollExtent <= 10;
      if (noScrollableContent && (_sectionHasMore[title] == true) && (_sectionLoadingMore[title] != true)) {
        _loadMoreForSection(title);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final greeting = _getGreeting();
    final recently = context.watch<LibraryState>().recentlyPlayed;

    final orderedSections = <Map<String, dynamic>>[
      ...primarySections,
      ..._dynamicSections,
      if (_extraLoaded) ...extraSections,
    ];

    return Stack(
      children: [
        const Positioned.fill(child: AppBackdrop()),
        RefreshIndicator(
          onRefresh: _loadHome,
          color: const Color(0xFF1DB954),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
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
                                  const Text('Tamil Music', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text('Good $greeting', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              const Text('Handpicked for you', style: TextStyle(color: Colors.white70, fontSize: 14)),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/profile'),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFF202020),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF2A2A2A)),
                            ),
                            child: const Icon(Icons.person_outline, color: Color(0xFF1DB954), size: 24),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(color: Color(0xFF1DB954)),
                    )
                  else
                    ...orderedSections.map((section) {
                      final title = section['title'] as String;
                      final icon = section['icon'];
                      final tracks = _sections[title] ?? const <Track>[];
                      final loadingMore = _sectionLoadingMore[title] == true;
                      return _section(title, icon, tracks, loadingMore);
                    }),
                  if (!_extraLoaded && !_loadingExtra && !_loading)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: GestureDetector(
                        onTap: _loadExtraSections,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF181818),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF2A2A2A)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.expand_more, color: Color(0xFF1DB954)),
                              SizedBox(width: 8),
                              Text('Show More Categories', style: TextStyle(color: Color(0xFF1DB954), fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (_loadingExtra)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1DB954))),
                          SizedBox(width: 12),
                          Text('Loading more categories...', style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),
                  if (recently.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.history, color: Color(0xFF1DB954), size: 20),
                              const SizedBox(width: 8),
                              const Text('Recently Played', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 218,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: recently.length,
                              itemBuilder: (_, i) => _trackCard(recently[i], recently),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _section(String title, dynamic icon, List<Track> tracks, bool loadingMore) {
    final controller = _controllerFor(title);
    _maybeAutoLoad(title);

    return Padding(
      padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon is IconData)
                Icon(icon, color: const Color(0xFF1DB954), size: 22)
              else if (icon is String)
                Text(icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 12),
          if (tracks.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('No songs found', style: TextStyle(color: Colors.white54, fontSize: 16)),
            )
          else
            SizedBox(
              height: 218,
              child: ListView.builder(
                controller: controller,
                scrollDirection: Axis.horizontal,
                itemCount: tracks.length,
                itemBuilder: (_, i) => _trackCard(tracks[i], tracks),
              ),
            ),
          if (loadingMore)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1DB954))),
                  SizedBox(width: 10),
                  Text('Loading...', style: TextStyle(color: Colors.white54)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _trackCard(Track track, List<Track> contextQueue) {
    return GestureDetector(
      onTap: () async {
        final auth = context.read<AuthState>();
        final library = context.read<LibraryState>();
        await context.read<PlayerState>().playTrack(track, contextQueue: contextQueue);
        await library.addRecentlyPlayed(track, token: auth.token);
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF181818),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                child: track.artwork != null
                    ? Image.network(track.artwork!, fit: BoxFit.cover, width: double.infinity,
                        errorBuilder: (_, __, ___) => Container(color: const Color(0xFF282828), child: const Icon(Icons.music_note, color: Colors.white30)))
                    : Container(color: const Color(0xFF282828), child: const Icon(Icons.music_note, color: Colors.white70)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(TextUtils.cleanSongTitle(track.title), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(TextUtils.cleanSongTitle(track.artist), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }
}

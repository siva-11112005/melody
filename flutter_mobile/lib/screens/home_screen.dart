import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/track.dart';
import '../services/api_service.dart';
import '../state/auth_state.dart';
import '../state/library_state.dart';
import '../state/player_state.dart';
import '../widgets/app_backdrop.dart';
import '../widgets/expo_skeleton.dart';
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
  List<Map<String, dynamic>> _dynamicSections = [];

  static const int initialLoadSize = 8;
  static const int pageSize = 6;

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
      _dynamicSections = [];
      _sections.clear();
      _sectionQueries.clear();
      _sectionPage.clear();
      _sectionQueryIndex.clear();
      _sectionHasMore.clear();
      _sectionLoadingMore.clear();
    });

    await _loadSectionBatch(primarySections.take(2).toList());

    if (mounted) {
      setState(() => _loading = false);
      unawaited(_loadHomeBackground());
    }
  }

  Future<void> _loadHomeBackground() async {
    // Load remaining primary + all extra sections in parallel
    await Future.wait([
      _generateDynamicSections(),
      _loadSectionBatch(primarySections.skip(2).toList()),
      _loadSectionBatch(extraSections),
    ]);
  }

  Future<void> _loadSectionBatch(List<Map<String, dynamic>> sections) async {
    final tasks = sections.map((section) {
      return _loadInitialSection(
        title: section['title'] as String,
        queries: (section['queries'] as List).cast<String>(),
      );
    }).toList();
    await Future.wait(tasks);
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
        'icon': Icons.auto_awesome,
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



  Future<void> _loadInitialSection({required String title, required List<String> queries}) async {
    _sectionQueries[title] = queries;
    _sectionPage[title] = 1;
    _sectionQueryIndex[title] = 0;
    _sectionHasMore[title] = true;
    _sectionLoadingMore[title] = false;

    final primaryQuery = queries.isNotEmpty ? queries.first : title;
    List<Track> fetched = const [];
    try {
      fetched = await _api.searchSongs(primaryQuery, page: 1, limit: 12);
    } catch (_) {}

    final seen = <String>{};
    final sliced = _dedupe(fetched, seen).take(initialLoadSize).toList();

    if (!mounted) return;
    setState(() {
      _sections[title] = sliced;
      _sectionQueryIndex[title] = 0;
      _sectionHasMore[title] = true;
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

    int queryIndex = _sectionQueryIndex[title] ?? 0;
    int page = _sectionPage[title] ?? 1;
    final fetchedBatches = await Future.wait(
      queries.map((query) async {
        try {
          return await _api.searchSongs(query, page: page + 1, limit: 12);
        } catch (_) {
          return const <Track>[];
        }
      }),
    );

    final appended = <Track>[];
    for (int i = 0; i < fetchedBatches.length; i++) {
      final unique = _dedupe(fetchedBatches[i], seen);
      if (unique.isNotEmpty) {
        unique.shuffle();
        appended.addAll(unique.take(pageSize));
        queryIndex = i;
        page = page + 1;
        if (appended.length >= pageSize) break;
      }
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
      ..._dynamicSections,
      ...primarySections,
      ...extraSections,
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
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 15),
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
                                      color: const Color(0xFF1DB954).withValues(alpha: 0.12),
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
                            ),
                            child: const Icon(Icons.person_outline, color: Color(0xFF1DB954), size: 24),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  if (_loading)
                    Column(
                      children: [
                        ExpoSkeleton.sectionShimmer(),
                        ExpoSkeleton.sectionShimmer(),
                        ExpoSkeleton.sectionShimmer(),
                      ],
                    )
                  else
                    ...orderedSections.map((section) {
                      final title = section['title'] as String;
                      final icon = section['icon'];
                      final tracks = _sections[title] ?? const <Track>[];
                      final loadingMore = _sectionLoadingMore[title] == true;
                      return _section(title, icon, tracks, loadingMore);
                    }),

                  if (recently.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.history, color: Color(0xFF1DB954), size: 22),
                              const SizedBox(width: 8),
                              const Text('Recently Played', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 19)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(height: 176, child: _horizontalTracks(recently, recently)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 150),
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

    final isLoading = !_sections.containsKey(title);

    if (!isLoading && tracks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 14, top: 5),
            child: Row(
              children: [
                if (icon is IconData)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(icon, color: const Color(0xFF1DB954), size: 22),
                  )
                else if (icon is String)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.auto_awesome, color: Color(0xFF1DB954), size: 22),
                  ),
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 19)),
              ],
            ),
          ),
          SizedBox(
            height: 176,
            child: _horizontalTracks(tracks, tracks, controller: controller, isLoadingMore: loadingMore),
          ),
        ],
      ),
    );
  }

  Widget _horizontalTracks(List<Track> tracks, List<Track> contextQueue, {ScrollController? controller, bool isLoadingMore = false}) {
    return ListView.builder(
      controller: controller,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(right: 20),
      itemCount: tracks.length + (isLoadingMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (i < tracks.length) {
          return _trackCard(tracks[i], contextQueue);
        }
        return Container(
          width: 80,
          margin: const EdgeInsets.only(left: 12),
          child: const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF1DB954)),
            ),
          ),
        );
      },
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
        width: 130,
        margin: const EdgeInsets.only(left: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 130,
                height: 130,
                child: track.artwork != null
                    ? Image.network(
                        track.artwork!,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, e, st) => Container(
                          color: const Color(0xFF282828),
                          child: const Icon(Icons.music_note, color: Colors.white70),
                        ),
                      )
                    : Container(
                        color: const Color(0xFF282828),
                        child: const Icon(Icons.music_note, color: Colors.white70),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              TextUtils.cleanSongTitle(track.title),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              TextUtils.cleanSongTitle(track.artist),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFb3b3b3), fontSize: 11),
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/track.dart';
import '../services/api_service.dart';
import '../state/auth_state.dart';
import '../state/library_state.dart';
import '../state/player_state.dart';
import '../utils/text_utils.dart';
import '../widgets/app_backdrop.dart';
import '../widgets/expo_skeleton.dart';

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
  String _selectedEra = 'default';
  List<Map<String, dynamic>> _dynamicSections = [];

  static const int initialLoadSize = 10;
  static const int pageSize = 8;

  static const List<Map<String, dynamic>> eraOptions = [
    {'id': 'default', 'label': 'Default', 'icon': Icons.whatshot},
    {'id': 'latest', 'label': 'Latest Hits', 'icon': Icons.bolt},
    {'id': '2010s', 'label': "2010's Hits", 'icon': Icons.electric_bolt},
    {'id': '2000s', 'label': "2000's Hits", 'icon': Icons.album},
    {'id': '90s', 'label': "90's Classics", 'icon': Icons.radio},
    {'id': '80s', 'label': "80's Classics", 'icon': Icons.star},
  ];

  @override
  void initState() {
    super.initState();
    _initEraAndLoad();
  }

  @override
  void dispose() {
    for (final c in _sectionControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _initEraAndLoad() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEra = prefs.getString('preferredMusicEra') ?? 'default';
      if (mounted) {
        setState(() => _selectedEra = savedEra);
      }
    } catch (_) {}
    _loadHome();
  }

  Future<void> _changeEra(String eraId) async {
    if (_selectedEra == eraId) return;
    setState(() {
      _selectedEra = eraId;
      _loading = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('preferredMusicEra', eraId);
    } catch (_) {}
    await _loadHome();
  }

  List<Map<String, dynamic>> _getSectionsForEra(String era) {
    switch (era) {
      case '80s':
        return [
          {
            'title': "80's Tamil Golden Classics",
            'icon': Icons.star,
            'isTrendingChart': true,
            'queries': ['80s tamil evergreen classic songs', 'ilaiyaraaja 80s hits', 'spb 80s tamil hits']
          },
          {
            'title': 'Ilaiyaraaja 80s Magic',
            'icon': Icons.album,
            'queries': ['ilayaraja 80s superhit songs', 'ilaiyaraaja evergreen 80s', 'ilayaraja spb duets']
          },
          {
            'title': 'SPB & S. Janaki 80s Duets',
            'icon': Icons.favorite,
            'queries': ['spb janaki tamil love duets 80s', 'spb romantic hits 80s', 'tamil 80s duet songs']
          },
          {
            'title': '80s Retro Melody Hits',
            'icon': Icons.music_note,
            'queries': ['80s tamil melody songs old', '80s tamil love songs golden', 'tamil old golden melodies']
          },
        ];

      case '90s':
        return [
          {
            'title': "90's Tamil Evergreen Hits",
            'icon': Icons.radio,
            'isTrendingChart': true,
            'queries': ['90s tamil superhit evergreen songs', 'ilayaraja 90s hits tamil', 'ar rahman 90s hits']
          },
          {
            'title': 'A.R. Rahman 90s Magic',
            'icon': Icons.headset,
            'queries': ['ar rahman 90s tamil hits', 'ar rahman roja bombay kadhalan', 'rahman 90s melody']
          },
          {
            'title': 'Ilaiyaraaja 90s Melodies',
            'icon': Icons.star,
            'queries': ['ilaiyaraaja 90s melody songs', 'ilayaraja 90s golden hits', 'ilayaraja melody classic 90s']
          },
          {
            'title': '90s Romantic Love Songs',
            'icon': Icons.favorite,
            'queries': ['90s tamil love songs romantic', '90s tamil kadhal melodies', '90s tamil duets love']
          },
          {
            'title': 'Yuvan Shankar Raja Early Hits',
            'icon': Icons.album,
            'queries': ['yuvan shankar raja 90s 2000s hits', 'yuvan initial hits tamil', 'yuvan love melodies']
          },
        ];

      case '2000s':
        return [
          {
            'title': "2000's Tamil Superhits",
            'icon': Icons.album,
            'isTrendingChart': true,
            'queries': ['2000s tamil superhit songs', 'harris jayaraj 2000s hits', 'yuvan 2000s hits']
          },
          {
            'title': 'Harris Jayaraj 2000s Magic',
            'icon': Icons.headset,
            'queries': ['harris jayaraj tamil hits 2000s', 'harris jayaraj melody songs', 'minnale kaakha kaakha songs']
          },
          {
            'title': 'Yuvan 2000s Cult Melodies',
            'icon': Icons.favorite,
            'queries': ['yuvan shankar raja 2000s love songs', 'yuvan best melodies 2000s', '7g rainbow paiyaa songs']
          },
          {
            'title': '2000s Mass & Kuthu Party',
            'icon': Icons.flash_on,
            'queries': ['2000s tamil kuthu dance songs', 'dharani vijay kuthu songs 2000s', 'tamil mass kuthu party 2000s']
          },
        ];

      case '2010s':
        return [
          {
            'title': "2010's Tamil Chartbusters",
            'icon': Icons.electric_bolt,
            'isTrendingChart': true,
            'queries': ['2010s tamil superhit songs', 'anirudh 2010s hits 3 vip', 'santhosh narayanan tamil hits']
          },
          {
            'title': 'Anirudh Early Viral Era',
            'icon': Icons.local_fire_department,
            'queries': ['anirudh ravichander 3 vip vedalam', 'anirudh kaththi remor songs', 'anirudh naanum rowdy dhaan']
          },
          {
            'title': 'Sid Sriram 2010s Melodies',
            'icon': Icons.mic,
            'queries': ['sid sriram tamil love melodies', 'sid sriram thalli pogathey', 'sid sriram maruvaarthai']
          },
          {
            'title': 'Dhanush & Vijay 2010s Mass',
            'icon': Icons.flash_on,
            'queries': ['dhanush anirudh songs vip', 'vijay theri mersal songs', 'tamil 2010s mass songs']
          },
        ];

      case 'latest':
        return [
          {
            'title': 'Top 50 Tamil Superhits',
            'icon': Icons.local_fire_department,
            'isTrendingChart': true,
            'queries': ['tamil top 50 hits 2025 2026', 'latest new tamil songs 2026', 'trending tamil songs']
          },
          {
            'title': 'New Releases & Movie Hits',
            'icon': Icons.auto_awesome,
            'queries': ['latest new tamil movie songs 2025 2026', 'recent tamil releases songs', 'new tamil movie album']
          },
          {
            'title': 'Anirudh Latest Hits',
            'icon': Icons.headset,
            'queries': ['anirudh latest songs 2025 2026', 'anirudh ravichander viral hits', 'anirudh dance songs']
          },
          {
            'title': 'Sai Abhyankkar & Indie Hits',
            'icon': Icons.mic_external_on,
            'queries': ['sai abhyankkar katchi sera aasa kooda', 'radhimaa song tamil', 'tamil independent viral songs']
          },
        ];

      case 'default':
      default:
        return [
          {
            'title': 'Trending in Tamil (Top Hits)',
            'icon': Icons.local_fire_department,
            'isTrendingChart': true,
            'queries': ['tamil top 50 superhits', 'trending tamil songs', 'top tamil hits']
          },
          {
            'title': 'Latest Tamil Releases',
            'icon': Icons.auto_awesome,
            'queries': ['latest new tamil movie songs 2025', 'recent tamil releases', 'new tamil songs']
          },
          {
            'title': 'Romantic Tamil Melodies',
            'icon': Icons.favorite,
            'queries': ['romantic tamil love songs', 'tamil love melody songs', 'tamil kadhal melody hits']
          },
          {
            'title': 'Mass & Energy Hits',
            'icon': Icons.flash_on,
            'queries': ['tamil mass kuthu dance songs', 'tamil fast beat mass songs', 'tamil energy party songs']
          },
          {
            'title': 'Anirudh Ravichander Hits',
            'icon': Icons.headset,
            'queries': ['anirudh ravichander tamil hits', 'anirudh viral dance songs', 'anirudh latest hits']
          },
          {
            'title': 'A.R. Rahman Evergreen',
            'icon': Icons.headset,
            'queries': ['ar rahman tamil hits best', 'ar rahman melody songs', 'ar rahman evergreen tamil']
          },
          {
            'title': 'Chill Tamil Vibes',
            'icon': Icons.local_cafe,
            'queries': ['chill tamil melody songs', 'relaxing tamil acoustic songs', 'tamil soft melodies']
          },
          {
            'title': 'Yuvan Shankar Raja Hits',
            'icon': Icons.album,
            'queries': ['yuvan shankar raja tamil hits', 'yuvan love songs tamil', 'yuvan best melodies']
          },
          {
            'title': 'Sid Sriram Melodies',
            'icon': Icons.mic,
            'queries': ['sid sriram tamil songs best', 'sid sriram melody songs', 'sid sriram hits']
          },
          {
            'title': 'Sad & Emotional Melodies',
            'icon': Icons.water_drop,
            'queries': ['sad tamil songs emotional', 'heartbreak tamil melody songs', 'tamil emotional songs']
          },
        ];
    }
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

    final currentSections = _getSectionsForEra(_selectedEra);
    final initialBatch = currentSections.take(2).toList();
    await _loadSectionBatch(initialBatch);

    if (mounted) {
      setState(() => _loading = false);
      unawaited(_loadHomeBackground(currentSections));
    }
  }

  Future<void> _loadHomeBackground(List<Map<String, dynamic>> allSections) async {
    await Future.wait([
      _generateDynamicSections(),
      _loadSectionBatch(allSections.skip(2).toList()),
    ]);
  }

  Future<void> _loadSectionBatch(List<Map<String, dynamic>> sections) async {
    final tasks = sections.map((section) {
      final isTrending = section['isTrendingChart'] == true;
      return _loadInitialSection(
        title: section['title'] as String,
        queries: (section['queries'] as List).cast<String>(),
        isTrending: isTrending,
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

  Future<void> _loadInitialSection({
    required String title,
    required List<String> queries,
    bool isTrending = false,
  }) async {
    _sectionQueries[title] = queries;
    _sectionPage[title] = 1;
    _sectionQueryIndex[title] = 0;
    _sectionHasMore[title] = true;
    _sectionLoadingMore[title] = false;

    List<Track> fetched = const [];

    try {
      if (isTrending) {
        // Fetch genuine Top 50 Chartbusters & high-play full songs!
        fetched = await _api.getTrendingSongs(era: _selectedEra, limit: 30);
      } else {
        final primaryQuery = queries.isNotEmpty ? queries.first : title;
        fetched = await _api.searchSongs(primaryQuery, page: 1, limit: 16);
      }
    } catch (_) {}

    final seen = <String>{};
    final filtered = fetched.where((t) => t.durationMs >= 95000 || t.durationMs == 0).toList();
    final sliced = _dedupe(filtered.isNotEmpty ? filtered : fetched, seen).take(initialLoadSize).toList();

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
      final filtered = fetchedBatches[i].where((t) => t.durationMs >= 95000 || t.durationMs == 0).toList();
      final unique = _dedupe(filtered.isNotEmpty ? filtered : fetchedBatches[i], seen);
      if (unique.isNotEmpty) {
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
    final eraSections = _getSectionsForEra(_selectedEra);

    final orderedSections = <Map<String, dynamic>>[
      ..._dynamicSections,
      ...eraSections,
    ];

    return Stack(
      children: [
        const Positioned.fill(child: AppBackdrop()),
        RefreshIndicator(
          onRefresh: _loadHome,
          color: const Color(0xFF1DB954),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 56, 20, 12),
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
                                      color: const Color(0xFF1DB954).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.music_note, color: Color(0xFF1DB954), size: 24),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'Tamil Music',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Good $greeting',
                                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              const Text('Curated hits & timeless melodies', style: TextStyle(color: Colors.white70, fontSize: 13)),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/profile'),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF222222),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: const Icon(Icons.person_outline, color: Color(0xFF1DB954), size: 22),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Era Selection Chips (Filter Bar)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8, top: 4),
                    child: SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: eraOptions.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 8),
                        itemBuilder: (ctx, i) {
                          final opt = eraOptions[i];
                          final isSelected = _selectedEra == opt['id'];
                          return GestureDetector(
                            onTap: () => _changeEra(opt['id'] as String),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF1DB954) : const Color(0xFF202020),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF1DB954) : Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    opt['icon'] as IconData,
                                    size: 15,
                                    color: isSelected ? Colors.black : Colors.white70,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    opt['label'] as String,
                                    style: TextStyle(
                                      color: isSelected ? Colors.black : Colors.white,
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

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
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: [
                                Icon(Icons.history, color: Color(0xFF1DB954), size: 20),
                                SizedBox(width: 8),
                                Text('Recently Played', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(height: 182, child: _horizontalTracks(recently, recently)),
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
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 12, top: 4),
            child: Row(
              children: [
                if (icon is IconData)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(icon, color: const Color(0xFF1DB954), size: 20),
                  )
                else if (icon is String)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.auto_awesome, color: Color(0xFF1DB954), size: 20),
                  ),
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
          ),
          SizedBox(
            height: 182,
            child: _horizontalTracks(tracks, tracks, controller: controller, isLoadingMore: loadingMore),
          ),
        ],
      ),
    );
  }

  Widget _horizontalTracks(
    List<Track> tracks,
    List<Track> contextQueue, {
    ScrollController? controller,
    bool isLoadingMore = false,
  }) {
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
    return Container(
      width: 130,
      margin: const EdgeInsets.only(left: 20),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final auth = context.read<AuthState>();
          final library = context.read<LibraryState>();
          await context.read<PlayerState>().playTrack(track, contextQueue: contextQueue);
          await library.addRecentlyPlayed(track, token: auth.token);
        },
        onLongPress: () => _openSongOptionsSheet(track),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 130,
                    height: 130,
                    child: track.artwork != null && track.artwork!.isNotEmpty
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
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: GestureDetector(
                    onTap: () => _openSongOptionsSheet(track),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.more_vert, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
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

  void _openSongOptionsSheet(Track track) {
    final library = context.read<LibraryState>();
    final isLiked = library.isLiked(track.id);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: track.artwork != null
                        ? Image.network(track.artwork!, width: 48, height: 48, fit: BoxFit.cover, errorBuilder: (ctx, err, stack) => Container(color: Colors.grey[900], width: 48, height: 48, child: const Icon(Icons.music_note, color: Colors.white54)))
                        : Container(color: Colors.grey[900], width: 48, height: 48, child: const Icon(Icons.music_note, color: Colors.white54)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(TextUtils.cleanSongTitle(track.title), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Text(TextUtils.cleanSongTitle(track.artist), style: const TextStyle(color: Colors.white60, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? const Color(0xFF1DB954) : Colors.white),
                title: Text(isLiked ? 'Remove from Liked Songs' : 'Like Song', style: const TextStyle(color: Colors.white)),
                onTap: () {
                  library.toggleLike(track);
                  Navigator.pop(sheetCtx);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.playlist_add, color: Color(0xFF1DB954)),
                title: const Text('Add to Playlist', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _openAddToPlaylistSheet(track);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.queue_music, color: Colors.white),
                title: const Text('Play Next in Queue', style: TextStyle(color: Colors.white)),
                onTap: () {
                  final player = context.read<PlayerState>();
                  player.queue.insert((player.currentIndex + 1).clamp(0, player.queue.length), track);
                  Navigator.pop(sheetCtx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to Up Next')));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openAddToPlaylistSheet(Track track) async {
    final token = context.read<AuthState>().token ?? '';
    final playlists = await _api.getPlaylists(token);
    final playlistNameCtrl = TextEditingController();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF181818),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Add to Playlist', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: playlistNameCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'New playlist name...',
                          hintStyle: TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: Color(0xFF242424),
                          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1DB954),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final name = playlistNameCtrl.text.trim();
                        if (name.isEmpty) return;
                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(ctx);
                        final created = await _api.createPlaylist(token, name);
                        final pid = (created['_id'] ?? created['id'])?.toString();
                        if (pid != null) {
                          await _api.addTrackToPlaylist(token, pid, track);
                        }
                        navigator.pop();
                        messenger.showSnackBar(SnackBar(content: Text('Added to "$name"')));
                      },
                      child: const Text('Create', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Your Playlists', style: TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (playlists.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text('No playlists yet. Create one above!', style: TextStyle(color: Colors.white38))),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 250),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: playlists.length,
                      itemBuilder: (c, idx) {
                        final pl = playlists[idx];
                        final pid = (pl['_id'] ?? pl['id'])?.toString() ?? '';
                        final name = (pl['name'] ?? 'Playlist').toString();
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.playlist_play, color: Color(0xFF1DB954)),
                          title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                          trailing: const Icon(Icons.add, color: Colors.white70),
                          onTap: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final navigator = Navigator.of(ctx);
                            await _api.addTrackToPlaylist(token, pid, track);
                            navigator.pop();
                            messenger.showSnackBar(SnackBar(content: Text('Added to "$name"')));
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
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

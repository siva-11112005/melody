import React, { useState, useEffect, useRef, useCallback } from 'react';
import {
  View, Text, StyleSheet, TouchableOpacity,
  ActivityIndicator, Image, ScrollView, FlatList, LayoutChangeEvent
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import axios from 'axios';
import { useLibraryStore } from '../store/useLibraryStore';
import { usePlayerStore } from '../store/usePlayerStore';
import { useAuthStore } from '../store/useAuthStore';
import { API_URL } from '../config/api';
import { cleanSongTitle } from '../utils/textUtils';
import { applyDownloadedUris } from '../services/downloadService';

const shuffleArray = (array: any[]) => {
  const newArr = [...array];
  for (let i = newArr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [newArr[i], newArr[j]] = [newArr[j], newArr[i]];
  }
  return newArr;
};

const PRIMARY_SECTIONS = [
  { id: 'trending', title: 'Trending in Tamil', icon: 'flame', queries: ['trending tamil songs', 'top tamil hits 2024', 'popular tamil songs'] },
  { id: 'latest', title: 'Latest Tamil Releases', icon: 'sparkles', queries: ['latest new tamil songs 2025', 'new tamil movie songs', 'recent tamil hits'] },
  { id: 'romantic', title: 'Romantic Tamil Songs', icon: 'heart', queries: ['romantic tamil love songs', 'tamil love melody', 'tamil kadhal songs'] },
  { id: 'mass', title: 'Mass / Energy Tamil Songs', icon: 'flash', queries: ['tamil mass kuthu dance songs', 'tamil mass entry songs', 'tamil kuthu party'] },
  { id: 'anirudh', title: 'Anirudh Hits', icon: 'headset', queries: ['anirudh ravichander tamil hits', 'anirudh latest songs', 'anirudh dance songs'] },
  { id: 'arrahman', title: 'A.R. Rahman Hits', icon: 'musical-notes', queries: ['ar rahman tamil hits', 'ar rahman best songs', 'ar rahman oscar songs'] },
  { id: 'chill', title: 'Chill Tamil Vibes', icon: 'cafe', queries: ['chill tamil melody songs', 'tamil soft melody', 'relaxing tamil songs'] },
  { id: 'sad', title: 'Sad Tamil Songs', icon: 'water', queries: ['sad tamil songs emotional', 'tamil sad melody songs', 'heartbreak tamil songs'] },
];

const EXTRA_SECTIONS = [
  { id: 'retro', title: '90s Tamil Classics', icon: 'radio', queries: ['90s tamil classic old songs', 'ilayaraja 90s hits tamil', 'old tamil golden songs'] },
  { id: 'yuvan', title: 'Yuvan Shankar Raja Hits', icon: 'disc', queries: ['yuvan shankar raja tamil hits', 'yuvan love songs tamil', 'yuvan best melodies'] },
  { id: 'ilaiyaraaja', title: 'Ilaiyaraaja Classics', icon: 'star', queries: ['ilaiyaraaja tamil classic songs', 'ilayaraja evergreen hits', 'ilayaraja melody songs'] },
  { id: 'sidsriram', title: 'Sid Sriram Tamil Hits', icon: 'mic-outline', queries: ['sid sriram tamil songs', 'sid sriram melody songs', 'sid sriram latest'] },
  { id: 'hiphop', title: 'Tamil Hip Hop & Rap', icon: 'volume-high', queries: ['tamil hip hop rap songs', 'tamil rap independent', 'tamil gaana songs'] },
  { id: 'duets', title: 'Tamil Duet Songs', icon: 'people', queries: ['tamil duet love songs', 'tamil romantic duet hits', 'tamil male female duets'] },
  { id: 'workout', title: 'Tamil Workout Beats', icon: 'barbell', queries: ['tamil gym workout motivational songs', 'tamil fast beat songs', 'tamil energy songs workout'] },
  { id: 'devotional', title: 'Tamil Devotional', icon: 'leaf', queries: ['tamil devotional songs murugan', 'tamil god songs vinayagar', 'tamil bhakti songs'] },
  { id: 'indie', title: 'Tamil Independent Music', icon: 'recording', queries: ['tamil independent indie album songs', 'tamil indie band songs', 'tamil album songs love'] },
  { id: 'kids', title: 'Tamil Kids & Fun Songs', icon: 'happy', queries: ['tamil kids fun songs', 'tamil children rhymes songs', 'tamil animated kids songs'] },
  { id: 'recommended', title: 'Recommended For You', icon: 'color-wand', queries: ['top tamil songs best', 'best tamil songs all time', 'tamil superhit songs collection'] },
];

interface SectionState {
  tracks: any[];
  page: number;
  loadingMore: boolean;
  hasMore: boolean;
  queryIndex: number;
}

const INITIAL_LOAD_SIZE = 10;
const PAGE_SIZE = 5;

export default function HomeScreen({ navigation }: any) {
  const [sections, setSections] = useState<Record<string, SectionState>>({});
  const [initialLoading, setInitialLoading] = useState<Record<string, boolean>>({});
  const [extraLoaded, setExtraLoaded] = useState(false);
  const [loadingExtra, setLoadingExtra] = useState(false);
  const globalSeenRef = useRef<Set<string>>(new Set());
  const listLayoutRef = useRef<Record<string, { layoutWidth: number; contentWidth: number }>>({});
  const [dynamicSections, setDynamicSections] = useState<typeof PRIMARY_SECTIONS>([]);
  const { recentlyPlayed, addRecentlyPlayed, loadLibrary } = useLibraryStore();
  const { playTrack } = usePlayerStore();
  const { logout } = useAuthStore();

  useEffect(() => {
    loadLibrary();
    globalSeenRef.current = new Set();
    fetchPrimarySections();
  }, []);

  useEffect(() => {
    if (recentlyPlayed.length > 0 && dynamicSections.length === 0) {
      const recentArtists = [...new Set(recentlyPlayed.map(t => cleanSongTitle(t.artist || '')))].filter(a => a && a.length > 2);
      if (recentArtists.length > 0) {
        const shuffledArtists = shuffleArray(recentArtists);
        const topArtists = shuffledArtists.slice(0, 2);
        const dynamicBasedOnRecent = topArtists.map(artist => ({
          id: `recent_${artist.replace(/[^a-zA-Z0-9]/g, '')}`,
          title: `Because you listened to ${artist}`,
          icon: 'headset',
          queries: [`${artist} tamil songs`, `best of ${artist} tamil`, `${artist} hits`]
        }));
        setDynamicSections(dynamicBasedOnRecent);
        dynamicBasedOnRecent.forEach(sec => fetchSectionInitial(sec));
      }
    }
  }, [recentlyPlayed]);

  // Load primary sections sequentially with a small delay to avoid overwhelming backend
  const fetchPrimarySections = async () => {
    for (let i = 0; i < PRIMARY_SECTIONS.length; i++) {
      await fetchSectionInitial(PRIMARY_SECTIONS[i]);
      // Small delay between sections for smoother UI
      await new Promise(resolve => setTimeout(resolve, 100));
    }
  };

  const loadExtraSections = useCallback(async () => {
    if (extraLoaded || loadingExtra) return;
    setLoadingExtra(true);
    for (let i = 0; i < EXTRA_SECTIONS.length; i += 2) {
      const batch = EXTRA_SECTIONS.slice(i, i + 2);
      await Promise.all(batch.map(section => fetchSectionInitial(section)));
    }
    setExtraLoaded(true);
    setLoadingExtra(false);
  }, [extraLoaded, loadingExtra]);

  const handleMainScroll = useCallback((event: any) => {
    const { contentOffset, contentSize, layoutMeasurement } = event.nativeEvent;
    const distanceFromBottom = contentSize.height - layoutMeasurement.height - contentOffset.y;
    if (distanceFromBottom < 600 && !extraLoaded && !loadingExtra) {
      loadExtraSections();
    }
  }, [extraLoaded, loadingExtra, loadExtraSections]);

  const getSongKey = (track: any): string => {
    const title = (track.name || track.title || '').toLowerCase().trim();
    const cleaned = title
      .replace(/\s*\(from\s+.*?\)\s*/gi, '')
      .replace(/\s*-\s*.*$/i, '')
      .replace(/[^a-z0-9]/g, '');
    return cleaned;
  };

  const deduplicateTracks = (results: any[], localSeen: Set<string>): any[] => {
    const tracks: any[] = [];
    for (const track of results) {
      const songId = track.id;
      const songKey = getSongKey(track);
      if (!songKey || songKey.length < 3) continue;
      if (localSeen.has(songId) || localSeen.has(songKey)) continue;
      if (globalSeenRef.current.has(songId)) continue;

      localSeen.add(songId);
      localSeen.add(songKey);
      globalSeenRef.current.add(songId);
      tracks.push(track);
    }
    return tracks;
  };

  const fetchSectionInitial = async (section: typeof PRIMARY_SECTIONS[0]) => {
    setInitialLoading(prev => ({ ...prev, [section.id]: true }));
    
    let allTracks: any[] = [];
    const localSeen = new Set<string>();

    // Initial load: Only try the FIRST query for speed
    try {
      const response = await axios.get(`${API_URL}/music/search`, {
        params: { query: section.queries[0], page: 1, limit: 15 },
        timeout: 10000,
      });
      if (response.data?.data?.results) {
        let newTracks = deduplicateTracks(response.data.data.results, localSeen);
        newTracks = shuffleArray(newTracks);
        allTracks = newTracks.slice(0, INITIAL_LOAD_SIZE);
      }
    } catch (error: any) {
      console.error(`Section ${section.id} initial fetch error:`, error?.message);
    }

    setSections(prev => ({
      ...prev,
      [section.id]: {
        tracks: allTracks,
        page: 1,
        loadingMore: false,
        hasMore: allTracks.length > 0,
        queryIndex: 0,
      }
    }));
    setInitialLoading(prev => ({ ...prev, [section.id]: false }));
  };

  const loadMoreForSection = async (sectionId: string) => {
    const state = sections[sectionId];
    if (!state || state.loadingMore || !state.hasMore) return;

    const allSections = [...PRIMARY_SECTIONS, ...EXTRA_SECTIONS, ...dynamicSections];
    const sectionDef = allSections.find(s => s.id === sectionId);
    if (!sectionDef) return;

    setSections(prev => ({
      ...prev,
      [sectionId]: { ...prev[sectionId], loadingMore: true }
    }));

    try {
      const localSeen = new Set<string>();
      state.tracks.forEach(t => {
        if (t?.id) localSeen.add(t.id);
        const key = getSongKey(t);
        if (key) localSeen.add(key);
      });

      const maxAttempts = sectionDef.queries.length;
      let attempt = 0;
      let nextQueryIndex = state.queryIndex;
      let appended: any[] = [];
      let usedQueryIndex = state.queryIndex;
      let usedPage = state.page;

      while (attempt < maxAttempts && appended.length === 0) {
        const query = sectionDef.queries[nextQueryIndex] || sectionDef.queries[0];
        const pageToUse = attempt === 0 ? state.page + 1 : 1;

        const response = await axios.get(`${API_URL}/music/search`, {
          params: { query, page: pageToUse, limit: 30 },
          timeout: 20000,
        });

        const results = response.data?.data?.results || [];
        if (results.length > 0) {
          let newTracks = deduplicateTracks(results, localSeen);
          newTracks = shuffleArray(newTracks);
          appended = newTracks.slice(0, PAGE_SIZE);
          if (appended.length > 0) {
            usedQueryIndex = nextQueryIndex;
            usedPage = pageToUse;
            break;
          }
        }

        attempt += 1;
        nextQueryIndex = (state.queryIndex + attempt) % sectionDef.queries.length;
      }

      if (appended.length === 0) {
        setSections(prev => ({
          ...prev,
          [sectionId]: { ...prev[sectionId], loadingMore: false, hasMore: false }
        }));
        return;
      }

      setSections(prev => ({
        ...prev,
        [sectionId]: {
          ...prev[sectionId],
          tracks: [...prev[sectionId].tracks, ...appended],
          page: usedPage,
          loadingMore: false,
          hasMore: true,
          queryIndex: usedQueryIndex,
        }
      }));
    } catch (error: any) {
      console.error(`Load more ${sectionId} error:`, error?.message);
      setSections(prev => ({
        ...prev,
        [sectionId]: { ...prev[sectionId], loadingMore: false }
      }));
    }
  };

  const maybeAutoLoad = (sectionId: string) => {
    const state = sections[sectionId];
    const layout = listLayoutRef.current[sectionId];
    if (!state || !layout || state.loadingMore || !state.hasMore) return;

    if (layout.contentWidth > 0 && layout.layoutWidth > 0 && layout.contentWidth <= layout.layoutWidth + 20) {
      loadMoreForSection(sectionId);
    }
  };

  const handleListLayout = (sectionId: string, event: LayoutChangeEvent) => {
    const layoutWidth = event.nativeEvent.layout.width;
    const prev = listLayoutRef.current[sectionId];
    listLayoutRef.current[sectionId] = {
      layoutWidth,
      contentWidth: prev?.contentWidth || 0,
    };
    maybeAutoLoad(sectionId);
  };

  const handleListContentSizeChange = (sectionId: string, contentWidth: number) => {
    const prev = listLayoutRef.current[sectionId];
    listLayoutRef.current[sectionId] = {
      layoutWidth: prev?.layoutWidth || 0,
      contentWidth,
    };
    maybeAutoLoad(sectionId);
  };

  const toPlayerTrack = (t: any) => {
    const imgArr = t.image;
    const artwork = imgArr
      ? (imgArr[imgArr.length - 1]?.url || imgArr[1]?.url || imgArr[0]?.url || null)
      : null;

    const dlArr = t.downloadUrl;
    const audioUrl = t.localUri || t.url || t.audioUrl || (dlArr
      ? (dlArr[dlArr.length - 1]?.url || dlArr[0]?.url || null)
      : null);

    const rawDuration = typeof t.duration === 'string' ? parseInt(t.duration, 10) : t.duration;
    const durationMs = rawDuration ? (rawDuration < 1000 ? rawDuration * 1000 : rawDuration) : 0;

    return {
      id: t.id,
      url: audioUrl,
      title: cleanSongTitle(t.title || t.name || ''),
      artist: cleanSongTitle(t.artist || t.artists?.primary?.[0]?.name || t.primaryArtists || ''),
      artwork: t.artwork || artwork,
      duration: durationMs,
      downloadUrl: t.downloadUrl || dlArr,
      localUri: t.localUri,
    };
  };

  const handlePlay = async (track: any, contextTracks: any[]) => {
    const baseQueue = contextTracks.map(toPlayerTrack);
    const queue = await applyDownloadedUris(baseQueue);
    const mapped = queue.find(t => t.id === track.id) || toPlayerTrack(track);
    playTrack(mapped, queue);
    addRecentlyPlayed(mapped);
  };

  const getHighQualityImage = (track: any) => {
    if (track.image && Array.isArray(track.image)) {
      return track.image[track.image.length - 1]?.url || track.image[1]?.url || track.image[0]?.url || null;
    }
    return track.artwork || null;
  };

  const renderHorizontalTracks = (sectionId: string, tracks: any[], loadingMore: boolean) => (
    <FlatList
      data={tracks}
      horizontal
      showsHorizontalScrollIndicator={false}
      contentContainerStyle={{ paddingRight: 20 }}
      keyExtractor={(item, index) => `${item.id}-${index}`}
      renderItem={({ item }) => (
        <TouchableOpacity
          style={styles.trackCard}
          onPress={() => { void handlePlay(item, tracks); }}
          activeOpacity={0.7}
        >
          <Image
            source={{ uri: getHighQualityImage(item) || 'https://placehold.co/130x130/282828/fff?text=♪' }}
            style={styles.trackImage}
          />
          <Text style={styles.trackTitle} numberOfLines={1}>
            {cleanSongTitle(item.name || item.title)}
          </Text>
          <Text style={styles.trackArtist} numberOfLines={1}>
            {cleanSongTitle(item.artists?.primary?.[0]?.name || item.artist)}
          </Text>
        </TouchableOpacity>
      )}
      onEndReached={() => loadMoreForSection(sectionId)}
      onEndReachedThreshold={0.7}
      onLayout={(event) => handleListLayout(sectionId, event)}
      onContentSizeChange={(contentWidth, _contentHeight) => handleListContentSizeChange(sectionId, contentWidth)}
      initialNumToRender={PAGE_SIZE}
      maxToRenderPerBatch={PAGE_SIZE}
      windowSize={5}
      removeClippedSubviews
      ListFooterComponent={
        loadingMore ? (
          <View style={styles.loadMoreIndicator}>
            <ActivityIndicator size="small" color="#1DB954" />
            <Text style={styles.loadMoreText}>Loading...</Text>
          </View>
        ) : null
      }
    />
  );

  const renderSection = (section: typeof PRIMARY_SECTIONS[0]) => {
    const state = sections[section.id];
    const isLoading = initialLoading[section.id];

    return (
      <View key={section.id} style={styles.section}>
        <View style={styles.sectionTitleContainer}>
          {section.icon && (
            <Ionicons name={section.icon as any} size={22} color="#1DB954" style={styles.sectionIcon} />
          )}
          <Text style={styles.sectionTitle}>{section.title}</Text>
        </View>
        {isLoading ? (
          <View style={styles.loaderRow}>
            <ActivityIndicator size="small" color="#1DB954" />
            <Text style={styles.loaderText}>Loading...</Text>
          </View>
        ) : state && state.tracks.length > 0 ? (
          renderHorizontalTracks(section.id, state.tracks, state.loadingMore)
        ) : (
          !isLoading && <Text style={styles.emptyText}>No songs found</Text>
        )}
      </View>
    );
  };

  const allVisibleSections = [
    ...dynamicSections,
    ...PRIMARY_SECTIONS,
    ...(extraLoaded ? EXTRA_SECTIONS : []),
  ];

  return (
    <ScrollView
      style={styles.container}
      showsVerticalScrollIndicator={false}
      onScroll={handleMainScroll}
      scrollEventThrottle={400}
    >
      {/* Header */}
      <View style={styles.header}>
        <View style={styles.headerContent}>
          <Image source={require('../../assets/logo.png')} style={styles.logo} />
          <View>
            <Text style={styles.greeting}>Good {getGreeting()}</Text>
            <Text style={styles.subtitle}>Tamil Music for You</Text>
          </View>
        </View>
        <TouchableOpacity style={styles.headerIconBtn} onPress={() => navigation.navigate('Profile')}>
          <Ionicons name="person-circle-outline" size={32} color="#1DB954" />
        </TouchableOpacity>
      </View>

      {/* All Sections */}
      {allVisibleSections.map(section => renderSection(section))}

      {/* Loading extras indicator */}
      {loadingExtra && (
        <View style={styles.loadingExtraContainer}>
          <ActivityIndicator size="small" color="#1DB954" />
          <Text style={styles.loadingExtraText}>Loading more categories...</Text>
        </View>
      )}

      {/* Load More Button if extras not yet loaded */}
      {!extraLoaded && !loadingExtra && (
        <TouchableOpacity style={styles.loadMoreSectionsBtn} onPress={loadExtraSections}>
          <Ionicons name="chevron-down" size={20} color="#1DB954" />
          <Text style={styles.loadMoreSectionsText}>Show More Categories</Text>
        </TouchableOpacity>
      )}

      {/* Recently Played */}
      {recentlyPlayed.length > 0 && (
        <View style={styles.section}>
          <View style={styles.sectionTitleContainer}>
            <Ionicons name="time" size={22} color="#1DB954" style={styles.sectionIcon} />
            <Text style={styles.sectionTitle}>Recently Played</Text>
          </View>
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ paddingRight: 20 }}>
            {recentlyPlayed.map((item, index) => (
              <TouchableOpacity
                key={`recent-${item.id}-${index}`}
                style={styles.trackCard}
                onPress={() => { void handlePlay(item, recentlyPlayed); }}
                activeOpacity={0.7}
              >
                <Image
                  source={{ uri: item.artwork || 'https://placehold.co/130x130/282828/fff?text=♪' }}
                  style={styles.trackImage}
                />
                <Text style={styles.trackTitle} numberOfLines={1}>{cleanSongTitle(item.title)}</Text>
                <Text style={styles.trackArtist} numberOfLines={1}>{cleanSongTitle(item.artist)}</Text>
              </TouchableOpacity>
            ))}
          </ScrollView>
        </View>
      )}

      <View style={{ height: 150 }} />
    </ScrollView>
  );
}

function getGreeting() {
  const hour = new Date().getHours();
  if (hour < 12) return 'Morning';
  if (hour < 17) return 'Afternoon';
  return 'Evening';
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#121212' },
  header: {
    paddingTop: 60, paddingHorizontal: 20, paddingBottom: 10,
    flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center',
  },
  headerContent: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  logo: { width: 40, height: 40, borderRadius: 8 },
  greeting: { color: '#fff', fontSize: 22, fontWeight: 'bold' },
  subtitle: { color: '#b3b3b3', fontSize: 13, marginTop: 2 },
  headerIconBtn: { padding: 4 },
  sectionTitleContainer: {
    flexDirection: 'row', alignItems: 'center', paddingHorizontal: 20, marginBottom: 14, marginTop: 5,
  },
  sectionIcon: { marginRight: 8 },
  sectionTitle: {
    color: '#fff', fontSize: 19, fontWeight: 'bold',
  },
  section: { marginTop: 18 },
  trackCard: { width: 130, marginLeft: 20 },
  trackImage: {
    width: 130, height: 130, borderRadius: 12,
    backgroundColor: '#282828', marginBottom: 8,
  },
  trackTitle: { color: '#fff', fontSize: 13, fontWeight: '600' },
  trackArtist: { color: '#b3b3b3', fontSize: 11, marginTop: 2 },
  loaderRow: { 
    flexDirection: 'row', alignItems: 'center', gap: 8,
    paddingHorizontal: 20, paddingVertical: 15,
  },
  loaderText: { color: '#b3b3b3', fontSize: 13 },
  emptyText: { color: '#555', fontSize: 13, paddingHorizontal: 20, paddingVertical: 10 },
  loadMoreIndicator: {
    width: 80, justifyContent: 'center', alignItems: 'center', gap: 6,
  },
  loadMoreText: { color: '#888', fontSize: 11 },
  loadingExtraContainer: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'center',
    gap: 10, paddingVertical: 20,
  },
  loadingExtraText: { color: '#b3b3b3', fontSize: 13 },
  loadMoreSectionsBtn: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'center',
    gap: 8, paddingVertical: 18, marginHorizontal: 20, marginTop: 10,
    backgroundColor: '#1a1a2e', borderRadius: 12,
  },
  loadMoreSectionsText: { color: '#1DB954', fontSize: 14, fontWeight: '600' },
});

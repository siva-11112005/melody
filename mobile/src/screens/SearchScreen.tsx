import React, { useState, useEffect, useCallback } from 'react';
import { 
  View, Text, StyleSheet, TextInput, TouchableOpacity, 
  FlatList, ActivityIndicator, Image, Modal, Alert
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import axios from 'axios';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { usePlayerStore } from '../store/usePlayerStore';
import { useLibraryStore } from '../store/useLibraryStore';
import { API_URL } from '../config/api';
import { cleanSongTitle, decodeHTMLEntities } from '../utils/textUtils';
import { applyDownloadedUris } from '../services/downloadService';

const DEFAULT_QUICK_SEARCHES = ['Anirudh', 'A.R. Rahman', 'Yuvan', 'Sid Sriram', 'Ilaiyaraaja', 'Hip Hop Tamizha'];

// Add tamil context to vague searches so JioSaavn returns Tamil results
function enrichQuery(query: string): string {
  const q = query.trim();
  const lower = q.toLowerCase();
  // If the query already contains "tamil", don't add more
  if (lower.includes('tamil')) return q;
  // If it matches patterns like "2018 songs", "melody songs", "love songs", add "tamil"
  if (/^\d{4}\b/.test(lower) || /\b(song|songs|melody|hit|hits|movie|film|kuthu|mass)\b/i.test(lower)) {
    return `${q} tamil`;
  }
  return q;
}

export default function SearchScreen() {
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<any[]>([]);
  const [suggestions, setSuggestions] = useState<string[]>([]);
  const [quickSearches, setQuickSearches] = useState<string[]>(DEFAULT_QUICK_SEARCHES);
  const [loading, setLoading] = useState(false);
  const [searched, setSearched] = useState(false);
  const [showPlaylistModal, setShowPlaylistModal] = useState(false);
  const [selectedTrack, setSelectedTrack] = useState<any>(null);
  const [playlists, setPlaylists] = useState<any[]>([]);
  const [newPlaylistName, setNewPlaylistName] = useState('');
  
  const { playTrack } = usePlayerStore();
  const { addRecentSearch, addRecentlyPlayed, recentSearches } = useLibraryStore();

  // Fetch autocomplete suggestions as user types
  useEffect(() => {
    if (query.length < 2) {
      setSuggestions([]);
      return;
    }
    const timer = setTimeout(async () => {
      try {
        const resp = await axios.get(`${API_URL}/music/suggest`, {
          params: { query },
          timeout: 3000,
        });
        const raw = Array.isArray(resp.data) ? resp.data : [];
        // Decode HTML entities in suggestions
        setSuggestions(raw.map((s: string) => decodeHTMLEntities(s)));
      } catch {
        setSuggestions([]);
      }
    }, 300); // debounce 300ms
    return () => clearTimeout(timer);
  }, [query]);

  // Load favorite artists for quick searches
  useEffect(() => {
    const loadFavorites = async () => {
      try {
        const data = await AsyncStorage.getItem('favoriteArtists');
        if (data) {
          const artists = JSON.parse(data);
          if (artists.length > 0) {
            setQuickSearches([...artists].slice(0, 8));
          }
        }
      } catch (err) {}
    };
    loadFavorites();
  }, []);

  const handleSearch = async (searchQuery?: string) => {
    const q = searchQuery || query;
    if (!q.trim()) return;
    setLoading(true);
    setSearched(true);
    setSuggestions([]);
    if (!searchQuery) setQuery(q);
    try {
      addRecentSearch(q);
      // Enrich query with tamil context for vague searches
      const enriched = enrichQuery(q);
      const response = await axios.get(`${API_URL}/music/search`, {
        params: { query: enriched },
        timeout: 15000,
      });
      if (response.data?.data?.results) {
        setResults(response.data.data.results);
      } else {
        setResults([]);
      }
    } catch (error: any) {
      console.error('Search error:', error?.message);
      setResults([]);
    } finally {
      setLoading(false);
    }
  };

  const toPlayerTrack = (t: any) => {
    const imgArr = t.image;
    // Get the highest quality image available for each song
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
      downloadUrl: t.downloadUrl,
      localUri: t.localUri,
    };
  };

  const handlePlay = async (track: any) => {
    const baseQueue = results.map(toPlayerTrack);
    const queue = await applyDownloadedUris(baseQueue);
    const mapped = queue.find(t => t.id === track.id) || toPlayerTrack(track);
    playTrack(mapped, queue);
    addRecentlyPlayed(mapped);
  };

  const openPlaylistModal = async (track: any) => {
    const mapped = {
      id: track.id,
      title: cleanSongTitle(track.name),
      artist: cleanSongTitle(track.artists?.primary?.[0]?.name),
      image: track.image?.[track.image.length - 1]?.url || track.image?.[0]?.url || '',
      artwork: track.image?.[track.image.length - 1]?.url || track.image?.[0]?.url || '',
      url: track.downloadUrl?.[track.downloadUrl.length - 1]?.url || track.downloadUrl?.[0]?.url || '',
      duration: track.duration || 0,
      downloadUrl: track.downloadUrl || [],
    };
    setSelectedTrack(mapped);
    // Fetch user playlists
    try {
      const token = await AsyncStorage.getItem('token');
      const resp = await axios.get(`${API_URL}/playlists`, {
        headers: { Authorization: `Bearer ${token}` },
        timeout: 5000,
      });
      setPlaylists(Array.isArray(resp.data) ? resp.data : []);
    } catch {
      setPlaylists([]);
    }
    setShowPlaylistModal(true);
  };

  const addToPlaylist = async (playlistId: string) => {
    try {
      const token = await AsyncStorage.getItem('token');
      await axios.post(`${API_URL}/playlists/${playlistId}/tracks`, 
        { track: selectedTrack },
        { headers: { Authorization: `Bearer ${token}` }, timeout: 5000 }
      );
      Alert.alert('Added!', 'Song added to playlist');
      setShowPlaylistModal(false);
    } catch (err: any) {
      Alert.alert('Error', err?.response?.data?.message || 'Could not add');
    }
  };

  const createPlaylistAndAdd = async () => {
    if (!newPlaylistName.trim()) return;
    try {
      const token = await AsyncStorage.getItem('token');
      const resp = await axios.post(`${API_URL}/playlists`, 
        { name: newPlaylistName.trim() },
        { headers: { Authorization: `Bearer ${token}` }, timeout: 5000 }
      );
      if (resp.data?._id) {
        await addToPlaylist(resp.data._id);
      }
      setNewPlaylistName('');
    } catch (err: any) {
      Alert.alert('Error', err?.response?.data?.message || 'Could not create playlist');
    }
  };

  const formatDuration = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs < 10 ? '0' : ''}${secs}`;
  };

  const getTrackImage = (item: any) => {
    // Get the best available image for each individual track
    if (item.image && Array.isArray(item.image)) {
      return item.image[item.image.length - 1]?.url || item.image[1]?.url || item.image[0]?.url || null;
    }
    return item.artwork || null;
  };

  return (
    <View style={styles.container}>
      <View style={styles.topBranding}>
        <View style={styles.logoContainer}>
          <Ionicons name="musical-notes" size={24} color="#8B5CF6" />
        </View>
        <Text style={styles.brandTitle}>Tamil Music</Text>
      </View>
      <Text style={styles.header}>Search</Text>
      
      {/* Search Bar */}
      <View style={styles.searchBar}>
        <Ionicons name="search" size={20} color="#b3b3b3" style={styles.searchIcon} />
        <TextInput
          style={styles.searchInput}
          placeholder="Song, artist, or movie name..."
          placeholderTextColor="#777"
          value={query}
          onChangeText={(t) => { setQuery(t); if (t.length === 0) { setSearched(false); setResults([]); } }}
          onSubmitEditing={() => handleSearch()}
          returnKeyType="search"
          autoFocus={false}
        />
        {query.length > 0 && (
          <TouchableOpacity onPress={() => { setQuery(''); setResults([]); setSearched(false); setSuggestions([]); }}>
            <Ionicons name="close-circle" size={20} color="#777" />
          </TouchableOpacity>
        )}
      </View>

      {/* Autocomplete Suggestions */}
      {suggestions.length > 0 && !searched && (
        <View style={styles.suggestionsContainer}>
          {suggestions.map((s, i) => (
            <TouchableOpacity 
              key={i} 
              style={styles.suggestionItem}
              onPress={() => { setQuery(s); handleSearch(s); }}
            >
              <Ionicons name="search-outline" size={16} color="#888" />
              <Text style={styles.suggestionText} numberOfLines={1}>{s}</Text>
              <Ionicons name="arrow-forward" size={14} color="#555" />
            </TouchableOpacity>
          ))}
        </View>
      )}

      {/* Quick Searches */}
      {!searched && suggestions.length === 0 && (
        <View>
          <Text style={styles.sectionTitle}>Quick Picks</Text>
          <View style={styles.chipContainer}>
            {quickSearches.map((q) => (
              <TouchableOpacity 
                key={q} style={styles.chip} 
                onPress={() => { setQuery(q); handleSearch(q); }}
                activeOpacity={0.7}
              >
                <Text style={styles.chipText}>{q}</Text>
              </TouchableOpacity>
            ))}
          </View>

          {recentSearches.length > 0 && (
            <>
              <Text style={styles.sectionTitle}>Recent Searches</Text>
              {recentSearches.slice(0, 5).map((q, i) => (
                <TouchableOpacity 
                  key={i} style={styles.recentItem}
                  onPress={() => { setQuery(q); handleSearch(q); }}
                >
                  <Ionicons name="time-outline" size={20} color="#b3b3b3" />
                  <Text style={styles.recentText}>{q}</Text>
                  <Ionicons name="arrow-forward" size={16} color="#555" />
                </TouchableOpacity>
              ))}
            </>
          )}
        </View>
      )}

      {/* Results */}
      {loading ? (
        <ActivityIndicator size="large" color="#1DB954" style={{ marginTop: 50 }} />
      ) : searched ? (
        <FlatList
          data={results}
          keyExtractor={(item) => item.id}
          contentContainerStyle={styles.list}
          ListEmptyComponent={
            <View style={styles.emptyContainer}>
              <Ionicons name="search-outline" size={60} color="#333" />
              <Text style={styles.emptyText}>No results found</Text>
            </View>
          }
          renderItem={({ item }) => (
            <TouchableOpacity style={styles.trackItem} onPress={() => { void handlePlay(item); }} activeOpacity={0.6}>
              <Image 
                source={{ uri: getTrackImage(item) || 'https://placehold.co/50x50/282828/fff?text=♪' }} 
                style={styles.trackImage} 
              />
              <View style={styles.trackInfo}>
                <Text style={styles.trackTitle} numberOfLines={1}>
                  {cleanSongTitle(item.name)}
                </Text>
                <Text style={styles.trackArtist} numberOfLines={1}>
                  {cleanSongTitle(item.artists?.primary?.[0]?.name || item.primaryArtists)}
                  {item.duration ? ` • ${formatDuration(item.duration)}` : ''}
                </Text>
              </View>
              <TouchableOpacity onPress={() => openPlaylistModal(item)} style={styles.addBtn}>
                <Ionicons name="add-circle-outline" size={24} color="#b3b3b3" />
              </TouchableOpacity>
              <Ionicons name="play-circle-outline" size={28} color="#1DB954" />
            </TouchableOpacity>
          )}
        />
      ) : null}

      {/* Add to Playlist Modal */}
      <Modal visible={showPlaylistModal} transparent animationType="slide" onRequestClose={() => setShowPlaylistModal(false)}>
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <View style={styles.modalHeader}>
              <TouchableOpacity onPress={() => setShowPlaylistModal(false)} style={styles.modalHeaderBtn}>
                <Ionicons name="arrow-back" size={24} color="#fff" />
                <Text style={styles.modalHeaderBtnText}>Back</Text>
              </TouchableOpacity>
              <Text style={styles.modalTitle}>Add to Playlist</Text>
              <TouchableOpacity onPress={() => setShowPlaylistModal(false)} style={styles.modalHeaderBtn}>
                <Text style={styles.modalHeaderBtnText}>Cancel</Text>
              </TouchableOpacity>
            </View>

            {selectedTrack && (
              <Text style={styles.modalTrackName} numberOfLines={1}>
                {selectedTrack.title} — {selectedTrack.artist}
              </Text>
            )}

            {/* Create new playlist */}
            <View style={styles.newPlaylistRow}>
              <TextInput
                style={styles.newPlaylistInput}
                placeholder="New playlist name..."
                placeholderTextColor="#666"
                value={newPlaylistName}
                onChangeText={setNewPlaylistName}
              />
              <TouchableOpacity style={styles.createBtn} onPress={createPlaylistAndAdd}>
                <Ionicons name="add" size={22} color="#fff" />
              </TouchableOpacity>
            </View>

            {/* Existing playlists */}
            {playlists.length > 0 ? (
              <FlatList
                data={playlists}
                keyExtractor={(item) => item._id}
                style={{ maxHeight: 250 }}
                renderItem={({ item }) => (
                  <TouchableOpacity style={styles.playlistItem} onPress={() => addToPlaylist(item._id)}>
                    <View style={styles.playlistInfo}>
                      <Text style={styles.playlistName}>{item.name}</Text>
                      <Text style={styles.playlistCount}>{item.tracks?.length || 0} songs</Text>
                    </View>
                    <Ionicons name="add-circle" size={22} color="#1DB954" />
                  </TouchableOpacity>
                )}
              />
            ) : (
              <Text style={styles.noPlaylistText}>No playlists yet. Create one above!</Text>
            )}
          </View>
        </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#121212' },
  topBranding: { flexDirection: 'row', alignItems: 'center', gap: 10, paddingHorizontal: 20, paddingTop: 60, marginBottom: 5 },
  logoContainer: { backgroundColor: 'rgba(139, 92, 246, 0.15)', padding: 8, borderRadius: 12 },
  brandTitle: { color: '#fff', fontSize: 20, fontWeight: 'bold' },
  header: { color: '#fff', fontSize: 28, fontWeight: 'bold', paddingHorizontal: 20, marginBottom: 15 },
  searchBar: {
    flexDirection: 'row', alignItems: 'center', backgroundColor: '#2a2a2a',
    borderRadius: 12, paddingHorizontal: 15, height: 48, marginHorizontal: 20, marginBottom: 10,
  },
  searchIcon: { marginRight: 10 },
  searchInput: { flex: 1, color: '#fff', fontSize: 16 },
  suggestionsContainer: { marginHorizontal: 20, backgroundColor: '#1e1e1e', borderRadius: 10, marginBottom: 10 },
  suggestionItem: {
    flexDirection: 'row', alignItems: 'center', paddingVertical: 12, paddingHorizontal: 14, gap: 10,
    borderBottomWidth: 0.5, borderBottomColor: '#333',
  },
  suggestionText: { flex: 1, color: '#ddd', fontSize: 14 },
  sectionTitle: { color: '#fff', fontSize: 18, fontWeight: 'bold', marginTop: 10, marginBottom: 12, paddingHorizontal: 20 },
  chipContainer: { flexDirection: 'row', flexWrap: 'wrap', paddingHorizontal: 20, gap: 10, marginBottom: 15 },
  chip: { backgroundColor: '#2a2a2a', paddingHorizontal: 16, paddingVertical: 10, borderRadius: 20 },
  chipText: { color: '#fff', fontSize: 14 },
  recentItem: { flexDirection: 'row', alignItems: 'center', paddingVertical: 12, paddingHorizontal: 20, gap: 12 },
  recentText: { flex: 1, color: '#ddd', fontSize: 15 },
  list: { paddingBottom: 140 },
  trackItem: { flexDirection: 'row', alignItems: 'center', marginBottom: 4, paddingVertical: 10, paddingHorizontal: 20 },
  trackImage: { width: 52, height: 52, borderRadius: 6, backgroundColor: '#282828' },
  trackInfo: { flex: 1, marginLeft: 15, justifyContent: 'center' },
  trackTitle: { color: '#fff', fontSize: 16, fontWeight: '500' },
  trackArtist: { color: '#b3b3b3', fontSize: 13, marginTop: 3 },
  addBtn: { padding: 6, marginRight: 4 },
  emptyContainer: { alignItems: 'center', marginTop: 60 },
  emptyText: { color: '#555', fontSize: 16, marginTop: 12 },
  // Modal styles
  modalOverlay: { flex: 1, backgroundColor: 'rgba(0,0,0,0.85)', justifyContent: 'flex-end' },
  modalContent: {
    backgroundColor: '#1e1e1e', borderTopLeftRadius: 25, borderTopRightRadius: 25,
    padding: 20, maxHeight: '80%',
  },
  modalHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 15, gap: 12 },
  modalHeaderBtn: { flexDirection: 'row', alignItems: 'center', gap: 4 },
  modalHeaderBtnText: { color: '#1DB954', fontSize: 14, fontWeight: '600' },
  modalTitle: { color: '#fff', fontSize: 18, fontWeight: 'bold', flex: 1, textAlign: 'center' },
  modalTrackName: { color: '#b3b3b3', fontSize: 13, marginBottom: 15, textAlign: 'center' },
  newPlaylistRow: { flexDirection: 'row', alignItems: 'center', gap: 10, marginBottom: 15 },
  newPlaylistInput: {
    flex: 1, backgroundColor: '#2a2a2a', borderRadius: 10,
    paddingHorizontal: 14, height: 44, color: '#fff', fontSize: 15,
  },
  createBtn: {
    width: 44, height: 44, borderRadius: 10, backgroundColor: '#1DB954',
    alignItems: 'center', justifyContent: 'center',
  },
  playlistItem: {
    flexDirection: 'row', alignItems: 'center', paddingVertical: 12, gap: 12,
    borderBottomWidth: 0.5, borderBottomColor: '#333',
  },
  playlistInfo: { flex: 1 },
  playlistName: { color: '#fff', fontSize: 15, fontWeight: '500' },
  playlistCount: { color: '#888', fontSize: 12, marginTop: 2 },
  noPlaylistText: { color: '#666', fontSize: 14, textAlign: 'center', paddingVertical: 30 },
});

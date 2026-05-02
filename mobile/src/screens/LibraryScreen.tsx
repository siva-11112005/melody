import React, { useState, useEffect, useCallback } from 'react';
import { 
  View, Text, StyleSheet, TouchableOpacity, FlatList, 
  Image, Alert, TextInput, Modal, ScrollView, ActivityIndicator, Dimensions,
  KeyboardAvoidingView, Platform
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useFocusEffect } from '@react-navigation/native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import axios from 'axios';
import { usePlayerStore } from '../store/usePlayerStore';
import { useLibraryStore } from '../store/useLibraryStore';
import { applyDownloadedUris, getDownloadedTracks } from '../services/downloadService';
import { API_URL } from '../config/api';
import { cleanSongTitle } from '../utils/textUtils';

type TabName = 'playlists' | 'recent' | 'downloads' | 'liked';

export default function LibraryScreen() {
  const [activeTab, setActiveTab] = useState<TabName>('playlists');
  const [downloads, setDownloads] = useState<any[]>([]);
  const [likedSongs, setLikedSongs] = useState<any[]>([]);
  const [playlists, setPlaylists] = useState<any[]>([]);
  const [expandedPlaylist, setExpandedPlaylist] = useState<string | null>(null);
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [createMode, setCreateMode] = useState<'manual' | 'search' | 'ai' | 'csv'>('manual');
  const [newName, setNewName] = useState('');
  const [csvSongs, setCsvSongs] = useState('');
  const [aiPrompt, setAiPrompt] = useState('');
  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState<any[]>([]);
  const [selectedTracks, setSelectedTracks] = useState<any[]>([]);
  const [searching, setSearching] = useState(false);
  const [generating, setGenerating] = useState(false);
  const [targetPlaylistId, setTargetPlaylistId] = useState<string | null>(null);
  const [showResultsView, setShowResultsView] = useState(false);
  const [tempResults, setTempResults] = useState<any[]>([]);
  const { recentlyPlayed, loadLibrary } = useLibraryStore();
  const { playTrack } = usePlayerStore();
  const createOptionWidth = (Dimensions.get('window').width - 60) / 4;

  useFocusEffect(
    useCallback(() => {
      loadLibrary();
      loadDownloads();
      loadLikedSongs();
      if (activeTab === 'playlists') loadPlaylists();
    }, [activeTab])
  );

  // Back handling is done via Modal's onRequestClose prop.
  // Removed BackHandler to prevent it from intercepting backspace key events in TextInputs.


  const loadDownloads = async () => { setDownloads(await getDownloadedTracks()); };
  const loadLikedSongs = async () => {
    const data = await AsyncStorage.getItem('likedSongs');
    setLikedSongs(data ? JSON.parse(data) : []);
  };

  const loadPlaylists = async () => {
    try {
      const token = await AsyncStorage.getItem('token');
      if (!token) return;
      const resp = await axios.get(`${API_URL}/playlists`, {
        headers: { Authorization: `Bearer ${token}` }, timeout: 5000,
      });
      setPlaylists(Array.isArray(resp.data) ? resp.data : []);
    } catch { setPlaylists([]); }
  };

  const removeLiked = async (trackId: string) => {
    const data = await AsyncStorage.getItem('likedSongs');
    const liked = data ? JSON.parse(data) : [];
    const updated = liked.filter((s: any) => s.id !== trackId);
    await AsyncStorage.setItem('likedSongs', JSON.stringify(updated));
    setLikedSongs(updated);
  };

  const removeDownloadItem = async (trackId: string) => {
    const { removeDownload } = await import('../services/downloadService');
    await removeDownload(trackId);
    loadDownloads();
  };

  const openCreateModal = (mode: 'manual' | 'search' | 'ai' | 'csv', existingPlaylistId?: string) => {
    setCreateMode(mode);
    setTargetPlaylistId(existingPlaylistId || null);
    setNewName(existingPlaylistId ? (playlists.find(p => p._id === existingPlaylistId)?.name || '') : '');
    setCsvSongs('');
    setAiPrompt('');
    setSearchQuery('');
    setSearchResults([]);
    setSelectedTracks([]);
    setTempResults([]);
    setShowResultsView(false);
    setShowCreateModal(true);
  };

  const searchSongs = async () => {
    if (!searchQuery.trim()) return;
    setSearching(true);
    try {
      const resp = await axios.get(`${API_URL}/music/search`, {
        params: { query: searchQuery }, timeout: 15000,
      });
      if (resp.data?.data?.results) {
        setSearchResults(resp.data.data.results.map((t: any) => ({
          id: t.id,
          title: cleanSongTitle(t.name),
          artist: cleanSongTitle(t.artists?.primary?.[0]?.name),
          image: t.image?.[t.image.length - 1]?.url || t.image?.[0]?.url || '',
          artwork: t.image?.[t.image.length - 1]?.url || '',
          url: t.downloadUrl?.[t.downloadUrl.length - 1]?.url || t.downloadUrl?.[0]?.url || '',
          duration: t.duration || 0,
          downloadUrl: t.downloadUrl || [],
        })));
      }
    } catch { setSearchResults([]); }
    finally { setSearching(false); }
  };

  const toggleTrackSelection = (track: any) => {
    const exists = selectedTracks.find(t => t.id === track.id);
    if (exists) setSelectedTracks(selectedTracks.filter(t => t.id !== track.id));
    else setSelectedTracks([...selectedTracks, track]);
  };

  const toggleTempSelection = (track: any) => {
    const exists = selectedTracks.find(t => t.id === track.id);
    if (exists) setSelectedTracks(selectedTracks.filter(t => t.id !== track.id));
    else setSelectedTracks([...selectedTracks, track]);
  };

  const addTracksToPlaylist = async (playlistId: string, tracks: any[]) => {
    const token = await AsyncStorage.getItem('token');
    for (const track of tracks) {
      await axios.post(`${API_URL}/playlists/${playlistId}/tracks`,
        { track },
        { headers: { Authorization: `Bearer ${token}` }, timeout: 5000 }
      ).catch(() => {});
    }
  };

  const createPlaylistWithTracks = async (tracks: any[]) => {
    try {
      const token = await AsyncStorage.getItem('token');
      if (targetPlaylistId) {
        // Adding to existing playlist
        if (tracks.length > 0) {
          await addTracksToPlaylist(targetPlaylistId, tracks);
        }
        setShowCreateModal(false);
        loadPlaylists();
        Alert.alert('Added!', `${tracks.length} songs added to playlist`);
      } else {
        // Creating new playlist
        if (!newName.trim()) { Alert.alert('Error', 'Enter a playlist name'); return; }
        const resp = await axios.post(`${API_URL}/playlists`,
          { name: newName.trim() },
          { headers: { Authorization: `Bearer ${token}` }, timeout: 5000 }
        );
        if (resp.data?._id && tracks.length > 0) {
          await addTracksToPlaylist(resp.data._id, tracks);
        }
        setShowCreateModal(false);
        loadPlaylists();
        Alert.alert('Created!', `"${newName}" with ${tracks.length} songs`);
      }
    } catch (err: any) {
      Alert.alert('Error', err?.response?.data?.message || 'Could not create');
    }
  };

  const handleCreateManual = () => createPlaylistWithTracks([]);

  const handleCreateWithSearch = () => createPlaylistWithTracks(selectedTracks);

  const handleCreateWithCsv = async () => {
    if (!csvSongs.trim()) {
      Alert.alert('Error', 'Enter song names'); return;
    }
    if (!targetPlaylistId && !newName.trim()) {
      Alert.alert('Error', 'Enter a playlist name'); return;
    }
    setGenerating(true);
    try {
      const names = csvSongs.split(/[\n,]/).map(s => s.trim()).filter(Boolean);
      const resp = await axios.post(`${API_URL}/ai/resolve-songs`,
        { songNames: names }, { timeout: 60000 }
      );
      if (resp.data?.tracks?.length > 0) {
        setTempResults(resp.data.tracks);
        setSelectedTracks(resp.data.tracks);
        setShowResultsView(true);
      } else {
        Alert.alert('No Results', 'Could not find any of those songs. Try different song names.');
      }
    } catch (err: any) {
      console.error('CSV resolve error:', err?.message);
      Alert.alert('Error', 'Failed to resolve songs. Check your internet connection.');
    }
    finally { setGenerating(false); }
  };

  const handleCreateWithAi = async () => {
    if (!aiPrompt.trim()) {
      Alert.alert('Error', 'Enter a description for the playlist'); return;
    }
    if (!targetPlaylistId && !newName.trim()) {
      Alert.alert('Error', 'Enter a playlist name'); return;
    }
    setGenerating(true);
    try {
      const resp = await axios.post(`${API_URL}/ai/generate-playlist`,
        { description: aiPrompt }, { timeout: 60000 }
      );
      if (resp.data?.tracks?.length > 0) {
        setTempResults(resp.data.tracks);
        setSelectedTracks(resp.data.tracks);
        setShowResultsView(true);
      } else {
        Alert.alert('No Results', 'Could not generate playlist. Try a different description.');
      }
    } catch (err: any) {
      console.error('AI playlist error:', err?.message);
      Alert.alert('Error', 'Failed to generate playlist. Check your internet connection.');
    }
    finally { setGenerating(false); }
  };

  const deletePlaylist = (id: string, name: string) => {
    Alert.alert('Delete Playlist', `Delete "${name}"?`, [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Delete', style: 'destructive', onPress: async () => {
        try {
          const token = await AsyncStorage.getItem('token');
          await axios.delete(`${API_URL}/playlists/${id}`, { headers: { Authorization: `Bearer ${token}` } });
          loadPlaylists();
        } catch { Alert.alert('Error', 'Could not delete'); }
      }},
    ]);
  };

  const removeFromPlaylist = async (playlistId: string, trackId: string) => {
    try {
      const token = await AsyncStorage.getItem('token');
      await axios.delete(`${API_URL}/playlists/${playlistId}/tracks/${trackId}`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      loadPlaylists();
    } catch { Alert.alert('Error', 'Could not remove'); }
  };

  const toPlayerTrack = (t: any) => {
    const rawDuration = typeof t.duration === 'string' ? parseInt(t.duration, 10) : t.duration;
    const durationMs = rawDuration ? (rawDuration < 1000 ? rawDuration * 1000 : rawDuration) : 0;

    // Resolve artwork: could be 'artwork' field, 'image' field (string or array)
    let artwork = t.artwork || null;
    if (!artwork && t.image) {
      if (typeof t.image === 'string') {
        artwork = t.image;
      } else if (Array.isArray(t.image)) {
        artwork = t.image[t.image.length - 1]?.url || t.image[0]?.url || null;
      }
    }

    // Resolve audio URL
    let audioUrl = t.localUri || t.url || t.audioUrl || t.streamUrl || null;
    if (!audioUrl && Array.isArray(t.downloadUrl) && t.downloadUrl.length > 0) {
      const last = t.downloadUrl[t.downloadUrl.length - 1];
      audioUrl = typeof last === 'string' ? last : last?.url || null;
    }

    return {
      id: t.id,
      url: audioUrl,
      title: cleanSongTitle(t.title || t.name || ''),
      artist: cleanSongTitle(t.artist || t.primaryArtists || ''),
      artwork: artwork,
      duration: durationMs,
      downloadUrl: t.downloadUrl || [],
      localUri: t.localUri,
    };
  };

  const handlePlay = async (track: any, contextTracks?: any[]) => {
    const baseList = contextTracks && contextTracks.length > 0 ? contextTracks : [track];
    const baseQueue = baseList.map(toPlayerTrack);
    const queue = await applyDownloadedUris(baseQueue);
    const mapped = queue.find(t => t.id === track.id) || toPlayerTrack(track);
    playTrack(mapped, queue);
  };

  const TABS: { key: TabName; label: string; icon: string }[] = [
    { key: 'playlists', label: 'Playlists', icon: 'list' },
    { key: 'recent', label: 'Recent', icon: 'time' },
    { key: 'downloads', label: 'Downloads', icon: 'download' },
    { key: 'liked', label: 'Liked', icon: 'heart' },
  ];

  const renderTrackItem = (track: any, playlistId?: string, contextTracks?: any[], type?: 'liked' | 'download') => (
    <TouchableOpacity style={styles.trackItem} onPress={() => { void handlePlay(track, contextTracks); }} activeOpacity={0.6} key={track.id}>
      <Image source={{ uri: track.artwork || track.image || 'https://placehold.co/50x50/282828/fff?text=♪' }} style={styles.trackImage} />
      <View style={styles.trackInfo}>
        <Text style={styles.trackTitle} numberOfLines={1}>{cleanSongTitle(track.title || track.name)}</Text>
        <Text style={styles.trackArtist} numberOfLines={1}>{cleanSongTitle(track.artist)}</Text>
      </View>
      <View style={styles.trackActions}>
        {playlistId && (
          <TouchableOpacity onPress={() => removeFromPlaylist(playlistId, track.id)} style={styles.removeBtn} hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}>
            <Ionicons name="trash-outline" size={20} color="#e74c3c" />
          </TouchableOpacity>
        )}
        {type === 'liked' && (
          <TouchableOpacity onPress={() => removeLiked(track.id)} style={styles.removeBtn} hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}>
            <Ionicons name="heart-dislike-outline" size={20} color="#e74c3c" />
          </TouchableOpacity>
        )}
        {type === 'download' && (
          <TouchableOpacity onPress={() => removeDownloadItem(track.id)} style={styles.removeBtn} hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}>
            <Ionicons name="trash-outline" size={20} color="#e74c3c" />
          </TouchableOpacity>
        )}
        <Ionicons name="play-circle" size={26} color="#1DB954" />
      </View>
    </TouchableOpacity>
  );

  const renderEmpty = (message: string, icon: string) => (
    <View style={styles.emptyContainer}>
      <Ionicons name={icon as any} size={60} color="#333" />
      <Text style={styles.emptyText}>{message}</Text>
    </View>
  );

  const renderPlaylists = () => (
    <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={{ paddingBottom: 140 }}>
      {/* Create playlist buttons */}
      <View style={styles.createOptions}>
        <TouchableOpacity style={[styles.createOptionBtn, { width: createOptionWidth }]} onPress={() => openCreateModal('manual')}>
          <View style={[styles.createIcon, { backgroundColor: '#1DB954' }]}>
            <Ionicons name="add" size={24} color="#fff" />
          </View>
          <Text style={styles.createOptionText}>Empty Playlist</Text>
        </TouchableOpacity>
        <TouchableOpacity style={[styles.createOptionBtn, { width: createOptionWidth }]} onPress={() => openCreateModal('search')}>
          <View style={[styles.createIcon, { backgroundColor: '#6c5ce7' }]}>
            <Ionicons name="search" size={22} color="#fff" />
          </View>
          <Text style={styles.createOptionText}>Search & Add</Text>
        </TouchableOpacity>
        <TouchableOpacity style={[styles.createOptionBtn, { width: createOptionWidth }]} onPress={() => openCreateModal('csv')}>
          <View style={[styles.createIcon, { backgroundColor: '#e17055' }]}>
            <Ionicons name="list" size={22} color="#fff" />
          </View>
          <Text style={styles.createOptionText}>Song Names</Text>
        </TouchableOpacity>
        <TouchableOpacity style={[styles.createOptionBtn, { width: createOptionWidth }]} onPress={() => openCreateModal('ai')}>
          <View style={[styles.createIcon, { backgroundColor: '#fd79a8' }]}>
            <Ionicons name="sparkles" size={22} color="#fff" />
          </View>
          <Text style={styles.createOptionText}>AI Playlist</Text>
        </TouchableOpacity>
      </View>

      {playlists.length === 0 ? renderEmpty('No playlists yet', 'list-outline') : (
        playlists.map((pl) => (
          <View key={pl._id}>
            <View style={styles.playlistRow}>
              <TouchableOpacity style={styles.playlistMain}
                onPress={() => setExpandedPlaylist(expandedPlaylist === pl._id ? null : pl._id)}>
                <View style={styles.playlistMeta}>
                  <Text style={styles.playlistName}>{pl.name}</Text>
                  <Text style={styles.playlistCount}>{pl.tracks?.length || 0} songs</Text>
                </View>
                <Ionicons name={expandedPlaylist === pl._id ? "chevron-up" : "chevron-down"} size={20} color="#888" />
              </TouchableOpacity>
              <TouchableOpacity onPress={() => deletePlaylist(pl._id, pl.name)} style={styles.playlistDeleteBtn}>
                <Ionicons name="trash-outline" size={18} color="#e74c3c" />
              </TouchableOpacity>
            </View>
            {expandedPlaylist === pl._id && (
              <View style={styles.playlistTracks}>
                {pl.tracks?.length > 0 && pl.tracks.map((t: any) => renderTrackItem(t, pl._id, pl.tracks))}
                {(!pl.tracks || pl.tracks.length === 0) && (
                  <Text style={styles.emptyPlaylistText}>No songs yet. Add some below!</Text>
                )}
                <View style={styles.addSongsRow}>
                  <TouchableOpacity style={styles.addSongBtn} onPress={() => openCreateModal('search', pl._id)}>
                    <Ionicons name="search" size={16} color="#fff" />
                    <Text style={styles.addSongBtnText}>Search</Text>
                  </TouchableOpacity>
                  <TouchableOpacity style={[styles.addSongBtn, { backgroundColor: '#e17055' }]} onPress={() => openCreateModal('csv', pl._id)}>
                    <Ionicons name="list" size={16} color="#fff" />
                    <Text style={styles.addSongBtnText}>Song Names</Text>
                  </TouchableOpacity>
                  <TouchableOpacity style={[styles.addSongBtn, { backgroundColor: '#fd79a8' }]} onPress={() => openCreateModal('ai', pl._id)}>
                    <Ionicons name="sparkles" size={16} color="#fff" />
                    <Text style={styles.addSongBtnText}>AI Add</Text>
                  </TouchableOpacity>
                </View>
              </View>
            )}
          </View>
        ))
      )}
    </ScrollView>
  );

  return (
    <View style={styles.container}>
      <View style={styles.topBranding}>
        <View style={styles.logoContainer}>
          <Ionicons name="musical-notes" size={24} color="#8B5CF6" />
        </View>
        <Text style={styles.brandTitle}>Tamil Music</Text>
      </View>
      <Text style={styles.header}>Your Library</Text>
      <View style={styles.tabBar}>
        {TABS.map(tab => (
          <TouchableOpacity key={tab.key}
            style={[styles.tab, activeTab === tab.key && styles.activeTab]}
            onPress={() => { setActiveTab(tab.key); if (tab.key === 'playlists') loadPlaylists(); }}>
            <Ionicons name={tab.icon as any} size={16} color={activeTab === tab.key ? '#fff' : '#888'} />
            <Text style={[styles.tabText, activeTab === tab.key && styles.activeTabText]}>{tab.label}</Text>
          </TouchableOpacity>
        ))}
      </View>

      {activeTab === 'playlists' && renderPlaylists()}
      {activeTab === 'recent' && (
        <FlatList data={recentlyPlayed} keyExtractor={(item, i) => item.id || String(i)}
          contentContainerStyle={{ paddingBottom: 140 }}
          ListEmptyComponent={renderEmpty('No recently played songs', 'time-outline')}
          renderItem={({ item }) => renderTrackItem(item, undefined, recentlyPlayed)} />
      )}
      {activeTab === 'downloads' && (
        <FlatList data={downloads} keyExtractor={(item, i) => item.id || String(i)}
          contentContainerStyle={{ paddingBottom: 140 }}
          ListEmptyComponent={renderEmpty('No downloaded songs', 'download-outline')}
          renderItem={({ item }) => renderTrackItem(item, undefined, downloads, 'download')} />
      )}
      {activeTab === 'liked' && (
        <FlatList data={likedSongs} keyExtractor={(item, i) => item.id || String(i)}
          contentContainerStyle={{ paddingBottom: 140 }}
          ListEmptyComponent={renderEmpty('No liked songs yet', 'heart-outline')}
          renderItem={({ item }) => renderTrackItem(item, undefined, likedSongs, 'liked')} />
      )}

      {/* Create Playlist Modal */}
      <Modal visible={showCreateModal} transparent animationType="slide" onRequestClose={() => setShowCreateModal(false)}>
        <KeyboardAvoidingView style={styles.modalOverlay} behavior={Platform.OS === 'ios' ? 'padding' : 'height'}>
          <View style={styles.modalContent}>
            <View style={styles.modalHeader}>
              <TouchableOpacity onPress={() => setShowCreateModal(false)} style={styles.modalHeaderBtn}>
                <Ionicons name="arrow-back" size={24} color="#fff" />
                <Text style={styles.modalHeaderBtnText}>Back</Text>
              </TouchableOpacity>
              <Text style={styles.modalTitle} numberOfLines={1}>
                {targetPlaylistId
                  ? (createMode === 'search' ? 'Search & Add' : createMode === 'csv' ? 'Add by Names' : 'AI Add')
                  : (createMode === 'manual' ? 'Create Playlist' : createMode === 'search' ? 'Search & Add' : createMode === 'csv' ? 'Add by Song Names' : 'AI Playlist')}
              </Text>
              <TouchableOpacity onPress={() => setShowCreateModal(false)} style={styles.modalHeaderBtn}>
                <Text style={styles.modalHeaderBtnText}>Cancel</Text>
              </TouchableOpacity>
            </View>

            <ScrollView showsVerticalScrollIndicator={false} keyboardShouldPersistTaps="handled">
              {!targetPlaylistId && (
                <TextInput style={styles.modalInput} placeholder="Playlist name" placeholderTextColor="#666"
                  value={newName} onChangeText={setNewName} />
              )}
              {targetPlaylistId && (
                <Text style={{ color: '#1DB954', fontSize: 14, marginBottom: 12 }}>Adding to: {newName}</Text>
              )}

              {createMode === 'manual' && (
                <TouchableOpacity style={styles.greenBtn} onPress={handleCreateManual}>
                  <Text style={styles.greenBtnText}>Create Empty Playlist</Text>
                </TouchableOpacity>
              )}

              {createMode === 'search' && (
                <>
                  <View style={styles.searchRow}>
                    <TextInput style={styles.searchInput} placeholder="Search songs..." placeholderTextColor="#666"
                      value={searchQuery} onChangeText={setSearchQuery} onSubmitEditing={searchSongs} returnKeyType="search" />
                    <TouchableOpacity style={styles.searchBtn} onPress={searchSongs}>
                      <Ionicons name="search" size={20} color="#fff" />
                    </TouchableOpacity>
                  </View>
                  {selectedTracks.length > 0 && (
                    <Text style={styles.selectedCount}>{selectedTracks.length} songs selected</Text>
                  )}
                  {searching ? <ActivityIndicator color="#1DB954" style={{ marginVertical: 15 }} /> : (
                    <FlatList data={searchResults} keyExtractor={item => item.id} style={{ maxHeight: 250 }}
                      keyboardShouldPersistTaps="handled"
                      renderItem={({ item }) => {
                        const isSelected = selectedTracks.some(t => t.id === item.id);
                        return (
                          <TouchableOpacity style={[styles.searchItem, isSelected && styles.searchItemSelected]} onPress={() => toggleTrackSelection(item)}>
                            <Image source={{ uri: item.image || '' }} style={styles.searchThumb} />
                            <View style={{ flex: 1 }}>
                              <Text style={styles.searchItemTitle} numberOfLines={1}>{item.title}</Text>
                              <Text style={styles.searchItemArtist} numberOfLines={1}>{item.artist}</Text>
                            </View>
                            <Ionicons name={isSelected ? "checkmark-circle" : "add-circle-outline"} size={24} color={isSelected ? "#1DB954" : "#888"} />
                          </TouchableOpacity>
                        );
                      }} />
                  )}
                  {selectedTracks.length > 0 && (
                    <TouchableOpacity style={styles.greenBtn} onPress={handleCreateWithSearch}>
                      <Text style={styles.greenBtnText}>{targetPlaylistId ? 'Add' : 'Create with'} {selectedTracks.length} Songs</Text>
                    </TouchableOpacity>
                  )}
                </>
              )}

              {/* Results Selection View (for CSV and AI) */}
              {showResultsView && (
                <>
                  <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10 }}>
                    <Text style={styles.selectedCount}>{selectedTracks.length} songs selected</Text>
                    <TouchableOpacity onPress={() => setShowResultsView(false)}>
                      <Text style={{ color: '#888', fontSize: 13 }}>Change search</Text>
                    </TouchableOpacity>
                  </View>
                  <FlatList data={tempResults} keyExtractor={(item, i) => item.id || String(i)} style={{ maxHeight: 300 }}
                    keyboardShouldPersistTaps="handled"
                    renderItem={({ item }) => {
                      const isSelected = selectedTracks.some(t => t.id === item.id);
                      return (
                        <TouchableOpacity style={[styles.searchItem, isSelected && styles.searchItemSelected]} onPress={() => toggleTempSelection(item)}>
                          <Image source={{ uri: item.image || item.artwork || '' }} style={styles.searchThumb} />
                          <View style={{ flex: 1 }}>
                            <Text style={styles.searchItemTitle} numberOfLines={1}>{item.title}</Text>
                            <Text style={styles.searchItemArtist} numberOfLines={1}>{item.artist}</Text>
                          </View>
                          <Ionicons name={isSelected ? "checkmark-circle" : "add-circle-outline"} size={24} color={isSelected ? "#1DB954" : "#888"} />
                        </TouchableOpacity>
                      );
                    }} />
                  <TouchableOpacity style={[styles.greenBtn, { marginTop: 20 }]} onPress={() => createPlaylistWithTracks(selectedTracks)}>
                    <Text style={styles.greenBtnText}>{targetPlaylistId ? 'Add' : 'Create with'} {selectedTracks.length} Songs</Text>
                  </TouchableOpacity>
                </>
              )}

              {createMode === 'csv' && !showResultsView && (
                <>
                  <Text style={styles.hintText}>Enter song names separated by commas or new lines</Text>
                  <TextInput style={[styles.modalInput, { height: 100, textAlignVertical: 'top', paddingTop: 12 }]}
                    placeholder="e.g. Enna Solla, Kannazhaga, Why This Kolaveri"
                    placeholderTextColor="#555" value={csvSongs} onChangeText={setCsvSongs} multiline
                    blurOnSubmit={false} />
                  <TouchableOpacity style={styles.greenBtn} onPress={handleCreateWithCsv} disabled={generating}>
                    {generating ? (
                      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
                        <ActivityIndicator color="#fff" />
                        <Text style={styles.greenBtnText}>Finding songs...</Text>
                      </View>
                    ) : <Text style={styles.greenBtnText}>{targetPlaylistId ? 'Find & Add Songs' : 'Find & Create Playlist'}</Text>}
                  </TouchableOpacity>
                </>
              )}

              {createMode === 'ai' && !showResultsView && (
                <>
                  <Text style={styles.hintText}>Describe the playlist you want</Text>
                  <TextInput style={[styles.modalInput, { height: 100, textAlignVertical: 'top', paddingTop: 12 }]}
                    placeholder="e.g. Sad tamil melodies for rainy night, Anirudh party songs, 90s romantic hits..."
                    placeholderTextColor="#555" value={aiPrompt} onChangeText={setAiPrompt} multiline
                    blurOnSubmit={false} />
                  <TouchableOpacity style={[styles.greenBtn, { backgroundColor: '#fd79a8' }]} onPress={handleCreateWithAi} disabled={generating}>
                    {generating ? (
                      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
                        <ActivityIndicator color="#fff" />
                        <Text style={styles.greenBtnText}>Generating...</Text>
                      </View>
                    ) : (
                      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
                        <Ionicons name="sparkles" size={18} color="#fff" />
                        <Text style={styles.greenBtnText}>{targetPlaylistId ? 'Generate & Add' : 'Generate with AI'}</Text>
                      </View>
                    )}
                  </TouchableOpacity>
                </>
              )}
              <View style={{ height: 20 }} />
            </ScrollView>
          </View>
        </KeyboardAvoidingView>
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
  tabBar: { flexDirection: 'row', paddingHorizontal: 15, marginBottom: 15, gap: 8 },
  tab: { flexDirection: 'row', alignItems: 'center', gap: 6, paddingHorizontal: 14, paddingVertical: 8, borderRadius: 20, backgroundColor: '#2a2a2a' },
  activeTab: { backgroundColor: '#1DB954' },
  tabText: { color: '#888', fontSize: 13, fontWeight: '500' },
  activeTabText: { color: '#fff' },
  createOptions: { flexDirection: 'row', flexWrap: 'wrap', paddingHorizontal: 15, gap: 10, marginBottom: 15 },
  createOptionBtn: { alignItems: 'center', width: (375 - 60) / 4 },
  createIcon: { width: 50, height: 50, borderRadius: 14, alignItems: 'center', justifyContent: 'center', marginBottom: 6 },
  createOptionText: { color: '#ccc', fontSize: 11, textAlign: 'center' },
  playlistRow: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 20, paddingVertical: 12, borderBottomWidth: 0.5, borderBottomColor: '#222' },
  playlistMain: { flex: 1, flexDirection: 'row', alignItems: 'center' },
  playlistMeta: { flex: 1 },
  playlistName: { color: '#fff', fontSize: 16, fontWeight: 'bold' },
  playlistCount: { color: '#888', fontSize: 12, marginTop: 4 },
  playlistDeleteBtn: { padding: 10, marginLeft: 10 },
  playlistTracks: { paddingLeft: 20, backgroundColor: '#1a1a1a' },
  emptyPlaylistText: { color: '#555', fontSize: 13, paddingVertical: 15, paddingHorizontal: 40, textAlign: 'center' },
  trackItem: { flexDirection: 'row', alignItems: 'center', paddingVertical: 10, paddingHorizontal: 20 },
  trackImage: { width: 48, height: 48, borderRadius: 6, backgroundColor: '#282828' },
  trackInfo: { flex: 1, marginLeft: 14 },
  trackTitle: { color: '#fff', fontSize: 15, fontWeight: '500' },
  trackArtist: { color: '#b3b3b3', fontSize: 12, marginTop: 2 },
  trackActions: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  removeBtn: { padding: 8, justifyContent: 'center', alignItems: 'center' },
  emptyContainer: { alignItems: 'center', marginTop: 80 },
  emptyText: { color: '#555', fontSize: 16, marginTop: 12 },
  modalOverlay: { flex: 1, backgroundColor: 'rgba(0,0,0,0.85)', justifyContent: 'flex-end' },
  modalContent: { backgroundColor: '#1e1e1e', borderTopLeftRadius: 25, borderTopRightRadius: 25, padding: 20, maxHeight: '85%' },
  modalHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20, gap: 12 },
  modalHeaderBtn: { flexDirection: 'row', alignItems: 'center', gap: 4, paddingVertical: 4 },
  modalHeaderBtnText: { color: '#1DB954', fontSize: 14, fontWeight: '600' },
  modalTitle: { color: '#fff', fontSize: 18, fontWeight: 'bold', flex: 1, textAlign: 'center' },
  modalInput: { backgroundColor: '#2a2a2a', borderRadius: 10, paddingHorizontal: 16, height: 48, color: '#fff', fontSize: 16, marginBottom: 12 },
  hintText: { color: '#888', fontSize: 13, marginBottom: 8 },
  greenBtn: { backgroundColor: '#1DB954', borderRadius: 25, paddingVertical: 14, alignItems: 'center', marginTop: 8 },
  greenBtnText: { color: '#fff', fontSize: 16, fontWeight: '600' },
  searchRow: { flexDirection: 'row', gap: 8, marginBottom: 10 },
  searchInput: { flex: 1, backgroundColor: '#2a2a2a', borderRadius: 10, paddingHorizontal: 14, height: 44, color: '#fff', fontSize: 15 },
  searchBtn: { width: 44, height: 44, borderRadius: 10, backgroundColor: '#1DB954', alignItems: 'center', justifyContent: 'center' },
  selectedCount: { color: '#1DB954', fontSize: 13, fontWeight: '600', marginBottom: 8 },
  searchItem: { flexDirection: 'row', alignItems: 'center', paddingVertical: 8, gap: 10, borderBottomWidth: 0.5, borderBottomColor: '#333' },
  searchItemSelected: { backgroundColor: 'rgba(29,185,84,0.1)' },
  searchThumb: { width: 40, height: 40, borderRadius: 6, backgroundColor: '#282828' },
  searchItemTitle: { color: '#fff', fontSize: 14, fontWeight: '500' },
  searchItemArtist: { color: '#888', fontSize: 12 },
  modalButtons: { flexDirection: 'row', justifyContent: 'flex-end', gap: 12 },
  addSongsRow: { flexDirection: 'row', gap: 8, paddingVertical: 12, paddingHorizontal: 10 },
  addSongBtn: { flexDirection: 'row', alignItems: 'center', gap: 5, backgroundColor: '#6c5ce7', paddingHorizontal: 12, paddingVertical: 8, borderRadius: 16 },
  addSongBtnText: { color: '#fff', fontSize: 12, fontWeight: '600' },
});

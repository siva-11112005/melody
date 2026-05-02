import React, { useState, useEffect } from 'react';
import { 
  View, Text, StyleSheet, TouchableOpacity, Image, 
  Dimensions, ScrollView, Modal, TextInput, FlatList, Alert, Share 
} from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { Ionicons } from '@expo/vector-icons';
import Slider from '@react-native-community/slider';
import axios from 'axios';
import { usePlayerStore } from '../store/usePlayerStore';
import { downloadTrack } from '../services/downloadService';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { API_URL } from '../config/api';
import { cleanSongTitle, decodeHTMLEntities } from '../utils/textUtils';

const { width } = Dimensions.get('window');

export default function FullPlayerScreen({ navigation }: any) {
  const { 
    currentTrack, isPlaying, pause, resume, 
    position, duration, setPosition,
    playNext, playPrevious, queue, currentIndex,
    seekTo, removeFromQueue
  } = usePlayerStore();
  const [downloading, setDownloading] = useState(false);
  const [downloaded, setDownloaded] = useState(false);
  const [liked, setLiked] = useState(false);
  const [shuffle, setShuffle] = useState(false);
  const [repeat, setRepeat] = useState(false);
  const [isSeeking, setIsSeeking] = useState(false);
  const [seekValue, setSeekValue] = useState(0);
  
  const [showPlaylistModal, setShowPlaylistModal] = useState(false);
  const [showQueueModal, setShowQueueModal] = useState(false);
  const [playlists, setPlaylists] = useState<any[]>([]);
  const [newPlaylistName, setNewPlaylistName] = useState('');

  useEffect(() => {
    if (!currentTrack) navigation.goBack();
    else {
      checkLiked();
      setDownloaded(false);
    }
  }, [currentTrack]);

  const checkLiked = async () => {
    if (!currentTrack) return;
    const data = await AsyncStorage.getItem('likedSongs');
    const likedSongs = data ? JSON.parse(data) : [];
    setLiked(likedSongs.some((s: any) => s.id === currentTrack.id));
  };

  const handleLike = async () => {
    if (!currentTrack) return;
    const data = await AsyncStorage.getItem('likedSongs');
    const likedSongs = data ? JSON.parse(data) : [];
    if (liked) {
      const updated = likedSongs.filter((s: any) => s.id !== currentTrack.id);
      await AsyncStorage.setItem('likedSongs', JSON.stringify(updated));
      setLiked(false);
    } else {
      likedSongs.unshift(currentTrack);
      await AsyncStorage.setItem('likedSongs', JSON.stringify(likedSongs));
      setLiked(true);
    }
  };

  const handleDownload = async () => {
    if (!currentTrack || downloaded || downloading) return;
    setDownloading(true);
    try {
      await downloadTrack(currentTrack);
      setDownloaded(true);
      Alert.alert('Downloaded!', `"${cleanSongTitle(currentTrack.title)}" saved to your device.`);
    } catch (error) {
      console.error(error);
      Alert.alert('Download Failed', 'Could not download this song. Please try again.');
    } finally {
      setDownloading(false);
    }
  };

  const handleShare = async () => {
    if (!currentTrack) return;
    try {
      const title = cleanSongTitle(currentTrack.title);
      const artist = cleanSongTitle(currentTrack.artist);
      await Share.share({
        message: `🎵 Listen to "${title}" by ${artist}! Check it out on our Music App!`,
        title: `${title} - ${artist}`,
      });
    } catch (error) {
      console.error('Share error:', error);
    }
  };

  const handleNext = () => {
    if (queue.length > 0 && currentIndex < queue.length - 1) {
      playNext();
    }
  };

  const handlePrevious = () => {
    // If more than 3 seconds in, restart the song instead of going back
    if (position > 3000 && seekTo) {
      seekTo(0);
    } else {
      playPrevious();
    }
  };

  const handleSeekStart = () => {
    setIsSeeking(true);
  };

  const handleSeekComplete = (value: number) => {
    setIsSeeking(false);
    if (seekTo) {
      seekTo(value);
    }
  };

  const openPlaylistModal = async () => {
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
        { track: currentTrack },
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

  const formatTime = (millis: number) => {
    if (!Number.isFinite(millis) || millis < 0) return '0:00';
    const totalSeconds = Math.floor(millis / 1000);
    const m = Math.floor(totalSeconds / 60);
    const s = totalSeconds % 60;
    return `${m}:${s < 10 ? '0' : ''}${s}`;
  };

  if (!currentTrack) return null;

  const canGoNext = queue.length > 0 && currentIndex < queue.length - 1;
  const canGoPrevious = queue.length > 0 && currentIndex > 0;
  const displayTitle = cleanSongTitle(currentTrack.title);
  const displayArtist = cleanSongTitle(currentTrack.artist);
  const rawDuration = typeof currentTrack.duration === 'string' ? parseInt(currentTrack.duration, 10) : currentTrack.duration;
  const fallbackDuration = rawDuration ? (rawDuration < 1000 ? rawDuration * 1000 : rawDuration) : 0;
  const safeDuration = duration || fallbackDuration || 0;

  return (
    <LinearGradient colors={['#2d1b4e', '#1a1a2e', '#121212']} style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <TouchableOpacity onPress={() => navigation.goBack()} style={styles.headerBtn}>
          <Ionicons name="chevron-down" size={28} color="#fff" />
        </TouchableOpacity>
        <View style={styles.headerTitleContainer}>
          <View style={styles.headerLogoContainer}>
            <Ionicons name="musical-notes" size={24} color="#8B5CF6" />
          </View>
          <Text style={styles.headerTitle}>Now Playing</Text>
        </View>
        <TouchableOpacity style={styles.headerBtn} onPress={() => setShowQueueModal(true)}>
          <Ionicons name="list" size={24} color="#fff" />
        </TouchableOpacity>
      </View>


      <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
        {/* Album Art */}
        <View style={styles.artworkContainer}>
          <Image 
            source={{ uri: currentTrack.artwork || 'https://placehold.co/300x300/282828/fff?text=♪' }} 
            style={styles.artwork} 
          />
        </View>

        {/* Song Info */}
        <View style={styles.infoRow}>
          <View style={styles.songInfo}>
            <Text style={styles.songTitle} numberOfLines={2}>{displayTitle}</Text>
            <Text style={styles.songArtist} numberOfLines={1}>{displayArtist}</Text>
          </View>
          <TouchableOpacity onPress={handleLike}>
            <Ionicons name={liked ? "heart" : "heart-outline"} size={28} color={liked ? "#1DB954" : "#b3b3b3"} />
          </TouchableOpacity>
        </View>

        {/* Progress Bar with Slider */}
        <View style={styles.progressContainer}>
          <Slider
            style={styles.slider}
            minimumValue={0}
            maximumValue={safeDuration || 1}
            value={isSeeking ? seekValue : Math.min(position, safeDuration || position)}
            onSlidingStart={handleSeekStart}
            onValueChange={(val) => { if (isSeeking) setSeekValue(val); }}
            onSlidingComplete={handleSeekComplete}
            minimumTrackTintColor="#1DB954"
            maximumTrackTintColor="#555"
            thumbTintColor="#1DB954"
          />
          <View style={styles.timeRow}>
            <Text style={styles.timeText}>{formatTime(isSeeking ? seekValue : position)}</Text>
            <Text style={styles.timeText}>{formatTime(safeDuration)}</Text>
          </View>
        </View>

        {/* Controls */}
        <View style={styles.controls}>
          <TouchableOpacity onPress={() => setShuffle(!shuffle)}>
            <Ionicons name="shuffle" size={24} color={shuffle ? "#1DB954" : "#b3b3b3"} />
          </TouchableOpacity>
          <TouchableOpacity onPress={handlePrevious} disabled={!canGoPrevious && position <= 3000}>
            <Ionicons name="play-skip-back" size={32} color={canGoPrevious || position > 3000 ? "#fff" : "#555"} />
          </TouchableOpacity>
          <TouchableOpacity 
            style={styles.playButton}
            onPress={isPlaying ? pause : resume}
            activeOpacity={0.8}
          >
            <Ionicons name={isPlaying ? "pause" : "play"} size={36} color="#000" />
          </TouchableOpacity>
          <TouchableOpacity onPress={handleNext} disabled={!canGoNext}>
            <Ionicons name="play-skip-forward" size={32} color={canGoNext ? "#fff" : "#555"} />
          </TouchableOpacity>
          <TouchableOpacity onPress={() => setRepeat(!repeat)}>
            <Ionicons name="repeat" size={24} color={repeat ? "#1DB954" : "#b3b3b3"} />
          </TouchableOpacity>
        </View>

        {/* Action Buttons */}
        <View style={styles.actions}>
          <TouchableOpacity style={styles.actionBtn} onPress={handleDownload}>
            <Ionicons 
              name={downloaded ? "checkmark-circle" : downloading ? "cloud-download" : "download-outline"} 
              size={24} color={downloaded ? "#1DB954" : "#b3b3b3"} 
            />
            <Text style={[styles.actionText, downloaded && { color: '#1DB954' }]}>
              {downloaded ? 'Saved' : downloading ? 'Saving...' : 'Download'}
            </Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.actionBtn} onPress={handleShare}>
            <Ionicons name="share-social-outline" size={24} color="#b3b3b3" />
            <Text style={styles.actionText}>Share</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.actionBtn} onPress={openPlaylistModal}>
            <Ionicons name="add-circle-outline" size={24} color="#b3b3b3" />
            <Text style={styles.actionText}>Playlist</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.actionBtn}>
            <Ionicons name="radio-outline" size={24} color="#b3b3b3" />
            <Text style={styles.actionText}>Radio</Text>
          </TouchableOpacity>
        </View>

        {/* Queue Info */}
        {queue.length > 1 && (
          <View style={styles.queueInfo}>
            <Ionicons name="list" size={16} color="#888" />
            <Text style={styles.queueText}>
              {currentIndex + 1} of {queue.length} songs in queue
            </Text>
          </View>
        )}
      </ScrollView>

      {/* Add to Playlist Modal */}
      <Modal visible={showPlaylistModal} transparent animationType="slide" onRequestClose={() => setShowPlaylistModal(false)}>
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <View style={styles.modalHeader}>
              <TouchableOpacity onPress={() => setShowPlaylistModal(false)} style={styles.modalHeaderBtn}>
                <Ionicons name="chevron-down" size={24} color="#fff" />
                <Text style={styles.modalHeaderBtnText}>Close</Text>
              </TouchableOpacity>
              <Text style={styles.modalTitle}>Add to Playlist</Text>
              <TouchableOpacity onPress={() => setShowPlaylistModal(false)} style={styles.modalHeaderBtn}>
                <Text style={styles.modalHeaderBtnText}>Cancel</Text>
              </TouchableOpacity>
            </View>

            <Text style={styles.modalTrackName} numberOfLines={1}>
              {displayTitle} — {displayArtist}
            </Text>

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
                    <Ionicons name="musical-notes" size={20} color="#1DB954" />
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
      {/* Queue Modal */}
      <Modal visible={showQueueModal} transparent animationType="slide" onRequestClose={() => setShowQueueModal(false)}>
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <View style={styles.modalHeader}>
              <TouchableOpacity onPress={() => setShowQueueModal(false)} style={styles.modalHeaderBtn}>
                <Ionicons name="chevron-down" size={24} color="#fff" />
                <Text style={styles.modalHeaderBtnText}>Close</Text>
              </TouchableOpacity>
              <Text style={styles.modalTitle}>Up Next</Text>
              <TouchableOpacity onPress={() => setShowQueueModal(false)} style={styles.modalHeaderBtn}>
                <Text style={styles.modalHeaderBtnText}>Done</Text>
              </TouchableOpacity>
            </View>

            <FlatList
              data={queue}
              keyExtractor={(item, index) => `${item.id}-${index}`}
              style={{ maxHeight: 400 }}
              renderItem={({ item, index }) => (
                <View style={[styles.queueItem, index === currentIndex && styles.activeQueueItem]}>
                  <Image source={{ uri: item.artwork || item.image || 'https://placehold.co/50x50/282828/fff?text=♪' }} style={styles.queueImage} />
                  <View style={styles.queueMeta}>
                    <Text style={[styles.queueTitle, index === currentIndex && { color: '#1DB954' }]} numberOfLines={1}>{item.title || item.name}</Text>
                    <Text style={styles.queueArtist} numberOfLines={1}>{item.artist}</Text>
                  </View>
                  {index !== currentIndex && (
                    <TouchableOpacity onPress={() => removeFromQueue(item.id)} style={styles.removeQueueBtn}>
                      <Ionicons name="remove-circle-outline" size={22} color="#e74c3c" />
                    </TouchableOpacity>
                  )}
                  {index === currentIndex && (
                    <Ionicons name="volume-medium" size={20} color="#1DB954" />
                  )}
                </View>
              )}
            />
          </View>
        </View>
      </Modal>
    </LinearGradient>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  header: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
    paddingTop: 55, paddingHorizontal: 20, paddingBottom: 10,
  },
  headerBtn: { width: 40, alignItems: 'center' },
  headerTitleContainer: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  headerLogoContainer: {
    marginRight: 2,
    backgroundColor: 'rgba(139, 92, 246, 0.1)',
    padding: 4,
    borderRadius: 8,
  },
  headerTitle: { color: '#ccc', fontSize: 13, fontWeight: '600', letterSpacing: 1, textTransform: 'uppercase' },
  content: { alignItems: 'center', paddingHorizontal: 30, paddingBottom: 40 },
  artworkContainer: {
    width: width - 60, height: width - 60, borderRadius: 16,
    overflow: 'hidden', elevation: 20,
    shadowColor: '#000', shadowOffset: { width: 0, height: 10 },
    shadowOpacity: 0.5, shadowRadius: 20,
    marginBottom: 30, marginTop: 10,
  },
  artwork: { width: '100%', height: '100%', backgroundColor: '#282828' },
  infoRow: {
    flexDirection: 'row', alignItems: 'center', width: '100%',
    justifyContent: 'space-between', marginBottom: 20,
  },
  songInfo: { flex: 1, marginRight: 15 },
  songTitle: { color: '#fff', fontSize: 22, fontWeight: 'bold' },
  songArtist: { color: '#b3b3b3', fontSize: 16, marginTop: 4 },
  progressContainer: { width: '100%', marginBottom: 10 },
  slider: { width: '100%', height: 40 },
  timeRow: { flexDirection: 'row', justifyContent: 'space-between', marginTop: -5 },
  timeText: { color: '#b3b3b3', fontSize: 12 },
  controls: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
    width: '100%', marginBottom: 30,
  },
  playButton: {
    width: 66, height: 66, borderRadius: 33,
    backgroundColor: '#fff', alignItems: 'center', justifyContent: 'center',
  },
  actions: {
    flexDirection: 'row', justifyContent: 'space-around', width: '100%', marginBottom: 20,
  },
  actionBtn: { alignItems: 'center', gap: 6 },
  actionText: { color: '#b3b3b3', fontSize: 11 },
  queueInfo: {
    flexDirection: 'row', alignItems: 'center', gap: 6,
    marginBottom: 40, opacity: 0.6,
  },
  queueText: { color: '#888', fontSize: 12 },
  // Modal styles
  modalOverlay: { flex: 1, backgroundColor: 'rgba(0,0,0,0.85)', justifyContent: 'flex-end' },
  modalContent: {
    backgroundColor: '#1e1e1e', borderTopLeftRadius: 25, borderTopRightRadius: 25,
    padding: 20, maxHeight: '70%',
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
  // Queue styles
  queueItem: { flexDirection: 'row', alignItems: 'center', paddingVertical: 10, gap: 12, borderBottomWidth: 0.5, borderBottomColor: '#222' },
  activeQueueItem: { backgroundColor: 'rgba(29, 185, 84, 0.05)' },
  queueImage: { width: 45, height: 45, borderRadius: 6 },
  queueMeta: { flex: 1 },
  queueTitle: { color: '#fff', fontSize: 14, fontWeight: '500' },
  queueArtist: { color: '#888', fontSize: 12, marginTop: 2 },
  removeQueueBtn: { padding: 5 },
});

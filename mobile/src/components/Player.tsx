import React, { useState, useEffect, useRef } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Image } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Audio } from 'expo-av';
import { usePlayerStore } from '../store/usePlayerStore';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { cleanSongTitle } from '../utils/textUtils';

interface PlayerProps {
  onPress?: () => void;
}

export default function Player({ onPress }: PlayerProps) {
  const { 
    currentTrack, isPlaying, audioUrl, 
    pause, resume, setPosition, setDuration, 
    playNext, _seekRequested,
    position, duration
  } = usePlayerStore();
  const [liked, setLiked] = useState(false);
  const soundRef = useRef<Audio.Sound | null>(null);
  const currentUrlRef = useRef<string | null>(null);
  const loadingRef = useRef(false);
  const mountedRef = useRef(true);

  // Set audio mode once on mount
  useEffect(() => {
    mountedRef.current = true;
    Audio.setAudioModeAsync({
      playsInSilentModeIOS: true,
      staysActiveInBackground: true,
      shouldDuckAndroid: true,
    }).catch(() => {});

    return () => {
      mountedRef.current = false;
      if (soundRef.current) {
        soundRef.current.unloadAsync().catch(() => {});
        soundRef.current = null;
      }
    };
  }, []);

  // Handle audio URL changes - core playback logic
  useEffect(() => {
    if (!audioUrl) return;
    if (currentUrlRef.current === audioUrl) return;

    const loadAndPlay = async () => {
      // Prevent concurrent loads
      if (loadingRef.current) {
        // If already loading, wait for it to finish then try again
        return;
      }
      loadingRef.current = true;

      try {
        // ALWAYS unload previous sound first to prevent double play
        if (soundRef.current) {
          try {
            await soundRef.current.stopAsync();
            await soundRef.current.unloadAsync();
          } catch {}
          soundRef.current = null;
        }

        // Check if this URL is still current (may have changed during unload)
        if (!mountedRef.current) return;
        
        currentUrlRef.current = audioUrl;

        const { sound } = await Audio.Sound.createAsync(
          { uri: audioUrl },
          { shouldPlay: true, progressUpdateIntervalMillis: 500 },
          (status: any) => {
            if (!mountedRef.current) return;
            if (status.isLoaded) {
              setPosition(status.positionMillis || 0);
              if (status.durationMillis) setDuration(status.durationMillis);
              if (status.didJustFinish) {
                playNext();
              }
            }
          }
        );

        // Verify URL hasn't changed during async load
        if (currentUrlRef.current !== audioUrl || !mountedRef.current) {
          await sound.unloadAsync().catch(() => {});
          return;
        }

        soundRef.current = sound;
      } catch (err) {
        console.log('Audio load error:', err);
      } finally {
        loadingRef.current = false;
      }
    };

    loadAndPlay();
  }, [audioUrl]);

  // Handle seek requests
  useEffect(() => {
    if (_seekRequested !== null && soundRef.current) {
      soundRef.current.setPositionAsync(_seekRequested).catch(() => {});
      usePlayerStore.setState({ _seekRequested: null });
    }
  }, [_seekRequested]);

  // Sync play/pause
  useEffect(() => {
    if (!soundRef.current) return;
    if (isPlaying) {
      soundRef.current.playAsync().catch(() => {});
    } else {
      soundRef.current.pauseAsync().catch(() => {});
    }
  }, [isPlaying]);

  const handlePlayPause = () => {
    if (isPlaying) pause();
    else resume();
  };

  const handleLike = async () => {
    if (!currentTrack) return;
    try {
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
    } catch (error) {
      console.error('Like error:', error);
    }
  };

  // Check liked state when track changes
  useEffect(() => {
    const checkLiked = async () => {
      if (!currentTrack) return;
      try {
        const data = await AsyncStorage.getItem('likedSongs');
        const likedSongs = data ? JSON.parse(data) : [];
        setLiked(likedSongs.some((s: any) => s.id === currentTrack.id));
      } catch {}
    };
    checkLiked();
  }, [currentTrack?.id]);

  if (!currentTrack) return null;

  const displayTitle = cleanSongTitle(currentTrack.title);
  const displayArtist = cleanSongTitle(currentTrack.artist);
  const progressPercent = duration > 0 ? (position / duration) * 100 : 0;

  return (
    <TouchableOpacity style={styles.container} onPress={onPress} activeOpacity={0.9}>
      <View style={styles.progressBarBg}>
        <View style={[styles.progressBarFill, { width: `${progressPercent}%` }]} />
      </View>
      <View style={styles.content}>
        <Image 
          source={{ uri: currentTrack.artwork || 'https://placehold.co/45x45/282828/fff?text=♪' }} 
          style={styles.artwork} 
        />
        <View style={styles.info}>
          <Text style={styles.title} numberOfLines={1}>{displayTitle}</Text>
          <Text style={styles.artist} numberOfLines={1}>{displayArtist}</Text>
        </View>
        <View style={styles.controls}>
          <TouchableOpacity style={styles.button} onPress={handleLike}>
            <Ionicons name={liked ? "heart" : "heart-outline"} size={22} color={liked ? "#1DB954" : "#b3b3b3"} />
          </TouchableOpacity>
          <TouchableOpacity style={styles.playButton} onPress={handlePlayPause} activeOpacity={0.7}>
            <Ionicons name={isPlaying ? "pause" : "play"} size={24} color="#000" />
          </TouchableOpacity>
        </View>
      </View>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  container: {
    position: 'absolute', bottom: 60, left: 8, right: 8,
    backgroundColor: '#282828', borderRadius: 10, overflow: 'hidden',
    elevation: 10, shadowColor: '#000', shadowOffset: { width: 0, height: -2 },
    shadowOpacity: 0.3, shadowRadius: 8,
  },
  progressBarBg: { height: 2, backgroundColor: '#444' },
  progressBarFill: { height: '100%', backgroundColor: '#1DB954' },
  content: {
    flexDirection: 'row', alignItems: 'center', paddingHorizontal: 12, paddingVertical: 10,
  },
  artwork: { width: 46, height: 46, borderRadius: 6, backgroundColor: '#121212' },
  info: { flex: 1, marginLeft: 12, marginRight: 8 },
  title: { color: '#fff', fontSize: 14, fontWeight: '600' },
  artist: { color: '#b3b3b3', fontSize: 12, marginTop: 2 },
  controls: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  button: { padding: 4 },
  playButton: {
    backgroundColor: '#1DB954', width: 36, height: 36, borderRadius: 18,
    alignItems: 'center', justifyContent: 'center',
  },
});

import React, { useEffect, useRef, useState } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Image } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import AsyncStorage from '@react-native-async-storage/async-storage';
import TrackPlayer from 'react-native-track-player';
import { cleanSongTitle } from '../utils/textUtils';
import { usePlayerStore } from '../store/usePlayerStore';
import { loadQueueAndPlay, seekToMillis } from '../services/trackPlayerService';

interface PlayerProps {
  onPress?: () => void;
}

export default function Player({ onPress }: PlayerProps) {
  const {
    currentTrack, isPlaying, position, duration, queue, currentIndex, _seekRequested,
    pause, resume, clearSleepTimer, sleepTimerMinutes,
  } = usePlayerStore();
  const [liked, setLiked] = useState(false);
  const sleepTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const queueSignatureRef = useRef<string>('');
  const currentIndexRef = useRef<number>(-1);
  const stallCheckRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const lastProgressRef = useRef<{ position: number; at: number }>({ position: 0, at: Date.now() });

  useEffect(() => {
    if (!currentTrack || !queue.length) return;
    const signature = queue.map((item) => String(item.id || '')).join('|');
    const nextIndex = Math.max(0, currentIndex);

    if (queueSignatureRef.current !== signature) {
      queueSignatureRef.current = signature;
      currentIndexRef.current = nextIndex;
      loadQueueAndPlay(queue, nextIndex).catch(() => {});
      return;
    }

    if (currentIndexRef.current !== nextIndex) {
      currentIndexRef.current = nextIndex;
      TrackPlayer.skip(nextIndex).catch(() => {});
    }
  }, [queue, currentIndex, currentTrack?.id]);

  useEffect(() => {
    if (_seekRequested === null) return;
    seekToMillis(_seekRequested).catch(() => {});
    usePlayerStore.setState({ _seekRequested: null });
  }, [_seekRequested]);

  useEffect(() => {
    if (!currentTrack) return;
    const now = Date.now();
    if (position > lastProgressRef.current.position + 300) {
      lastProgressRef.current = { position, at: now };
    }
  }, [position, currentTrack?.id]);

  useEffect(() => {
    if (stallCheckRef.current) {
      clearInterval(stallCheckRef.current);
      stallCheckRef.current = null;
    }
    if (!isPlaying || !currentTrack) return;

    stallCheckRef.current = setInterval(async () => {
      const now = Date.now();
      const stalledForMs = now - lastProgressRef.current.at;
      if (stalledForMs < 8000) return;
      try {
        const currentSec = await TrackPlayer.getPosition();
        await TrackPlayer.seekTo(Math.max(0, currentSec));
        await TrackPlayer.play();
        lastProgressRef.current = { position: Math.floor(currentSec * 1000), at: Date.now() };
      } catch {}
    }, 4000);

    return () => {
      if (stallCheckRef.current) {
        clearInterval(stallCheckRef.current);
        stallCheckRef.current = null;
      }
    };
  }, [isPlaying, currentTrack?.id]);

  useEffect(() => {
    if (sleepTimeoutRef.current) {
      clearTimeout(sleepTimeoutRef.current);
      sleepTimeoutRef.current = null;
    }
    if (!sleepTimerMinutes || sleepTimerMinutes <= 0 || !isPlaying) return;
    sleepTimeoutRef.current = setTimeout(() => {
      pause();
      clearSleepTimer();
    }, sleepTimerMinutes * 60 * 1000);
  }, [sleepTimerMinutes, isPlaying, pause, clearSleepTimer]);

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
    } catch {}
  };

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
          source={{ uri: currentTrack.artwork || 'https://placehold.co/45x45/282828/fff?text=?' }}
          style={styles.artwork}
        />
        <View style={styles.info}>
          <Text style={styles.title} numberOfLines={1}>{displayTitle}</Text>
          <Text style={styles.artist} numberOfLines={1}>{displayArtist}</Text>
        </View>
        <View style={styles.controls}>
          <TouchableOpacity style={styles.button} onPress={handleLike}>
            <Ionicons name={liked ? 'heart' : 'heart-outline'} size={22} color={liked ? '#1DB954' : '#b3b3b3'} />
          </TouchableOpacity>
          <TouchableOpacity style={styles.playButton} onPress={isPlaying ? pause : resume} activeOpacity={0.7}>
            <Ionicons name={isPlaying ? 'pause' : 'play'} size={24} color="#000" />
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
  content: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 12, paddingVertical: 10 },
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

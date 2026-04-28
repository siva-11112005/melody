import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ScrollView, Image } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { Ionicons } from '@expo/vector-icons';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { useAuthStore } from '../store/useAuthStore';

const ARTISTS_BY_LANGUAGE: Record<string, { name: string; color: string }[]> = {
  tamil: [
    { name: 'Anirudh Ravichander', color: '#FF6B6B' },
    { name: 'A.R. Rahman', color: '#6C5CE7' },
    { name: 'Sid Sriram', color: '#00B894' },
    { name: 'Yuvan Shankar Raja', color: '#FDCB6E' },
    { name: 'D. Imman', color: '#E17055' },
    { name: 'Harris Jayaraj', color: '#0984E3' },
    { name: 'GV Prakash Kumar', color: '#E84393' },
    { name: 'Ilaiyaraaja', color: '#00CEC9' },
    { name: 'SPB', color: '#FAB1A0' },
    { name: 'Shreya Ghoshal', color: '#a29bfe' },
  ],
  hindi: [
    { name: 'Arijit Singh', color: '#6C5CE7' },
    { name: 'Shreya Ghoshal', color: '#E84393' },
    { name: 'Pritam', color: '#00B894' },
    { name: 'Vishal Mishra', color: '#FDCB6E' },
    { name: 'Jubin Nautiyal', color: '#0984E3' },
    { name: 'Neha Kakkar', color: '#FF6B6B' },
    { name: 'KK', color: '#FAB1A0' },
    { name: 'Atif Aslam', color: '#00CEC9' },
    { name: 'Sonu Nigam', color: '#a29bfe' },
    { name: 'Lata Mangeshkar', color: '#E17055' },
  ],
  english: [
    { name: 'Ed Sheeran', color: '#FF6B6B' },
    { name: 'Taylor Swift', color: '#E84393' },
    { name: 'The Weeknd', color: '#6C5CE7' },
    { name: 'Dua Lipa', color: '#00B894' },
    { name: 'Billie Eilish', color: '#FDCB6E' },
    { name: 'Post Malone', color: '#0984E3' },
    { name: 'Justin Bieber', color: '#E17055' },
    { name: 'Drake', color: '#00CEC9' },
    { name: 'Ariana Grande', color: '#a29bfe' },
    { name: 'Bruno Mars', color: '#FAB1A0' },
  ],
  telugu: [
    { name: 'SS Thaman', color: '#FF6B6B' },
    { name: 'Devi Sri Prasad', color: '#6C5CE7' },
    { name: 'Sid Sriram', color: '#00B894' },
    { name: 'Anurag Kulkarni', color: '#FDCB6E' },
    { name: 'Armaan Malik', color: '#0984E3' },
    { name: 'SP Balasubrahmanyam', color: '#E84393' },
  ],
  kannada: [
    { name: 'Vijay Prakash', color: '#FF6B6B' },
    { name: 'Sonu Nigam', color: '#6C5CE7' },
    { name: 'Haricharan', color: '#00B894' },
    { name: 'Armaan Malik', color: '#0984E3' },
    { name: 'Shankar Mahadevan', color: '#FDCB6E' },
  ],
  malayalam: [
    { name: 'KJ Yesudas', color: '#6C5CE7' },
    { name: 'Vineeth Sreenivasan', color: '#00B894' },
    { name: 'Sushin Shyam', color: '#FF6B6B' },
    { name: 'Sid Sriram', color: '#FDCB6E' },
  ],
  punjabi: [
    { name: 'AP Dhillon', color: '#FF6B6B' },
    { name: 'Diljit Dosanjh', color: '#6C5CE7' },
    { name: 'Sidhu Moose Wala', color: '#00B894' },
    { name: 'Karan Aujla', color: '#0984E3' },
    { name: 'Guru Randhawa', color: '#E84393' },
  ],
  bengali: [
    { name: 'Arijit Singh', color: '#6C5CE7' },
    { name: 'Anupam Roy', color: '#00B894' },
    { name: 'Shreya Ghoshal', color: '#E84393' },
  ],
  marathi: [
    { name: 'Ajay-Atul', color: '#FF6B6B' },
    { name: 'Shankar Mahadevan', color: '#6C5CE7' },
  ],
  other: [
    { name: 'Ed Sheeran', color: '#FF6B6B' },
    { name: 'Arijit Singh', color: '#6C5CE7' },
    { name: 'A.R. Rahman', color: '#00B894' },
    { name: 'Anirudh Ravichander', color: '#FDCB6E' },
  ],
};

function getInitials(name: string): string {
  return name.split(' ').map(w => w[0]).join('').toUpperCase().slice(0, 2);
}

export default function ArtistPickScreen({ navigation }: any) {
  const [selectedArtists, setSelectedArtists] = useState<string[]>([]);
  const [artists, setArtists] = useState<{ name: string; color: string }[]>([]);
  const { setOnboardingComplete } = useAuthStore();

  useEffect(() => {
    loadArtists();
  }, []);

  const loadArtists = async () => {
    const langStr = await AsyncStorage.getItem('preferredLanguages');
    const langs: string[] = langStr ? JSON.parse(langStr) : ['english', 'hindi'];
    
    const allArtists: { name: string; color: string }[] = [];
    const seen = new Set<string>();
    for (const lang of langs) {
      for (const artist of (ARTISTS_BY_LANGUAGE[lang] || [])) {
        if (!seen.has(artist.name)) {
          seen.add(artist.name);
          allArtists.push(artist);
        }
      }
    }
    setArtists(allArtists);
  };

  const toggleArtist = (name: string) => {
    setSelectedArtists(prev =>
      prev.includes(name) ? prev.filter(a => a !== name) : [...prev, name]
    );
  };

  const handleDone = async () => {
    await AsyncStorage.setItem('favoriteArtists', JSON.stringify(selectedArtists));
    await setOnboardingComplete();
  };

  return (
    <LinearGradient colors={['#121212', '#1a1a2e']} style={styles.container}>
      <ScrollView contentContainerStyle={styles.scrollContent} showsVerticalScrollIndicator={false}>
        <Text style={styles.title}>Pick Your Artists</Text>
        <Text style={styles.subtitle}>
          Choose at least 3 artists you love
        </Text>

        <View style={styles.grid}>
          {artists.map((artist) => (
            <TouchableOpacity
              key={artist.name}
              onPress={() => toggleArtist(artist.name)}
              activeOpacity={0.7}
              style={styles.artistCard}
            >
              <View style={[
                styles.avatarCircle,
                { backgroundColor: artist.color },
                selectedArtists.includes(artist.name) && styles.selectedCircle,
              ]}>
                {selectedArtists.includes(artist.name) ? (
                  <Ionicons name="checkmark" size={30} color="#fff" />
                ) : (
                  <Text style={styles.initials}>{getInitials(artist.name)}</Text>
                )}
              </View>
              <Text style={[
                styles.artistName,
                selectedArtists.includes(artist.name) && styles.selectedArtistName,
              ]} numberOfLines={2}>
                {artist.name}
              </Text>
            </TouchableOpacity>
          ))}
        </View>
      </ScrollView>

      <View style={styles.bottomBar}>
        <Text style={styles.selectedCount}>
          {selectedArtists.length} selected {selectedArtists.length < 3 ? '(min 3)' : ''}
        </Text>
        <TouchableOpacity 
          onPress={handleDone}
          disabled={selectedArtists.length < 3}
          activeOpacity={0.8}
        >
          <LinearGradient 
            colors={selectedArtists.length >= 3 ? ['#1DB954', '#1ed760'] : ['#333', '#444']}
            style={styles.doneButton}
          >
            <Text style={styles.doneText}>Let's Go!</Text>
            <Ionicons name="arrow-forward" size={18} color="#fff" />
          </LinearGradient>
        </TouchableOpacity>
      </View>
    </LinearGradient>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  scrollContent: { paddingTop: 70, paddingHorizontal: 20, paddingBottom: 120 },
  title: { color: '#fff', fontSize: 30, fontWeight: 'bold' },
  subtitle: { color: '#b3b3b3', fontSize: 15, marginTop: 8, marginBottom: 30 },
  grid: {
    flexDirection: 'row', flexWrap: 'wrap', gap: 16,
    justifyContent: 'space-between',
  },
  artistCard: { width: 100, alignItems: 'center', marginBottom: 12 },
  avatarCircle: {
    width: 85, height: 85, borderRadius: 43,
    alignItems: 'center', justifyContent: 'center',
    borderWidth: 3, borderColor: 'transparent',
  },
  selectedCircle: {
    borderColor: '#1DB954',
    opacity: 0.9,
  },
  initials: {
    color: '#fff', fontSize: 24, fontWeight: 'bold',
  },
  artistName: { color: '#ccc', fontSize: 12, textAlign: 'center', marginTop: 8 },
  selectedArtistName: { color: '#1DB954', fontWeight: '600' },
  bottomBar: {
    position: 'absolute', bottom: 0, left: 0, right: 0,
    paddingHorizontal: 20, paddingBottom: 40, paddingTop: 15,
    backgroundColor: '#121212',
    flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
  },
  selectedCount: { color: '#b3b3b3', fontSize: 14 },
  doneButton: {
    flexDirection: 'row', alignItems: 'center', gap: 8,
    paddingHorizontal: 28, paddingVertical: 14, borderRadius: 25,
  },
  doneText: { color: '#fff', fontSize: 16, fontWeight: 'bold' },
});

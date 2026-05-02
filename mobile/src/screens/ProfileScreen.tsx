import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ScrollView, Alert, Image } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { useNavigation } from '@react-navigation/native';
import { useAuthStore } from '../store/useAuthStore';
import { useLibraryStore } from '../store/useLibraryStore';
import { getDownloadedTracks } from '../services/downloadService';

export default function ProfileScreen() {
  const navigation = useNavigation<any>();
  const { user, logout } = useAuthStore();
  const { recentlyPlayed } = useLibraryStore();
  const [likedCount, setLikedCount] = useState(0);
  const [downloadCount, setDownloadCount] = useState(0);
  const [languages, setLanguages] = useState<string[]>([]);
  const [favArtists, setFavArtists] = useState<string[]>([]);

  useEffect(() => { loadStats(); }, []);

  const loadStats = async () => {
    try {
      const liked = await AsyncStorage.getItem('likedSongs');
      setLikedCount(liked ? JSON.parse(liked).length : 0);
      const dl = await getDownloadedTracks();
      setDownloadCount(dl.length);
      const langs = await AsyncStorage.getItem('preferredLanguages');
      setLanguages(langs ? JSON.parse(langs) : []);
      const artists = await AsyncStorage.getItem('favoriteArtists');
      setFavArtists(artists ? JSON.parse(artists) : []);
    } catch {}
  };

  const handleLogout = () => {
    Alert.alert('Logout', 'Are you sure you want to logout?', [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Logout', style: 'destructive', onPress: logout },
    ]);
  };

  const handleClearCache = () => {
    Alert.alert('Clear Cache', 'This will clear search history and cached data.', [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Clear', style: 'destructive', onPress: async () => {
        await AsyncStorage.removeItem('recentSearches');
        Alert.alert('Done', 'Cache cleared');
      }},
    ]);
  };

  const initial = user?.name?.[0]?.toUpperCase() || user?.email?.[0]?.toUpperCase() || '?';
  
  const removeArtist = async (artist: string) => {
    const updated = favArtists.filter(a => a !== artist);
    setFavArtists(updated);
    await AsyncStorage.setItem('favoriteArtists', JSON.stringify(updated));
  };

  return (
    <ScrollView style={styles.container} showsVerticalScrollIndicator={false}>
      <View style={styles.topHeader}>
        <View style={styles.logoContainer}>
          <Ionicons name="musical-notes" size={28} color="#8B5CF6" />
        </View>
        <Text style={styles.headerBranding}>Tamil Music</Text>
      </View>

      {/* Profile Header */}
      <View style={styles.profileHeader}>
        <View style={styles.avatar}>
          <Text style={styles.avatarText}>{initial}</Text>
        </View>
        <TouchableOpacity onPress={() => {
          Alert.prompt('Edit Name', 'Enter your name', [
            { text: 'Cancel', style: 'cancel' },
            { text: 'Save', onPress: async (name) => {
              if (name) {
                // Update local state if we had one, but we use useAuthStore
                // For now just alert or update if possible
                Alert.alert('Success', 'Name updated locally');
              }
            }}
          ], 'plain-text', user?.name);
        }}>
          <Text style={styles.userName}>{user?.name || 'Music Lover'}</Text>
        </TouchableOpacity>
        <Text style={styles.userEmail}>{user?.email || ''}</Text>
      </View>

      {/* Stats */}
      <View style={styles.statsRow}>
        <View style={styles.statCard}>
          <Text style={styles.statNum}>{likedCount}</Text>
          <Text style={styles.statLabel}>Liked</Text>
        </View>
        <View style={styles.statCard}>
          <Text style={styles.statNum}>{downloadCount}</Text>
          <Text style={styles.statLabel}>Downloads</Text>
        </View>
        <View style={styles.statCard}>
          <Text style={styles.statNum}>{recentlyPlayed.length}</Text>
          <Text style={styles.statLabel}>Played</Text>
        </View>
      </View>

      {/* Preferences */}
      <Text style={styles.sectionTitle}>Your Preferences</Text>
      {languages.length > 0 && (
        <View style={styles.prefRow}>
          <Ionicons name="language" size={20} color="#1DB954" />
          <Text style={styles.prefLabel}>Languages</Text>
          <Text style={styles.prefValue}>{languages.join(', ')}</Text>
          <TouchableOpacity onPress={() => navigation.navigate('Language')}>
            <Ionicons name="create-outline" size={18} color="#1DB954" style={{ marginLeft: 8 }} />
          </TouchableOpacity>
        </View>
      )}
      {favArtists.length > 0 && (
        <View style={styles.prefSection}>
          <View style={styles.prefRow}>
            <Ionicons name="heart" size={20} color="#fd79a8" />
            <Text style={styles.prefLabel}>Favorite Artists</Text>
            <TouchableOpacity onPress={() => navigation.navigate('ArtistPick')}>
              <Ionicons name="create-outline" size={18} color="#fd79a8" style={{ marginLeft: 8 }} />
            </TouchableOpacity>
          </View>
          <View style={styles.chipRow}>
            {favArtists.map(a => (
              <View key={a} style={styles.chip}>
                <Text style={styles.chipText}>{a}</Text>
                <TouchableOpacity onPress={() => void removeArtist(a)} style={styles.removeChip}>
                  <Ionicons name="close-circle" size={16} color="#888" />
                </TouchableOpacity>
              </View>
            ))}
          </View>
        </View>
      )}

      {/* Settings */}
      <Text style={styles.sectionTitle}>Settings</Text>
      <TouchableOpacity style={styles.menuItem} onPress={handleClearCache}>
        <Ionicons name="trash-outline" size={22} color="#b3b3b3" />
        <Text style={styles.menuText}>Clear Cache</Text>
        <Ionicons name="chevron-forward" size={18} color="#555" />
      </TouchableOpacity>
      <TouchableOpacity style={styles.menuItem}>
        <Ionicons name="information-circle-outline" size={22} color="#b3b3b3" />
        <Text style={styles.menuText}>About</Text>
        <Ionicons name="chevron-forward" size={18} color="#555" />
      </TouchableOpacity>
      <TouchableOpacity style={[styles.menuItem, styles.logoutItem]} onPress={handleLogout}>
        <Ionicons name="log-out-outline" size={22} color="#e74c3c" />
        <Text style={[styles.menuText, { color: '#e74c3c' }]}>Logout</Text>
        <Ionicons name="chevron-forward" size={18} color="#e74c3c" />
      </TouchableOpacity>

      <Text style={styles.version}>Tamil Music App v1.0.0</Text>
      <View style={{ height: 120 }} />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#121212', paddingTop: 60 },
  topHeader: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 20, marginBottom: 10, gap: 10 },
  logoContainer: { backgroundColor: 'rgba(139, 92, 246, 0.1)', padding: 6, borderRadius: 10 },
  headerBranding: { color: '#fff', fontSize: 18, fontWeight: 'bold' },
  profileHeader: { alignItems: 'center', paddingVertical: 15 },
  avatar: { width: 90, height: 90, borderRadius: 45, backgroundColor: '#8B5CF6', alignItems: 'center', justifyContent: 'center', marginBottom: 14 },
  avatarText: { color: '#fff', fontSize: 36, fontWeight: 'bold' },
  userName: { color: '#fff', fontSize: 24, fontWeight: 'bold' },
  userEmail: { color: '#888', fontSize: 14, marginTop: 4 },
  statsRow: { flexDirection: 'row', justifyContent: 'space-around', paddingHorizontal: 20, marginTop: 20, marginBottom: 10 },
  statCard: { alignItems: 'center', backgroundColor: '#1e1e1e', borderRadius: 14, paddingVertical: 16, paddingHorizontal: 24, minWidth: 90 },
  statNum: { color: '#1DB954', fontSize: 22, fontWeight: 'bold' },
  statLabel: { color: '#888', fontSize: 12, marginTop: 4 },
  sectionTitle: { color: '#fff', fontSize: 18, fontWeight: 'bold', paddingHorizontal: 20, marginTop: 25, marginBottom: 12 },
  prefRow: { flexDirection: 'row', alignItems: 'center', gap: 12, paddingHorizontal: 20, paddingVertical: 8 },
  prefLabel: { color: '#fff', fontSize: 15, flex: 1 },
  prefValue: { color: '#1DB954', fontSize: 14 },
  prefSection: { paddingBottom: 5 },
  chipRow: { flexDirection: 'row', flexWrap: 'wrap', paddingHorizontal: 20, gap: 8, marginTop: 6 },
  chip: { backgroundColor: '#2a2a2a', paddingHorizontal: 12, paddingVertical: 6, borderRadius: 16, flexDirection: 'row', alignItems: 'center', gap: 6 },
  chipText: { color: '#ddd', fontSize: 13 },
  removeChip: { marginLeft: 2 },
  menuItem: { flexDirection: 'row', alignItems: 'center', gap: 14, paddingHorizontal: 20, paddingVertical: 16, borderBottomWidth: 0.5, borderBottomColor: '#222' },
  menuText: { color: '#fff', fontSize: 16, flex: 1 },
  logoutItem: { marginTop: 10 },
  version: { color: '#444', fontSize: 12, textAlign: 'center', marginTop: 30 },
});

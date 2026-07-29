import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ScrollView, Alert, Modal, TextInput } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { useNavigation } from '@react-navigation/native';
import { useAuthStore } from '../store/useAuthStore';
import { useLibraryStore } from '../store/useLibraryStore';
import { getDownloadedTracks } from '../services/downloadService';
import { usePlayerStore } from '../store/usePlayerStore';

export default function ProfileScreen() {
  const navigation = useNavigation<any>();
  const { user, token, logout, setAuth } = useAuthStore();
  const { recentlyPlayed } = useLibraryStore();
  const [likedCount, setLikedCount] = useState(0);
  const [downloadCount, setDownloadCount] = useState(0);
  const [languages, setLanguages] = useState<string[]>([]);
  const [favArtists, setFavArtists] = useState<string[]>([]);
  const [showEditNameModal, setShowEditNameModal] = useState(false);
  const [editingName, setEditingName] = useState('');
  const [showAutoOffModal, setShowAutoOffModal] = useState(false);
  const [autoOffInput, setAutoOffInput] = useState('');
  const { sleepTimerMinutes, setSleepTimer, clearSleepTimer, autoPlayNextEnabled, setAutoPlayNextEnabled } = usePlayerStore();

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
      const autoOff = await AsyncStorage.getItem('autoOffMinutes');
      if (autoOff) {
        const mins = parseInt(autoOff, 10);
        if (!Number.isNaN(mins) && mins > 0) setSleepTimer(mins);
      }
      const autoNext = await AsyncStorage.getItem('autoPlayNextEnabled');
      if (autoNext !== null) setAutoPlayNextEnabled(autoNext === 'true');
    } catch {}
  };

  const setAutoOffMinutes = async (minutes: number | null) => {
    try {
      if (!minutes) {
        await AsyncStorage.removeItem('autoOffMinutes');
        clearSleepTimer();
        Alert.alert('Auto Off', 'Auto Off is turned off');
        return;
      }
      await AsyncStorage.setItem('autoOffMinutes', String(minutes));
      setSleepTimer(minutes);
      Alert.alert('Auto Off', `Music will stop after ${minutes} minutes`);
    } catch {
      Alert.alert('Error', 'Could not update auto off setting');
    }
  };

  const saveCustomAutoOff = async () => {
    const minutes = parseInt(autoOffInput.trim(), 10);
    if (Number.isNaN(minutes) || minutes <= 0) {
      Alert.alert('Invalid time', 'Enter minutes only (example: 10)');
      return;
    }
    await setAutoOffMinutes(minutes);
    setShowAutoOffModal(false);
  };

  const toggleAutoPlayNext = async () => {
    try {
      const nextValue = !autoPlayNextEnabled;
      await AsyncStorage.setItem('autoPlayNextEnabled', String(nextValue));
      setAutoPlayNextEnabled(nextValue);
    } catch {
      Alert.alert('Error', 'Could not update autoplay setting');
    }
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

  const openEditNameModal = () => {
    setEditingName(user?.name || '');
    setShowEditNameModal(true);
  };

  const saveEditedName = async () => {
    const nextName = editingName.trim();
    if (!nextName) {
      Alert.alert('Error', 'Name cannot be empty');
      return;
    }

    try {
      if (token && user) {
        await setAuth(token, { ...user, name: nextName });
      } else if (user) {
        await AsyncStorage.setItem('user', JSON.stringify({ ...user, name: nextName }));
      }
      setShowEditNameModal(false);
      Alert.alert('Success', 'Name updated');
    } catch {
      Alert.alert('Error', 'Could not update name');
    }
  };
  
  return (
    <ScrollView style={styles.container} showsVerticalScrollIndicator={false}>
      {/* Branding Header */}
      <View style={styles.topBranding}>
        <View style={styles.logoContainer}>
          <Ionicons name="musical-notes" size={24} color="#1DB954" />
        </View>
        <Text style={styles.brandTitle}>Tamil Music</Text>
      </View>

      {/* Profile Header */}
      <View style={styles.profileHeader}>
        <View style={styles.avatar}>
          <Text style={styles.avatarText}>{initial}</Text>
        </View>
        <Text style={styles.userName}>{user?.name || 'Music Lover'}</Text>
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
          <Text style={styles.prefLabel}>Languages</Text>
          <Text style={styles.prefValue}>{languages.join(', ')}</Text>
          <TouchableOpacity onPress={() => navigation.navigate('LanguageSelect')}>
            <Ionicons name="create-outline" size={18} color="#1DB954" style={{ marginLeft: 8 }} />
          </TouchableOpacity>
        </View>
      )}
      {favArtists.length > 0 && (
        <View style={styles.prefSection}>
          <View style={styles.prefRow}>
            <Text style={styles.prefLabel}>Favorite Artists</Text>
            <TouchableOpacity onPress={() => navigation.navigate('ArtistPick')}>
              <Ionicons name="create-outline" size={18} color="#fd79a8" style={{ marginLeft: 8 }} />
            </TouchableOpacity>
          </View>
          <View style={styles.chipRow}>
            {favArtists.map(a => (
              <View key={a} style={styles.chip}>
                <Text style={styles.chipText}>{a}</Text>
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
      <TouchableOpacity style={styles.menuItem} onPress={() => {
        setAutoOffInput(sleepTimerMinutes ? String(sleepTimerMinutes) : '');
        setShowAutoOffModal(true);
      }}>
        <Ionicons name="moon-outline" size={22} color="#b3b3b3" />
        <Text style={styles.menuText}>
          {sleepTimerMinutes ? `Auto Off: ${sleepTimerMinutes} min` : 'Auto Off (Custom Time)'}
        </Text>
        <Ionicons name="chevron-forward" size={18} color="#555" />
      </TouchableOpacity>
      <TouchableOpacity style={styles.menuItem} onPress={() => setAutoOffMinutes(null)}>
        <Ionicons name="moon" size={22} color={sleepTimerMinutes ? "#1DB954" : "#b3b3b3"} />
        <Text style={styles.menuText}>
          {sleepTimerMinutes ? 'Turn Off Auto Off' : 'Auto Off is Off'}
        </Text>
        <Ionicons name="chevron-forward" size={18} color="#555" />
      </TouchableOpacity>
      <TouchableOpacity style={styles.menuItem} onPress={toggleAutoPlayNext}>
        <Ionicons name={autoPlayNextEnabled ? "play-forward" : "play-forward-outline"} size={22} color={autoPlayNextEnabled ? "#1DB954" : "#b3b3b3"} />
        <Text style={styles.menuText}>
          {autoPlayNextEnabled ? 'Auto Play Next: On' : 'Auto Play Next: Off'}
        </Text>
        <Ionicons name="chevron-forward" size={18} color="#555" />
      </TouchableOpacity>
      <TouchableOpacity style={styles.menuItem}>
        <Ionicons name="information-circle-outline" size={22} color="#b3b3b3" />
        <Text style={styles.menuText}>About</Text>
        <Ionicons name="chevron-forward" size={18} color="#555" />
      </TouchableOpacity>
      <TouchableOpacity style={styles.menuItem} onPress={() => Alert.alert('Change Password', 'Password change UI can be connected to your backend auth endpoint.')}>
        <Ionicons name="key-outline" size={22} color="#b3b3b3" />
        <Text style={styles.menuText}>Change Password</Text>
        <Ionicons name="chevron-forward" size={18} color="#555" />
      </TouchableOpacity>
      <TouchableOpacity style={[styles.menuItem, styles.logoutItem]} onPress={handleLogout}>
        <Ionicons name="log-out-outline" size={22} color="#e74c3c" />
        <Text style={[styles.menuText, { color: '#e74c3c' }]}>Logout</Text>
        <Ionicons name="chevron-forward" size={18} color="#e74c3c" />
      </TouchableOpacity>

      <Text style={styles.version}>Tamil Music App v1.0.0</Text>
      <View style={{ height: 120 }} />

      <Modal visible={showEditNameModal} transparent animationType="fade" onRequestClose={() => setShowEditNameModal(false)}>
        <View style={styles.modalOverlay}>
          <View style={styles.modalCard}>
            <Text style={styles.modalTitle}>Edit Name</Text>
            <TextInput
              style={styles.modalInput}
              value={editingName}
              onChangeText={setEditingName}
              placeholder="Enter your name"
              placeholderTextColor="#777"
              autoFocus
            />
            <View style={styles.modalActions}>
              <TouchableOpacity style={styles.modalBtn} onPress={() => setShowEditNameModal(false)}>
                <Text style={styles.modalBtnText}>Cancel</Text>
              </TouchableOpacity>
              <TouchableOpacity style={[styles.modalBtn, styles.modalBtnPrimary]} onPress={saveEditedName}>
                <Text style={[styles.modalBtnText, styles.modalBtnPrimaryText]}>Save</Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>
      <Modal visible={showAutoOffModal} transparent animationType="fade" onRequestClose={() => setShowAutoOffModal(false)}>
        <View style={styles.modalOverlay}>
          <View style={styles.modalCard}>
            <Text style={styles.modalTitle}>Set Auto Off</Text>
            <TextInput
              style={styles.modalInput}
              value={autoOffInput}
              onChangeText={setAutoOffInput}
              placeholder="Minutes only (e.g. 45)"
              placeholderTextColor="#777"
              keyboardType="number-pad"
              autoFocus
            />
            <View style={styles.modalActions}>
              <TouchableOpacity style={styles.modalBtn} onPress={() => setShowAutoOffModal(false)}>
                <Text style={styles.modalBtnText}>Cancel</Text>
              </TouchableOpacity>
              <TouchableOpacity style={[styles.modalBtn, styles.modalBtnPrimary]} onPress={saveCustomAutoOff}>
                <Text style={[styles.modalBtnText, styles.modalBtnPrimaryText]}>Save</Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#121212', paddingTop: 10 },
  topBranding: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 20, marginBottom: 20, gap: 10 },
  logoContainer: { backgroundColor: 'rgba(29, 185, 84, 0.12)', padding: 6, borderRadius: 10 },
  brandTitle: { color: '#fff', fontSize: 18, fontWeight: 'bold' },
  profileHeader: { alignItems: 'center', paddingVertical: 15 },
  avatar: { width: 90, height: 90, borderRadius: 45, backgroundColor: '#8B5CF6', alignItems: 'center', justifyContent: 'center', marginBottom: 14 },
  avatarText: { color: '#fff', fontSize: 36, fontWeight: 'bold' },
  userName: { color: '#fff', fontSize: 24, fontWeight: 'bold', marginTop: 8 },
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
  chip: { backgroundColor: '#2a2a2a', paddingHorizontal: 12, paddingVertical: 6, borderRadius: 16 },
  chipText: { color: '#ddd', fontSize: 13 },
  menuItem: { flexDirection: 'row', alignItems: 'center', gap: 14, paddingHorizontal: 20, paddingVertical: 16, borderBottomWidth: 0.5, borderBottomColor: '#222' },
  menuText: { color: '#fff', fontSize: 16, flex: 1 },
  logoutItem: { marginTop: 10 },
  version: { color: '#444', fontSize: 12, textAlign: 'center', marginTop: 30 },
  modalOverlay: { flex: 1, backgroundColor: 'rgba(0,0,0,0.55)', justifyContent: 'center', paddingHorizontal: 24 },
  modalCard: { backgroundColor: '#1f1f1f', borderRadius: 14, padding: 16, borderWidth: 1, borderColor: '#2f2f2f' },
  modalTitle: { color: '#fff', fontSize: 18, fontWeight: '700', marginBottom: 12 },
  modalInput: {
    backgroundColor: '#2a2a2a',
    borderRadius: 10,
    borderWidth: 1,
    borderColor: '#3a3a3a',
    color: '#fff',
    paddingHorizontal: 12,
    height: 44,
    marginBottom: 14,
  },
  modalActions: { flexDirection: 'row', justifyContent: 'flex-end', gap: 10 },
  modalBtn: { paddingVertical: 8, paddingHorizontal: 14, borderRadius: 10, backgroundColor: '#2a2a2a' },
  modalBtnPrimary: { backgroundColor: '#1DB954' },
  modalBtnText: { color: '#ddd', fontSize: 14, fontWeight: '600' },
  modalBtnPrimaryText: { color: '#fff' },
});

import { create } from 'zustand';
import AsyncStorage from '@react-native-async-storage/async-storage';
import axios from 'axios';
import { API_URL } from '../config/api';

interface LibraryState {
  recentSearches: string[];
  recentlyPlayed: any[];
  addRecentSearch: (query: string) => Promise<void>;
  addRecentlyPlayed: (track: any) => Promise<void>;
  loadLibrary: () => Promise<void>;
}

export const useLibraryStore = create<LibraryState>((set, get) => ({
  recentSearches: [],
  recentlyPlayed: [],
  
  addRecentSearch: async (query) => {
    const { recentSearches } = get();
    const updated = [query, ...recentSearches.filter(q => q !== query)].slice(0, 10);
    await AsyncStorage.setItem('recentSearches', JSON.stringify(updated));
    set({ recentSearches: updated });
  },
  
  addRecentlyPlayed: async (track) => {
    const { recentlyPlayed } = get();
    const updated = [track, ...recentlyPlayed.filter(t => t.id !== track.id)].slice(0, 20);
    await AsyncStorage.setItem('recentlyPlayed', JSON.stringify(updated));
    set({ recentlyPlayed: updated });

    // Sync to backend in background - don't await, don't block
    try {
      const token = await AsyncStorage.getItem('token');
      if (token) {
        axios.post(`${API_URL}/auth/recent`, { track }, {
          headers: { Authorization: `Bearer ${token}` },
          timeout: 5000,
        }).catch(() => {}); // Fire and forget
      }
    } catch {}
  },
  
  loadLibrary: async () => {
    // Load from local storage FIRST (instant, never fails)
    try {
      const searches = await AsyncStorage.getItem('recentSearches');
      const played = await AsyncStorage.getItem('recentlyPlayed');
      
      set({
        recentSearches: searches ? JSON.parse(searches) : [],
        recentlyPlayed: played ? JSON.parse(played) : [],
      });
    } catch {
      // Local storage read failed, use empty state
    }

    // Then try to sync from backend in background (don't block app startup)
    try {
      const token = await AsyncStorage.getItem('token');
      if (token) {
        axios.get(`${API_URL}/auth/me`, {
          headers: { Authorization: `Bearer ${token}` },
          timeout: 8000,
        }).then(resp => {
          if (resp.data && resp.data.recentlyPlayed && Array.isArray(resp.data.recentlyPlayed)) {
            set({ recentlyPlayed: resp.data.recentlyPlayed });
            AsyncStorage.setItem('recentlyPlayed', JSON.stringify(resp.data.recentlyPlayed)).catch(() => {});
          }
        }).catch(() => {
          // Backend sync failed silently - local data is already loaded
        });
      }
    } catch {}
  }
}));

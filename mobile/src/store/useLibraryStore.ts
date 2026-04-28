import { create } from 'zustand';
import AsyncStorage from '@react-native-async-storage/async-storage';

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
  },
  
  loadLibrary: async () => {
    const searches = await AsyncStorage.getItem('recentSearches');
    const played = await AsyncStorage.getItem('recentlyPlayed');
    
    set({
      recentSearches: searches ? JSON.parse(searches) : [],
      recentlyPlayed: played ? JSON.parse(played) : [],
    });
  }
}));

import { create } from 'zustand';
import AsyncStorage from '@react-native-async-storage/async-storage';

interface AuthState {
  token: string | null;
  user: any | null;
  isReady: boolean;
  onboardingComplete: boolean;
  setAuth: (token: string, user: any) => Promise<void>;
  logout: () => Promise<void>;
  checkAuth: () => Promise<void>;
  setOnboardingComplete: () => Promise<void>;
}

export const useAuthStore = create<AuthState>((set) => ({
  token: null,
  user: null,
  isReady: false,
  onboardingComplete: false,

  setAuth: async (token, user) => {
    const preferredLanguages = await AsyncStorage.getItem('preferredLanguages');
    const favoriteArtists = await AsyncStorage.getItem('favoriteArtists');
    const hasOnboardingData = !!preferredLanguages && !!favoriteArtists;

    await AsyncStorage.setItem('token', token);
    await AsyncStorage.setItem('user', JSON.stringify(user));
    if (hasOnboardingData) {
      await AsyncStorage.setItem('onboardingComplete', 'true');
    }
    set({ token, user, onboardingComplete: hasOnboardingData });
  },

  logout: async () => {
    await AsyncStorage.removeItem('token');
    await AsyncStorage.removeItem('user');
    await AsyncStorage.removeItem('onboardingComplete');
    set({ token: null, user: null, onboardingComplete: false });
  },

  checkAuth: async () => {
    try {
      // Timeout wrapper — if AsyncStorage hangs for 2s, proceed anyway
      const withTimeout = <T>(promise: Promise<T>, fallback: T): Promise<T> =>
        Promise.race([
          promise,
          new Promise<T>((resolve) => setTimeout(() => resolve(fallback), 2000)),
        ]);

      const token = await withTimeout(AsyncStorage.getItem('token'), null);
      const userStr = await withTimeout(AsyncStorage.getItem('user'), null);
      const onboarding = await withTimeout(AsyncStorage.getItem('onboardingComplete'), null);
      const preferredLanguages = await withTimeout(AsyncStorage.getItem('preferredLanguages'), null);
      const favoriteArtists = await withTimeout(AsyncStorage.getItem('favoriteArtists'), null);
      const hasOnboardingData = !!preferredLanguages && !!favoriteArtists;

      if (token && userStr) {
        try {
          const user = JSON.parse(userStr);
          const isOnboardingDone = onboarding === 'true' || hasOnboardingData;
          if (isOnboardingDone && onboarding !== 'true') {
            await AsyncStorage.setItem('onboardingComplete', 'true');
          }
          set({ token, user, isReady: true, onboardingComplete: isOnboardingDone });
        } catch {
          // Corrupted JSON in storage — clear and proceed as logged out
          await AsyncStorage.multiRemove(['token', 'user', 'onboardingComplete']);
          set({ isReady: true });
        }
      } else {
        set({ isReady: true });
      }
    } catch {
      // Any error → just mark ready so app doesn't hang
      set({ isReady: true });
    }
  },

  setOnboardingComplete: async () => {
    await AsyncStorage.setItem('onboardingComplete', 'true');
    set({ onboardingComplete: true });
  },
}));

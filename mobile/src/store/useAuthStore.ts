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
    await AsyncStorage.setItem('token', token);
    await AsyncStorage.setItem('user', JSON.stringify(user));
    set({ token, user });
  },
  
  logout: async () => {
    await AsyncStorage.removeItem('token');
    await AsyncStorage.removeItem('user');
    await AsyncStorage.removeItem('onboardingComplete');
    set({ token: null, user: null, onboardingComplete: false });
  },
  
  checkAuth: async () => {
    const token = await AsyncStorage.getItem('token');
    const userStr = await AsyncStorage.getItem('user');
    const onboarding = await AsyncStorage.getItem('onboardingComplete');
    if (token && userStr) {
      set({ token, user: JSON.parse(userStr), isReady: true, onboardingComplete: onboarding === 'true' });
    } else {
      set({ isReady: true });
    }
  },

  setOnboardingComplete: async () => {
    await AsyncStorage.setItem('onboardingComplete', 'true');
    set({ onboardingComplete: true });
  },
}));

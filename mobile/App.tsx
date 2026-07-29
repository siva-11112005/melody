import React, { useEffect, useState } from 'react';
import { StatusBar } from 'expo-status-bar';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { View, ActivityIndicator, StyleSheet, Image, PermissionsAndroid, Platform } from 'react-native';
import { useFonts } from 'expo-font';
import { Ionicons } from '@expo/vector-icons';
import AppNavigator from './src/navigation/AppNavigator';
import { useAuthStore } from './src/store/useAuthStore';
import { bindTrackPlayerEvents, setupTrackPlayer } from './src/services/trackPlayerService';

export default function App() {
  const { isReady, checkAuth } = useAuthStore();
  const [fontsLoaded] = useFonts(Ionicons.font);

  // Force-unblock the loading screen after 3 seconds maximum
  // This prevents the app from getting stuck if fonts/auth hang
  const [forceReady, setForceReady] = useState(false);

  useEffect(() => {
    checkAuth();
    setupTrackPlayer().catch(() => {});
    if (Platform.OS === 'android' && Platform.Version >= 33) {
      PermissionsAndroid.request(PermissionsAndroid.PERMISSIONS.POST_NOTIFICATIONS).catch(() => {});
    }
    const unbind = bindTrackPlayerEvents();
    const timer = setTimeout(() => {
      setForceReady(true);
    }, 3000);
    return () => {
      clearTimeout(timer);
      unbind();
    };
  }, []);

  const appReady = (isReady && fontsLoaded) || forceReady;

  if (!appReady) {
    return (
      <View style={styles.splash}>
        <View style={styles.logoContainer}>
          <Image 
            source={require('./assets/icon.png')} 
            style={{ width: 100, height: 100, borderRadius: 20 }} 
          />
        </View>
        <ActivityIndicator size="small" color="#1DB954" style={{ marginTop: 30 }} />
      </View>
    );
  }

  return (
    <SafeAreaProvider>
      <StatusBar style="light" />
      <AppNavigator />
    </SafeAreaProvider>
  );
}

const styles = StyleSheet.create({
  splash: {
    flex: 1,
    backgroundColor: '#121212',
    alignItems: 'center',
    justifyContent: 'center',
  },
  logoContainer: {
    width: 140,
    height: 140,
    backgroundColor: 'rgba(29, 185, 84, 0.1)',
    borderRadius: 70,
    alignItems: 'center',
    justifyContent: 'center',
  },
});

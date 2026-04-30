import React, { useEffect, useState } from 'react';
import { StatusBar } from 'expo-status-bar';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { View, ActivityIndicator, StyleSheet } from 'react-native';
import { useFonts } from 'expo-font';
import { Ionicons } from '@expo/vector-icons';
import AppNavigator from './src/navigation/AppNavigator';
import { useAuthStore } from './src/store/useAuthStore';

export default function App() {
  const { isReady, checkAuth } = useAuthStore();
  const [fontsLoaded] = useFonts(Ionicons.font);

  // Force-unblock the loading screen after 3 seconds maximum
  // This prevents the app from getting stuck if fonts/auth hang
  const [forceReady, setForceReady] = useState(false);

  useEffect(() => {
    checkAuth();
    const timer = setTimeout(() => {
      setForceReady(true);
    }, 3000);
    return () => clearTimeout(timer);
  }, []);

  const appReady = (isReady && fontsLoaded) || forceReady;

  if (!appReady) {
    return (
      <View style={styles.splash}>
        <ActivityIndicator size="large" color="#1DB954" />
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
});

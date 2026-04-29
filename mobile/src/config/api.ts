import { Platform } from 'react-native';
import Constants from 'expo-constants';

// ============================================
// SET YOUR RENDER BACKEND URL HERE
// ============================================
const PRODUCTION_API_URL = 'https://melody-beqg.onrender.com/api';

function getApiUrl(): string {
  // Always use the Render URL, even in local development.
  // Tip: Comment this return statement out if you want to test the backend locally again!
  return PRODUCTION_API_URL;

  /*
  // In production builds (APK), use the Render URL
  if (!__DEV__) {
    return PRODUCTION_API_URL;
  }

  // For dev: use the same IP Expo is serving from
  const expoHost = Constants.expoConfig?.hostUri?.split(':')[0];
  
  if (Platform.OS === 'android') {
    if (expoHost) {
      return `http://${expoHost}:5000/api`;
    }
    return 'http://10.0.2.2:5000/api';
  }
  
  if (Platform.OS === 'ios') {
    if (expoHost) {
      return `http://${expoHost}:5000/api`;
    }
    return 'http://localhost:5000/api';
  }

  return 'http://localhost:5000/api';
  */
}

export const API_URL = getApiUrl();

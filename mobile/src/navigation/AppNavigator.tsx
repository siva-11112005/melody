import React from 'react';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { NavigationContainer, DarkTheme, useNavigation } from '@react-navigation/native';
import { Ionicons } from '@expo/vector-icons';

import HomeScreen from '../screens/HomeScreen';
import SearchScreen from '../screens/SearchScreen';
import LibraryScreen from '../screens/LibraryScreen';
import ProfileScreen from '../screens/ProfileScreen';
import LoginScreen from '../screens/LoginScreen';
import SignupScreen from '../screens/SignupScreen';
import LanguageScreen from '../screens/LanguageScreen';
import ArtistPickScreen from '../screens/ArtistPickScreen';
import FullPlayerScreen from '../screens/FullPlayerScreen';
import Player from '../components/Player';
import { useAuthStore } from '../store/useAuthStore';
import { usePlayerStore } from '../store/usePlayerStore';

const Tab = createBottomTabNavigator();
const Stack = createNativeStackNavigator();

const customDarkTheme = {
  ...DarkTheme,
  colors: {
    ...DarkTheme.colors,
    background: '#121212',
    card: '#181818',
    text: '#ffffff',
    border: '#282828',
    primary: '#1DB954',
  },
};

function MainTabs() {
  return (
    <Tab.Navigator
      screenOptions={{
        headerShown: false,
        tabBarStyle: {
          backgroundColor: '#181818',
          borderTopColor: '#282828',
          paddingBottom: 8,
          height: 65,
        },
        tabBarActiveTintColor: '#1DB954',
        tabBarInactiveTintColor: '#b3b3b3',
        tabBarLabelStyle: { fontSize: 11, fontWeight: '500', marginBottom: 2 },
      }}
    >
      <Tab.Screen name="Home" component={HomeScreen}
        options={{ 
          tabBarLabel: 'Home',
          tabBarIcon: ({ color, size, focused }) => <Ionicons name={focused ? "home" : "home-outline"} size={size} color={color} /> 
        }}
      />
      <Tab.Screen name="Search" component={SearchScreen}
        options={{ 
          tabBarLabel: 'Search',
          tabBarIcon: ({ color, size, focused }) => <Ionicons name={focused ? "search" : "search-outline"} size={size} color={color} /> 
        }}
      />
      <Tab.Screen name="Library" component={LibraryScreen}
        options={{ 
          tabBarLabel: 'Library',
          tabBarIcon: ({ color, size, focused }) => <Ionicons name={focused ? "library" : "library-outline"} size={size} color={color} /> 
        }}
      />
      <Tab.Screen name="Profile" component={ProfileScreen}
        options={{ 
          tabBarLabel: 'Profile',
          tabBarIcon: ({ color, size, focused }) => <Ionicons name={focused ? "person" : "person-outline"} size={size} color={color} /> 
        }}
      />
    </Tab.Navigator>
  );
}


function MainTabsWithPlayer() {
  const navigation = useNavigation<any>();
  const { currentTrack } = usePlayerStore();

  return (
    <>
      <MainTabs />
      {currentTrack && (
        <Player onPress={() => navigation.navigate('FullPlayer')} />
      )}
    </>
  );
}

function AuthStack() {
  return (
    <Stack.Navigator screenOptions={{ headerShown: false }}>
      <Stack.Screen name="Login" component={LoginScreen} />
      <Stack.Screen name="Signup" component={SignupScreen} />
      <Stack.Screen name="LanguageSelect" component={LanguageScreen} />
      <Stack.Screen name="ArtistPick" component={ArtistPickScreen} />
    </Stack.Navigator>
  );
}

function OnboardingStack() {
  return (
    <Stack.Navigator screenOptions={{ headerShown: false }}>
      <Stack.Screen name="LanguageSelect" component={LanguageScreen} />
      <Stack.Screen name="ArtistPick" component={ArtistPickScreen} />
    </Stack.Navigator>
  );
}

function AppStack() {
  return (
    <Stack.Navigator screenOptions={{ headerShown: false }}>
      <Stack.Screen name="MainTabs" component={MainTabsWithPlayer} />
      <Stack.Screen 
        name="FullPlayer" 
        component={FullPlayerScreen}
        options={{ presentation: 'modal', animation: 'slide_from_bottom' }} 
      />
    </Stack.Navigator>
  );
}

export default function AppNavigator() {
  const { token, isReady, onboardingComplete } = useAuthStore();

  if (!isReady) return null;

  return (
    <NavigationContainer theme={customDarkTheme}>
      {!token ? <AuthStack /> : !onboardingComplete ? <OnboardingStack /> : <AppStack />}
    </NavigationContainer>
  );
}

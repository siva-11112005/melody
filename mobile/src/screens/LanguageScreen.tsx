import React, { useState } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ScrollView } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { Ionicons } from '@expo/vector-icons';
import AsyncStorage from '@react-native-async-storage/async-storage';

const LANGUAGES = [
  { id: 'tamil', label: 'Tamil', icon: 'musical-notes', gradient: ['#FF6B6B', '#ee5a24'] },
  { id: 'hindi', label: 'Hindi', icon: 'musical-note', gradient: ['#6C5CE7', '#a29bfe'] },
  { id: 'english', label: 'English', icon: 'headset', gradient: ['#00B894', '#55efc4'] },
  { id: 'telugu', label: 'Telugu', icon: 'mic', gradient: ['#FDCB6E', '#f39c12'] },
  { id: 'kannada', label: 'Kannada', icon: 'megaphone', gradient: ['#E17055', '#d63031'] },
  { id: 'malayalam', label: 'Malayalam', icon: 'ear', gradient: ['#0984E3', '#74b9ff'] },
  { id: 'punjabi', label: 'Punjabi', icon: 'disc', gradient: ['#E84393', '#fd79a8'] },
  { id: 'bengali', label: 'Bengali', icon: 'radio', gradient: ['#00CEC9', '#81ecec'] },
  { id: 'marathi', label: 'Marathi', icon: 'volume-high', gradient: ['#FAB1A0', '#e17055'] },
  { id: 'other', label: 'Other', icon: 'globe', gradient: ['#636E72', '#b2bec3'] },
];

export default function LanguageScreen({ navigation }: any) {
  const [selected, setSelected] = useState<string[]>([]);

  const toggleLanguage = (id: string) => {
    setSelected(prev => 
      prev.includes(id) ? prev.filter(l => l !== id) : [...prev, id]
    );
  };

  const handleContinue = async () => {
    if (selected.length === 0) return;
    await AsyncStorage.setItem('preferredLanguages', JSON.stringify(selected));
    navigation.navigate('ArtistPick');
  };

  return (
    <LinearGradient colors={['#121212', '#1a1a2e']} style={styles.container}>
      <ScrollView contentContainerStyle={styles.scrollContent} showsVerticalScrollIndicator={false}>
        <Text style={styles.title}>Choose Your Languages</Text>
        <Text style={styles.subtitle}>Select the languages you enjoy listening to</Text>

        <View style={styles.grid}>
          {LANGUAGES.map((lang) => (
            <TouchableOpacity
              key={lang.id}
              onPress={() => toggleLanguage(lang.id)}
              activeOpacity={0.7}
            >
              <LinearGradient
                colors={selected.includes(lang.id) ? lang.gradient as [string, string] : ['#2a2a2a', '#333']}
                style={[
                  styles.langCard,
                  selected.includes(lang.id) && styles.selectedCard,
                ]}
                start={{ x: 0, y: 0 }}
                end={{ x: 1, y: 1 }}
              >
                {selected.includes(lang.id) && (
                  <View style={styles.checkBadge}>
                    <Ionicons name="checkmark" size={14} color="#fff" />
                  </View>
                )}
                <Ionicons name={lang.icon as any} size={32} color="#fff" />
                <Text style={styles.langLabel}>{lang.label}</Text>
              </LinearGradient>
            </TouchableOpacity>
          ))}
        </View>
      </ScrollView>

      <View style={styles.bottomBar}>
        <Text style={styles.selectedCount}>
          {selected.length} language{selected.length !== 1 ? 's' : ''} selected
        </Text>
        <TouchableOpacity 
          onPress={handleContinue}
          disabled={selected.length === 0}
          activeOpacity={0.8}
        >
          <LinearGradient 
            colors={selected.length > 0 ? ['#1DB954', '#1ed760'] : ['#333', '#444']}
            style={styles.continueButton}
          >
            <Text style={styles.continueText}>Continue</Text>
            <Ionicons name="arrow-forward" size={20} color="#fff" />
          </LinearGradient>
        </TouchableOpacity>
      </View>
    </LinearGradient>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  scrollContent: { paddingTop: 70, paddingHorizontal: 20, paddingBottom: 120 },
  title: { color: '#fff', fontSize: 30, fontWeight: 'bold' },
  subtitle: { color: '#b3b3b3', fontSize: 16, marginTop: 8, marginBottom: 30 },
  grid: {
    flexDirection: 'row', flexWrap: 'wrap', gap: 12,
    justifyContent: 'space-between',
  },
  langCard: {
    width: 105, height: 105, borderRadius: 16,
    alignItems: 'center', justifyContent: 'center',
  },
  selectedCard: {
    borderWidth: 2, borderColor: '#fff',
  },
  checkBadge: {
    position: 'absolute', top: 8, right: 8,
    backgroundColor: 'rgba(0,0,0,0.4)', borderRadius: 10,
    width: 20, height: 20, alignItems: 'center', justifyContent: 'center',
  },
  langLabel: { color: '#fff', fontSize: 14, fontWeight: '600', marginTop: 6 },
  bottomBar: {
    position: 'absolute', bottom: 0, left: 0, right: 0,
    paddingHorizontal: 20, paddingBottom: 40, paddingTop: 15,
    backgroundColor: '#121212',
    flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
  },
  selectedCount: { color: '#b3b3b3', fontSize: 14 },
  continueButton: {
    flexDirection: 'row', alignItems: 'center', gap: 8,
    paddingHorizontal: 28, paddingVertical: 14, borderRadius: 25,
  },
  continueText: { color: '#fff', fontSize: 16, fontWeight: 'bold' },
});

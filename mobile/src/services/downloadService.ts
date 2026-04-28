import * as FileSystem from 'expo-file-system';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { Alert } from 'react-native';

export const downloadTrack = async (track: any) => {
  try {
    // Get the best available URL
    const audioUrl = track.url || track.audioUrl || null;
    
    if (!audioUrl) {
      throw new Error('No stream URL available for this track');
    }
    
    // Create a safe filename
    const safeTitle = (track.title || 'unknown').replace(/[^a-zA-Z0-9]/g, '_').substring(0, 50);
    const fileUri = `${FileSystem.documentDirectory}${track.id}_${safeTitle}.m4a`;
    
    // Check if already downloaded
    const fileInfo = await FileSystem.getInfoAsync(fileUri);
    if (fileInfo.exists) {
      console.log('Already downloaded:', fileUri);
      return fileUri;
    }

    const downloadResumable = FileSystem.createDownloadResumable(
      audioUrl,
      fileUri,
      {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      },
      (downloadProgress) => {
        const progress = downloadProgress.totalBytesWritten / downloadProgress.totalBytesExpectedToWrite;
        console.log(`Downloading ${track.title}: ${Math.round(progress * 100)}%`);
      }
    );

    const result = await downloadResumable.downloadAsync();
    
    if (result && result.uri) {
      // Save metadata to local storage for the library
      const existingStr = await AsyncStorage.getItem('downloads');
      const existing = existingStr ? JSON.parse(existingStr) : [];
      
      // Avoid duplicate entries
      const filtered = existing.filter((t: any) => t.id !== track.id);
      const updated = [...filtered, { 
        ...track, 
        localUri: result.uri,
        downloadedAt: new Date().toISOString(),
      }];
      await AsyncStorage.setItem('downloads', JSON.stringify(updated));
      return result.uri;
    }
    
    throw new Error('Download returned no result');
  } catch (error: any) {
    console.error('Download error:', error?.message || error);
    throw error;
  }
};

export const getDownloadedTracks = async () => {
  try {
    const existingStr = await AsyncStorage.getItem('downloads');
    return existingStr ? JSON.parse(existingStr) : [];
  } catch (error) {
    console.error('Error fetching downloads:', error);
    return [];
  }
};

export const removeDownload = async (trackId: string) => {
  try {
    const existingStr = await AsyncStorage.getItem('downloads');
    const existing = existingStr ? JSON.parse(existingStr) : [];
    const track = existing.find((t: any) => t.id === trackId);
    
    if (track?.localUri) {
      const fileInfo = await FileSystem.getInfoAsync(track.localUri);
      if (fileInfo.exists) {
        await FileSystem.deleteAsync(track.localUri);
      }
    }
    
    const updated = existing.filter((t: any) => t.id !== trackId);
    await AsyncStorage.setItem('downloads', JSON.stringify(updated));
  } catch (error) {
    console.error('Error removing download:', error);
  }
};

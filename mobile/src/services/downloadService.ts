import * as FileSystem from 'expo-file-system';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { Alert } from 'react-native';

const getBestAudioUrl = (track: any): string | null => {
  if (!track) return null;
  if (track.localUri) return track.localUri;
  
  // Try downloadUrl array first (best quality)
  if (Array.isArray(track.downloadUrl) && track.downloadUrl.length > 0) {
    // Pick highest quality (last item in array)
    const last = track.downloadUrl[track.downloadUrl.length - 1];
    if (typeof last === 'string' && last.length > 0) return last;
    if (last?.url && last.url.length > 0) return last.url;
    // Fallback to first item
    const first = track.downloadUrl[0];
    if (typeof first === 'string' && first.length > 0) return first;
    if (first?.url && first.url.length > 0) return first.url;
  }
  if (typeof track.downloadUrl === 'string' && track.downloadUrl.length > 0) return track.downloadUrl;
  
  // Then try direct url fields
  if (track.url && typeof track.url === 'string' && track.url.length > 0) return track.url;
  if (track.audioUrl && typeof track.audioUrl === 'string') return track.audioUrl;
  if (track.streamUrl && typeof track.streamUrl === 'string') return track.streamUrl;
  
  return null;
};

export const downloadTrack = async (track: any) => {
  try {
    // Get the best available URL
    let audioUrl = getBestAudioUrl(track);
    
    if (!audioUrl) {
      throw new Error('No stream URL available for this track');
    }

    if (audioUrl.startsWith('file://')) {
      return audioUrl;
    }

    if (audioUrl.startsWith('http://')) {
      audioUrl = audioUrl.replace('http://', 'https://');
    }

    const existingStr = await AsyncStorage.getItem('downloads');
    const existing = existingStr ? JSON.parse(existingStr) : [];
    const existingTrack = existing.find((t: any) => t.id === track.id && t.localUri);
    if (existingTrack?.localUri) {
      const info = await FileSystem.getInfoAsync(existingTrack.localUri);
      if (info.exists) {
        return existingTrack.localUri;
      }
    }
    
    // Create a safe filename
    const safeTitle = (track.title || 'unknown').replace(/[^a-zA-Z0-9]/g, '_').substring(0, 50);
    const fileUri = `${FileSystem.documentDirectory}${track.id || Date.now()}_${safeTitle}.m4a`;
    
    // Check if already downloaded
    const fileInfo = await FileSystem.getInfoAsync(fileUri);
    if (fileInfo.exists) {
      console.log('Already downloaded:', fileUri);
      // Make sure metadata is saved
      const filtered = existing.filter((t: any) => t.id !== track.id);
      const updated = [...filtered, { 
        ...track, 
        localUri: fileUri,
        downloadedAt: new Date().toISOString(),
      }];
      await AsyncStorage.setItem('downloads', JSON.stringify(updated));
      return fileUri;
    }

    console.log('Downloading from URL:', audioUrl);

    const downloadResumable = FileSystem.createDownloadResumable(
      audioUrl,
      fileUri,
      {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Referer': 'https://www.jiosaavn.com',
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

export const applyDownloadedUris = async (tracks: any[]) => {
  try {
    if (!Array.isArray(tracks) || tracks.length === 0) return tracks;
    const downloaded = await getDownloadedTracks();
    if (!Array.isArray(downloaded) || downloaded.length === 0) return tracks;

    const localMap = new Map<string, string>();
    downloaded.forEach((t: any) => {
      if (t?.id && t?.localUri) localMap.set(t.id, t.localUri);
    });

    if (localMap.size === 0) return tracks;

    return tracks.map((t: any) => {
      const localUri = t?.id ? localMap.get(t.id) : null;
      if (!localUri) return t;
      return { ...t, localUri, url: localUri };
    });
  } catch (error) {
    console.error('Error applying downloads:', error);
    return tracks;
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

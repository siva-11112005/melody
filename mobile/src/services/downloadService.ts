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
    const existingStr = await AsyncStorage.getItem('downloads');
    const existing = existingStr ? JSON.parse(existingStr) : [];
    
    // 1. Check if already downloaded
    const existingTrack = existing.find((t: any) => t.id === track.id && t.localUri);
    if (existingTrack?.localUri) {
      const info = await FileSystem.getInfoAsync(existingTrack.localUri);
      if (info.exists) return existingTrack.localUri;
    }

    // 2. Collect all potential URLs to try
    const urlsToTry: string[] = [];
    
    // Highest quality first
    if (Array.isArray(track.downloadUrl) && track.downloadUrl.length > 0) {
      // Create a copy and reverse to get highest quality first
      const sorted = [...track.downloadUrl].reverse();
      sorted.forEach((item: any) => {
        const u = typeof item === 'string' ? item : item?.url;
        if (u && u.startsWith('http')) urlsToTry.push(u);
      });
    }
    
    // Add direct URL fields as fallbacks
    const directUrl = track.url || track.audioUrl || track.streamUrl;
    if (directUrl && directUrl.startsWith('http') && !urlsToTry.includes(directUrl)) {
      urlsToTry.push(directUrl);
    }

    if (urlsToTry.length === 0) {
      throw new Error('No valid download URLs found for this track');
    }

    // 3. Prepare for download
    const safeTitle = (track.title || 'unknown').replace(/[^a-zA-Z0-9]/g, '_').substring(0, 50);
    const fileUri = `${FileSystem.documentDirectory}${track.id || Date.now()}_${safeTitle}.m4a`;

    // 4. Try each URL until one works
    let lastError = null;
    for (let audioUrl of urlsToTry) {
      try {
        console.log(`Attempting download for ${track.title} from: ${audioUrl}`);
        
        // Ensure HTTPS
        if (audioUrl.startsWith('http://')) {
          audioUrl = audioUrl.replace('http://', 'https://');
        }

        const downloadResumable = FileSystem.createDownloadResumable(
          audioUrl,
          fileUri,
          {
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
              'Referer': 'https://www.jiosaavn.com/',
            },
          }
        );

        const result = await downloadResumable.downloadAsync();
        
        if (result && result.uri) {
          // Verify file exists and is not empty
          const info = await FileSystem.getInfoAsync(result.uri);
          if (info.exists && info.size > 1000) { // At least 1KB
            console.log(`Download successful: ${result.uri} (${info.size} bytes)`);
            
            // Save metadata
            const filtered = existing.filter((t: any) => t.id !== track.id);
            const updated = [...filtered, { 
              ...track, 
              localUri: result.uri,
              downloadedAt: new Date().toISOString(),
            }];
            await AsyncStorage.setItem('downloads', JSON.stringify(updated));
            return result.uri;
          }
        }
      } catch (err: any) {
        console.log(`Failed to download from ${audioUrl}:`, err.message);
        lastError = err;
        // Continue to next URL
      }
    }

    throw lastError || new Error('All download attempts failed');
  } catch (error: any) {
    console.error('Download service error:', error?.message || error);
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

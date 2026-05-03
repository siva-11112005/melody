const https = require('https');
const http = require('http');
const fs = require('fs');
const path = require('path');

// Try multiple possible backend URLs
const POSSIBLE_URLS = [
  'http://localhost:5000',
  'http://localhost:3000',
  'http://localhost:8000',
  'http://127.0.0.1:5000',
  'http://127.0.0.1:3000',
];

let API_BASE = process.argv[2] || 'http://localhost:5000';
const SONG_QUERY = process.argv[3] || 'Neelohi';

// Helper to fetch from API
function fetchFromAPI(pathname, params = {}) {
  return new Promise((resolve, reject) => {
    const queryString = new URLSearchParams(params).toString();
    // Ensure /api prefix
    const apiPath = pathname.startsWith('/api') ? pathname : `/api${pathname}`;
    const fullPath = queryString ? `${apiPath}?${queryString}` : apiPath;
    
    const url = new URL(fullPath, API_BASE);
    const protocol = url.protocol === 'https:' ? https : http;
    
    console.log(`Fetching: ${url}`);
    
    const req = protocol.get(url, { timeout: 15000 }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          reject(new Error(`Failed to parse API response: ${e.message}`));
        }
      });
    });
    
    req.on('error', reject);
    req.on('timeout', () => {
      req.destroy();
      reject(new Error('Request timeout'));
    });
  });
}

// Download file from URL
function downloadFile(url, filename) {
  return new Promise((resolve, reject) => {
    const protocol = url.startsWith('https') ? https : http;
    const file = fs.createWriteStream(filename);
    
    console.log(`Downloading from: ${url}`);
    
    const req = protocol.get(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://www.jiosaavn.com/',
      },
      timeout: 30000,
    }, (res) => {
      if (res.statusCode !== 200) {
        file.destroy();
        fs.unlinkSync(filename);
        reject(new Error(`Download failed with status ${res.statusCode}`));
        return;
      }
      
      res.pipe(file);
      
      file.on('finish', () => {
        file.close();
        const fileSize = fs.statSync(filename).size;
        if (fileSize < 10000) {
          fs.unlinkSync(filename);
          reject(new Error(`Downloaded file too small (${fileSize} bytes). May be corrupted.`));
        } else {
          console.log(`✓ Downloaded successfully! (${(fileSize / 1024 / 1024).toFixed(2)} MB)`);
          resolve(filename);
        }
      });
    });
    
    req.on('error', (err) => {
      file.destroy();
      fs.unlinkSync(filename);
      reject(err);
    });
    
    req.on('timeout', () => {
      req.destroy();
      file.destroy();
      fs.unlinkSync(filename);
      reject(new Error('Download timeout'));
    });
  });
}

async function main() {
  try {
    console.log(`🎵 Music Download Tool\n`);
    console.log(`Searching for: "${SONG_QUERY}"\n`);
    
    // Step 1: Try to find working API URL
    let apiWorking = false;
    let searchRes = null;
    
    // First try the provided/default URL
    try {
      console.log(`Trying API at: ${API_BASE}`);
      searchRes = await fetchFromAPI('/music/search', { query: SONG_QUERY });
      apiWorking = true;
    } catch (err) {
      console.log(`✗ API not available at ${API_BASE}\n`);
      
      // Try alternative URLs
      for (const baseUrl of POSSIBLE_URLS) {
        if (baseUrl === API_BASE) continue; // Skip already tried
        try {
          console.log(`Trying API at: ${baseUrl}`);
          API_BASE = baseUrl;
          searchRes = await fetchFromAPI('/music/search', { query: SONG_QUERY });
          apiWorking = true;
          console.log(`✓ Found working API at ${API_BASE}\n`);
          break;
        } catch (e) {
          console.log(`✗ API not available at ${baseUrl}`);
        }
      }
    }
    
    if (!apiWorking || !searchRes) {
      throw new Error(`No working API found. Please make sure backend is running.\nTried: ${POSSIBLE_URLS.join(', ')}`);
    }
    
    // Step 2: Find song
    console.log('Step 1: Searching for songs...');
    
    let results = searchRes.data?.results;
    
    if (!Array.isArray(results) || results.length === 0) {
      throw new Error(`No songs found for query "${SONG_QUERY}". Please check:\n1. Backend is running\n2. Query is correct\n3. Songs exist in the API`);
    }
    
    // Display found songs
    console.log(`✓ Found ${results.length} song(s):\n`);
    
    // Log first result to understand structure
    console.log('First result structure:', JSON.stringify(results[0], null, 2));
    console.log('\n');
    
    results.forEach((s, i) => {
      const title = s.name || s.title || s.song || 'Unknown';
      const artistList = s.artists?.primary || [];
      const artist = artistList.length > 0 ? artistList.map((a) => a.name).join(', ') : (s.artist || s.singers || 'Unknown');
      console.log(`  ${i + 1}. "${title}" by ${artist}`);
    });
    console.log('');
    
    const song = results[0]; // Use first result
    
    // Try to extract title from various fields - prioritize 'name' field
    let songTitle = song.name || song.title || song.song || 'Unknown';
    
    // Extract artist from artists.primary array or fallback
    let songArtist = 'Unknown';
    if (song.artists?.primary && Array.isArray(song.artists.primary)) {
      songArtist = song.artists.primary.map((a) => a.name).join(', ');
    } else if (song.artist) {
      songArtist = song.artist;
    } else if (song.singers) {
      songArtist = song.singers;
    }
    
    console.log(`Using: "${songTitle}" by ${songArtist}\n`);
    console.log(`Song Details:`, JSON.stringify({
      title: songTitle,
      artist: songArtist,
      hasDownloadUrl: !!song.downloadUrl,
      hasUrl: !!song.url,
      hasAudioUrl: !!song.audioUrl,
    }, null, 2));
    console.log('');
    
    // Step 3: Get download URLs
    console.log('Step 2: Getting download URLs...');
    
    let downloadUrl = null;
    
    // Try different URL sources in order of priority
    if (Array.isArray(song.downloadUrl) && song.downloadUrl.length > 0) {
      // Get highest quality (last item)
      downloadUrl = song.downloadUrl[song.downloadUrl.length - 1];
      if (typeof downloadUrl === 'object') {
        downloadUrl = downloadUrl.url || downloadUrl.link;
      }
    } else if (typeof song.downloadUrl === 'string') {
      downloadUrl = song.downloadUrl;
    } else if (song.url) {
      downloadUrl = song.url;
    } else if (song.audioUrl) {
      downloadUrl = song.audioUrl;
    }
    
    if (!downloadUrl || typeof downloadUrl !== 'string') {
      console.log(`Full song object:`, JSON.stringify(song, null, 2));
      throw new Error(`No download URL found.`);
    }
    
    // Normalize URL
    if (downloadUrl.startsWith('http://')) {
      downloadUrl = `https://${downloadUrl.slice(7)}`;
    }
    
    console.log(`✓ Got URL (${downloadUrl.includes('_320') ? '320kbps' : downloadUrl.includes('_160') ? '160kbps' : '96kbps'} quality): ${downloadUrl.substring(0, 80)}...\n`);
    
    // Step 4: Download the song
    console.log('Step 3: Downloading song...');
    
    const downloadDir = path.join(__dirname, 'downloads');
    if (!fs.existsSync(downloadDir)) {
      fs.mkdirSync(downloadDir, { recursive: true });
    }
    
    // Better title extraction - use the song title, not URL
    let safeTitle = songTitle;
    safeTitle = safeTitle.replace(/[^a-zA-Z0-9\s]/g, ' ').trim().replace(/\s+/g, '_').substring(0, 50);
    
    // Determine file extension from URL
    let ext = 'mp4';
    if (downloadUrl.includes('.m4a')) ext = 'm4a';
    else if (downloadUrl.includes('.mp3')) ext = 'mp3';
    else if (downloadUrl.includes('.wav')) ext = 'wav';
    
    console.log(`Title: ${safeTitle}`);
    console.log(`Artist: ${songArtist}`);
    console.log(`Format: ${ext.toUpperCase()}\n`);
    
    const filename = path.join(downloadDir, `${safeTitle}.${ext}`);

    
    const result = await downloadFile(downloadUrl, filename);
    
    console.log(`\n✅ Success!\n`);
    console.log(`📁 Saved to: ${result}`);
    console.log(`🎵 Song: ${songTitle}`);
    console.log(`🎤 Artist: ${songArtist}`);
    console.log(`📊 Size: ${(fs.statSync(result).size / 1024 / 1024).toFixed(2)} MB`);
    
  } catch (error) {
    console.error(`\n❌ Error: ${error.message}`);
    console.log(`\n📝 Usage: node downloadSong.js [API_URL] [SONG_NAME]`);
    console.log(`Examples:`);
    console.log(`  node downloadSong.js`);
    console.log(`  node downloadSong.js http://localhost:3000 "Neelohi"`);
    console.log(`  node downloadSong.js http://localhost:5000 "Anirudh"`);
    process.exit(1);
  }
}

main();

import { Router } from 'express';
import axios from 'axios';
import NodeCache from 'node-cache';
import CryptoJS from 'crypto-js';

const router = Router();
const cache = new NodeCache({ stdTTL: 7200 }); // Cache for 2 hours

function decodeHTMLEntities(text: string) {
  if (!text) return text;
  return text
    .replace(/&quot;/g, '"')
    .replace(/&amp;/g, '&')
    .replace(/&#039;/g, "'")
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>');
}

// Direct JioSaavn API base URL (official endpoints)
const JIOSAAVN_BASE = 'https://www.jiosaavn.com/api.php';

// Helper: call JioSaavn's actual API and parse response
async function jiosaavnSearch(query: string, limit: number = 10, page: number = 1) {
  try {
    const response = await axios.get(JIOSAAVN_BASE, {
      params: {
        __call: 'search.getResults',
        _format: 'json',
        _marker: '0',
        api_version: '4',
        ctx: 'web6dot0',
        n: limit,
        p: page,
        q: query,
      },
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'application/json',
      },
      timeout: 8000,
    });

    if (!response.data?.results) return [];

    // Map to clean format
    return response.data.results.map((song: any) => ({
      id: song.id,
      name: decodeHTMLEntities(song.title || song.song || 'Unknown'),
      duration: parseInt(song.more_info?.duration || song.duration || '0'),
      artists: {
        primary: song.more_info?.artistMap?.primary_artists?.map((a: any) => ({
          name: decodeHTMLEntities(a.name),
          id: a.id,
        })) || [{ name: decodeHTMLEntities(song.more_info?.primary_artists || song.primary_artists || 'Unknown'), id: '' }],
      },
      image: [
        { quality: '50x50', url: (song.image || '').replace('150x150', '50x50').replace('500x500', '50x50') },
        { quality: '150x150', url: (song.image || '').replace('500x500', '150x150') },
        { quality: '500x500', url: (song.image || '').replace('150x150', '500x500').replace('50x50', '500x500') },
      ],
      downloadUrl: getDownloadUrls(song),
      language: song.language || song.more_info?.language || '',
      year: song.year || song.more_info?.year || '',
      album: decodeHTMLEntities(song.more_info?.album || ''),
    }));
  } catch (error: any) {
    console.error('JioSaavn direct search error:', error?.message);
    return [];
  }
}

function getDownloadUrls(song: any) {
  let finalUrl = '';
  const encUrl = song.more_info?.encrypted_media_url;
  if (encUrl) {
    try {
      const key = CryptoJS.enc.Utf8.parse('38346591');
      const decrypted = CryptoJS.DES.decrypt({ ciphertext: CryptoJS.enc.Base64.parse(encUrl) } as any, key, {
        mode: CryptoJS.mode.ECB,
        padding: CryptoJS.pad.Pkcs7
      });
      finalUrl = decrypted.toString(CryptoJS.enc.Utf8);
    } catch(e) {
      console.error('Decryption failed');
    }
  }

  if (!finalUrl) {
    const preview = song.more_info?.media_preview_url;
    if (preview) {
      finalUrl = preview.replace('preview', 'aac').replace('_96_p.mp4', '_96.mp4');
    }
  }

  if (!finalUrl) {
    finalUrl = song.more_info?.vlink || song.perma_url || '';
  }

  if (!finalUrl) return [];

  return [
    { quality: '96kbps', url: finalUrl.replace('_320.mp4', '_96.mp4').replace('_160.mp4', '_96.mp4') },
    { quality: '160kbps', url: finalUrl.replace('_320.mp4', '_160.mp4').replace('_96.mp4', '_160.mp4') },
    { quality: '320kbps', url: finalUrl.replace('_96.mp4', '_320.mp4').replace('_160.mp4', '_320.mp4') },
  ];
}

// Search suggestions/autocomplete
router.get('/suggest', async (req, res) => {
  try {
    const { query } = req.query;
    if (!query || (query as string).length < 2) {
      return res.json([]);
    }

    const cacheKey = `suggest_${query}`;
    if (cache.has(cacheKey)) {
      return res.json(cache.get(cacheKey));
    }

    // Try JioSaavn autocomplete API
    const response = await axios.get(JIOSAAVN_BASE, {
      params: {
        __call: 'autocomplete.get',
        _format: 'json',
        _marker: '0',
        ctx: 'web6dot0',
        query: query,
      },
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      },
      timeout: 3000,
    });

    const suggestions: string[] = [];
    // Extract song titles and artist names
    if (response.data?.songs?.data) {
      response.data.songs.data.forEach((s: any) => {
        if (s.title) suggestions.push(decodeHTMLEntities(s.title));
      });
    }
    if (response.data?.artists?.data) {
      response.data.artists.data.forEach((a: any) => {
        if (a.title) suggestions.push(decodeHTMLEntities(a.title));
      });
    }
    if (response.data?.albums?.data) {
      response.data.albums.data.forEach((a: any) => {
        if (a.title) suggestions.push(decodeHTMLEntities(a.title));
      });
    }

    const unique = [...new Set(suggestions)].slice(0, 8);
    cache.set(cacheKey, unique, 1800); // cache 30 min
    res.json(unique);
  } catch (error: any) {
    console.error('Suggest error:', error?.message);
    res.json([]);
  }
});

// Search songs
router.get('/search', async (req, res) => {
  try {
    const { query, page } = req.query;
    if (!query) {
      return res.status(400).json({ message: 'Query is required' });
    }

    const pageNum = parseInt(page as string) || 1;
    const cacheKey = `search_${query}_p${pageNum}`;
    if (cache.has(cacheKey)) {
      return res.json(cache.get(cacheKey));
    }

    // Try the local JioSaavn proxy first (if running), fall back to direct API
    let results: any[] = [];
    const JIOSAAVN_API_URL = process.env.JIOSAAVN_API_URL || 'http://localhost:3000';

    try {
      const response = await axios.get(`${JIOSAAVN_API_URL}/api/search/songs`, {
        params: { query, limit: 30, page: pageNum },
        timeout: 5000,
      });
      if (response.data?.data?.results?.length > 0) {
        results = response.data.data.results;
      }
    } catch {
      // Proxy not available, use direct JioSaavn API
      console.log('JioSaavn proxy unavailable, using direct API');
    }

    // Fallback to direct JioSaavn API
    if (results.length === 0) {
      results = await jiosaavnSearch(query as string, 30, pageNum);
    }

    const data = { data: { results } };
    cache.set(cacheKey, data);
    res.json(data);
  } catch (error: any) {
    console.error('Search error:', error?.message);
    res.status(500).json({ message: 'Error searching songs' });
  }
});

// Trending songs
router.get('/trending', async (req, res) => {
  try {
    const { languages } = req.query;
    const cacheKey = `trending_songs_${languages || 'all'}`;
    if (cache.has(cacheKey)) {
      return res.json(cache.get(cacheKey));
    }

    let langs = ['hindi', 'english'];
    if (languages && typeof languages === 'string') {
      langs = languages.split(',').map(l => l.trim().toLowerCase()).filter(Boolean);
      if (langs.length === 0) langs = ['hindi'];
    }

    const queries = langs.map(lang => `latest ${lang} songs`).concat(langs.map(lang => `top ${lang} hits`));
    const allTracks: any[] = [];

    const JIOSAAVN_API_URL = process.env.JIOSAAVN_API_URL || 'http://localhost:3000';
    let useProxy = true;

    // Test proxy availability with first query
    try {
      const testResp = await axios.get(`${JIOSAAVN_API_URL}/api/search/songs`, {
        params: { query: queries[0], limit: 6 },
        timeout: 3000,
      });
      if (testResp.data?.data?.results) {
        allTracks.push(...testResp.data.data.results);
      }
    } catch {
      useProxy = false;
    }

    // Fetch remaining queries
    await Promise.all(queries.slice(useProxy ? 1 : 0).map(async (q) => {
      try {
        if (useProxy) {
          const resp = await axios.get(`${JIOSAAVN_API_URL}/api/search/songs`, {
            params: { query: q, limit: 6 },
            timeout: 3000,
          });
          if (resp.data?.data?.results) {
            allTracks.push(...resp.data.data.results);
          }
        } else {
          const results = await jiosaavnSearch(q, 6);
          allTracks.push(...results);
        }
      } catch (err: any) {
        console.error(`Trending fetch error for "${q}":`, err?.message);
      }
    }));

    // Deduplicate
    const seen = new Set();
    const unique = allTracks.filter(t => {
      if (seen.has(t.id)) return false;
      seen.add(t.id);
      return true;
    });

    const result = { data: { results: unique } };
    cache.set(cacheKey, result);
    res.json(result);
  } catch (error: any) {
    console.error('Trending error:', error?.message);
    res.status(500).json({ message: 'Error fetching trending' });
  }
});

// Get song details
router.get('/song/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const cacheKey = `song_${id}`;

    if (cache.has(cacheKey)) {
      return res.json(cache.get(cacheKey));
    }

    const JIOSAAVN_API_URL = process.env.JIOSAAVN_API_URL || 'http://localhost:3000';

    try {
      const response = await axios.get(`${JIOSAAVN_API_URL}/api/songs/${id}`, { timeout: 4000 });
      const data = response.data;
      cache.set(cacheKey, data);
      return res.json(data);
    } catch {
      // Direct API fallback
      const response = await axios.get(JIOSAAVN_BASE, {
        params: {
          __call: 'song.getDetails',
          cc: 'in',
          _marker: '0',
          _format: 'json',
          pids: id,
        },
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
        timeout: 5000,
      });
      cache.set(cacheKey, response.data);
      return res.json(response.data);
    }
  } catch (error: any) {
    console.error('Song detail error:', error?.message);
    res.status(500).json({ message: 'Error fetching song details' });
  }
});

export default router;

import { Router } from 'express';
import axios from 'axios';
import NodeCache from 'node-cache';
import CryptoJS from 'crypto-js';

const router = Router();
const cache = new NodeCache({ stdTTL: 1800 }); // Cache for 30 minutes (shorter for variety)
const SEARCH_DEBUG = process.env.SEARCH_DEBUG === 'true';

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

// Check if we have a real JioSaavn proxy configured (not localhost)
const JIOSAAVN_API_URL = process.env.JIOSAAVN_API_URL || '';
const hasProxy = JIOSAAVN_API_URL && !JIOSAAVN_API_URL.includes('localhost') && !JIOSAAVN_API_URL.includes('127.0.0.1');
const REQUEST_TIMEOUT_MS = 12000;

async function fetchWithRetry<T>(work: () => Promise<T>, attempts: number = 2): Promise<T> {
  let lastErr: any;
  for (let i = 0; i < attempts; i++) {
    try {
      return await work();
    } catch (err) {
      lastErr = err;
      await new Promise((resolve) => setTimeout(resolve, 200 * (i + 1)));
    }
  }
  throw lastErr;
}

function normalizeQuery(value: string) {
  return value
    .toLowerCase()
    .trim()
    .replace(/[^\p{L}\p{N}\s.'&-]/gu, ' ')
    .replace(/\s+/g, ' ');
}

function buildSearchVariants(query: string) {
  const cleaned = query.trim();
  if (!cleaned) return [];
  const lower = normalizeQuery(cleaned);
  const compact = cleaned.replace(/[^\p{L}\p{N}\s.'&-]/gu, ' ').replace(/\s+/g, ' ').trim();
  const variants = [cleaned, compact];

  if (lower.includes('medoly')) {
    variants.push(cleaned.replace(/medoly/gi, 'melody'));
  }

  if (!/\bsongs?\b/.test(lower)) {
    variants.push(`${cleaned} songs`);
  }

  if (!lower.includes('movie')) {
    variants.push(`${cleaned} movie songs`);
  }

  if (!lower.includes('tamil')) {
    variants.push(`${cleaned} tamil songs`);
    variants.push(`${cleaned} tamil`);
  }

  const yearMatch = lower.match(/\b(19|20)\d{2}\b/);
  if (yearMatch) {
    const year = yearMatch[0];
    variants.push(`${year} tamil songs`, `${year} hits songs`, `${year} movie songs`);
  }

  // Add broader variants for hard-to-find songs
  variants.push(`${cleaned} full song`);
  variants.push(`${cleaned} jukebox`);
  variants.push(`${cleaned} audio song`);
  variants.push(`${cleaned} official`);

  // Sometimes users paste long prompts; short query helps recall
  const short = cleaned.split(' ').slice(0, 4).join(' ').trim();
  if (short && short !== cleaned) {
    variants.push(short, `${short} tamil`, `${short} songs`);
  }

  return [...new Set(variants.map(v => v.trim()).filter(Boolean))];
}

function normalizeSongTitle(value: string) {
  return normalizeQuery(value)
    .replace(/\(from\s+.*?\)/g, ' ')
    .replace(/\(.*?\)/g, ' ')
    .replace(/\b(remix|version|ver|live|karaoke|slowed|reverb|mashup|dj|mix|edit|cover)\b/g, ' ')
    .replace(/[^a-z0-9]/g, '');
}

function getTokens(value: string) {
  return normalizeQuery(value)
    .split(' ')
    .map((token) => token.trim())
    .filter((token) => token.length > 2);
}

function scoreCandidate(query: string, item: any) {
  const title = normalizeQuery(item?.name || item?.title || '');
  const artist = normalizeQuery(item?.artists?.primary?.[0]?.name || item?.primaryArtists || item?.artist || '');
  const album = normalizeQuery(item?.album || '');
  const lang = normalizeQuery(item?.language || item?.more_info?.language || '');
  const haystack = `${title} ${artist} ${album}`;
  const qNorm = normalizeQuery(query);
  const tokens = getTokens(qNorm);

  let score = 0;

  // Language match bonus: prioritized selected language
  if (qNorm.includes('tamil') && lang.includes('tamil')) score += 25;
  else if (qNorm.includes('telugu') && lang.includes('telugu')) score += 25;
  else if (qNorm.includes('hindi') && lang.includes('hindi')) score += 25;
  else if (qNorm.includes('malayalam') && lang.includes('malayalam')) score += 25;
  else if (qNorm.includes('kannada') && lang.includes('kannada')) score += 25;
  else if (qNorm.includes('english') && lang.includes('english')) score += 25;

  if (title.includes(qNorm)) score += 10;
  if (album.includes(qNorm)) score += 8;
  if (qNorm.includes(title) && title.length > 3) score += 4;
  for (const token of tokens) {
    if (title.includes(token)) score += 2;
    if (album.includes(token)) score += 2;
    if (artist.includes(token)) score += 1;
    if (haystack.includes(token)) score += 1;
  }
  return score;
}

function isLowQualityTrack(item: any) {
  const title = normalizeQuery(item?.name || item?.title || '');
  const durationSec = Number(item?.duration || item?.more_info?.duration || 0);
  if (durationSec > 0 && durationSec < 60) return true;
  if (/\b(promo|teaser|trailer|preview|clip|reel|shorts?|ringtone|status|interview|dialogue|speech|announcement|bgm|theme)\b/i.test(title)) {
    return true;
  }
  return false;
}

function getResultKey(item: any) {
  const title = normalizeSongTitle(item?.name || item?.title || item?.song || '');
  const artist = normalizeQuery(item?.artists?.primary?.[0]?.name || item?.primaryArtists || item?.artist || '').replace(/[^a-z0-9]/g, '');
  const album = normalizeQuery(item?.album || '').replace(/[^a-z0-9]/g, '');
  const lang = normalizeQuery(item?.language || item?.more_info?.language || '').replace(/[^a-z0-9]/g, '');
  const durationSec = Number(item?.duration || item?.more_info?.duration || 0);
  const durBucket = durationSec > 0 ? Math.round(durationSec / 6) : 0;

  if (title && (artist || album)) {
    return `${title}__${artist}__${album}__${lang}__${durBucket}`;
  }
  return item?.id ? String(item.id) : `${title}_${lang}_${durBucket}`;
}

function normalizeMediaUrl(url: string) {
  if (!url) return '';
  return url.startsWith('http://') ? `https://${url.slice(7)}` : url;
}

function extractBestDownloadUrl(source: any) {
  const candidates: string[] = [];

  if (Array.isArray(source?.downloadUrl)) {
    for (const entry of source.downloadUrl) {
      if (typeof entry === 'string') {
        candidates.push(entry);
      } else if (entry && typeof entry.url === 'string') {
        candidates.push(entry.url);
      } else if (entry && typeof entry.link === 'string') {
        candidates.push(entry.link);
      }
    }
  } else if (typeof source?.downloadUrl === 'string') {
    candidates.push(source.downloadUrl);
  }

  if (typeof source?.url === 'string') candidates.push(source.url);
  if (typeof source?.audioUrl === 'string') candidates.push(source.audioUrl);

  const normalized = candidates.map(normalizeMediaUrl).filter(Boolean);
  const preferred = normalized.find((url) => /(_320\.mp4|320kbps|\.flac|\.m4a|\.mp3)(\?|$)/i.test(url));
  return preferred || normalized[normalized.length - 1] || '';
}

function normalizeTrackRecord(source: any, fallbackTitle?: string) {
  const title = decodeHTMLEntities(String(source?.name || source?.title || source?.song || fallbackTitle || 'Unknown'));
  const artist = decodeHTMLEntities(
    String(
      source?.artists?.primary?.[0]?.name ||
      source?.primaryArtists ||
      source?.artist ||
      source?.singers ||
      'Unknown',
    ),
  );
  const album = decodeHTMLEntities(String(source?.album || ''));
  const rawLang = source?.language || source?.more_info?.language || '';
  const language = rawLang ? rawLang.charAt(0).toUpperCase() + rawLang.slice(1).toLowerCase() : '';
  const artwork =
    source?.artwork ||
    (Array.isArray(source?.image)
      ? source.image[source.image.length - 1]?.url || source.image[0]?.url || ''
      : source?.image || '');
  const downloadUrl = extractBestDownloadUrl(source);
  const downloadUrls = Array.isArray(source?.downloadUrl)
    ? source.downloadUrl
    : downloadUrl
      ? [{ quality: 'best', url: downloadUrl }]
      : [];

  return {
    ...source,
    id: source?.id,
    name: title,
    title,
    song: title,
    artist,
    primaryArtists: artist,
    album,
    language,
    artwork,
    image: Array.isArray(source?.image)
      ? source.image
      : artwork
        ? [
            { quality: '500x500', url: artwork },
            { quality: '150x150', url: artwork },
            { quality: '50x50', url: artwork },
          ]
        : [],
    url: downloadUrl,
    streamUrl: downloadUrl,
    audioUrl: downloadUrl,
    downloadUrl: downloadUrls,
  };
}

// Helper: call JioSaavn's actual API and parse response
export async function jiosaavnSearch(query: string, limit: number = 10, page: number = 1) {
  try {
    const response = await fetchWithRetry(() => axios.get(JIOSAAVN_BASE, {
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
      timeout: REQUEST_TIMEOUT_MS,
    }), 2);

    if (!response.data?.results) return [];

    // Map to clean format and attach the best playback URL for every client.
    return response.data.results
      .map((song: any) => normalizeTrackRecord({
      id: song.id,
      name: song.title || song.song || 'Unknown',
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
    }))
      .filter((track: any) => !isLowQualityTrack(track));
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
      timeout: 5000,
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
    const { query, page, limit, debug } = req.query;
    if (!query) {
      return res.status(400).json({ message: 'Query is required' });
    }
    const requestDebug = SEARCH_DEBUG || debug === '1' || debug === 'true';

    const pageNum = Math.max(parseInt(page as string) || 1, 1);
    const limitNum = Math.min(Math.max(parseInt(limit as string) || 30, 10), 100);
    const queryText = String(query);
    const cacheKey = `search_${queryText}_p${pageNum}_l${limitNum}`;
    if (cache.has(cacheKey)) {
      return res.json(cache.get(cacheKey));
    }

    let results: any[] = [];

    const trace: any[] = [];
    const fetchResults = async (q: string, pageForQuery: number) => {
      let fetched: any[] = [];
      let source = 'none';

      // Only try proxy if it's a real external URL (not localhost)
      if (hasProxy) {
        try {
          const response = await fetchWithRetry(() => axios.get(`${JIOSAAVN_API_URL}/api/search/songs`, {
            params: { query: q, limit: limitNum, page: pageForQuery },
            timeout: 8000,
          }), 2);
          if (response.data?.data?.results?.length > 0) {
            fetched = response.data.data.results.map((item: any) => normalizeTrackRecord(item));
            source = 'proxy';
          }
        } catch {
          // Proxy failed, fall through to direct API
        }
      }

      if (fetched.length === 0) {
        fetched = await jiosaavnSearch(q, limitNum, pageForQuery);
        if (fetched.length > 0) source = 'direct';
      }

      if (requestDebug) {
        trace.push({ query: q, page: pageForQuery, source, count: fetched.length });
      }

      return fetched;
    };

    const variants = buildSearchVariants(queryText);
    const merged: any[] = [];
    const seen = new Set<string>();

    for (const q of variants) {
      const pagesToTry = Array.from(new Set([pageNum, 1, 2, 3]));
      for (const pageToTry of pagesToTry) {
        const fetched = await fetchResults(q, pageToTry);
        fetched.forEach((item: any) => {
          const key = getResultKey(item);
          if (!seen.has(key)) {
            seen.add(key);
            merged.push(item);
          }
        });
        if (merged.length >= limitNum + 30) break;
      }
      if (merged.length >= limitNum + 30) break;
    }

    // Last-resort fuzzy fallback for difficult song/movie name queries
    if (merged.length < Math.max(5, Math.floor(limitNum / 2))) {
      const queryTokens = getTokens(queryText);
      const broadQueries = Array.from(new Set([
        `${queryText} tamil`,
        `${queryText} movie`,
        `${queryTokens.slice(0, 2).join(' ')} tamil songs`.trim(),
        `${queryTokens.slice(0, 1).join(' ')} tamil`.trim(),
      ])).filter(Boolean);

      for (const broad of broadQueries) {
        const fetched = await fetchResults(broad, 1);
        const scored = fetched
          .map((item: any) => ({ item, score: scoreCandidate(queryText, item) }))
          .filter((entry) => entry.score > 0)
          .sort((a, b) => b.score - a.score)
          .slice(0, limitNum);

        for (const entry of scored) {
          const key = getResultKey(entry.item);
          if (!seen.has(key)) {
            seen.add(key);
            merged.push(entry.item);
          }
        }
        if (merged.length >= limitNum + 30) break;
      }
    }

    // Prefer exact title matches for top ranking
    const qNorm = normalizeQuery(queryText);
    results = merged
      .map((item) => normalizeTrackRecord(item))
      .sort((a, b) => {
        const at = normalizeQuery(a?.name || a?.title || '');
        const bt = normalizeQuery(b?.name || b?.title || '');
        const aScore = (at.includes(qNorm) ? 2 : 0) + (qNorm.includes(at) ? 1 : 0) + scoreCandidate(queryText, a);
        const bScore = (bt.includes(qNorm) ? 2 : 0) + (qNorm.includes(bt) ? 1 : 0) + scoreCandidate(queryText, b);
        return bScore - aScore;
      })
      .slice(0, limitNum);

    const data = requestDebug
      ? { data: { results }, debug: { originalQuery: queryText, variants, trace, totalMerged: merged.length } }
      : { data: { results } };
    cache.set(cacheKey, data);
    if (requestDebug) {
      console.log('[search-debug]', JSON.stringify({
        query: queryText,
        variantsTried: variants.length,
        totalMerged: merged.length,
        returned: results.length,
        trace,
      }));
    }
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

    let langs = ['tamil'];
    if (languages && typeof languages === 'string') {
      langs = languages.split(',').map(l => l.trim().toLowerCase()).filter(Boolean);
      if (langs.length === 0) langs = ['tamil'];
    }

    const queries = langs
      .map(lang => `latest ${lang} songs`)
      .concat(langs.map(lang => `top ${lang} hits`))
      .concat(langs.map(lang => `${lang} movie songs`));
    const allTracks: any[] = [];

    // Only try proxy if it's a real external URL
    if (hasProxy) {
      try {
        const testResp = await axios.get(`${JIOSAAVN_API_URL}/api/search/songs`, {
          params: { query: queries[0], limit: 12, page: 1 },
          timeout: 3000,
        });
        if (testResp.data?.data?.results) {
          allTracks.push(...testResp.data.data.results.map((item: any) => normalizeTrackRecord(item)));
        }
      } catch {}
    }

    // Fetch remaining queries using direct API
    await Promise.all(queries.slice(hasProxy && allTracks.length > 0 ? 1 : 0).map(async (q) => {
      try {
        const [page1, page2] = await Promise.all([
          jiosaavnSearch(q, 10, 1),
          jiosaavnSearch(q, 10, 2),
        ]);
        const results = [...page1, ...page2];
        allTracks.push(...results);
      } catch (err: any) {
        console.error(`Trending fetch error for "${q}":`, err?.message);
      }
    }));

    // Deduplicate & strict language filter
    const seen = new Set();
    const unique = allTracks.filter(t => {
      Object.assign(t, normalizeTrackRecord(t));
      if (isLowQualityTrack(t)) return false;
      if (!t?.id) return false;

      // Filter out non-matching languages if language tag exists
      if (t.language && typeof t.language === 'string' && t.language.trim().length > 0) {
        const trackLang = t.language.toLowerCase();
        const matchesAny = langs.some(l => trackLang.includes(l));
        if (!matchesAny) return false;
      }

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

    // Try proxy only if available
    if (hasProxy) {
      try {
        const response = await axios.get(`${JIOSAAVN_API_URL}/api/songs/${id}`, { timeout: 4000 });
        const data = normalizeTrackRecord(response.data?.song || response.data?.data?.song || response.data?.data || response.data);
        cache.set(cacheKey, data);
        return res.json(data);
      } catch {}
    }

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
      timeout: 8000,
    });
    const data = normalizeTrackRecord(
      response.data?.songs?.[0] ||
      response.data?.results?.[0] ||
      response.data?.data?.songs?.[0] ||
      response.data?.data?.results?.[0] ||
      response.data?.data ||
      response.data,
    );
    cache.set(cacheKey, data);
    return res.json(data);
  } catch (error: any) {
    console.error('Song detail error:', error?.message);
    res.status(500).json({ message: 'Error fetching song details' });
  }
});

export default router;

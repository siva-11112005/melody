import { Router } from 'express';
import OpenAI from 'openai';
import axios from 'axios';
import { GoogleGenerativeAI } from '@google/generative-ai';
import { jiosaavnSearch } from './music.routes';

const router = Router();

// Helper to get AI suggestions using either Direct Gemini or OpenRouter
async function getAiSuggestions(prompt: string) {
  // 1. Try Direct Gemini if key is present
  const geminiKey = process.env.GEMINI_API_KEY;
  if (geminiKey && geminiKey !== 'your_gemini_api_key_here') {
    try {
      const genAI = new GoogleGenerativeAI(geminiKey);
      const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });
      const result = await model.generateContent(prompt);
      return result.response.text();
    } catch (err: any) {
      console.error('Direct Gemini failed:', err?.message);
    }
  }

  // 2. Try OpenRouter as fallback
  const openRouterKey = process.env.OPENROUTER_API_KEY;
  if (openRouterKey && openRouterKey !== 'dummy_key' && !openRouterKey.includes('localhost')) {
    try {
      const openai = new OpenAI({
        baseURL: 'https://openrouter.ai/api/v1',
        apiKey: openRouterKey,
        defaultHeaders: {
          'HTTP-Referer': 'https://github.com/tamil-music-app',
          'X-Title': 'Tamil Music App',
        },
      });

      const completion = await openai.chat.completions.create({
        model: 'google/gemini-1.5-flash',
        messages: [{ role: 'user', content: prompt }],
      });
      return completion.choices[0]?.message?.content || '';
    } catch (err: any) {
      console.error('OpenRouter failed:', err?.message);
    }
  }

  return '';
}

const hasAiConfigured = () => {
  const geminiKey = process.env.GEMINI_API_KEY;
  const openRouterKey = process.env.OPENROUTER_API_KEY;
  return (geminiKey && geminiKey !== 'your_gemini_api_key_here') || (openRouterKey && openRouterKey !== 'dummy_key');
};

const normalizeText = (value: string) => (
  value
    .toLowerCase()
    .replace(/\(from\s+.*?\)/g, ' ')
    .replace(/[^a-z0-9\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
);

const normalizeSongTitle = (value: string) => (
  normalizeText(value)
    .replace(/\(from\s+.*?\)/g, ' ')
    .replace(/\(.*?\)/g, ' ')
    .replace(/\b(remix|version|ver|live|karaoke|slowed|reverb|mashup|dj|mix|edit|cover)\b/g, ' ')
    .replace(/[^a-z0-9]/g, '')
);

const dedupePlaylistTracks = (tracks: any[]) => {
  const seen = new Set<string>();
  const output: any[] = [];
  for (const track of tracks) {
    const title = normalizeSongTitle(track?.title || track?.name || '');
    const artist = normalizeText(track?.artist || track?.primaryArtists || track?.artists?.primary?.[0]?.name || '').replace(/[^a-z0-9]/g, '');
    const key = `${title}:${artist}`;
    if (!title || seen.has(key)) continue;
    seen.add(key);
    output.push(track);
  }
  return output;
};

const scoreMatch = (query: string, title: string, artist: string) => {
  const q = normalizeText(query);
  const t = normalizeText(title);
  const a = normalizeText(artist);
  if (!q || !t) return 0;

  let score = 0;
  if (t.includes(q)) score += 5;
  if (q.includes(t)) score += 3;

  const qTokens = q.split(' ').filter(Boolean);
  qTokens.forEach((token) => {
    if (token.length > 2 && t.includes(token)) score += 1;
  });

  if (a && q.includes(a)) score += 1;
  return score;
};

const pickBestMatch = (query: string, results: any[]) => {
  if (!Array.isArray(results) || results.length === 0) return null;

  let best = results[0];
  let bestScore = scoreMatch(query, best.name || best.title || '', best.artists?.primary?.[0]?.name || best.artist || '');

  for (const item of results.slice(1)) {
    const score = scoreMatch(query, item.name || item.title || '', item.artists?.primary?.[0]?.name || item.artist || '');
    if (score > bestScore) {
      best = item;
      bestScore = score;
    }
  }

  return best;
};

const mapToPlaylistTrack = (track: any, fallbackTitle?: string) => ({
  id: track.id,
  title: track.name || track.title || fallbackTitle || 'Unknown',
  artist: track.artists?.primary?.[0]?.name || track.primaryArtists || track.artist || 'Unknown',
  image: track.image?.[track.image.length - 1]?.url || track.image?.[0]?.url || '',
  artwork: track.image?.[track.image.length - 1]?.url || track.image?.[0]?.url || '',
  url: track.downloadUrl?.[track.downloadUrl.length - 1]?.url || track.downloadUrl?.[0]?.url || track.url || '',
  duration: track.duration || 0,
  downloadUrl: track.downloadUrl || [],
});

async function searchSongsHelper(query: string, limit: number = 10) {
  const JIOSAAVN_API_URL = process.env.JIOSAAVN_API_URL || '';
  const hasProxy = JIOSAAVN_API_URL && !JIOSAAVN_API_URL.includes('localhost') && !JIOSAAVN_API_URL.includes('127.0.0.1');
  
  const q = query.trim();
  const variants = Array.from(new Set([
    q,
    `${q} tamil`,
    `${q} tamil full song`,
    `${q} audio song`,
  ]));

  for (const variant of variants) {
    if (hasProxy) {
      try {
        const res = await axios.get(`${JIOSAAVN_API_URL}/api/search/songs`, { params: { query: variant, limit }, timeout: 7000 });
        if (res.data?.data?.results?.length > 0) return res.data.data.results;
      } catch (err) {}
    }

    try {
      const direct = await jiosaavnSearch(variant, limit);
      if (direct.length > 0) return direct;
    } catch {}
  }
  return [];
}

// AI recommendations - no auth required for now
router.post('/recommend', async (req, res) => {
  try {
    const { mood, recentHistory } = req.body;

    if (!mood) {
      return res.status(400).json({ message: 'Mood is required' });
    }

    const prompt = `You are a music recommendation expert specializing in Indian and international music.
The user is in a "${mood}" mood.
Their recent listening history includes: ${recentHistory?.join(', ') || 'None provided'}.

Suggest 8 songs that fit this mood. Include a mix of Bollywood and English songs.
Return ONLY a valid JSON object with a "songs" key containing an array of objects, each with "title" and "artist" properties.
Example: {"songs": [{"title": "Shape of You", "artist": "Ed Sheeran"}]}`;

    if (!hasAiConfigured()) {
      const fallback = await searchSongsHelper(`${mood} songs`, 8);
      return res.json(fallback || []);
    }

    const aiResponse = await getAiSuggestions(prompt);
    let suggestions: any[] = [];
    
    try {
      // Try to extract JSON from the response
      const jsonMatch = aiResponse.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        const parsed = JSON.parse(jsonMatch[0]);
        suggestions = parsed.songs || parsed.suggestions || parsed;
        if (!Array.isArray(suggestions)) suggestions = [];
      }
    } catch (e) {
      console.error('Failed to parse AI response:', aiResponse);
      const fallback = await searchSongsHelper(`${mood} songs`, 8);
      return res.json(fallback || []);
    }

    // Search each suggestion
    let finalTracks: any[] = [];

    await Promise.all(suggestions.slice(0, 12).map(async (song: any) => {
      try {
        const query = `${song.title} ${song.artist}`;
        const results = await searchSongsHelper(query, 3);
        if (results.length > 0) {
          const best = pickBestMatch(query, results) || results[0];
          finalTracks.push(best);
        }
      } catch (err: any) {
        console.error(`Failed to fetch song ${song.title}:`, err?.message);
      }
    }));

    finalTracks = dedupePlaylistTracks(finalTracks).slice(0, 10);
    res.json(finalTracks);
  } catch (error: any) {
    console.error('AI Recommendation error:', error?.message);
    try {
      const fallback = await searchSongsHelper(`${req.body.mood || 'popular'} songs`, 10);
      res.json(fallback || []);
    } catch {
      res.status(500).json({ message: 'Error generating recommendations' });
    }
  }
});

// AI-powered playlist generator from text description
router.post('/generate-playlist', async (req, res) => {
  try {
    const { description } = req.body;

    if (!description) {
      return res.status(400).json({ message: 'Description is required' });
    }

    const prompt = `You are a Tamil music expert. The user wants a playlist based on: "${description}".

Generate a list of 15 Tamil song titles that match this description. 
If the user gives specific song names, include those and add similar songs.
Return ONLY a valid JSON object with a "songs" key containing an array of objects with "title" and "artist" properties.
Focus on real Tamil songs that exist on streaming platforms.
Example: {"songs": [{"title": "Nenjukkul Peidhidum", "artist": "Harris Jayaraj"}]}`;

    if (!hasAiConfigured()) {
      const fallback = await searchSongsHelper(`${description} tamil songs`, 15);
      const tracks = (fallback || []).slice(0, 15).map((t: any) => mapToPlaylistTrack(t, description));
      return res.json({ tracks });
    }

    const aiResponse = await getAiSuggestions(prompt);
    console.log('AI Response received');
    let suggestions: any[] = [];

    try {
      const jsonMatch = aiResponse.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        const parsed = JSON.parse(jsonMatch[0]);
        suggestions = parsed.songs || parsed.suggestions || parsed;
        if (!Array.isArray(suggestions)) suggestions = [];
      }
    } catch (e) {
      console.error('Failed to parse AI playlist response');
    }

    // Fallback if AI fails
    if (suggestions.length === 0) {
      console.log('No AI suggestions found, using fallback search');
      const fallback = await searchSongsHelper(`${description} tamil songs`, 15);
      const tracks = (fallback || []).slice(0, 15).map((t: any) => mapToPlaylistTrack(t, description));
      return res.json({ tracks });
    }


    const finalTracks: any[] = [];

    await Promise.all(suggestions.slice(0, 20).map(async (song: any) => {
      try {
        const query = `${song.title} ${song.artist || ''} tamil`;
        console.log(`AI Searching for: ${query}`);
        const results = await searchSongsHelper(query, 5);
        console.log(`Search for "${song.title}" returned ${results.length} results`);

        if (results.length > 0) {
          const track = pickBestMatch(query, results) || results[0];
          finalTracks.push(mapToPlaylistTrack(track, song.title));
        }
      } catch (err: any) {
        console.error(`Failed to fetch: ${song.title}`, err?.message);
      }
    }));

    const cleanedTracks = dedupePlaylistTracks(finalTracks).slice(0, 15);
    console.log(`Generated ${cleanedTracks.length} tracks for AI playlist`);
    res.json({ tracks: cleanedTracks, suggestions });


  } catch (error: any) {
    console.error('AI Playlist generation error:', error?.message);
    res.status(500).json({ message: 'Error generating playlist' });
  }
});

// Resolve comma-separated song names to actual tracks
router.post('/resolve-songs', async (req, res) => {
  try {
    const { songNames } = req.body;

    if (!songNames || !Array.isArray(songNames) || songNames.length === 0) {
      return res.status(400).json({ message: 'songNames array is required' });
    }

    const tracks: any[] = [];

    await Promise.all(songNames.slice(0, 30).map(async (name: string) => {
      try {
        const trimmed = name.trim();
        if (!trimmed) return;
        const results = await searchSongsHelper(trimmed, 8);
        if (results.length > 0) {
          const best = pickBestMatch(trimmed, results) || results[0];
          tracks.push(mapToPlaylistTrack(best, trimmed));
        }
      } catch (err: any) {
        console.error(`Failed to resolve: ${name}`, err?.message);
      }
    }));

    res.json({ tracks: dedupePlaylistTracks(tracks) });
  } catch (error: any) {
    console.error('Resolve songs error:', error?.message);
    res.status(500).json({ message: 'Error resolving songs' });
  }
});

export default router;

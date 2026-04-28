import { Router } from 'express';
import OpenAI from 'openai';
import axios from 'axios';

const router = Router();

const openai = new OpenAI({
  baseURL: 'https://openrouter.ai/api/v1',
  apiKey: process.env.OPENROUTER_API_KEY || 'dummy_key',
});

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

    const completion = await openai.chat.completions.create({
      model: 'google/gemini-2.5-flash-preview-05-20',
      messages: [
        { role: 'user', content: prompt }
      ],
    });

    const aiResponse = completion.choices[0]?.message?.content || '';
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
      // Fallback: return trending songs instead
      const JIOSAAVN_API_URL = process.env.JIOSAAVN_API_URL || 'http://localhost:3000';
      const fallback = await axios.get(`${JIOSAAVN_API_URL}/api/search/songs`, {
        params: { query: `${mood} songs`, limit: 8 }
      });
      return res.json(fallback.data?.data?.results || []);
    }

    // Search each suggestion on JioSaavn
    const JIOSAAVN_API_URL = process.env.JIOSAAVN_API_URL || 'http://localhost:3000';
    const finalTracks: any[] = [];

    await Promise.all(suggestions.slice(0, 8).map(async (song: any) => {
      try {
        const query = `${song.title} ${song.artist}`;
        const searchRes = await axios.get(`${JIOSAAVN_API_URL}/api/search/songs`, {
          params: { query, limit: 1 }
        });
        
        if (searchRes.data?.data?.results?.length > 0) {
          finalTracks.push(searchRes.data.data.results[0]);
        }
      } catch (err: any) {
        console.error(`Failed to fetch song ${song.title}:`, err?.message);
      }
    }));

    res.json(finalTracks);
  } catch (error: any) {
    console.error('AI Recommendation error:', error?.message);
    // Fallback to mood-based search
    try {
      const JIOSAAVN_API_URL = process.env.JIOSAAVN_API_URL || 'http://localhost:3000';
      const fallback = await axios.get(`${JIOSAAVN_API_URL}/api/search/songs`, {
        params: { query: `${req.body.mood || 'popular'} songs`, limit: 10 }
      });
      res.json(fallback.data?.data?.results || []);
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

    const completion = await openai.chat.completions.create({
      model: 'google/gemini-2.5-flash-preview-05-20',
      messages: [
        { role: 'user', content: prompt }
      ],
    });

    const aiResponse = completion.choices[0]?.message?.content || '';
    let suggestions: any[] = [];

    try {
      const jsonMatch = aiResponse.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        const parsed = JSON.parse(jsonMatch[0]);
        suggestions = parsed.songs || parsed.suggestions || parsed;
        if (!Array.isArray(suggestions)) suggestions = [];
      }
    } catch (e) {
      console.error('Failed to parse AI playlist response:', aiResponse);
      return res.status(500).json({ message: 'AI could not generate playlist' });
    }

    // Search each suggestion on JioSaavn to get real track data
    const JIOSAAVN_API_URL = process.env.JIOSAAVN_API_URL || 'http://localhost:3000';
    const finalTracks: any[] = [];

    await Promise.all(suggestions.slice(0, 15).map(async (song: any) => {
      try {
        const query = `${song.title} ${song.artist || ''} tamil`;
        const searchRes = await axios.get(`${JIOSAAVN_API_URL}/api/search/songs`, {
          params: { query, limit: 1 },
          timeout: 4000,
        });

        if (searchRes.data?.data?.results?.length > 0) {
          const track = searchRes.data.data.results[0];
          finalTracks.push({
            id: track.id,
            title: track.name || song.title,
            artist: track.artists?.primary?.[0]?.name || song.artist || 'Unknown',
            image: track.image?.[track.image.length - 1]?.url || track.image?.[0]?.url || '',
            artwork: track.image?.[track.image.length - 1]?.url || '',
            url: track.downloadUrl?.[track.downloadUrl.length - 1]?.url || track.downloadUrl?.[0]?.url || '',
            duration: track.duration || 0,
          });
        }
      } catch (err: any) {
        console.error(`Failed to fetch: ${song.title}`, err?.message);
      }
    }));

    res.json({ tracks: finalTracks });
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

    const JIOSAAVN_API_URL = process.env.JIOSAAVN_API_URL || 'http://localhost:3000';
    const tracks: any[] = [];

    await Promise.all(songNames.slice(0, 30).map(async (name: string) => {
      try {
        const searchRes = await axios.get(`${JIOSAAVN_API_URL}/api/search/songs`, {
          params: { query: name.trim(), limit: 1 },
          timeout: 4000,
        });

        if (searchRes.data?.data?.results?.length > 0) {
          const track = searchRes.data.data.results[0];
          tracks.push({
            id: track.id,
            title: track.name || name,
            artist: track.artists?.primary?.[0]?.name || 'Unknown',
            image: track.image?.[track.image.length - 1]?.url || track.image?.[0]?.url || '',
            artwork: track.image?.[track.image.length - 1]?.url || '',
            url: track.downloadUrl?.[track.downloadUrl.length - 1]?.url || track.downloadUrl?.[0]?.url || '',
            duration: track.duration || 0,
          });
        }
      } catch (err: any) {
        console.error(`Failed to resolve: ${name}`, err?.message);
      }
    }));

    res.json({ tracks });
  } catch (error: any) {
    console.error('Resolve songs error:', error?.message);
    res.status(500).json({ message: 'Error resolving songs' });
  }
});

export default router;

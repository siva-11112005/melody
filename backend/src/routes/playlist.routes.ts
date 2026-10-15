import { Router } from 'express';
import { Playlist } from '../models/Playlist';
import { authenticateToken, AuthRequest } from '../middleware/auth';

const router = Router();

// Get all playlists for logged in user
router.get('/', authenticateToken, async (req: AuthRequest, res) => {
  try {
    const playlists = await Playlist.find({ userId: req.user?.id })
      .sort({ createdAt: -1 })
      .lean();
    res.json(playlists);
  } catch (error) {
    console.error('Fetch playlists error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Create a new playlist
router.post('/', authenticateToken, async (req: AuthRequest, res) => {
  try {
    const name = typeof req.body?.name === 'string' ? req.body.name.trim() : '';
    if (!name) return res.status(400).json({ message: 'Playlist name is required' });
    if (name.length > 100) return res.status(400).json({ message: 'Playlist name is too long' });

    const newPlaylist = new Playlist({
      userId: req.user?.id,
      name,
      tracks: []
    });

    await newPlaylist.save();
    res.status(201).json(newPlaylist);
  } catch (error) {
    console.error('Create playlist error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Add multiple tracks in one atomic request.
router.post('/:id/tracks/bulk', authenticateToken, async (req: AuthRequest, res) => {
  try {
    const tracks = Array.isArray(req.body?.tracks) ? req.body.tracks : [];
    if (tracks.length === 0) {
      return res.status(400).json({ message: 'At least one track is required' });
    }
    if (tracks.length > 100) {
      return res.status(400).json({ message: 'Too many tracks in one request' });
    }

    const playlist = await Playlist.findOne({ _id: req.params.id, userId: req.user?.id });
    if (!playlist) return res.status(404).json({ message: 'Playlist not found' });

    const existingIds = new Set(playlist.tracks.map((track) => track.id));
    const newTracks = tracks.filter((track: any) =>
      track && typeof track.id === 'string' && track.id && !existingIds.has(track.id),
    );

    if (newTracks.length > 0) {
      playlist.tracks.push(...newTracks);
      await playlist.save();
    }

    res.json(playlist);
  } catch (error) {
    console.error('Bulk add tracks error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Add track to playlist
router.post('/:id/tracks', authenticateToken, async (req: AuthRequest, res) => {
  try {
    const { id } = req.params;
    const { track } = req.body;
    if (!track || typeof track.id !== 'string' || !track.id) {
      return res.status(400).json({ message: 'A valid track is required' });
    }

    const playlist = await Playlist.findOne({ _id: id, userId: req.user?.id });
    if (!playlist) return res.status(404).json({ message: 'Playlist not found' });

    // Check if track already exists
    if (playlist.tracks.some(t => t.id === track.id)) {
      return res.status(400).json({ message: 'Track already in playlist' });
    }

    playlist.tracks.push(track);
    await playlist.save();

    res.json(playlist);
  } catch (error) {
    console.error('Add track error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Remove track from playlist
router.delete('/:id/tracks/:trackId', authenticateToken, async (req: AuthRequest, res) => {
  try {
    const { id, trackId } = req.params;

    const playlist = await Playlist.findOne({ _id: id, userId: req.user?.id });
    if (!playlist) return res.status(404).json({ message: 'Playlist not found' });

    playlist.tracks = playlist.tracks.filter(t => t.id !== trackId);
    await playlist.save();

    res.json(playlist);
  } catch (error) {
    console.error('Remove track error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Delete playlist
router.delete('/:id', authenticateToken, async (req: AuthRequest, res) => {
  try {
    const { id } = req.params;
    await Playlist.findOneAndDelete({ _id: id, userId: req.user?.id });
    res.json({ message: 'Playlist deleted' });
  } catch (error) {
    console.error('Delete playlist error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

export default router;

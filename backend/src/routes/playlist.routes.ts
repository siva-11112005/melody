import { Router } from 'express';
import { Playlist } from '../models/Playlist';
import { authenticateToken, AuthRequest } from '../middleware/auth';

const router = Router();

// Get all playlists for logged in user
router.get('/', authenticateToken, async (req: AuthRequest, res) => {
  try {
    const playlists = await Playlist.find({ userId: req.user?.id }).sort({ createdAt: -1 });
    res.json(playlists);
  } catch (error) {
    console.error('Fetch playlists error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Create a new playlist
router.post('/', authenticateToken, async (req: AuthRequest, res) => {
  try {
    const { name } = req.body;
    if (!name) return res.status(400).json({ message: 'Playlist name is required' });

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

// Add track to playlist
router.post('/:id/tracks', authenticateToken, async (req: AuthRequest, res) => {
  try {
    const { id } = req.params;
    const { track } = req.body; // Expecting full track object

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

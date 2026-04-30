import mongoose from 'mongoose';

const playlistSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  name: {
    type: String,
    required: true,
  },
  tracks: [{
    id: String, // JioSaavn Track ID
    title: String,
    artist: String,
    image: String,
    artwork: String, // High quality image for player
    url: String, // Streaming URL
    duration: Number,
    downloadUrl: mongoose.Schema.Types.Mixed, // Array of {quality, url} objects
  }],
  createdAt: {
    type: Date,
    default: Date.now,
  }
});

export const Playlist = mongoose.model('Playlist', playlistSchema);

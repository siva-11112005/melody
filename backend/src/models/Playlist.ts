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
    url: String, // Streaming URL
    duration: Number,
  }],
  createdAt: {
    type: Date,
    default: Date.now,
  }
});

export const Playlist = mongoose.model('Playlist', playlistSchema);

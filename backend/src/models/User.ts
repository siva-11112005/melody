import mongoose from 'mongoose';

const userSchema = new mongoose.Schema({
  email: {
    type: String,
    required: true,
    unique: true,
    lowercase: true,
  },
  passwordHash: {
    type: String,
    required: true,
  },
  recentlyPlayed: {
    type: [Object],
    default: [],
  },
  onboardingComplete: {
    type: Boolean,
    default: false,
  },
  preferredLanguages: {
    type: [String],
    default: [],
  },
  favoriteArtists: {
    type: [String],
    default: [],
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
});

export const User = mongoose.model('User', userSchema);

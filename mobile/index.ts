import { registerRootComponent } from 'expo';
import { NativeModules } from 'react-native';

// Mock TrackPlayer native module if it doesn't exist (e.g., in Expo Go)
if (!NativeModules.TrackPlayerModule) {
  NativeModules.TrackPlayerModule = {
    // Constants
    CAPABILITY_PLAY: 1,
    CAPABILITY_PLAY_FROM_ID: 2,
    CAPABILITY_PLAY_FROM_SEARCH: 3,
    CAPABILITY_PAUSE: 4,
    CAPABILITY_STOP: 5,
    CAPABILITY_SEEK_TO: 6,
    CAPABILITY_SKIP: 7,
    CAPABILITY_SKIP_TO_NEXT: 8,
    CAPABILITY_SKIP_TO_PREVIOUS: 9,
    CAPABILITY_SET_RATING: 10,
    CAPABILITY_JUMP_FORWARD: 11,
    CAPABILITY_JUMP_BACKWARD: 12,
    CAPABILITY_LIKE: 13,
    CAPABILITY_DISLIKE: 14,
    CAPABILITY_BOOKMARK: 15,
    
    REPEAT_OFF: 0,
    REPEAT_TRACK: 1,
    REPEAT_QUEUE: 2,
    
    PITCH_ALGORITHM_LINEAR: 'linear',
    PITCH_ALGORITHM_MUSIC: 'music',
    PITCH_ALGORITHM_VOICE: 'voice',
    
    RATING_HEART: 0,
    RATING_THUMBS_UP_DOWN: 1,
    RATING_3_STARS: 2,
    RATING_4_STARS: 3,
    RATING_5_STARS: 4,
    RATING_PERCENTAGE: 5,

    // Methods
    setupPlayer: () => Promise.resolve(),
    updateOptions: () => Promise.resolve(),
    registerPlaybackService: () => {},
    addEventListener: () => ({ remove: () => {} }),
    add: () => Promise.resolve(),
    load: () => Promise.resolve(),
    move: () => Promise.resolve(),
    remove: () => Promise.resolve(),
    removeUpcomingTracks: () => Promise.resolve(),
    skip: () => Promise.resolve(),
    skipToNext: () => Promise.resolve(),
    skipToPrevious: () => Promise.resolve(),
    updateMetadataForTrack: () => Promise.resolve(),
    clearNowPlayingMetadata: () => Promise.resolve(),
    updateNowPlayingMetadata: () => Promise.resolve(),
    reset: () => Promise.resolve(),
    play: () => Promise.resolve(),
    pause: () => Promise.resolve(),
    stop: () => Promise.resolve(),
    setPlayWhenReady: () => Promise.resolve(true),
    getPlayWhenReady: () => Promise.resolve(true),
    seekTo: () => Promise.resolve(),
    seekBy: () => Promise.resolve(),
    setVolume: () => Promise.resolve(),
    setRate: () => Promise.resolve(),
    setQueue: () => Promise.resolve(),
    setRepeatMode: () => Promise.resolve(0),
    getVolume: () => Promise.resolve(1.0),
    getRate: () => Promise.resolve(1.0),
    getTrack: () => Promise.resolve(undefined),
    getQueue: () => Promise.resolve([]),
    getActiveTrackIndex: () => Promise.resolve(undefined),
    getActiveTrack: () => Promise.resolve(undefined),
    getDuration: () => Promise.resolve(0),
    getBufferedPosition: () => Promise.resolve(0),
    getPosition: () => Promise.resolve(0),
    getProgress: () => Promise.resolve({ position: 0, duration: 0, buffered: 0 }),
    getPlaybackState: () => Promise.resolve({ state: 'none' }),
    getRepeatMode: () => Promise.resolve(0),
    retry: () => Promise.resolve(),
  };
}

import TrackPlayer from 'react-native-track-player';
import App from './App';

// registerRootComponent calls AppRegistry.registerComponent('main', () => App);
// It also ensures that whether you load the app in Expo Go or in a native build,
// the environment is set up appropriately
TrackPlayer.registerPlaybackService(() => require('./src/services/playbackService'));
registerRootComponent(App);

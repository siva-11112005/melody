import { create } from 'zustand';

interface PlayerState {
  currentTrack: any | null;
  isPlaying: boolean;
  audioUrl: string | null;
  position: number;
  duration: number;
  queue: any[];
  currentIndex: number;
  setCurrentTrack: (track: any) => void;
  setIsPlaying: (isPlaying: boolean) => void;
  setPosition: (pos: number) => void;
  setDuration: (dur: number) => void;
  playTrack: (track: any, queue?: any[]) => void;
  playNext: () => void;
  playPrevious: () => void;
  pause: () => void;
  resume: () => void;
  seekTo: (positionMillis: number) => void;
  removeFromQueue: (trackId: string) => void;
  setQueue: (queue: any[]) => void;
  _seekRequested: number | null;
}

const normalizeDuration = (value: number | undefined) => {
  if (!value || value <= 0) return 0;
  return value < 1000 ? value * 1000 : value;
};

const resolveAudioUrl = (track: any): string | undefined => {
  if (track.localUri) return track.localUri;
  if (track.url) return track.url;
  if (Array.isArray(track.downloadUrl) && track.downloadUrl.length > 0) {
    const best = track.downloadUrl[track.downloadUrl.length - 1];
    if (typeof best === 'string') return best;
    if (best?.url) return best.url;
  }
  return undefined;
};

export const usePlayerStore = create<PlayerState>((set, get) => ({
  currentTrack: null,
  isPlaying: false,
  audioUrl: null,
  position: 0,
  duration: 0,
  queue: [],
  currentIndex: -1,
  _seekRequested: null,
  setCurrentTrack: (track) => set({ currentTrack: track }),
  setIsPlaying: (isPlaying) => set({ isPlaying }),
  setPosition: (pos) => set({ position: pos }),
  setDuration: (dur) => set({ duration: dur }),
  
  playTrack: (track, newQueue) => {
    const queue = newQueue || get().queue;
    const index = queue.findIndex((t) => t.id === track.id);
    set({ 
      currentTrack: track, 
      isPlaying: true, 
      audioUrl: resolveAudioUrl(track), 
      position: 0,
      duration: normalizeDuration(track?.duration),
      queue,
      currentIndex: index >= 0 ? index : 0,
      _seekRequested: null,
    });
  },

  playNext: () => {
    const { queue, currentIndex } = get();
    if (queue.length > 0 && currentIndex < queue.length - 1) {
      const nextTrack = queue[currentIndex + 1];
      set({ 
        currentTrack: nextTrack, 
        isPlaying: true, 
        audioUrl: resolveAudioUrl(nextTrack), 
        position: 0,
        duration: normalizeDuration(nextTrack?.duration),
        currentIndex: currentIndex + 1,
        _seekRequested: null,
      });
    }
  },

  playPrevious: () => {
    const { queue, currentIndex } = get();
    if (queue.length > 0 && currentIndex > 0) {
      const prevTrack = queue[currentIndex - 1];
      set({ 
        currentTrack: prevTrack, 
        isPlaying: true, 
        audioUrl: resolveAudioUrl(prevTrack), 
        position: 0,
        duration: normalizeDuration(prevTrack?.duration),
        currentIndex: currentIndex - 1,
        _seekRequested: null,
      });
    }
  },
  
  pause: () => {
    set({ isPlaying: false });
  },
  
  resume: () => {
    set({ isPlaying: true });
  },

  seekTo: (positionMillis: number) => {
    set({ _seekRequested: positionMillis });
  },

  removeFromQueue: (trackId: string) => {
    const { queue, currentIndex, currentTrack } = get();
    const newQueue = queue.filter(t => t.id !== trackId);
    let newIndex = newQueue.findIndex(t => t.id === currentTrack?.id);
    set({ queue: newQueue, currentIndex: newIndex });
  },
  setQueue: (newQueue: any[]) => {
    const { currentTrack } = get();
    let newIndex = newQueue.findIndex(t => t.id === currentTrack?.id);
    set({ queue: newQueue, currentIndex: newIndex });
  },
}));

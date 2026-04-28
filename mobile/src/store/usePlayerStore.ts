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
  _seekRequested: number | null;
}

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
      audioUrl: track.url || track.downloadUrl?.[0]?.url, 
      position: 0,
      duration: 0,
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
        audioUrl: nextTrack.url || nextTrack.downloadUrl?.[0]?.url, 
        position: 0,
        duration: 0,
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
        audioUrl: prevTrack.url || prevTrack.downloadUrl?.[0]?.url, 
        position: 0,
        duration: 0,
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
}));

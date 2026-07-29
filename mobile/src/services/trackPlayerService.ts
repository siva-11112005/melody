import TrackPlayer, {
  AppKilledPlaybackBehavior,
  Capability,
  Event,
  IOSCategory,
  IOSCategoryMode,
  IOSCategoryOptions,
  RepeatMode,
  State,
} from 'react-native-track-player';
import { usePlayerStore } from '../store/usePlayerStore';

let initialized = false;

export async function setupTrackPlayer() {
  if (initialized) return;
  await TrackPlayer.setupPlayer({
    autoHandleInterruptions: true,
    iosCategory: IOSCategory.Playback,
    iosCategoryMode: IOSCategoryMode.Default,
    iosCategoryOptions: [IOSCategoryOptions.AllowBluetoothA2DP, IOSCategoryOptions.AllowAirPlay],
    autoUpdateMetadata: true,
  });
  await TrackPlayer.updateOptions({
    android: {
      appKilledPlaybackBehavior: AppKilledPlaybackBehavior.ContinuePlayback,
      alwaysPauseOnInterruption: true,
    },
    capabilities: [
      Capability.Play,
      Capability.Pause,
      Capability.SkipToNext,
      Capability.SkipToPrevious,
      Capability.SeekTo,
      Capability.Stop,
    ],
    compactCapabilities: [Capability.Play, Capability.Pause, Capability.SkipToNext],
    notificationCapabilities: [
      Capability.Play,
      Capability.Pause,
      Capability.SkipToNext,
      Capability.SkipToPrevious,
      Capability.Stop,
      Capability.SeekTo,
    ],
    progressUpdateEventInterval: 2,
  });
  await TrackPlayer.setRepeatMode(RepeatMode.Off);
  initialized = true;
}

export function bindTrackPlayerEvents() {
  const subs = [
    TrackPlayer.addEventListener(Event.PlaybackState, async ({ state }) => {
      const playing = state === State.Playing || state === State.Buffering;
      usePlayerStore.setState({ isPlaying: playing });
    }),
    TrackPlayer.addEventListener(Event.PlaybackProgressUpdated, ({ position, duration }) => {
      usePlayerStore.setState({
        position: Math.floor((position || 0) * 1000),
        duration: Math.floor((duration || 0) * 1000),
      });
    }),
    TrackPlayer.addEventListener(Event.PlaybackQueueEnded, async () => {
      const store = usePlayerStore.getState();
      if (store.autoPlayNextEnabled) {
        store.setIsPlaying(false);
      }
    }),
    TrackPlayer.addEventListener(Event.PlaybackError, async () => {
      try {
        const current = await TrackPlayer.getCurrentTrack();
        if (typeof current === 'number') {
          await TrackPlayer.retry();
          await TrackPlayer.play();
          return;
        }
      } catch {}
      usePlayerStore.setState({ isPlaying: false });
    }),
    TrackPlayer.addEventListener(Event.PlaybackActiveTrackChanged, async ({ index }) => {
      const store = usePlayerStore.getState();
      if (typeof index === 'number' && index >= 0 && index < store.queue.length) {
        const nextTrack = store.queue[index];
        usePlayerStore.setState({
          currentTrack: nextTrack,
          currentIndex: index,
          audioUrl: nextTrack?.url || null,
        });
      }
    }),
  ];
  return () => {
    subs.forEach((sub) => sub.remove());
  };
}

export async function loadQueueAndPlay(queue: any[], startIndex: number) {
  await setupTrackPlayer();
  await TrackPlayer.reset();
  const validQueue = queue.filter((item) => !!(item?.localUri || item?.url));
  if (validQueue.length === 0) return;
  await TrackPlayer.add(
    validQueue.map((item, idx) => ({
      id: String(item.id || idx),
      url: item.localUri || item.url,
      title: item.title || 'Unknown',
      artist: item.artist || 'Unknown',
      artwork: item.artwork,
      duration: item.duration ? item.duration / 1000 : undefined,
    }))
  );
  const safeIndex = Math.min(Math.max(0, startIndex), validQueue.length - 1);
  await TrackPlayer.skip(safeIndex);
  await TrackPlayer.play();
}

export async function seekToMillis(positionMillis: number) {
  await TrackPlayer.seekTo(Math.max(0, positionMillis) / 1000);
}

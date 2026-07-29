import TrackPlayer, { Event } from 'react-native-track-player';

module.exports = async function () {
  TrackPlayer.addEventListener(Event.RemotePlay, async () => {
    await TrackPlayer.play();
  });

  TrackPlayer.addEventListener(Event.RemotePause, async () => {
    await TrackPlayer.pause();
  });

  TrackPlayer.addEventListener(Event.RemoteNext, async () => {
    try {
      await TrackPlayer.skipToNext();
    } catch {}
  });

  TrackPlayer.addEventListener(Event.RemotePrevious, async () => {
    try {
      await TrackPlayer.skipToPrevious();
    } catch {}
  });

  TrackPlayer.addEventListener(Event.RemoteStop, async () => {
    await TrackPlayer.stop();
  });

  TrackPlayer.addEventListener(Event.RemoteSeek, async (event: any) => {
    const position = Number(event?.position || 0);
    await TrackPlayer.seekTo(Math.max(0, position)).catch(() => {});
  });

  TrackPlayer.addEventListener(Event.RemoteDuck, async (event: any) => {
    if (event?.paused) {
      await TrackPlayer.pause();
      return;
    }
    if (event?.permanent) return;
    if (event?.ducking) return;
    await TrackPlayer.play().catch(() => {});
  });
};

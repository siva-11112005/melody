import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:just_audio_background/just_audio_background.dart';

import '../models/track.dart';
import '../services/download_service.dart';

class PlayerState extends ChangeNotifier {
  final ja.AudioPlayer _audioPlayer = ja.AudioPlayer();
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<ja.PlayerState>? _playerStateSub;
  Timer? _positionNotifyTimer;
  bool _disposed = false;
  bool _wasPlayingBeforeInterruption = false;

  Track? currentTrack;
  List<Track> queue = [];
  int currentIndex = -1;

  bool isPlaying = false;
  int positionMs = 0;
  int durationMs = 0;
  bool shuffleEnabled = false;
  bool repeatEnabled = false;
  int? sleepTimerMinutes;
  bool autoPlayNextEnabled = true;

  Timer? _sleepTimer;
  final DownloadService _downloadService = DownloadService();
  final Map<String, Track?> _downloadedTrackCache = {};

  PlayerState() {
    _initAudioSession();

    _positionSub = _audioPlayer.positionStream.listen((p) {
      positionMs = p.inMilliseconds;
      _schedulePositionNotify();
    });

    _playerStateSub = _audioPlayer.playerStateStream.listen((state) {
      isPlaying = state.playing;
      if (state.processingState == ja.ProcessingState.completed) {
        playNext();
      }
      notifyListeners();
    });

    _audioPlayer.durationStream.listen((d) {
      durationMs = d?.inMilliseconds ?? 0;
      notifyListeners();
    });
  }

  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      session.interruptionEventStream.listen((event) {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _audioPlayer.setVolume(0.5);
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              _wasPlayingBeforeInterruption = isPlaying;
              if (isPlaying) {
                _audioPlayer.pause();
              }
              break;
          }
        } else {
          _audioPlayer.setVolume(1.0);
          switch (event.type) {
            case AudioInterruptionType.duck:
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              if (_wasPlayingBeforeInterruption && currentTrack != null) {
                _audioPlayer.play();
                _wasPlayingBeforeInterruption = false;
              }
              break;
          }
        }
      });

      session.becomingNoisyEventStream.listen((_) {
        pause();
      });
    } catch (e) {
      debugPrint('AudioSession init error: $e');
    }
  }

  void _schedulePositionNotify() {
    if (_positionNotifyTimer?.isActive == true) return;
    _positionNotifyTimer = Timer(const Duration(milliseconds: 200), () {
      if (!_disposed) {
        notifyListeners();
      }
    });
  }

  String _downloadLookupKey(Track track) {
    return track.id.isNotEmpty ? track.id : '${track.title}_${track.artist}'.toLowerCase();
  }

  Future<void> playTrack(Track track, {List<Track>? contextQueue}) async {
    queue = contextQueue ?? queue;
    if (queue.isEmpty) {
      queue = [track];
    }
    currentIndex = queue.indexWhere((e) => e.id == track.id);
    if (currentIndex < 0) currentIndex = 0;

    final cacheKey = _downloadLookupKey(track);
    final cachedDownloaded = _downloadedTrackCache.containsKey(cacheKey) ? _downloadedTrackCache[cacheKey] : null;
    final downloadedTrack = track.localUri != null
        ? track
        : cachedDownloaded ?? await _downloadService.findDownloadedTrackFor(track);
    _downloadedTrackCache[cacheKey] = downloadedTrack;
    final playableTrack = downloadedTrack ?? track;

    currentTrack = playableTrack;
    durationMs = playableTrack.durationMs;
    positionMs = 0;
    notifyListeners();

    final url = playableTrack.localUri ?? playableTrack.url;
    if (url == null || url.isEmpty) return;

    final mediaItem = MediaItem(
      id: playableTrack.id.isNotEmpty ? playableTrack.id : url,
      album: playableTrack.album ?? 'Tamil Music',
      title: playableTrack.title,
      artist: playableTrack.artist,
      artUri: playableTrack.artwork != null && playableTrack.artwork!.isNotEmpty
          ? Uri.tryParse(playableTrack.artwork!)
          : null,
      duration: playableTrack.durationMs > 0 ? Duration(milliseconds: playableTrack.durationMs) : null,
    );

    try {
      if (playableTrack.localUri != null) {
        await _audioPlayer.setAudioSource(
          ja.AudioSource.file(playableTrack.localUri!, tag: mediaItem),
          preload: true,
        );
      } else {
        await _audioPlayer.setAudioSource(
          ja.AudioSource.uri(Uri.parse(url), tag: mediaItem),
          preload: true,
        );
      }
      _audioPlayer.play();
    } catch (e) {
      debugPrint('Playback error: $e');
      playNext();
    }
  }

  Future<void> stopPlayback() async {
    await _audioPlayer.stop();
    isPlaying = false;
    currentTrack = null;
    notifyListeners();
  }

  void setSleepTimer(int minutes) {
    sleepTimerMinutes = minutes;
    _sleepTimer?.cancel();
    _sleepTimer = Timer(Duration(minutes: minutes), () {
      pause();
    });
    notifyListeners();
  }

  void clearSleepTimer() {
    sleepTimerMinutes = null;
    _sleepTimer?.cancel();
    _sleepTimer = null;
    notifyListeners();
  }

  void setAutoPlayNextEnabled(bool enabled) {
    autoPlayNextEnabled = enabled;
    notifyListeners();
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  Future<void> resume() async {
    await _audioPlayer.play();
  }

  Future<void> seekTo(int millis) async {
    await _audioPlayer.seek(Duration(milliseconds: millis));
  }

  Future<void> playNext() async {
    if (queue.isEmpty) return;
    if (shuffleEnabled && queue.length > 1) {
      final candidates = List<Track>.from(queue);
      candidates.removeWhere((e) => e.id == currentTrack?.id);
      final next = candidates[(DateTime.now().millisecondsSinceEpoch) % candidates.length];
      await playTrack(next, contextQueue: queue);
      return;
    }
    if (currentIndex >= queue.length - 1) {
      if (repeatEnabled || autoPlayNextEnabled) {
        if (queue.isNotEmpty) {
          currentIndex = 0;
          await playTrack(queue[0], contextQueue: queue);
        }
      } else {
        await pause();
      }
      return;
    }
    currentIndex += 1;
    await playTrack(queue[currentIndex], contextQueue: queue);
  }

  Future<void> playPrevious() async {
    if (queue.isEmpty || currentIndex <= 0) return;
    currentIndex -= 1;
    await playTrack(queue[currentIndex], contextQueue: queue);
  }

  void toggleShuffle() {
    shuffleEnabled = !shuffleEnabled;
    notifyListeners();
  }

  void toggleRepeat() {
    repeatEnabled = !repeatEnabled;
    notifyListeners();
  }

  Future<void> removeFromQueue(String trackId) async {
    if (queue.isEmpty) return;
    final removedIndex = queue.indexWhere((e) => e.id == trackId);
    if (removedIndex < 0) return;

    queue = queue.where((e) => e.id != trackId).toList();
    if (queue.isEmpty) {
      currentTrack = null;
      currentIndex = -1;
      await _audioPlayer.stop();
      notifyListeners();
      return;
    }

    if (removedIndex < currentIndex) {
      currentIndex -= 1;
    } else if (removedIndex == currentIndex) {
      currentIndex = currentIndex.clamp(0, queue.length - 1);
      await playTrack(queue[currentIndex], contextQueue: queue);
      return;
    }

    notifyListeners();
  }

  bool get hasTrack => currentTrack != null;

  @override
  void dispose() {
    _disposed = true;
    _sleepTimer?.cancel();
    _positionNotifyTimer?.cancel();
    _positionSub?.cancel();
    _playerStateSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}

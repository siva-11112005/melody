import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as ja;

import '../models/track.dart';

class PlayerState extends ChangeNotifier {
  final ja.AudioPlayer _audioPlayer = ja.AudioPlayer();
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<ja.PlayerState>? _playerStateSub;

  Track? currentTrack;
  List<Track> queue = [];
  int currentIndex = -1;

  bool isPlaying = false;
  int positionMs = 0;
  int durationMs = 0;
  bool shuffleEnabled = false;
  bool repeatEnabled = false;

  PlayerState() {
    _positionSub = _audioPlayer.positionStream.listen((p) {
      positionMs = p.inMilliseconds;
      notifyListeners();
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

  Future<void> playTrack(Track track, {List<Track>? contextQueue}) async {
    queue = contextQueue ?? queue;
    if (queue.isEmpty) {
      queue = [track];
    }
    currentIndex = queue.indexWhere((e) => e.id == track.id);
    if (currentIndex < 0) currentIndex = 0;

    currentTrack = track;
    durationMs = track.durationMs;
    positionMs = 0;
    notifyListeners();

    final url = track.localUri ?? track.url;
    if (url == null || url.isEmpty) return;

    try {
      if (track.localUri != null) {
        await _audioPlayer.setAudioSource(ja.AudioSource.file(track.localUri!));
      } else {
        await _audioPlayer.setAudioSource(ja.AudioSource.uri(Uri.parse(url)));
      }
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('Playback error: $e');
      playNext();
    }
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
      if (repeatEnabled && queue.isNotEmpty) {
        await playTrack(queue.first, contextQueue: queue);
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
    _positionSub?.cancel();
    _playerStateSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}

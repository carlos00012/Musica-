import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class PlayerHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  final OnAudioQuery _audioQuery = OnAudioQuery();
  List<SongModel> _librarySongs = const [];
  List<SongModel> _queueSongs = const [];
  final Map<int, Future<Uri?>> _artworkFiles = {};
  String? _lastWidgetState;
  late final Future<void> _ready;

  PlayerHandler() {
    _ready = _initialize();
  }

  Future<void> _initialize() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    _player.playbackEventStream.listen(
      (_) => _publishState(),
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Error de reproducción: $error');
      },
    );
    _player.currentIndexStream.listen((index) {
      if (index != null && index >= 0 && index < queue.value.length) {
        unawaited(
          _publishCurrentMediaItem(index).catchError(
            (Object error, StackTrace stackTrace) {
              debugPrint('No se pudo cargar la carátula de la canción: $error');
            },
          ),
        );
        _scheduleWidgetUpdate(index);
      }
      _publishState();
    });
    _player.playingStream.listen((_) {
      final index = _player.currentIndex;
      if (index != null) _scheduleWidgetUpdate(index);
      _publishState();
    });
    _player.durationStream.listen((_) => _publishState());
    _publishState();
  }

  Future<bool> requestLibraryPermission() async {
    await _ready;
    if (Platform.isAndroid && await Permission.notification.isDenied) {
      final status = await Permission.notification.request();
      if (!status.isGranted) {
        debugPrint('Permiso de notificaciones no concedido; la reproducción seguirá disponible.');
      }
    }
    if (await _audioQuery.permissionsStatus()) return true;
    return _audioQuery.permissionsRequest();
  }

  Future<List<SongModel>> loadLibrary() async {
    if (!await requestLibraryPermission()) {
      throw StateError('Se necesita permiso para leer la música del dispositivo.');
    }
    final songs = await _audioQuery.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );
    _librarySongs = songs.where((song) => song.uri != null).toList(growable: false);
    _queueSongs = _librarySongs;
    queue.add(_queueSongs.map(_toMediaItem).toList(growable: false));
    return _librarySongs;
  }

  Future<void> playSong(SongModel song) async {
    var index = _librarySongs.indexWhere((item) => item.id == song.id);
    if (index < 0) {
      _librarySongs = [..._librarySongs, song];
      index = _librarySongs.length - 1;
    }
    await playSongs(_librarySongs, index);
  }

  Future<void> playSongs(List<SongModel> songs, int initialIndex) async {
    await _ready;
    if (songs.isEmpty || initialIndex < 0 || initialIndex >= songs.length) return;
    _queueSongs = List.unmodifiable(songs);
    queue.add(_queueSongs.map(_toMediaItem).toList(growable: false));
    await _player.setAudioSource(
      ConcatenatingAudioSource(
        children: _queueSongs
            .map((item) => AudioSource.uri(Uri.parse(item.uri!)))
            .toList(growable: false),
      ),
      initialIndex: initialIndex,
    );
    await _publishCurrentMediaItem(initialIndex);
    await _player.play();
  }

  MediaItem _toMediaItem(SongModel song) => MediaItem(
        id: song.uri!,
        title: song.title,
        artist: song.artist ?? 'Artista desconocido',
        album: song.album ?? 'Álbum desconocido',
        duration: Duration(milliseconds: song.duration ?? 0),
        extras: {'songId': song.id},
      );

  Future<Uri?> _artworkFile(SongModel song) => _artworkFiles.putIfAbsent(
        song.id,
        () async {
          final artwork = await _audioQuery.queryArtwork(
            song.id,
            ArtworkType.AUDIO,
            size: 256,
            quality: 75,
          );
          if (artwork == null) return null;
          final directory = await getTemporaryDirectory();
          final file = File('${directory.path}/artwork-${song.id}.jpg');
          await file.writeAsBytes(artwork, flush: true);
          return Uri.file(file.path);
        },
      );

  Future<void> _publishCurrentMediaItem(int index) async {
    final song = _queueSongs[index];
    final artworkUri = await _artworkFile(song);
    mediaItem.add(_toMediaItem(song).copyWith(artUri: artworkUri));
  }

  void _scheduleWidgetUpdate(int index) {
    final key = '${_queueSongs[index].id}:${_player.playing}';
    if (_lastWidgetState == key) return;
    _lastWidgetState = key;
    unawaited(
      _updateWidgets(index).catchError((Object error, StackTrace stackTrace) {
        debugPrint('No se pudieron actualizar los widgets: $error');
      }),
    );
  }

  Future<void> _updateWidgets(int index) async {
    if (index < 0 || index >= _queueSongs.length) return;
    final song = _queueSongs[index];
    await HomeWidget.saveWidgetData<String>('title', song.title);
    await HomeWidget.saveWidgetData<String>(
      'artist',
      song.artist ?? 'Artista desconocido',
    );
    await HomeWidget.saveWidgetData<bool>('isPlaying', _player.playing);
    final artworkUri = await _artworkFile(song);
    await HomeWidget.saveWidgetData<String>(
      'artworkPath',
      artworkUri?.toFilePath(),
    );
    await HomeWidget.updateWidget(name: 'CompactPlayerWidgetProvider');
    await HomeWidget.updateWidget(name: 'ArtworkPlayerWidgetProvider');
  }

  void _publishState() {
    final index = _player.currentIndex;
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          _player.playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        androidCompactActionIndices: const [0, 1, 2],
        systemActions: const {MediaAction.seek},
        processingState: switch (_player.processingState) {
          ProcessingState.idle => AudioProcessingState.idle,
          ProcessingState.loading => AudioProcessingState.loading,
          ProcessingState.buffering => AudioProcessingState.buffering,
          ProcessingState.ready => AudioProcessingState.ready,
          ProcessingState.completed => AudioProcessingState.completed,
        },
        playing: _player.playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: index,
        repeatMode: switch (_player.loopMode) {
          LoopMode.off => AudioServiceRepeatMode.none,
          LoopMode.one => AudioServiceRepeatMode.one,
          LoopMode.all => AudioServiceRepeatMode.all,
        },
        shuffleMode: _player.shuffleModeEnabled
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
      ),
    );
  }

  @override
  Future<void> play() async {
    await _ready;
    await _player.play();
  }

  @override
  Future<void> pause() async {
    await _ready;
    await _player.pause();
  }

  @override
  Future<void> stop() async {
    await _ready;
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await _ready;
    await _player.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    await _ready;
    if (_player.hasNext) await _player.seekToNext();
  }

  @override
  Future<void> skipToPrevious() async {
    await _ready;
    if (_player.hasPrevious) {
      await _player.seekToPrevious();
    } else {
      await _player.seek(Duration.zero);
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    await _ready;
    if (index < 0 || index >= _queueSongs.length) return;
    await _player.seek(Duration.zero, index: index);
    await _player.play();
  }

  Future<void> toggleShuffle() async {
    await _ready;
    await _player.setShuffleModeEnabled(!_player.shuffleModeEnabled);
    _publishState();
  }

  Future<void> cycleRepeatMode() async {
    await _ready;
    final next = switch (_player.loopMode) {
      LoopMode.off => LoopMode.all,
      LoopMode.all => LoopMode.one,
      LoopMode.one => LoopMode.off,
    };
    await _player.setLoopMode(next);
    _publishState();
  }

  double get volume => _player.volume;

  Future<void> setVolume(double volume) async {
    await _ready;
    await _player.setVolume(volume);
    _publishState();
  }
}

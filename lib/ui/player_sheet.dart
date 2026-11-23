import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../main.dart';

const _accent = Color(0xFFB8F36A);
const _surface = Color(0xFF1C201C);

Future<void> showPlayerSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF101210),
      builder: (_) => const _PlayerSheet(),
    );

class _PlayerSheet extends StatefulWidget {
  const _PlayerSheet();

  @override
  State<_PlayerSheet> createState() => _PlayerSheetState();
}

class _PlayerSheetState extends State<_PlayerSheet> {
  double? _dragPosition;

  String _time(Duration value) {
    final minutes = value.inMinutes.toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<MediaItem?>(
        stream: playerHandler.mediaItem,
        builder: (context, itemSnapshot) {
          final item = itemSnapshot.data;
          if (item == null) {
            return const SizedBox(
              height: 300,
              child: Center(child: Text('Elige una canción para empezar')),
            );
          }
          final songId = item.extras?['songId'];
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 28),
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: songId is int
                      ? QueryArtworkWidget(
                          id: songId,
                          type: ArtworkType.AUDIO,
                          size: 280,
                          artworkWidth: 280,
                          artworkHeight: 280,
                          artworkFit: BoxFit.cover,
                          nullArtworkWidget: const _CoverPlaceholder(),
                        )
                      : const _CoverPlaceholder(),
                ),
                const SizedBox(height: 26),
                Text(
                  item.title,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  item.artist ?? 'Artista desconocido',
                  style: const TextStyle(color: Colors.white60, fontSize: 16),
                ),
                const SizedBox(height: 18),
                StreamBuilder<PlaybackState>(
                  stream: playerHandler.playbackState,
                  builder: (context, snapshot) {
                    final state = snapshot.data;
                    final position = state?.updatePosition ?? Duration.zero;
                    final duration = item.duration ?? Duration.zero;
                    final max = duration.inMilliseconds.toDouble();
                    final value = max == 0
                        ? 0.0
                        : position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble();
                    return Column(
                      children: [
                        Slider(
                          value: _dragPosition ?? value,
                          max: max > 0 ? max : 1,
                          onChanged: max > 0
                              ? (next) => setState(() => _dragPosition = next)
                              : null,
                          onChangeEnd: max > 0
                              ? (next) {
                                  setState(() => _dragPosition = null);
                                  playerHandler.seek(
                                    Duration(milliseconds: next.round()),
                                  );
                                }
                              : null,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_time(position),
                                  style: const TextStyle(color: Colors.white60)),
                              Text(_time(duration),
                                  style: const TextStyle(color: Colors.white60)),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                StreamBuilder<PlaybackState>(
                  stream: playerHandler.playbackState,
                  builder: (context, snapshot) {
                    final state = snapshot.data;
                    final repeat = state?.repeatMode ?? AudioServiceRepeatMode.none;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          tooltip: 'Aleatorio',
                          onPressed: playerHandler.toggleShuffle,
                          color: state?.shuffleMode == AudioServiceShuffleMode.all
                              ? _accent
                              : Colors.white60,
                          icon: const Icon(Icons.shuffle),
                        ),
                        IconButton(
                          tooltip: 'Anterior',
                          onPressed: playerHandler.skipToPrevious,
                          icon: const Icon(Icons.skip_previous, size: 34),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: Colors.black,
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(16),
                          ),
                          onPressed: state?.playing == true
                              ? playerHandler.pause
                              : playerHandler.play,
                          child: Icon(
                            state?.playing == true ? Icons.pause : Icons.play_arrow,
                            size: 32,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Siguiente',
                          onPressed: playerHandler.skipToNext,
                          icon: const Icon(Icons.skip_next, size: 34),
                        ),
                        IconButton(
                          tooltip: 'Repetir',
                          onPressed: playerHandler.cycleRepeatMode,
                          color: repeat == AudioServiceRepeatMode.none
                              ? Colors.white60
                              : _accent,
                          icon: Icon(
                            repeat == AudioServiceRepeatMode.one
                                ? Icons.repeat_one
                                : Icons.repeat,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                TextButton.icon(
                  onPressed: () => _showQueue(context),
                  icon: const Icon(Icons.queue_music),
                  label: const Text('Cola de reproducción'),
                ),
                StreamBuilder<PlaybackState>(
                  stream: playerHandler.playbackState,
                  builder: (context, snapshot) => Row(
                    children: [
                      const Icon(Icons.volume_down, color: Colors.white60),
                      Expanded(
                        child: Slider(
                          value: playerHandler.volume.clamp(0, 1).toDouble(),
                          onChanged: playerHandler.setVolume,
                        ),
                      ),
                      const Icon(Icons.volume_up, color: Colors.white60),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
}

Future<void> _showQueue(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: _surface,
    builder: (context) {
      final items = playerHandler.queue.value;
      final currentId = playerHandler.mediaItem.value?.id;
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text('Cola de reproducción'),
              subtitle: Text('Canciones de la biblioteca'),
            ),
            ...items.asMap().entries.map(
              (entry) => ListTile(
                leading: Icon(
                  entry.value.id == currentId ? Icons.equalizer : Icons.music_note,
                  color: entry.value.id == currentId ? _accent : Colors.white60,
                ),
                title: Text(entry.value.title, maxLines: 1),
                subtitle: Text(entry.value.artist ?? ''),
                onTap: () {
                  Navigator.pop(context);
                  playerHandler.skipToQueueItem(entry.key);
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 280,
        height: 280,
        child: ColoredBox(
          color: _surface,
          child: Icon(Icons.album, size: 100, color: _accent),
        ),
      );
}

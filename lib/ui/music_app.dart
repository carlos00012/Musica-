import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import 'player_sheet.dart';

const _background = Color(0xFF101210);
const _surface = Color(0xFF1C201C);
const _accent = Color(0xFFB8F36A);

class MusicaApp extends StatelessWidget {
  const MusicaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Música',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: _background,
          colorScheme: const ColorScheme.dark(
            primary: _accent,
            surface: _surface,
          ),
          useMaterial3: true,
        ),
        home: const LibraryScreen(),
      );
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<SongModel> _songs = const [];
  Set<int> _favorites = {};
  Map<String, List<int>> _playlists = {};
  List<int> _history = [];
  String _sort = 'Canciones';
  String _search = '';
  String? _error;
  bool _loading = true;
  bool _onlyMusic = true;
  bool _excludeSystemSounds = true;
  int _minimumDurationSeconds = 30;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _loadSaved();
    _loadLibrary();
    playerHandler.mediaItem.listen((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _favorites = (prefs.getStringList('favorites') ?? [])
          .map(int.tryParse)
          .whereType<int>()
          .toSet();
      _history = (prefs.getStringList('history') ?? [])
          .map(int.tryParse)
          .whereType<int>()
          .toList();
      _sort = prefs.getString('librarySort') ?? 'Canciones';
      _onlyMusic = prefs.getBool('libraryOnlyMusic') ?? true;
      _excludeSystemSounds = prefs.getBool('libraryExcludeSystemSounds') ?? true;
      _minimumDurationSeconds = prefs.getInt('libraryMinimumDuration') ?? 30;
      final savedPlaylists = prefs.getStringList('playlists') ?? [];
      _playlists = {
        for (final entry in savedPlaylists)
          if (entry.contains('|'))
            entry.substring(0, entry.indexOf('|')): entry
                .substring(entry.indexOf('|') + 1)
                .split(',')
                .where((id) => id.isNotEmpty)
                .map(int.tryParse)
                .whereType<int>()
                .toList(),
      };
    });
  }

  Future<void> _savePlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'playlists',
      _playlists.entries
          .map((entry) => '${entry.key}|${entry.value.join(',')}')
          .toList(),
    );
  }

  Future<void> _loadLibrary() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final songs = await playerHandler.loadLibrary();
      if (mounted) setState(() => _songs = songs);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFavorite(SongModel song) async {
    final next = {..._favorites};
    if (!next.add(song.id)) next.remove(song.id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'favorites',
      next.map((id) => id.toString()).toList(),
    );
    if (mounted) setState(() => _favorites = next);
  }

  Future<void> _play(SongModel song) async {
    final songs = _visibleSongs;
    final index = songs.indexWhere((item) => item.id == song.id);
    if (index < 0) return;
    await playerHandler.playSongs(songs, index);
    await _recordHistory(song);
  }

  Future<void> _showLibraryFilters() async {
    var onlyMusic = _onlyMusic;
    var excludeSystemSounds = _excludeSystemSounds;
    var minimumDurationSeconds = _minimumDurationSeconds;
    final applied = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: _surface,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 8, 4, 12),
                  child: Text(
                    'Filtros de biblioteca',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mostrar solo música'),
                  subtitle: const Text('Usa la clasificación de audio de Android'),
                  value: onlyMusic,
                  onChanged: (value) => setSheetState(() => onlyMusic = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ocultar tonos y sonidos del sistema'),
                  subtitle: const Text(
                    'Alarmas, tonos, notificaciones, audiolibros y podcasts',
                  ),
                  value: excludeSystemSounds,
                  onChanged: (value) =>
                      setSheetState(() => excludeSystemSounds = value),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: minimumDurationSeconds,
                  decoration: const InputDecoration(
                    labelText: 'Duración mínima',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Sin mínimo')),
                    DropdownMenuItem(value: 15, child: Text('15 segundos')),
                    DropdownMenuItem(value: 30, child: Text('30 segundos')),
                    DropdownMenuItem(value: 60, child: Text('1 minuto')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setSheetState(() => minimumDurationSeconds = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Aplicar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (applied != true || !mounted) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('libraryOnlyMusic', onlyMusic);
    await prefs.setBool('libraryExcludeSystemSounds', excludeSystemSounds);
    await prefs.setInt('libraryMinimumDuration', minimumDurationSeconds);
    if (mounted) {
      setState(() {
        _onlyMusic = onlyMusic;
        _excludeSystemSounds = excludeSystemSounds;
        _minimumDurationSeconds = minimumDurationSeconds;
      });
    }
  }

  Future<void> _recordHistory(SongModel song) async {
    final nextHistory = [song.id, ..._history.where((id) => id != song.id)]
        .take(100)
        .toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'history',
      nextHistory.map((id) => id.toString()).toList(),
    );
    if (mounted) setState(() => _history = nextHistory);
  }

  Future<void> _createPlaylist() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva lista'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(hintText: 'Nombre de la lista'),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || name == null || name.isEmpty || _playlists.containsKey(name)) return;
    setState(() => _playlists[name] = []);
    await _savePlaylists();
  }

  Future<void> _addToPlaylist(SongModel song) async {
    if (_playlists.isEmpty) {
      await _createPlaylist();
      if (_playlists.isEmpty) return;
    }
    if (!mounted) return;
    final name = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _surface,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Añadir a una lista')),
            ..._playlists.keys.map(
              (name) => ListTile(
                title: Text(name),
                onTap: () => Navigator.pop(context, name),
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted || name == null) return;
    final updated = {..._playlists};
    updated[name] = {...updated[name]!, song.id}.toList();
    setState(() => _playlists = updated);
    await _savePlaylists();
  }

  List<SongModel> get _visibleSongs {
    Iterable<SongModel> songs = _songs;
    if (_onlyMusic) {
      songs = songs.where((song) => song.isMusic == true);
    }
    if (_excludeSystemSounds) {
      songs = songs.where(
        (song) =>
            song.isAlarm != true &&
            song.isRingtone != true &&
            song.isNotification != true &&
            song.isAudioBook != true &&
            song.isPodcast != true,
      );
    }
    if (_minimumDurationSeconds > 0) {
      final minimumMilliseconds = _minimumDurationSeconds * 1000;
      songs = songs.where(
        (song) =>
            song.duration == null || song.duration! >= minimumMilliseconds,
      );
    }
    if (_tab == 2) {
      songs = songs.where((song) => _favorites.contains(song.id));
    } else if (_tab == 3 && _history.isNotEmpty) {
      final byId = {for (final song in _songs) song.id: song};
      songs = _history.map((id) => byId[id]).whereType<SongModel>();
    }
    if (_tab == 1 && _search.trim().isNotEmpty) {
      final query = _search.toLowerCase();
      songs = songs.where(
        (song) =>
            song.title.toLowerCase().contains(query) ||
            (song.artist ?? '').toLowerCase().contains(query) ||
            (song.album ?? '').toLowerCase().contains(query),
      );
    }
    final result = songs.toList();
    if (_tab != 3) {
      result.sort((a, b) {
        switch (_sort) {
          case 'Artista':
            return (a.artist ?? '').compareTo(b.artist ?? '');
          case 'Álbum':
            return (a.album ?? '').compareTo(b.album ?? '');
          default:
            return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        }
      });
    }
    return result;
  }

  String get _title => switch (_tab) {
        0 => 'Tu música',
        1 => 'Buscar',
        2 => 'Favoritos',
        _ => 'Escuchado recientemente',
      };

  @override
  Widget build(BuildContext context) {
    final current = playerHandler.mediaItem.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(_title, style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: 'Filtros de biblioteca',
            onPressed: _showLibraryFilters,
            icon: const Icon(Icons.filter_list),
          ),
          if (_tab == 0)
            PopupMenuButton<String>(
              tooltip: 'Ordenar biblioteca',
              initialValue: _sort,
              onSelected: (value) async {
                setState(() => _sort = value);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('librarySort', value);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'Canciones', child: Text('Canción')),
                PopupMenuItem(value: 'Artista', child: Text('Artista')),
                PopupMenuItem(value: 'Álbum', child: Text('Álbum')),
              ],
              icon: const Icon(Icons.sort),
            ),
          if (_tab == 3)
            IconButton(
              tooltip: 'Crear lista',
              onPressed: _createPlaylist,
              icon: const Icon(Icons.playlist_add),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          if (_tab == 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                onChanged: (value) => setState(() => _search = value),
                decoration: InputDecoration(
                  hintText: 'Canción, artista o álbum',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: _surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          Expanded(child: _buildContent()),
          if (current != null) _MiniPlayer(item: current),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.library_music_outlined),
            selectedIcon: Icon(Icons.library_music),
            label: 'Música',
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            label: 'Buscar',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label: 'Favoritos',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: 'Historial',
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.music_off, size: 44, color: _accent),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _loadLibrary, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }
    if (_tab == 3) return _buildHistoryAndPlaylists();
    final songs = _visibleSongs;
    if (songs.isEmpty) {
      return Center(
        child: Text(
          _tab == 2
              ? 'Aún no tienes favoritos.'
              : _tab == 1 && _search.isNotEmpty
                  ? 'No se encontraron canciones.'
                  : _songs.isNotEmpty
                      ? 'No hay canciones con estos filtros. Puedes ajustarlos desde el botón de filtros.'
                  : 'No encontramos música local en el dispositivo.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final song = songs[index];
        return _SongTile(
          song: song,
          favorite: _favorites.contains(song.id),
          onTap: () => _play(song),
          onFavorite: () => _toggleFavorite(song),
          onPlaylist: () => _addToPlaylist(song),
        );
      },
    );
  }

  Widget _buildHistoryAndPlaylists() {
    final historySongs = _visibleSongs;
    return ListView(
      padding: const EdgeInsets.only(bottom: 12),
      children: [
        if (_playlists.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 12, 18, 4),
            child: Text('TUS LISTAS', style: TextStyle(color: Colors.white60)),
          ),
          ..._playlists.entries.map(
            (entry) => ListTile(
              leading: const CircleAvatar(
                backgroundColor: _surface,
                child: Icon(Icons.queue_music, color: _accent),
              ),
              title: Text(entry.key),
              subtitle: Text('${entry.value.length} canciones'),
              onTap: () async {
                setState(() {
                  _tab = 0;
                  _search = '';
                });
                final byId = {for (final song in _songs) song.id: song};
                final songs = entry.value
                    .map((id) => byId[id])
                    .whereType<SongModel>()
                    .toList();
                if (songs.isNotEmpty) {
                  await playerHandler.playSongs(songs, 0);
                  await _recordHistory(songs.first);
                }
              },
            ),
          ),
        ],
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 18, 18, 4),
          child: Text('RECIENTES', style: TextStyle(color: Colors.white60)),
        ),
        if (historySongs.isEmpty)
          const Padding(
            padding: EdgeInsets.all(18),
            child: Text('Las canciones que reproduzcas aparecerán aquí.'),
          )
        else
          ...historySongs.map(
            (song) => _SongTile(
              song: song,
              favorite: _favorites.contains(song.id),
              onTap: () => _play(song),
              onFavorite: () => _toggleFavorite(song),
              onPlaylist: () => _addToPlaylist(song),
            ),
          ),
      ],
    );
  }
}

class _SongTile extends StatelessWidget {
  const _SongTile({
    required this.song,
    required this.favorite,
    required this.onTap,
    required this.onFavorite,
    required this.onPlaylist,
  });

  final SongModel song;
  final bool favorite;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final VoidCallback onPlaylist;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: QueryArtworkWidget(
            id: song.id,
            type: ArtworkType.AUDIO,
            size: 96,
            artworkFit: BoxFit.cover,
            nullArtworkWidget: _ArtworkPlaceholder(size: 52),
          ),
        ),
        title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${song.artist ?? 'Artista desconocido'} · ${song.album ?? 'Álbum desconocido'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: onTap,
        trailing: PopupMenuButton<String>(
          tooltip: 'Más opciones',
          onSelected: (value) {
            if (value == 'favorite') onFavorite();
            if (value == 'playlist') onPlaylist();
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'favorite',
              child: Text(favorite ? 'Quitar de favoritos' : 'Añadir a favoritos'),
            ),
            const PopupMenuItem(
              value: 'playlist',
              child: Text('Añadir a una lista'),
            ),
          ],
          icon: const Icon(Icons.more_vert),
        ),
      );
}

class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
        child: Material(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => showPlayerSheet(context),
            child: SizedBox(
              height: 64,
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  item.extras?['songId'] is int
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: QueryArtworkWidget(
                            id: item.extras!['songId'] as int,
                            type: ArtworkType.AUDIO,
                            size: 96,
                            artworkWidth: 42,
                            artworkHeight: 42,
                            artworkFit: BoxFit.cover,
                            nullArtworkWidget: const _ArtworkPlaceholder(size: 42),
                          ),
                        )
                      : const _ArtworkPlaceholder(size: 42),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(
                          item.artist ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  StreamBuilder<PlaybackState>(
                    stream: playerHandler.playbackState,
                    builder: (context, snapshot) {
                      final playing = snapshot.data?.playing ?? false;
                      return IconButton(
                        tooltip: playing ? 'Pausar' : 'Reproducir',
                        onPressed: playing ? playerHandler.pause : playerHandler.play,
                        icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                      );
                    },
                  ),
                  IconButton(
                    tooltip: 'Siguiente',
                    onPressed: playerHandler.skipToNext,
                    icon: const Icon(Icons.skip_next),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ),
      );
}

class _ArtworkPlaceholder extends StatelessWidget {
  const _ArtworkPlaceholder({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.album, color: _accent, size: size * .55),
        ),
      );
}

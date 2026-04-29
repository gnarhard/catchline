import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../data/models/audio_clip_meta.dart';
import '../../../state/providers.dart';

class AudioClipTile extends ConsumerStatefulWidget {
  const AudioClipTile({
    super.key,
    required this.clip,
    required this.index,
    required this.onDelete,
  });

  final AudioClipMeta clip;
  final int index;
  final VoidCallback onDelete;

  @override
  ConsumerState<AudioClipTile> createState() => _AudioClipTileState();
}

class _AudioClipTileState extends ConsumerState<AudioClipTile> {
  late final AudioPlayer _player;
  StreamSubscription<PlayerState>? _stateSub;
  bool _loaded = false;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _stateSub = _player.playerStateStream.listen((state) {
      if (!mounted) return;
      final isPlaying =
          state.playing && state.processingState != ProcessingState.completed;
      if (isPlaying != _playing) {
        setState(() => _playing = isPlaying);
      }
      if (state.processingState == ProcessingState.completed) {
        _player.seek(Duration.zero);
        _player.pause();
      }
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final repo = ref.read(audioRepoProvider);
    final uri = await repo.playableUri(widget.clip);
    await _player.setUrl(uri);
    _loaded = true;
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      return;
    }
    await _ensureLoaded();
    await _player.play();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duration = Duration(milliseconds: widget.clip.durationMs);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: IconButton.filledTonal(
          onPressed: _toggle,
          icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
        ),
        title: Text('Clip ${widget.index + 1}'),
        subtitle: Text(
          _formatDuration(duration),
          style: theme.textTheme.bodySmall,
        ),
        trailing: IconButton(
          onPressed: widget.onDelete,
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Delete clip',
        ),
      ),
    );
  }
}

String _formatDuration(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

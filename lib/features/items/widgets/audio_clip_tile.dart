import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
    final colorScheme = theme.colorScheme;
    final duration = Duration(milliseconds: widget.clip.durationMs);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Material(
              color: colorScheme.primary.withAlpha(40),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _toggle,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(
                    _playing ? LucideIcons.pause : LucideIcons.play,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Clip ${widget.index + 1}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDuration(duration),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: widget.onDelete,
              icon: const Icon(LucideIcons.trash2, size: 18),
              tooltip: 'Delete clip',
            ),
          ],
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

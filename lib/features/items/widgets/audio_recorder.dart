import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../../data/models/audio_clip_meta.dart';
import '../../../state/providers.dart';

enum _RecorderUiState { idle, recording, finalizing }

class AudioRecorderButton extends ConsumerStatefulWidget {
  const AudioRecorderButton({super.key, required this.onClipRecorded});

  final void Function(AudioClipMeta meta) onClipRecorded;

  @override
  ConsumerState<AudioRecorderButton> createState() =>
      _AudioRecorderButtonState();
}

class _AudioRecorderButtonState extends ConsumerState<AudioRecorderButton>
    with WidgetsBindingObserver {
  static const _kFileExt = 'm4a';
  static const _kMime = 'audio/aac';

  final AudioRecorder _recorder = AudioRecorder();
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;

  _RecorderUiState _state = _RecorderUiState.idle;
  String? _activeClipId;
  String? _activeTarget;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    if (_state == _RecorderUiState.recording) {
      _recorder.cancel();
    }
    _recorder.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        _state == _RecorderUiState.recording) {
      _abortRecording();
    }
  }

  Future<void> _start() async {
    final repo = ref.read(audioRepoProvider);

    final hasMicAccess = await _recorder.hasPermission();
    if (!hasMicAccess) {
      if (!mounted) return;
      await _showPermissionDialog();
      return;
    }

    final session = await repo.beginRecording(fileExt: _kFileExt);
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: session.recordingTarget,
    );

    _stopwatch
      ..reset()
      ..start();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      setState(() => _elapsed = _stopwatch.elapsed);
    });

    setState(() {
      _state = _RecorderUiState.recording;
      _activeClipId = session.clipId;
      _activeTarget = session.recordingTarget;
      _elapsed = Duration.zero;
    });
  }

  Future<void> _stop() async {
    if (_state != _RecorderUiState.recording) return;
    _ticker?.cancel();
    _stopwatch.stop();
    final durationMs = _stopwatch.elapsedMilliseconds;

    setState(() => _state = _RecorderUiState.finalizing);

    final stopPath = await _recorder.stop();
    final source = stopPath ?? _activeTarget ?? '';

    if (source.isEmpty) {
      _resetIdle();
      return;
    }

    final repo = ref.read(audioRepoProvider);
    final clipId = _activeClipId!;
    final result = await repo.finalizeRecording(
      clipId: clipId,
      sourcePath: source,
      mimeType: _kMime,
      fileExt: _kFileExt,
      durationMs: durationMs,
    );

    widget.onClipRecorded(result.meta);
    _resetIdle();
  }

  Future<void> _abortRecording() async {
    _ticker?.cancel();
    _stopwatch.stop();
    try {
      await _recorder.cancel();
    } catch (_) {
      // recorder may already be stopped; ignore
    }
    _resetIdle();
  }

  void _resetIdle() {
    if (!mounted) return;
    setState(() {
      _state = _RecorderUiState.idle;
      _activeClipId = null;
      _activeTarget = null;
      _elapsed = Duration.zero;
    });
  }

  Future<void> _showPermissionDialog() async {
    final ctx = context;
    final result = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Microphone access needed'),
        content: const Text(
          'Catchline needs microphone access to record audio clips. '
          'Enable it in your device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
    if (result == true) {
      await openAppSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRecording = _state == _RecorderUiState.recording;
    final isFinalizing = _state == _RecorderUiState.finalizing;

    return Row(
      children: [
        FilledButton.tonalIcon(
          onPressed: isFinalizing ? null : (isRecording ? _stop : _start),
          icon: Icon(
            isRecording ? LucideIcons.square : LucideIcons.mic,
            size: 16,
          ),
          label: Text(isRecording ? 'Stop' : 'Record'),
        ),
        const SizedBox(width: 12),
        if (isRecording)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: theme.colorScheme.error,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatElapsed(_elapsed),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          )
        else if (isFinalizing)
          Text('Saving…', style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

String _formatElapsed(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

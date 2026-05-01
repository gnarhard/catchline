import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/sync/sync_service.dart';
import '../../state/providers.dart';
import '../../state/sync_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountAsync = ref.watch(googleAccountProvider);
    final statusAsync = ref.watch(syncStatusProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              const _SectionHeader('Google Drive sync'),
              accountAsync.when(
                data: (account) => account == null
                    ? const _SignedOutTile()
                    : _SignedInTile(email: account.email),
                loading: () => const ListTile(
                  leading: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  title: Text('Checking sign-in…'),
                ),
                error: (e, _) => ListTile(
                  leading: const Icon(LucideIcons.circleAlert),
                  title: const Text('Sign-in unavailable'),
                  subtitle: Text('$e'),
                ),
              ),
              if (accountAsync.value != null) ...[
                const Divider(),
                _SyncStatusTile(status: statusAsync.value ?? SyncStatus.idle),
              ],
              const _SectionHeader('AI'),
              const _AnthropicKeyTile(),
              const Divider(height: 24),
              const _PhraseStylesEditor(),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SignedOutTile extends ConsumerWidget {
  const _SignedOutTile();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(LucideIcons.cloudOff),
      title: const Text('Not connected'),
      subtitle: const Text(
        'Connect Drive to back up entries on app open and close.',
      ),
      trailing: FilledButton(
        onPressed: () => _connect(context, ref),
        child: const Text('Connect'),
      ),
    );
  }

  Future<void> _connect(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(googleAuthProvider).connectDrive();
      if (!context.mounted) return;
      // Kick a sync immediately so the user sees something happen.
      unawaited(ref.read(syncServiceProvider).syncNow());
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sign-in failed: $e')));
    }
  }
}

class _SignedInTile extends ConsumerWidget {
  const _SignedInTile({required this.email});
  final String email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(LucideIcons.cloudCheck),
          title: const Text('Connected'),
          subtitle: Text(email),
          trailing: TextButton(
            onPressed: () => _disconnect(context, ref),
            child: const Text('Disconnect'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(LucideIcons.refreshCw, size: 18),
                  label: const Text('Sync now'),
                  onPressed: () => ref.read(syncServiceProvider).syncNow(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _disconnect(BuildContext context, WidgetRef ref) async {
    final auth = ref.read(googleAuthProvider);
    final service = ref.read(syncServiceProvider);
    await service.clearAccountMeta(email);
    await auth.signOut();
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Disconnected from Drive')));
  }
}

class _SyncStatusTile extends StatelessWidget {
  const _SyncStatusTile({required this.status});
  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, title, subtitle) = switch (status.kind) {
      SyncStatusKind.idle => (
        const Icon(LucideIcons.check),
        'Up to date',
        status.lastSyncedAtMs == null
            ? null
            : 'Last sync ${_relative(status.lastSyncedAtMs!)}',
      ),
      SyncStatusKind.syncing => (
        const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        'Syncing…',
        null,
      ),
      SyncStatusKind.error => (
        const Icon(LucideIcons.circleAlert),
        'Sync failed',
        status.message,
      ),
      SyncStatusKind.signedOut => (
        const Icon(LucideIcons.cloudOff),
        'Not connected',
        null,
      ),
    };
    return ListTile(
      leading: icon,
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
    );
  }

  static String _relative(int ms) {
    final delta = DateTime.now().toUtc().millisecondsSinceEpoch - ms;
    if (delta < 60 * 1000) return 'just now';
    if (delta < 60 * 60 * 1000) return '${delta ~/ (60 * 1000)} min ago';
    if (delta < 24 * 60 * 60 * 1000) {
      return '${delta ~/ (60 * 60 * 1000)} h ago';
    }
    return '${delta ~/ (24 * 60 * 60 * 1000)} d ago';
  }
}

class _AnthropicKeyTile extends ConsumerStatefulWidget {
  const _AnthropicKeyTile();

  @override
  ConsumerState<_AnthropicKeyTile> createState() => _AnthropicKeyTileState();
}

class _AnthropicKeyTileState extends ConsumerState<_AnthropicKeyTile> {
  late final TextEditingController _controller;
  bool _obscure = true;
  bool _loaded = false;
  bool _saving = false;
  String _initial = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    final value =
        await ref.read(secureSettingsProvider).getAnthropicApiKey() ?? '';
    if (!mounted) return;
    setState(() {
      _initial = value;
      _controller.text = value;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isDirty => _loaded && _controller.text != _initial;

  Future<void> _save() async {
    final value = _controller.text.trim();
    setState(() => _saving = true);
    try {
      await ref.read(secureSettingsProvider).setAnthropicApiKey(value);
      if (!mounted) return;
      setState(() {
        _initial = value;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value.isEmpty ? 'API key cleared.' : 'API key saved.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save key: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.key, size: 18),
              const SizedBox(width: 12),
              Text('Anthropic API key', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Stored in your device keychain. Used for journal synopses and phrase rephrasing.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            obscureText: _obscure,
            enabled: _loaded && !_saving,
            decoration: InputDecoration(
              hintText: _loaded ? 'sk-ant-…' : 'Loading…',
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Show' : 'Hide',
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure ? LucideIcons.eye : LucideIcons.eyeOff,
                  size: 18,
                ),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: (_isDirty && !_saving) ? _save : null,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhraseStylesEditor extends ConsumerStatefulWidget {
  const _PhraseStylesEditor();

  @override
  ConsumerState<_PhraseStylesEditor> createState() =>
      _PhraseStylesEditorState();
}

class _PhraseStylesEditorState extends ConsumerState<_PhraseStylesEditor> {
  late List<String> _styles;
  bool _initialized = false;
  final _addController = TextEditingController();

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  Future<void> _persist() async {
    await ref.read(appSettingsRepoProvider).setPhraseStyles(_styles);
  }

  Future<void> _addStyle() async {
    final value = _addController.text.trim();
    if (value.isEmpty) return;
    if (_styles.any((s) => s.toLowerCase() == value.toLowerCase())) {
      _addController.clear();
      return;
    }
    setState(() {
      _styles = [..._styles, value];
      _addController.clear();
    });
    await _persist();
  }

  Future<void> _removeStyle(int index) async {
    setState(() {
      _styles = [..._styles]..removeAt(index);
    });
    await _persist();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(appSettingsRepoProvider);
    if (!_initialized) {
      _styles = List<String>.from(repo.phraseStyles);
      _initialized = true;
    }
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.sparkles, size: 18),
              const SizedBox(width: 12),
              Text(
                'Phrase rephrase styles',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Names of artists, writers, or personalities. Tapping rephrase on a phrase will generate one rewrite per style.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          if (_styles.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No styles yet. Add one below.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _styles.length; i++)
                  InputChip(
                    label: Text(_styles[i]),
                    onDeleted: () => _removeStyle(i),
                    deleteIconColor: theme.colorScheme.onSurfaceVariant,
                  ),
              ],
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _addController,
                  decoration: const InputDecoration(
                    hintText: 'Add a style…',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.words,
                  onSubmitted: (_) => _addStyle(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _addStyle,
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('Add'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

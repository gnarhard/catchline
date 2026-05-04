import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/sync/sync_service.dart';
import '../../state/items_notifier.dart';
import '../../state/journal_lock.dart';
import '../../state/providers.dart';
import '../../state/sync_providers.dart';
import '../../data/models/item_kind.dart';
import '../../theme/app_theme.dart';
import '../../util/instant_page_route.dart';
import '../journal_lock/journal_pin_dialogs.dart';
import 'tag_editor_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _Title('Settings'),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                children: const [
                  _SectionLabel('Google Drive sync'),
                  _SyncCard(),
                  SizedBox(height: 6),
                  _SectionLabel('AI'),
                  _AiKeyCard(),
                  SizedBox(height: 6),
                  _SectionLabel('Privacy'),
                  _JournalPinCard(),
                  SizedBox(height: 6),
                  _SectionLabel('Tags'),
                  _TagsCard(),
                  SizedBox(height: 6),
                  _SectionLabel('Phrase rephrase styles'),
                  _RephraseStylesCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: serifStyle(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
          color: AppColors.sectionLabel,
        ),
      ),
    );
  }
}

/// Shared dark card used by every settings section. Translucent surface +
/// subtle warm-rose hairline matches the design tokens.
class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x8C14080C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x14FFDCDC)),
      ),
      child: child,
    );
  }
}

class _SyncCard extends ConsumerWidget {
  const _SyncCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountAsync = ref.watch(googleAccountProvider);
    return _Card(
      child: accountAsync.when(
        data: (account) => account == null
            ? const _SignedOutBlock()
            : _SignedInBlock(email: account.email),
        loading: () => const SizedBox(
          height: 40,
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        error: (e, _) => Row(
          children: [
            const Icon(
              LucideIcons.circleAlert,
              size: 18,
              color: AppColors.textMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Sign-in unavailable: $e',
                style: const TextStyle(fontSize: 12, color: AppColors.textDim),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignedOutBlock extends ConsumerWidget {
  const _SignedOutBlock();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.textMuted.withAlpha(36),
          ),
          alignment: Alignment.center,
          child: const Icon(
            LucideIcons.cloudOff,
            size: 16,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Not connected',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Connect Drive to back up entries.',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        FilledButton(
          onPressed: () => _connect(context, ref),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: const Text('Connect'),
        ),
      ],
    );
  }

  Future<void> _connect(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(googleAuthProvider).connectDrive();
      if (!context.mounted) return;
      unawaited(ref.read(syncServiceProvider).syncNow());
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sign-in failed: $e')));
    }
  }
}

class _SignedInBlock extends ConsumerWidget {
  const _SignedInBlock({required this.email});
  final String email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(syncStatusProvider);
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x24A0C4A8),
              ),
              alignment: Alignment.center,
              child: const Icon(
                LucideIcons.check,
                size: 16,
                color: Color(0xFFA0C4A8),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Connected',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    email,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _disconnect(context, ref),
              child: const Text(
                'Disconnect',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.accent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(height: 1, color: const Color(0x14FFDCDC)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SyncStatusRow(
                status: statusAsync.value ?? SyncStatus.idle,
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: () => ref.read(syncServiceProvider).syncNow(),
              icon: const Icon(LucideIcons.refreshCw, size: 12),
              label: const Text('Sync now'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: BorderSide(color: AppColors.accent.withAlpha(76)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
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

class _SyncStatusRow extends StatelessWidget {
  const _SyncStatusRow({required this.status});
  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, title, subtitle, color) = switch (status.kind) {
      SyncStatusKind.idle => (
        LucideIcons.check,
        'Up to date',
        status.lastSyncedAtMs == null
            ? null
            : 'Last sync ${_relative(status.lastSyncedAtMs!)}',
        AppColors.textDim,
      ),
      SyncStatusKind.syncing => (
        LucideIcons.loader,
        'Syncing…',
        null,
        AppColors.textDim,
      ),
      SyncStatusKind.error => (
        LucideIcons.circleAlert,
        'Sync failed',
        status.message,
        AppColors.textMuted,
      ),
      SyncStatusKind.signedOut => (
        LucideIcons.cloudOff,
        'Not connected',
        null,
        AppColors.textMuted,
      ),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDim,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
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

class _AiKeyCard extends ConsumerStatefulWidget {
  const _AiKeyCard();
  @override
  ConsumerState<_AiKeyCard> createState() => _AiKeyCardState();
}

class _AiKeyCardState extends ConsumerState<_AiKeyCard> {
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
    final cost = ref.watch(anthropicCostUsdProvider).value ?? 0.0;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.key, size: 14, color: AppColors.textPrimary),
              SizedBox(width: 8),
              Text(
                'Anthropic API key',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Stored in your device keychain. Used for journal synopses and phrase rephrasing.',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  obscureText: _obscure,
                  enabled: _loaded && !_saving,
                  style: const TextStyle(
                    fontSize: 12,
                    letterSpacing: 1,
                    color: AppColors.textDim,
                  ),
                  decoration: InputDecoration(
                    hintText: _loaded ? 'sk-ant-…' : 'Loading…',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    border: const UnderlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure ? LucideIcons.eye : LucideIcons.eyeOff,
                  size: 14,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 4),
              FilledButton(
                onPressed: (_isDirty && !_saving) ? _save : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _UsageRow(costUsd: cost),
        ],
      ),
    );
  }
}

class _UsageRow extends StatelessWidget {
  const _UsageRow({required this.costUsd});
  final double costUsd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          LucideIcons.circleDollarSign,
          size: 13,
          color: AppColors.textMuted,
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'API usage so far',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ),
        Text(
          _formatUsd(costUsd),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textDim,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  static String _formatUsd(double v) {
    if (v <= 0) return '\$0.00';
    if (v >= 1.0) return '\$${v.toStringAsFixed(2)}';
    return '\$${v.toStringAsFixed(4)}';
  }
}

class _TagsCard extends ConsumerWidget {
  const _TagsCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(itemsProvider);
    final tagged = <ItemKind, int>{for (final kind in ItemKind.values) kind: 0};
    for (final item in all) {
      if (item.tag != null) tagged[item.kind] = (tagged[item.kind] ?? 0) + 1;
    }
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Each entry type has its own tag set.',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < ItemKind.values.length; i++) ...[
            if (i > 0) Container(height: 1, color: const Color(0x10FFDCDC)),
            _TagsRow(
              kind: ItemKind.values[i],
              label: '${_kindAdjective(ItemKind.values[i])} tags',
              tagged: tagged[ItemKind.values[i]] ?? 0,
            ),
          ],
        ],
      ),
    );
  }

  static String _kindAdjective(ItemKind k) => switch (k) {
    ItemKind.phrase => 'Phrase',
    ItemKind.poem => 'Poem',
    ItemKind.lyric => 'Lyric',
    ItemKind.journal => 'Journal',
  };
}

class _TagsRow extends ConsumerWidget {
  const _TagsRow({
    required this.kind,
    required this.label,
    required this.tagged,
  });
  final ItemKind kind;
  final String label;
  final int tagged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availableTags = ref.watch(tagsForKindProvider(kind)).length;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => Navigator.of(context).push(
          InstantPageRoute<void>(builder: (_) => TagEditorScreen(kind: kind)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$availableTags available · $tagged in use',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                LucideIcons.chevronRight,
                size: 14,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RephraseStylesCard extends ConsumerStatefulWidget {
  const _RephraseStylesCard();
  @override
  ConsumerState<_RephraseStylesCard> createState() =>
      _RephraseStylesCardState();
}

class _RephraseStylesCardState extends ConsumerState<_RephraseStylesCard> {
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
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tapping rephrase on a phrase generates one rewrite per style.',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          if (_styles.isEmpty)
            const Text(
              'No styles yet. Add one below.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < _styles.length; i++)
                  _StyleChip(
                    label: _styles[i],
                    onRemove: () => _removeStyle(i),
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
                    hintStyle: TextStyle(color: AppColors.textMuted),
                    border: UnderlineInputBorder(),
                    isDense: true,
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.words,
                  onSubmitted: (_) => _addStyle(),
                ),
              ),
              const SizedBox(width: 6),
              FilledButton.icon(
                onPressed: _addStyle,
                icon: const Icon(LucideIcons.plus, size: 14),
                label: const Text('Add'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StyleChip extends StatelessWidget {
  const _StyleChip({required this.label, required this.onRemove});
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xB314080C),
        border: Border.all(color: const Color(0x14FFDCDC)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textDim),
          ),
          const SizedBox(width: 6),
          InkWell(
            customBorder: const CircleBorder(),
            onTap: onRemove,
            child: const Icon(
              LucideIcons.x,
              size: 11,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _JournalPinCard extends ConsumerWidget {
  const _JournalPinCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(journalLockProvider);
    final hasPin = state.value?.hasPin ?? false;
    final loading = state.isLoading && state.value == null;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.lock, size: 14, color: AppColors.textPrimary),
              SizedBox(width: 8),
              Text(
                'Journal PIN',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'When set, journal entries are blurred until you enter the PIN. '
            'The journal re-locks when you background or close the app.',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  loading ? 'Loading…' : (hasPin ? 'PIN is set' : 'No PIN set'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: hasPin ? AppColors.textPrimary : AppColors.textDim,
                  ),
                ),
              ),
              if (!loading)
                FilledButton(
                  onPressed: () => _onPress(context, ref, hasPin: hasPin),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text(hasPin ? 'Change' : 'Set PIN'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _onPress(
    BuildContext context,
    WidgetRef ref, {
    required bool hasPin,
  }) async {
    final ok = await showJournalPinSetupDialog(context, hasExistingPin: hasPin);
    if (!ok || !context.mounted) return;
    final updated = ref.read(journalLockProvider).value;
    final nowHasPin = updated?.hasPin ?? false;
    final message = hasPin
        ? (nowHasPin ? 'Journal PIN updated.' : 'Journal PIN removed.')
        : 'Journal PIN set. Journal will re-lock when you close the app.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

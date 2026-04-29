import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/sync/sync_service.dart';
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../state/journal_lock.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';

const int _kMinPinLength = 4;
const int _kMaxPinLength = 12;

/// Prompts for the configured PIN. Returns true if the user successfully
/// unlocks (the [JournalLockNotifier] is updated as a side-effect), false
/// if they cancel.
Future<bool> promptForJournalPin(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _PinPromptDialog(),
  );
  return result ?? false;
}

/// Set or change the journal PIN. If a PIN already exists, requires the
/// current PIN before accepting a new one. Returns true if the PIN was
/// successfully set or cleared, false if the user cancelled.
Future<bool> showJournalPinSetupDialog(
  BuildContext context, {
  required bool hasExistingPin,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PinSetupDialog(hasExistingPin: hasExistingPin),
  );
  return result ?? false;
}

class _PinPromptDialog extends ConsumerStatefulWidget {
  const _PinPromptDialog();

  @override
  ConsumerState<_PinPromptDialog> createState() => _PinPromptDialogState();
}

class _PinPromptDialogState extends ConsumerState<_PinPromptDialog> {
  final _controller = TextEditingController();
  String? _error;
  bool _popped = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onChanged(String value) async {
    if (_popped) return;
    if (_error != null) setState(() => _error = null);
    if (value.length < _kMinPinLength) return;
    final ok = await ref.read(journalLockProvider.notifier).tryUnlock(value);
    if (!mounted || _popped) return;
    if (ok) {
      _popped = true;
      Navigator.of(context).pop(true);
      return;
    }
    // No inline error while typing — they may simply not be done. Only flag
    // once they reach max length without being correct.
    if (value.length >= _kMaxPinLength) {
      setState(() {
        _error = 'Incorrect PIN.';
        _controller.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(LucideIcons.lock, size: 18, color: AppColors.textPrimary),
          SizedBox(width: 10),
          Text('Unlock journal'),
        ],
      ),
      content: _PinField(
        controller: _controller,
        autofocus: true,
        onChanged: _onChanged,
        errorText: _error,
        hintText: 'Enter PIN',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _PinSetupDialog extends ConsumerStatefulWidget {
  const _PinSetupDialog({required this.hasExistingPin});
  final bool hasExistingPin;

  @override
  ConsumerState<_PinSetupDialog> createState() => _PinSetupDialogState();
}

enum _SetupStep { current, newPin, confirm }

class _PinSetupDialogState extends ConsumerState<_PinSetupDialog> {
  late _SetupStep _step;
  final _controller = TextEditingController();
  String? _newPin;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _step = widget.hasExistingPin ? _SetupStep.current : _SetupStep.newPin;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final value = _controller.text;
    if (value.length < _kMinPinLength) {
      setState(() => _error = 'PIN must be at least $_kMinPinLength digits.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });

    if (_step == _SetupStep.current) {
      final ok = await ref.read(secureSettingsProvider).verifyJournalPin(value);
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _busy = false;
          _error = 'Incorrect current PIN.';
          _controller.clear();
        });
        return;
      }
      setState(() {
        _busy = false;
        _step = _SetupStep.newPin;
        _controller.clear();
      });
      return;
    }

    if (_step == _SetupStep.newPin) {
      setState(() {
        _busy = false;
        _newPin = value;
        _step = _SetupStep.confirm;
        _controller.clear();
      });
      return;
    }

    // confirm step
    if (value != _newPin) {
      setState(() {
        _busy = false;
        _error = 'PINs don\'t match.';
        _controller.clear();
      });
      return;
    }
    await ref.read(journalLockProvider.notifier).setPin(value);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _removePin() async {
    setState(() => _busy = true);
    await ref.read(journalLockProvider.notifier).setPin(null);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final (title, hint, helper) = switch (_step) {
      _SetupStep.current => (
        'Confirm current PIN',
        'Current PIN',
        'Enter the PIN you set previously to make changes.',
      ),
      _SetupStep.newPin => (
        widget.hasExistingPin ? 'New PIN' : 'Set journal PIN',
        'New PIN',
        '$_kMinPinLength to $_kMaxPinLength digits. You\'ll be asked to confirm.',
      ),
      _SetupStep.confirm => (
        'Confirm new PIN',
        'Re-enter PIN',
        'Type the new PIN again to confirm.',
      ),
    };

    return AlertDialog(
      title: Row(
        children: [
          const Icon(LucideIcons.lock, size: 18, color: AppColors.textPrimary),
          const SizedBox(width: 10),
          Expanded(child: Text(title)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            helper,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          _PinField(
            controller: _controller,
            autofocus: true,
            enabled: !_busy,
            onSubmitted: (_) => _submit(),
            errorText: _error,
            hintText: hint,
          ),
        ],
      ),
      actions: [
        if (_step == _SetupStep.current && widget.hasExistingPin) ...[
          TextButton(
            onPressed: _busy ? null : _removePin,
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Remove PIN'),
          ),
          const Spacer(),
        ],
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(switch (_step) {
                  _SetupStep.current => 'Continue',
                  _SetupStep.newPin => 'Next',
                  _SetupStep.confirm => 'Save',
                }),
        ),
      ],
    );
  }
}

/// Numeric PIN entry. Obscured by default, restricted to digits up to
/// [_kMaxPinLength] characters.
class _PinField extends StatelessWidget {
  const _PinField({
    required this.controller,
    required this.hintText,
    this.autofocus = false,
    this.enabled = true,
    this.errorText,
    this.onSubmitted,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final bool autofocus;
  final bool enabled;
  final String? errorText;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      enabled: enabled,
      obscureText: true,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      maxLength: _kMaxPinLength,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(_kMaxPinLength),
      ],
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      style: const TextStyle(
        fontSize: 22,
        letterSpacing: 6,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        counterText: '',
        errorText: errorText,
        hintStyle: const TextStyle(
          color: AppColors.textMuted,
          letterSpacing: 0,
          fontSize: 14,
        ),
      ),
    );
  }
}

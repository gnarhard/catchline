import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../theme/app_theme.dart';

/// Generates / displays an AI synopsis of a journal entry.
///
/// Visual is the design's "AI button expanded" treatment: rose-tinted card,
/// SPARKLES eyebrow, italic Fraunces body. Idle state is the rose pill that
/// reads "Generate synopsis".
class AiSynopsisCard extends StatelessWidget {
  const AiSynopsisCard({
    super.key,
    required this.synopsis,
    required this.isGenerating,
    required this.onGenerate,
    required this.onClear,
  });

  final String? synopsis;
  final bool isGenerating;
  final Future<void> Function() onGenerate;
  final Future<void> Function() onClear;

  @override
  Widget build(BuildContext context) {
    final hasSynopsis = synopsis != null && synopsis!.isNotEmpty;
    if (isGenerating) return const _Loading();
    if (!hasSynopsis) {
      return _AiPillButton(label: 'Generate synopsis', onPressed: onGenerate);
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accent.withAlpha(15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withAlpha(56)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.sparkles,
                size: 13,
                color: AppColors.accent,
              ),
              const SizedBox(width: 7),
              const Text(
                'SYNOPSIS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: AppColors.accent,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onGenerate,
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Regenerate',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ),
              IconButton(
                onPressed: onClear,
                icon: const Icon(LucideIcons.x, size: 14),
                color: AppColors.textMuted,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 4),
          SelectableText(
            synopsis!,
            style: serifStyle(
              fontSize: 13,
              color: const Color(0xFFE8D8D8),
              height: 1.5,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: synopsis!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Synopsis copied.')),
                );
              },
              icon: const Icon(LucideIcons.copy, size: 12),
              label: const Text('Copy', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accentDeep,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiPillButton extends StatelessWidget {
  const _AiPillButton({required this.label, required this.onPressed});
  final String label;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(LucideIcons.sparkles, size: 14),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accent,
          side: BorderSide(color: AppColors.accent.withAlpha(102)),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 18),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accent.withAlpha(15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withAlpha(56)),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accent,
            ),
          ),
          SizedBox(width: 12),
          Text(
            'Generating…',
            style: TextStyle(fontSize: 13, color: AppColors.textDim),
          ),
        ],
      ),
    );
  }
}

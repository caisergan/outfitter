import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fashion_app/core/models/playground_models.dart';
import 'package:fashion_app/core/theme/app_colors.dart';
import 'package:fashion_app/features/playground/data/playground_repository.dart';

/// Full snapshot view of a past run. Re-fetches /playground/runs/{id} to get
/// fresh signed image URLs (the list-page URLs are 15 min and may have
/// expired). Shows all images, full system + user prompt text, and a
/// Reproduce button that delegates to the caller.
class RunDetailSheet extends ConsumerWidget {
  final String runId;
  final Future<void> Function(PlaygroundRun run) onReproduce;

  const RunDetailSheet({
    required this.runId,
    required this.onReproduce,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runAsync = ref.watch(_runDetailProvider(runId));

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: runAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load run: $err',
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
            data: (run) =>
                _Body(run: run, scrollController: scrollController, onReproduce: onReproduce),
          ),
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  final PlaygroundRun run;
  final ScrollController scrollController;
  final Future<void> Function(PlaygroundRun run) onReproduce;

  const _Body({
    required this.run,
    required this.scrollController,
    required this.onReproduce,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: ListView(
        controller: scrollController,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Run snapshot',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ID ${run.id.substring(0, 8)} · ${run.size} · ${run.quality} · n=${run.n} · ${run.elapsedMs}ms',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (run.images.isNotEmpty)
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: run.images.length == 1 ? 1 : 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: run.images
                  .map(
                    (url) => ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppColors.surfaceAlt,
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image_outlined,
                              color: AppColors.textMuted),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          if (run.errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      run.errorMessage!,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          _PromptBlock(
            label: 'System prompt',
            content: run.systemPromptText,
          ),
          const SizedBox(height: 12),
          _PromptBlock(
            label: 'User prompt',
            content:
                run.userPromptText.isEmpty ? '(empty)' : run.userPromptText,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Reproduce'),
            onPressed: () async {
              Navigator.of(context).pop();
              await onReproduce(run);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.text,
              foregroundColor: AppColors.surface,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromptBlock extends StatelessWidget {
  final String label;
  final String content;
  const _PromptBlock({required this.label, required this.content});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          constraints: const BoxConstraints(maxHeight: 220),
          decoration: BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              content,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: AppColors.text,
                  ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Family provider that fetches a single run by id; used by RunDetailSheet
/// so the modal owns its own loading/error states.
final _runDetailProvider =
    FutureProvider.family<PlaygroundRun, String>((ref, runId) async {
  return ref.read(playgroundRepositoryProvider).getRun(runId);
});

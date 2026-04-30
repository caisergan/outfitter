import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fashion_app/core/models/playground_models.dart';
import 'package:fashion_app/core/theme/app_colors.dart';
import 'package:fashion_app/features/playground/providers/playground_library_provider.dart';
import 'package:fashion_app/features/playground/providers/playground_runs_provider.dart';

import 'run_detail_sheet.dart';

/// Modal bottom sheet listing the user's recent playground runs (newest
/// first) with thumbnails, status badges, prompt excerpts, and tap-to-view
/// or reproduce actions.
class RecentRunsSheet extends ConsumerWidget {
  final Future<void> Function(PlaygroundRun run) onReproduce;

  const RecentRunsSheet({required this.onReproduce, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runs = ref.watch(playgroundRunsProvider);
    final lib = ref.watch(playgroundLibraryProvider).valueOrNull;
    final notifier = ref.read(playgroundRunsProvider.notifier);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              _Handle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recent runs',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          Text(
                            'Tap to view a snapshot or reproduce.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: runs.loading ? null : notifier.refresh,
                      icon: runs.loading
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _buildBody(context, runs, lib, scrollController),
              ),
              if (runs.nextCursor != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: OutlinedButton(
                    onPressed: runs.loading ? null : notifier.loadMore,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      side: const BorderSide(color: AppColors.border),
                      foregroundColor: AppColors.text,
                    ),
                    child: Text(runs.loading ? 'Loading…' : 'Load more'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    PlaygroundRunsState runs,
    PlaygroundLibrary? lib,
    ScrollController scrollController,
  ) {
    if (runs.error != null && runs.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Could not load runs: ${runs.error}',
          style: const TextStyle(color: AppColors.danger),
        ),
      );
    }
    if (runs.items.isEmpty && runs.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (runs.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text(
            'No runs yet. Generate something to see it here.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      itemCount: runs.items.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 12, color: AppColors.border),
      itemBuilder: (context, i) => _RunRow(
        run: runs.items[i],
        library: lib,
        onView: () => _openDetail(context, runs.items[i]),
        onReproduce: () => onReproduce(runs.items[i]),
      ),
    );
  }

  void _openDetail(BuildContext context, PlaygroundRun run) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RunDetailSheet(
        runId: run.id,
        onReproduce: onReproduce,
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.borderStrong,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _RunRow extends StatelessWidget {
  final PlaygroundRun run;
  final PlaygroundLibrary? library;
  final VoidCallback onView;
  final VoidCallback onReproduce;

  const _RunRow({
    required this.run,
    required this.library,
    required this.onView,
    required this.onReproduce,
  });

  @override
  Widget build(BuildContext context) {
    final templateLabel = library?.templates
        .where((t) => t.id == run.templateId)
        .firstOrNull
        ?.label;
    final persona = library?.allPersonas
        .where((p) => p.id == run.personaId)
        .firstOrNull;
    final timestamp = _formatTimestamp(run.createdAt.toLocal());
    final isFailed = run.status == 'failed';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 64,
          height: 86,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              color: AppColors.surfaceAlt,
              child: run.images.isNotEmpty
                  ? Image.network(
                      run.images.first,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const _ThumbPlaceholder(),
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                              ? child
                              : const Center(
                                  child: SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                ),
                    )
                  : const _ThumbPlaceholder(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatusBadge(status: run.status),
                  const SizedBox(width: 8),
                  Text(
                    timestamp,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                isFailed
                    ? (run.errorMessage ?? 'Generation failed')
                    : _excerpt(run.userPromptText.isNotEmpty
                        ? run.userPromptText
                        : run.systemPromptText),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isFailed ? AppColors.danger : AppColors.text,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                '${templateLabel ?? '—'} · ${run.size} · n=${run.n}'
                '${persona != null ? ' · ${persona.gender == 'female' ? 'F' : 'M'} ${persona.label}' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.refresh, size: 14),
                    label: const Text('Reproduce'),
                    onPressed: onReproduce,
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    icon: const Icon(Icons.visibility_outlined, size: 14),
                    label: const Text('View'),
                    onPressed: onView,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _excerpt(String text, {int max = 90}) {
    final firstLine = text.split('\n').firstWhere(
          (l) => l.trim().isNotEmpty,
          orElse: () => '',
        );
    return firstLine.length > max ? '${firstLine.substring(0, max - 1)}…' : firstLine;
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _formatTimestamp(DateTime t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '${_months[t.month - 1]} ${t.day}, $hh:$mm';
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isFailed = status == 'failed';
    final color = isFailed ? AppColors.danger : AppColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _ThumbPlaceholder extends StatelessWidget {
  const _ThumbPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.image_outlined,
        color: AppColors.textMuted,
        size: 22,
      ),
    );
  }
}

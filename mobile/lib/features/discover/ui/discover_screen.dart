import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../assistant/providers/assistant_provider.dart';

class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'OUTFITTER',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.textMuted,
                letterSpacing: 2,
              ),
            ),
            Text(
              'Discover',
              style: theme.textTheme.titleLarge,
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton.outlined(
              onPressed: () => context.go('/profile'),
              style: IconButton.styleFrom(
                side: const BorderSide(color: AppColors.line),
                foregroundColor: AppColors.text,
              ),
              icon: const Icon(Icons.person_outline),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(savedOutfitsProvider),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            _EditorialHero(
              onPrimaryTap: () => context.go('/playground'),
            ),
            const SizedBox(height: 32),
            const _SectionHeader(
              eyebrow: 'OCCASION EDITS',
              title: 'Built for the day ahead.',
              description:
                  'Start with a mood, then send it straight into the stylist.',
            ),
            const SizedBox(height: 16),
            const _OccasionRail(),
            const SizedBox(height: 32),
            const _SectionHeader(
              eyebrow: 'SAVED LOOKS',
              title: 'Your private lookbook.',
              description: 'Reopen recent styling sets without rebuilding them.',
            ),
            const SizedBox(height: 16),
            const _SavedOutfitsSection(),
          ],
        ),
      ),
    );
  }
}

class _EditorialHero extends StatelessWidget {
  final VoidCallback onPrimaryTap;

  const _EditorialHero({required this.onPrimaryTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 420,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const CachedItemImage(
            url:
                'https://images.unsplash.com/photo-1529139574466-a303027c1d8b?q=80&w=1400&auto=format&fit=crop',
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.06),
                  Colors.black.withValues(alpha: 0.2),
                  Colors.black.withValues(alpha: 0.52),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SPRING CITY EDIT',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                    letterSpacing: 2.2,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 270,
                  child: Text(
                    'Cool tailoring, soft layers, and cleaner silhouettes.',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      height: 1.02,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: 280,
                  child: Text(
                    'Build a look in the canvas, then refine it with the stylist.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: onPrimaryTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.text,
                    minimumSize: const Size(150, 52),
                  ),
                  child: const Text('Build a look'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String description;

  const _SectionHeader({
    required this.eyebrow,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.textMuted,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontSize: 24,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _OccasionRail extends StatelessWidget {
  const _OccasionRail();

  final List<_OccasionCardData> _items = const [
    _OccasionCardData(
      label: 'Work Wear',
      prompt: 'work',
      image:
          'https://images.unsplash.com/photo-1483985988355-763728e1935b?q=80&w=1200&auto=format&fit=crop',
    ),
    _OccasionCardData(
      label: 'Brunch Date',
      prompt: 'brunch',
      image:
          'https://images.unsplash.com/photo-1496747611176-843222e1e57c?q=80&w=1200&auto=format&fit=crop',
    ),
    _OccasionCardData(
      label: 'Night Out',
      prompt: 'party',
      image:
          'https://images.unsplash.com/photo-1512436991641-6745cdb1723f?q=80&w=1200&auto=format&fit=crop',
    ),
    _OccasionCardData(
      label: 'Travel',
      prompt: 'travel',
      image:
          'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?q=80&w=1200&auto=format&fit=crop',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 250,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final item = _items[index];
          return GestureDetector(
            onTap: () => context.go(
              '/assistant',
              extra: {'occasion': item.prompt},
            ),
            child: SizedBox(
              width: 184,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: AppColors.line),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: CachedItemImage(url: item.image),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.48),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Spacer(),
                        Text(
                          item.label,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SavedOutfitsSection extends ConsumerWidget {
  const _SavedOutfitsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedOutfits = ref.watch(savedOutfitsProvider);

    return savedOutfits.when(
      data: (outfits) {
        if (outfits.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.backgroundElevated,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.lightMint,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.bookmark_outline, color: AppColors.text),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'No saved looks yet. Build one in the playground and it will appear here.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textMuted,
                        ),
                  ),
                ),
              ],
            ),
          );
        }

        return SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: outfits.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final outfit = outfits[index];

              return GestureDetector(
                onTap: () => context.go(
                  '/playground',
                  extra: {'slots': outfit.slots},
                ),
                child: SizedBox(
                  width: 156,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.backgroundElevated,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppColors.line),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: outfit.generatedImageUrl != null
                              ? CachedItemImage(url: outfit.generatedImageUrl!)
                              : const Center(
                                  child: Icon(
                                    Icons.checkroom_outlined,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Look ${index + 1}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontSize: 15,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${outfit.slots.length} pieces',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _OccasionCardData {
  final String label;
  final String prompt;
  final String image;

  const _OccasionCardData({
    required this.label,
    required this.prompt,
    required this.image,
  });
}

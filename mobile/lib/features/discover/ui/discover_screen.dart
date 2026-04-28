import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../assistant/providers/assistant_provider.dart';

class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  static const _editorialStories = [
    _StoryCardData(
      title: 'Soft tailoring',
      subtitle: 'Relaxed outer layers, fluid trousers, and polished neutrals.',
      imageUrl:
          'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?q=80&w=1200&auto=format&fit=crop',
      tag: 'Edit 01',
    ),
    _StoryCardData(
      title: 'Weekend monochrome',
      subtitle: 'A quieter mix of ivory, oat, and washed black.',
      imageUrl:
          'https://images.unsplash.com/photo-1529139574466-a303027c1d8b?q=80&w=1200&auto=format&fit=crop',
      tag: 'Edit 02',
    ),
    _StoryCardData(
      title: 'Evening texture',
      subtitle: 'Satin accents, sharp lines, and understated shine.',
      imageUrl:
          'https://images.unsplash.com/photo-1496747611176-843222e1e57c?q=80&w=1200&auto=format&fit=crop',
      tag: 'Edit 03',
    ),
  ];

  static const _occasionCards = [
    _OccasionCardData(
      title: 'Brunch Date',
      subtitle: 'Soft layers and relaxed polish.',
      occasion: 'brunch date',
      imageUrl:
          'https://images.unsplash.com/photo-1483985988355-763728e1935b?q=80&w=1200&auto=format&fit=crop',
    ),
    _OccasionCardData(
      title: 'Work Wear',
      subtitle: 'Clean lines for office-to-dinner dressing.',
      occasion: 'work wear',
      imageUrl:
          'https://images.unsplash.com/photo-1487412720507-e7ab37603c6f?q=80&w=1200&auto=format&fit=crop',
    ),
    _OccasionCardData(
      title: 'Night Out',
      subtitle: 'Sharp contrast with a more dressed-up finish.',
      occasion: 'night out',
      imageUrl:
          'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?q=80&w=1200&auto=format&fit=crop',
    ),
    _OccasionCardData(
      title: 'Travel',
      subtitle: 'Layerable pieces built for movement.',
      occasion: 'travel',
      imageUrl:
          'https://images.unsplash.com/photo-1512436991641-6745cdb1723f?q=80&w=1200&auto=format&fit=crop',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        toolbarHeight: 76,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Discover',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              'Curated edits for quieter, more elevated dressing.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              tooltip: 'Profile',
              icon: const Icon(Icons.person_outline),
              onPressed: () => context.go('/profile'),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(savedOutfitsProvider);
        },
        color: AppColors.blush,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _DiscoverHero(
              onAskStylist: () => context.go('/assistant'),
              onOpenWardrobe: () => context.go('/wardrobe'),
            ),
            const SizedBox(height: 32),
            const _SectionHeader(
              eyebrow: 'Seasonal Edit',
              title: 'Styled like an editorial rail.',
              subtitle:
                  'Use these looks as a starting point for the studio or your saved lookbook.',
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 286,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _editorialStories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final story = _editorialStories[index];
                  return _StoryCard(data: story);
                },
              ),
            ),
            const SizedBox(height: 36),
            const _SectionHeader(
              eyebrow: 'Occasions',
              title: 'Choose the mood, let the stylist set the direction.',
            ),
            const SizedBox(height: 18),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _occasionCards.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.82,
              ),
              itemBuilder: (context, index) {
                final occasion = _occasionCards[index];
                return _OccasionCard(
                  data: occasion,
                  onTap: () => context.go(
                    '/assistant',
                    extra: {'occasion': occasion.occasion},
                  ),
                );
              },
            ),
            const SizedBox(height: 36),
            const _SectionHeader(
              eyebrow: 'Lookbook',
              title: 'Recently saved',
              subtitle:
                  'Open a saved outfit in the studio and continue refining it.',
            ),
            const SizedBox(height: 18),
            _SavedOutfitsSection(ref: ref),
          ],
        ),
      ),
    );
  }
}

class _DiscoverHero extends StatelessWidget {
  final VoidCallback onAskStylist;
  final VoidCallback onOpenWardrobe;

  const _DiscoverHero({
    required this.onAskStylist,
    required this.onOpenWardrobe,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: SizedBox(
        height: 430,
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
                    Colors.black.withValues(alpha: 0.08),
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Text(
                      'APRIL CURATION',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Colors.white,
                            letterSpacing: 1.0,
                          ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Quiet luxury, cut for everyday wear.',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: Colors.white,
                          height: 1.02,
                        ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: Text(
                      'Build looks from your wardrobe and the catalog with cleaner silhouettes, softer layers, and more room for the imagery to lead.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.82),
                            height: 1.45,
                          ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: onAskStylist,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.surface,
                            foregroundColor: AppColors.text,
                          ),
                          child: const Text('Ask Stylist'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onOpenWardrobe,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.26),
                            ),
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.04),
                          ),
                          child: const Text('Open Wardrobe'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? subtitle;

  const _SectionHeader({
    required this.eyebrow,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.textMuted,
                letterSpacing: 1.2,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: 24,
              ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                ),
          ),
        ],
      ],
    );
  }
}

class _StoryCard extends StatelessWidget {
  final _StoryCardData data;

  const _StoryCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedItemImage(url: data.imageUrl),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.05),
                    Colors.black.withValues(alpha: 0.46),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.tag.toUpperCase(),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.78),
                          letterSpacing: 1.0,
                        ),
                  ),
                  const Spacer(),
                  Text(
                    data.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontSize: 22,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    data.subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                          height: 1.4,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OccasionCard extends StatelessWidget {
  final _OccasionCardData data;
  final VoidCallback onTap;

  const _OccasionCard({
    required this.data,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedItemImage(url: data.imageUrl),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.02),
                        Colors.black.withValues(alpha: 0.44),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Spacer(),
                      Text(
                        data.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        data.subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.82),
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SavedOutfitsSection extends StatelessWidget {
  final WidgetRef ref;

  const _SavedOutfitsSection({required this.ref});

  @override
  Widget build(BuildContext context) {
    final savedOutfits = ref.watch(savedOutfitsProvider);

    return savedOutfits.when(
      data: (outfits) {
        if (outfits.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your lookbook is still empty.',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 22,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Save a look from the studio to keep it ready for later refinement.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textMuted,
                      ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: 180,
                  child: OutlinedButton(
                    onPressed: () => context.go('/playground'),
                    child: const Text('Open Studio'),
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
              return SizedBox(
                width: 156,
                child: Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    onTap: () => context.go(
                      '/playground',
                      extra: {'slots': outfit.slots},
                    ),
                    borderRadius: BorderRadius.circular(24),
                    child: Ink(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(24),
                              ),
                              child: outfit.generatedImageUrl != null
                                  ? CachedItemImage(
                                      url: outfit.generatedImageUrl!,
                                    )
                                  : Container(
                                      color: AppColors.surfaceAlt,
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.checkroom_outlined,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Look ${index + 1}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(
                                        color: AppColors.textMuted,
                                        letterSpacing: 0.9,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${outfit.slots.length} selected pieces',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          'Could not load saved outfits right now.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textMuted,
              ),
        ),
      ),
    );
  }
}

class _StoryCardData {
  final String title;
  final String subtitle;
  final String imageUrl;
  final String tag;

  const _StoryCardData({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.tag,
  });
}

class _OccasionCardData {
  final String title;
  final String subtitle;
  final String occasion;
  final String imageUrl;

  const _OccasionCardData({
    required this.title,
    required this.subtitle,
    required this.occasion,
    required this.imageUrl,
  });
}

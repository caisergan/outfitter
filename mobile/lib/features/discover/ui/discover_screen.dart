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
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        title: const Text('Discover'),
        iconTheme: const IconThemeData(color: AppColors.text),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline, color: AppColors.text),
            onPressed: () => context.go('/profile'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(savedOutfitsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Curated daily',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.secondaryText,
                            letterSpacing: 1.8,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Refined edits for the week ahead.',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Browse seasonal inspiration, then jump straight into styling.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.secondaryText,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            const _SectionTitle(
              title: 'Seasonal Edits',
              subtitle: 'Image-led outfit directions with room to browse.',
            ),
            const SizedBox(height: 18),
            _buildHorizontalOutfitRow(context),
            const SizedBox(height: 36),
            const _SectionTitle(
              title: 'Occasion Collections',
              subtitle: 'Choose a direction and move into the assistant.',
            ),
            const SizedBox(height: 18),
            _buildOccasionGrid(context),
            const SizedBox(height: 36),
            const _SectionTitle(
              title: 'Recently Saved',
              subtitle: 'Return to outfits you already saved.',
            ),
            const SizedBox(height: 18),
            _buildSavedOutfitsSection(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalOutfitRow(BuildContext context) {
    return SizedBox(
      height: 304,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 18),
        itemBuilder: (context, index) {
          return Container(
            width: 224,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppColors.divider),
              color: AppColors.surface,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const CachedItemImage(
                  url:
                      'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?q=80&w=1000&auto=format&fit=crop',
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        AppColors.text.withValues(alpha: 0.72),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  top: 18,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.paper.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: const Text(
                      'SEASONAL EDIT',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 20,
                  left: 18,
                  right: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        index.isEven ? 'Spring Essentials' : 'Quiet Luxury',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppColors.background,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Soft tailoring, tonal layers, and clean proportions.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color:
                                  AppColors.background.withValues(alpha: 0.88),
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOccasionGrid(BuildContext context) {
    final occasions = [
      {'name': 'Brunch Date', 'icon': Icons.restaurant_menu},
      {'name': 'Work Wear', 'icon': Icons.business_center},
      {'name': 'Night Out', 'icon': Icons.nightlife},
      {'name': 'Gym Ready', 'icon': Icons.fitness_center},
    ];

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: occasions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.12,
      ),
      itemBuilder: (context, index) {
        final occasion = occasions[index];

        return InkWell(
          onTap: () => context.go(
            '/assistant',
            extra: {'occasion': (occasion['name'] as String).toLowerCase()},
          ),
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.divider),
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.paper,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Icon(
                    occasion['icon'] as IconData,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
                const Spacer(),
                Text(
                  occasion['name'] as String,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Open styled suggestions',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSavedOutfitsSection(BuildContext context, WidgetRef ref) {
    final savedOutfits = ref.watch(savedOutfitsProvider);

    return savedOutfits.when(
      data: (outfits) {
        if (outfits.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.divider),
              ),
              child: Text(
                'No saved outfits yet. Create one in the Playground.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.secondaryText,
                    ),
              ),
            ),
          );
        }

        return SizedBox(
          height: 158,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            scrollDirection: Axis.horizontal,
            itemCount: outfits.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final outfit = outfits[index];

              return InkWell(
                onTap: () => context.go(
                  '/playground',
                  extra: {'slots': outfit.slots},
                ),
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: 132,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.divider),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: outfit.generatedImageUrl != null
                            ? CachedItemImage(url: outfit.generatedImageUrl!)
                            : const Center(
                                child: Icon(
                                  Icons.checkroom,
                                  color: AppColors.text,
                                ),
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Saved Look',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Open in Playground',
                              style: Theme.of(context).textTheme.bodySmall,
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
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.secondaryText,
                ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../assistant/providers/assistant_provider.dart';
import '../../../core/widgets/shared_widgets.dart';

class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/discover/profile'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(savedOutfitsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          children: [
             _buildSectionHeader(context, "Seasonal Edits"),
             const SizedBox(height: 16),
             _buildHorizontalOutfitRow(context),
             const SizedBox(height: 32),
             _buildSectionHeader(context, "Occasion Collections"),
             const SizedBox(height: 16),
             _buildOccasionGrid(context),
             const SizedBox(height: 32),
             _buildSectionHeader(context, "Recently Saved"),
             const SizedBox(height: 16),
             _buildSavedOutfitsSection(ref),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
      ),
    );
  }

  Widget _buildHorizontalOutfitRow(BuildContext context) {
    // Mocking seasonal edits for MVP
    return SizedBox(
      height: 240,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          return Container(
            width: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.grey.shade200,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const CachedItemImage(
                  url: 'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?q=80&w=1000&auto=format&fit=crop',
                ),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black54],
                    ),
                  ),
                ),
                const Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Text(
                    'Spring Essentials',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
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
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.5,
      ),
      itemCount: occasions.length,
      itemBuilder: (context, index) {
        final occasion = occasions[index];
        return InkWell(
          onTap: () => context.go('/assistant', extra: {'occasion': (occasion['name'] as String).toLowerCase()}),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(occasion['icon'] as IconData, size: 20, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                Text(
                  occasion['name'] as String,
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSavedOutfitsSection(WidgetRef ref) {
    final savedOutfits = ref.watch(savedOutfitsProvider);

    return savedOutfits.when(
      data: (outfits) {
        if (outfits.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text('No saved outfits yet. Create one in the Playground!'),
          );
        }
        return SizedBox(
          height: 120,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            scrollDirection: Axis.horizontal,
            itemCount: outfits.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final outfit = outfits[index];
              return InkWell(
                onTap: () => context.go('/playground', extra: {'slots': outfit.slots}),
                child: Container(
                  width: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: outfit.generatedImageUrl != null 
                    ? CachedItemImage(url: outfit.generatedImageUrl!)
                    : const Center(child: Icon(Icons.checkroom, color: Colors.grey)),
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

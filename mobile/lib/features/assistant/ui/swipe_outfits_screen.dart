import 'package:flutter/material.dart';

import '../../../core/models/outfit_models.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/shared_widgets.dart';
import '/features/playground/ui/playground_screen.dart';

class SwipeOutfitsScreen extends StatefulWidget {
  final List<OutfitSuggestion> outfits;

  const SwipeOutfitsScreen({
    super.key,
    required this.outfits,
  });

  @override
  State<SwipeOutfitsScreen> createState() => _SwipeOutfitsScreenState();
}

class _SwipeOutfitsScreenState extends State<SwipeOutfitsScreen> {
  final List<OutfitSuggestion> liked = [];
  int index = 0;

  @override
  Widget build(BuildContext context) {
    if (index >= widget.outfits.length) {
      return _buildResultScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'LOOK REVIEW',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textMuted,
                    letterSpacing: 2,
                  ),
            ),
            Text(
              'Outfits ${index + 1}/${widget.outfits.length}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          ...List.generate(
            widget.outfits.length - index,
            (i) {
              final outfit = widget.outfits[index + i];

              return SwipeCard(
                outfit: outfit,
                isTop: i == 0,
                onSwiped: (direction) {
                  if (direction == 'right') {
                    liked.add(outfit);
                  }
                  setState(() => index++);
                },
              );
            },
          ).reversed,
          Positioned(
            left: 24,
            right: 24,
            bottom: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.backgroundElevated,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  const Icon(Icons.swipe, color: AppColors.textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Swipe right to keep, left to move on.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultScreen() {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SELECTED LOOKS',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textMuted,
                    letterSpacing: 2,
                  ),
            ),
            Text(
              'Your likes',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      ),
      body: liked.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: AppColors.lightMint,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: const Icon(
                        Icons.favorite_border_outlined,
                        size: 34,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'No liked outfits yet.',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Run the stylist again and keep the looks that feel closest.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textMuted,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : PageView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: liked.length,
              controller: PageController(viewportFraction: 0.9),
              itemBuilder: (context, i) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
                  child: _LikedCard(outfit: liked[i]),
                );
              },
            ),
    );
  }
}

class SwipeCard extends StatefulWidget {
  final OutfitSuggestion outfit;
  final bool isTop;
  final Function(String direction) onSwiped;

  const SwipeCard({
    super.key,
    required this.outfit,
    required this.isTop,
    required this.onSwiped,
  });

  @override
  State<SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<SwipeCard> {
  Offset position = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final slots = widget.outfit.slots;

    return Positioned.fill(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 92),
        child: GestureDetector(
          onPanUpdate: widget.isTop
              ? (d) => setState(() => position += d.delta)
              : null,
          onPanEnd: (_) => _handleSwipe(),
          child: Transform.translate(
            offset: position,
            child: Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(32),
              clipBehavior: Clip.antiAlias,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: AppColors.line),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _item(slots['top'])),
                    const SizedBox(height: 10),
                    Expanded(flex: 3, child: _item(slots['bottom'])),
                    const SizedBox(height: 10),
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: [
                          Expanded(child: _item(slots['shoes'], scale: 0.92)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              children: slots.entries
                                  .where((e) =>
                                      e.key != 'top' &&
                                      e.key != 'bottom' &&
                                      e.key != 'shoes')
                                  .take(2)
                                  .map(
                                    (e) => Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(bottom: 10),
                                        child: _item(e.value, scale: 0.84),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      widget.outfit.styleNote,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textMuted,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleSwipe() {
    final dx = position.dx;

    if (dx > 120) {
      widget.onSwiped('right');
    } else if (dx < -120) {
      widget.onSwiped('left');
    }

    setState(() => position = Offset.zero);
  }

  Widget _item(SlotItem? item, {double scale = 1}) {
    if (item == null) return const SizedBox();

    return Transform.scale(
      scale: scale,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: AppColors.backgroundElevated,
          border: Border.all(color: AppColors.line),
        ),
        padding: const EdgeInsets.all(14),
        clipBehavior: Clip.antiAlias,
        child: CachedItemImage(
          url: item.imageUrl,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _LikedCard extends StatelessWidget {
  final OutfitSuggestion outfit;

  const _LikedCard({required this.outfit});

  @override
  Widget build(BuildContext context) {
    final slots = outfit.slots;

    final accessories = slots.entries
        .where((e) => e.key != 'top' && e.key != 'bottom' && e.key != 'shoes')
        .map((e) => e.value)
        .toList();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Expanded(child: _previewPanel(slots['top']!.imageUrl)),
                  const SizedBox(height: 10),
                  Expanded(child: _previewPanel(slots['bottom']!.imageUrl)),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(child: _previewPanel(slots['shoes']!.imageUrl)),
                        const SizedBox(width: 10),
                        if (accessories.isNotEmpty)
                          Expanded(child: _previewPanel(accessories.first.imageUrl))
                        else
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.backgroundElevated,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: AppColors.line),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  outfit.styleNote,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textMuted,
                      ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PlaygroundScreen(
                                prefilledSlots: {
                                  'top': outfit.slots['top']?.imageUrl ?? '',
                                  'bottom': outfit.slots['bottom']?.imageUrl ?? '',
                                  'shoes': outfit.slots['shoes']?.imageUrl ?? '',
                                },
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.outlined(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Liked')),
                        );
                      },
                      icon: const Icon(Icons.favorite_outline),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Saved')),
                        );
                      },
                      icon: const Icon(Icons.bookmark_outline),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewPanel(String url) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
      ),
      padding: const EdgeInsets.all(14),
      child: CachedItemImage(
        url: url,
        fit: BoxFit.contain,
      ),
    );
  }
}

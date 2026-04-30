import 'package:flutter/material.dart';

import '../../../core/models/outfit_models.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/shared_widgets.dart';
import '/features/tryon/ui/tryon_screen.dart';

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
      return _buildResultScreen(context);
    }

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        toolbarHeight: 76,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Styled looks',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              '${index + 1} of ${widget.outfits.length}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Stack(
          children: List.generate(
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
          ).reversed.toList(),
        ),
      ),
    );
  }

  Widget _buildResultScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: Text(
          'Saved from this round',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
      body: liked.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 82,
                      height: 82,
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceAlt,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite_border_outlined,
                        color: AppColors.blush,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'No liked outfits yet.',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Run another stylist round when you want a different direction.',
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
                  padding: const EdgeInsets.symmetric(vertical: 14),
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
      child: GestureDetector(
        onPanUpdate:
            widget.isTop ? (d) => setState(() => position += d.delta) : null,
        onPanEnd: (_) => _handleSwipe(),
        child: Transform.translate(
          offset: position,
          child: Material(
            color: AppColors.surface,
            elevation: 0,
            borderRadius: BorderRadius.circular(32),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: AppColors.border),
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final h = constraints.maxHeight;
                        final w = constraints.maxWidth;
                        return Stack(
                          children: [
                            // Bottom layer.
                            Positioned(
                              top: h * 0.30,
                              left: 0,
                              width: w,
                              height: h * 0.65,
                              child: CachedItemImage(
                                url: slots['bottom']!.imageUrl,
                                fit: BoxFit.contain,
                              ),
                            ),
                            // Middle layer.
                            Positioned(
                              top: h * 0.00,
                              left: 0,
                              width: w,
                              height: h * 0.70,
                              child: CachedItemImage(
                                url: slots['top']!.imageUrl,
                                fit: BoxFit.contain,
                              ),
                            ),
                            // Front layer.
                            Positioned(
                              top: h * 0.70,
                              left: 0,
                              width: w,
                              height: h * 0.32,
                              child: CachedItemImage(
                                url: slots['shoes']!.imageUrl,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'STYLIST NOTE',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.textMuted,
                          letterSpacing: 1.1,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.outfit.styleNote,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 23,
                        ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(
                        Icons.swipe_left_alt_outlined,
                        color: AppColors.textMuted,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Skip',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Spacer(),
                      Text(
                        'Keep',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.favorite_border_outlined,
                        color: AppColors.blush,
                        size: 18,
                      ),
                    ],
                  ),
                ],
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
}

class _LikedCard extends StatelessWidget {
  final OutfitSuggestion outfit;

  const _LikedCard({required this.outfit});

  @override
  Widget build(BuildContext context) {
    final slots = outfit.slots;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final h = constraints.maxHeight;
                  final w = constraints.maxWidth;
                  return Stack(
                    children: [
                      // Bottom layer.
                      Positioned(
                        top: h * 0.30,
                        left: 0,
                        width: w,
                        height: h * 0.65,
                        child: CachedItemImage(
                          url: slots['bottom']!.imageUrl,
                          fit: BoxFit.contain,
                        ),
                      ),
                      // Middle layer.
                      Positioned(
                        top: h * 0.00,
                        left: 0,
                        width: w,
                        height: h * 0.70,
                        child: CachedItemImage(
                          url: slots['top']!.imageUrl,
                          fit: BoxFit.contain,
                        ),
                      ),
                      // Front layer.
                      Positioned(
                        top: h * 0.65,
                        left: 0,
                        width: w,
                        height: h * 0.32,
                        child: CachedItemImage(
                          url: slots['shoes']!.imageUrl,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            Text(
              outfit.styleNote,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 22,
                  ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TryOnScreen(
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
              label: const Text('Open in Studio'),
            ),
          ],
        ),
      ),
    );
  }
}

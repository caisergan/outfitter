import 'package:flutter/material.dart';
import '../../../core/models/outfit_models.dart';
import '../../../core/widgets/shared_widgets.dart';
import '/features/playground/ui/playground_screen.dart';
import '/core/theme/app_colors.dart';

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
        title: Text("Outfits ${index + 1}/${widget.outfits.length}"),
      ),
      body: Stack(
        children: List.generate(
          widget.outfits.length - index,
              (i) {
            final outfit = widget.outfits[index + i];

            return SwipeCard(
              outfit: outfit,
              isTop: i == 0,
              onSwiped: (direction) {
                if (direction == "right") {
                  liked.add(outfit);
                }
                setState(() => index++);
              },
            );
          },
        ).reversed.toList(),
      ),
    );
  }

  // ───────────────────────── RESULT SCREEN
  Widget _buildResultScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Your Likes"),
      ),
      body: liked.isEmpty
          ? const Center(child: Text("No liked outfits"))
          : PageView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: liked.length,
        controller: PageController(viewportFraction: 0.9),
        itemBuilder: (context, i) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: _LikedCard(outfit: liked[i]),
          );
        },
      ),
    );
  }
}

// ───────────────────────────────────────── CARD STACK ITEM
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
        padding: const EdgeInsets.all(16),
        child: GestureDetector(
          onPanUpdate: widget.isTop
              ? (d) => setState(() => position += d.delta)
              : null,
          onPanEnd: (_) => _handleSwipe(),
          child: Transform.translate(
            offset: position,
            child: Material(
              elevation: 10,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    // ───── TOP
                    Expanded(flex: 3, child: _item(slots['top'])),

                    const SizedBox(height: 8),

                    // ───── BOTTOM
                    Expanded(flex: 3, child: _item(slots['bottom'])),

                    const SizedBox(height: 10),

                    // ───── SHOES + ACCESSORIES
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: [
                          Expanded(child: _item(slots['shoes'], scale: 0.9)),
                          const SizedBox(width: 8),
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
                                  child: _item(e.value, scale: 0.8),
                                ),
                              )
                                  .toList(),
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
        ),
      ),
    );
  }

  void _handleSwipe() {
    final dx = position.dx;

    if (dx > 120) {
      widget.onSwiped("right");
    } else if (dx < -120) {
      widget.onSwiped("left");
    }

    setState(() => position = Offset.zero);
  }

  Widget _item(SlotItem? item, {double scale = 1}) {
    if (item == null) return const SizedBox();

    return Transform.scale(
      scale: scale,
      child: Container(
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.grey.shade100,
        ),
        clipBehavior: Clip.antiAlias,
        child: CachedItemImage(
          url: item.imageUrl,
          fit: BoxFit.cover,
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
        .where((e) =>
    e.key != 'top' &&
        e.key != 'bottom' &&
        e.key != 'shoes')
        .map((e) => e.value)
        .toList();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            color: Colors.black.withValues(alpha: 0.08),
          )
        ],
      ),
      child: Column(
        children: [
          Expanded(child: CachedItemImage(url: slots['top']!.imageUrl)),
          Expanded(child: CachedItemImage(url: slots['bottom']!.imageUrl)),

          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: CachedItemImage(url: slots['shoes']!.imageUrl),
                ),
                if (accessories.isNotEmpty)
                  Expanded(
                    child: CachedItemImage(
                      url: accessories.first.imageUrl,
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ───────── EDIT (still primary, but compact pill)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.text,
                    foregroundColor: AppColors.cream,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: const Size(0, 36),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
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
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text("Edit"),
                ),

                const SizedBox(width: 10),

                // ───────── LIKE (icon-fit pill)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.blush,
                    side: const BorderSide(color: AppColors.blush),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: const Size(0, 36),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Liked"),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Icon(Icons.favorite, size: 18),
                ),

                const SizedBox(width: 10),

                // ───────── SAVE (icon-fit pill)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.mint,
                    side: const BorderSide(color: AppColors.mint),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: const Size(0, 36),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Saved"),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Icon(Icons.bookmark_border, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  void _saveOutfit(BuildContext context, OutfitSuggestion outfit) {
    // TODO: wire into backend / riverpod / local storage
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Outfit saved"),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
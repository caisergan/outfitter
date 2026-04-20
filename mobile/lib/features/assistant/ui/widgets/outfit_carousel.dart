import 'package:flutter/material.dart';

import 'package:fashion_app/core/models/outfit_models.dart';
import 'outfit_suggestion_card.dart';

class OutfitCarousel extends StatefulWidget {
  final List<OutfitSuggestion> outfits;
  final VoidCallback onRefresh;

  const OutfitCarousel(
      {required this.outfits, required this.onRefresh, super.key});

  @override
  State<OutfitCarousel> createState() => _OutfitCarouselState();
}

class _OutfitCarouselState extends State<OutfitCarousel> {
  final _pageController = PageController(viewportFraction: 0.9);
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.outfits.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No outfits found for these parameters.'),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: widget.onRefresh, child: const Text('Try Again')),
          ],
        ),
      );
    }

    return Column(
      children: [
        const SizedBox(height: 24),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemCount: widget.outfits.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: OutfitSuggestionCard(outfit: widget.outfits[index]),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.outfits.length,
            (index) => Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentPage == index
                    ? Theme.of(context).primaryColor
                    : Colors.grey.shade300,
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Generate New Batch'),
            onPressed: widget.onRefresh,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: Colors.grey.shade300),
            ),
          ),
        ),
        const SizedBox(height: 48),
      ],
    );
  }
}

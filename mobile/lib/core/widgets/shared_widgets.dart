import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Consistent cached image with a loading placeholder and broken-image fallback.
class CachedItemImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const CachedItemImage({
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    Widget image = CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      placeholder: (_, __) => Container(
        color: const Color(0xFFF8F4EC),
        width: width,
        height: height,
      ),
      errorWidget: (_, __, ___) => Container(
        color: const Color(0xFFF8F4EC),
        width: width,
        height: height,
        child: const Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: Color(0xFF7A736A),
            size: 24,
          ),
        ),
      ),
    );

    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }

    return image;
  }
}

/// Horizontal swipe-able row of selectable filter chips.
class FilterChipRow extends StatelessWidget {
  final List<String> options;
  final Set<String> selected;
  final void Function(String, bool) onChanged;

  const FilterChipRow({
    required this.options,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: options.map((opt) {
          final isSelected = selected.contains(opt);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(opt),
              selected: isSelected,
              onSelected: (val) => onChanged(opt, val),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }
}

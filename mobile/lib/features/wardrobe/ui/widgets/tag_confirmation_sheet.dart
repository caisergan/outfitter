import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fashion_app/core/models/wardrobe_item.dart';
import 'package:fashion_app/core/utils/error_helpers.dart';
import 'package:fashion_app/core/widgets/shared_widgets.dart';
import 'package:fashion_app/features/wardrobe/providers/wardrobe_provider.dart';

import '/core/theme/app_colors.dart';

class TagConfirmationSheet extends ConsumerStatefulWidget {
  final WardrobeTagResult initialTags;
  final String imageUrl;

  const TagConfirmationSheet({
    required this.initialTags,
    required this.imageUrl,
    super.key,
  });

  @override
  ConsumerState<TagConfirmationSheet> createState() =>
      _TagConfirmationSheetState();
}

class _TagConfirmationSheetState extends ConsumerState<TagConfirmationSheet> {
  late String _category;
  late List<String> _color;
  String? _subtype;
  late List<String> _styleTags;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _category = widget.initialTags.category;
    _color = List.from(widget.initialTags.color);
    _subtype = widget.initialTags.subtype;
    _styleTags = List.from(widget.initialTags.styleTags);
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    try {
      final request = CreateWardrobeItemRequest(
        imageUrl: widget.imageUrl,
        category: _category,
        subtype: _subtype,
        color: _color,
        styleTags: _styleTags,
      );
      await ref.read(wardrobeNotifierProvider.notifier).addItem(request);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showErrorSnackbar(context, dioErrorToMessage(e));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Stack(
          children: [
            ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 124),
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Confirm Details',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Review the detected wardrobe tags before saving.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.secondaryText,
                      ),
                ),
                const SizedBox(height: 20),
                Container(
                  height: 220,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.paper,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: CachedItemImage(
                    url: widget.imageUrl,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    children: [
                      _buildSection(
                        'Category',
                        _category[0].toUpperCase() + _category.substring(1),
                      ),
                      _buildSection('Type', _subtype ?? '-'),
                      _buildSection('Colors', _color.join(', ')),
                      _buildSection('Tags', _styleTags.join(', ')),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 28,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _handleSave,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: AppColors.background,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Add to Wardrobe'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSection(String title, String value) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (title != 'Tags') const Divider(height: 1),
      ],
    );
  }
}

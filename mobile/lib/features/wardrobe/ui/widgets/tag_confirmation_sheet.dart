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
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 120),
              children: [
                const SheetHandle(),
                const SizedBox(height: 18),
                Text(
                  'Confirm Details',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Review the detected information before saving the item into your wardrobe.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textMuted,
                      ),
                ),
                const SizedBox(height: 20),
                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppColors.line),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: CachedItemImage(
                    url: widget.imageUrl,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.backgroundElevated,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    children: [
                      _InfoRow(
                        title: 'Category',
                        value: _category,
                      ),
                      _InfoRow(
                        title: 'Type',
                        value: _subtype ?? 'Not set',
                      ),
                      _InfoRow(
                        title: 'Colors',
                        value: _color.isEmpty ? 'Not set' : _color.join(', '),
                      ),
                      _InfoRow(
                        title: 'Tags',
                        value: _styleTags.isEmpty ? 'Not set' : _styleTags.join(', '),
                        isLast: true,
                      ),
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
                          color: AppColors.surface,
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
}

class _InfoRow extends StatelessWidget {
  final String title;
  final String value;
  final bool isLast;

  const _InfoRow({
    required this.title,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: AppColors.line),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textMuted,
                    letterSpacing: 1.6,
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

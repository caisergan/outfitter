import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fashion_app/core/models/wardrobe_item.dart';
import 'package:fashion_app/core/theme/app_colors.dart';
import 'package:fashion_app/core/utils/error_helpers.dart';
import 'package:fashion_app/core/widgets/shared_widgets.dart';
import 'package:fashion_app/features/wardrobe/providers/wardrobe_provider.dart';

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
        return Column(
          children: [
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                children: [
                  Text(
                    'Confirm the piece',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Review the detected details before adding this image to your wardrobe.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textMuted,
                        ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    height: 220,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: CachedItemImage(
                      url: widget.imageUrl,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        _InfoRow(
                          label: 'Category',
                          value: _titleCase(_category),
                        ),
                        _InfoRow(
                          label: 'Type',
                          value: _subtype == null || _subtype!.isEmpty
                              ? 'Not detected'
                              : _titleCase(_subtype!),
                        ),
                        _InfoRow(
                          label: 'Colors',
                          value: _color.isEmpty
                              ? 'Not detected'
                              : _color.map(_titleCase).join(', '),
                        ),
                        _InfoRow(
                          label: 'Style tags',
                          value: _styleTags.isEmpty
                              ? 'Not detected'
                              : _styleTags.map(_titleCase).join(', '),
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _handleSave,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Add to Wardrobe'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _titleCase(String value) {
    return value
        .split(' ')
        .map((word) => word.isEmpty
            ? word
            : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;

  const _InfoRow({
    required this.label,
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
                bottom: BorderSide(color: AppColors.border),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.textMuted,
                    letterSpacing: 0.9,
                  ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}

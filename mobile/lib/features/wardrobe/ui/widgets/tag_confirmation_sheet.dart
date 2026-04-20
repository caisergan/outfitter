import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fashion_app/core/models/wardrobe_item.dart';
import 'package:fashion_app/core/widgets/shared_widgets.dart';
import 'package:fashion_app/core/utils/error_helpers.dart';
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
        return Stack(
          children: [
            Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(24),
                    children: [
                      const Text('Confirm Details',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 24),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child:
                            CachedItemImage(url: widget.imageUrl, height: 200),
                      ),
                      const SizedBox(height: 32),
                      _buildSection('Category', _category),
                      _buildSection('Colors', _color.join(", ")),
                      _buildSection('Style Tags', _styleTags.join(", ")),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _handleSave,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Add to Wardrobe'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSection(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Divider(color: Colors.grey.shade200),
        ],
      ),
    );
  }
}

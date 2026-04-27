import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fashion_app/core/models/wardrobe_item.dart';
import 'package:fashion_app/core/widgets/shared_widgets.dart';
import 'package:fashion_app/core/utils/error_helpers.dart';
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
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  // ── Drag handle ──────────────────────────────────────
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.lightMint.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 120),
                      children: [
                        const Text(
                          'Confirm Details',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Image preview ──────────────────────────────
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            height: 200,
                            color: Colors.white,
                            padding: const EdgeInsets.all(12),
                            child: CachedItemImage(
                              url: widget.imageUrl,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // ── Details card ───────────────────────────────
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.lightMint.withOpacity(0.6),
                            ),
                          ),
                          child: Column(
                            children: [
                              _buildSection('Category',
                                  _category[0].toUpperCase() +
                                      _category.substring(1),
                                  showDivider: true),
                              _buildSection(
                                  'Type', _subtype ?? '—',
                                  showDivider: true),
                              _buildSection('Colors', _color.join(', '),
                                  showDivider: true),
                              _buildSection(
                                  'Tags', _styleTags.join(', '),showDivider: true),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // ── Save button (pinned) ───────────────────────────────────
              Positioned(
                bottom: 28,
                left: 24,
                right: 24,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blush,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
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
                      : const Text(
                    'Add to Wardrobe',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSection(String title, String value,
      {bool showDivider = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppColors.text.withOpacity(0.4),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
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
        if (showDivider)
          Divider(
            height: 1,
            color: AppColors.lightMint.withOpacity(0.5),
          ),
      ],
    );
  }
}
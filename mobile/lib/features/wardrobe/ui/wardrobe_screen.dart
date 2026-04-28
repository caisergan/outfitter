import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:fashion_app/core/utils/error_helpers.dart';
import 'package:fashion_app/core/widgets/error_view.dart';
import 'package:fashion_app/features/wardrobe/data/wardrobe_repository.dart';
import 'package:fashion_app/features/wardrobe/providers/wardrobe_provider.dart';

import '/core/theme/app_colors.dart';
import 'widgets/tag_confirmation_sheet.dart';
import 'widgets/wardrobe_item_card.dart';

class WardrobeScreen extends ConsumerStatefulWidget {
  const WardrobeScreen({super.key});

  @override
  ConsumerState<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends ConsumerState<WardrobeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _categories = [
    'All',
    'top',
    'bottom',
    'shoes',
    'outerwear',
    'accessory',
    'bag',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) _refresh();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refresh() {
    final cat =
        _tabController.index == 0 ? null : _categories[_tabController.index];
    ref.read(wardrobeNotifierProvider.notifier).fetch(category: cat);
  }

  Future<ImageSource?> _selectImageSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            const SizedBox(height: 12),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                'Add Item',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: const Icon(
                  Icons.camera_alt_outlined,
                  color: AppColors.primary,
                ),
              ),
              title: const Text('Take a photo'),
              subtitle: const Text('Capture a new wardrobe item.'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: const Icon(
                  Icons.photo_library_outlined,
                  color: AppColors.primary,
                ),
              ),
              title: const Text('Choose from gallery'),
              subtitle: const Text('Import an item you already photographed.'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _addItem() async {
    final source = await _selectImageSource();
    if (source == null) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (image == null) return;
    if (!mounted) return;

    try {
      final repo = ref.read(wardrobeRepositoryProvider);
      final tags = await repo.tagPhoto(image.path);
      if (!mounted) return;

      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => TagConfirmationSheet(
          initialTags: tags,
          imageUrl: tags.imageUrl,
        ),
      );

      if (saved == true || saved == false) _refresh();
    } catch (e) {
      if (mounted) {
        showErrorSnackbar(context, dioErrorToMessage(e));
        _refresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final wardrobeState = ref.watch(wardrobeNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        foregroundColor: AppColors.text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('My Wardrobe'),
            Text(
              'A quieter archive of what you own',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              indicatorSize: TabBarIndicatorSize.label,
              tabs: _categories
                  .map((c) => Tab(text: c[0].toUpperCase() + c.substring(1)))
                  .toList(),
            ),
          ),
        ),
      ),
      body: wardrobeState.when(
        data: (items) => items.isEmpty
            ? _buildEmptyState(context)
            : GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 18,
                  childAspectRatio: 0.68,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) =>
                    WardrobeItemCard(item: items[index]),
              ),
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (e, __) => ErrorView(
          message: dioErrorToMessage(e),
          onRetry: _refresh,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addItem,
        child: const Icon(Icons.add_a_photo_outlined),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.divider),
                ),
                child: const Icon(
                  Icons.door_sliding_outlined,
                  size: 34,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Your wardrobe is empty.',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Add your first item to start building outfits.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.secondaryText,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

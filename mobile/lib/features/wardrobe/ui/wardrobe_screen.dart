import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:fashion_app/core/utils/error_helpers.dart';
import 'package:fashion_app/core/widgets/error_view.dart';
import 'package:fashion_app/core/widgets/shared_widgets.dart';
import 'package:fashion_app/features/wardrobe/data/wardrobe_repository.dart';
import 'package:fashion_app/features/wardrobe/providers/wardrobe_provider.dart';
import 'widgets/tag_confirmation_sheet.dart';
import 'widgets/wardrobe_item_card.dart';
import '/core/theme/app_colors.dart';

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
    final cat = _tabController.index == 0 ? null : _categories[_tabController.index];
    ref.read(wardrobeNotifierProvider.notifier).fetch(category: cat);
  }

  Future<ImageSource?> _selectImageSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(),
              const SizedBox(height: 18),
              Text(
                'Add Item',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'Capture a piece or import one from your gallery.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
              ),
              const SizedBox(height: 18),
              _SourceTile(
                icon: Icons.camera_alt_outlined,
                title: 'Take a photo',
                subtitle: 'Capture a new item from your camera.',
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              const SizedBox(height: 10),
              _SourceTile(
                icon: Icons.photo_library_outlined,
                title: 'Choose from gallery',
                subtitle: 'Import an existing image for tagging.',
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
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
    if (image == null || !mounted) return;

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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PRIVATE ARCHIVE',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.textMuted,
                letterSpacing: 2,
              ),
            ),
            Text('Wardrobe', style: theme.textTheme.titleLarge),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorPadding: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              tabs: _categories
                  .map((c) => Tab(text: _categoryLabel(c)))
                  .toList(),
            ),
          ),
        ),
      ),
      body: wardrobeState.when(
        data: (items) => items.isEmpty
            ? _EmptyWardrobeState(onAddItem: _addItem)
            : GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.69,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) =>
                    WardrobeItemCard(item: items[index]),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => ErrorView(
          message: dioErrorToMessage(e),
          onRetry: _refresh,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addItem,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Add item'),
      ),
    );
  }

  String _categoryLabel(String category) {
    if (category == 'All') return category;
    return category[0].toUpperCase() + category.substring(1);
  }
}

class _SourceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.backgroundElevated,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.lightMint,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: AppColors.text),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _EmptyWardrobeState extends StatelessWidget {
  final VoidCallback onAddItem;

  const _EmptyWardrobeState({required this.onAddItem});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.lightMint,
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.checkroom_outlined,
                size: 34,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Your wardrobe is still empty.',
              style: theme.textTheme.headlineSmall?.copyWith(fontSize: 24),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Start by adding a piece. The app will tag it and place it into your archive.',
              style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            OutlinedButton(
              onPressed: onAddItem,
              child: const Text('Add your first item'),
            ),
          ],
        ),
      ),
    );
  }
}

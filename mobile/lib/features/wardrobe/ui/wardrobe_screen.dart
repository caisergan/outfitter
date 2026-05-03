import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:fashion_app/core/utils/error_helpers.dart';
import 'package:fashion_app/core/widgets/error_view.dart';
import 'package:fashion_app/core/widgets/glass_widgets.dart';
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

  final _slots = [
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
    _tabController = TabController(length: _slots.length, vsync: this);
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
    final slot =
        _tabController.index == 0 ? null : _slots[_tabController.index];
    ref.read(wardrobeNotifierProvider.notifier).fetch(slot: slot);
  }

  Future<ImageSource?> _selectImageSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      useSafeArea: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add a new piece',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Start with a photo so the wardrobe stays image-led and easy to scan.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
              ),
              const SizedBox(height: 18),
              _SourceTile(
                icon: Icons.camera_alt_outlined,
                title: 'Take a photo',
                subtitle: 'Capture an item directly from the camera.',
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              const SizedBox(height: 10),
              _SourceTile(
                icon: Icons.photo_library_outlined,
                title: 'Choose from gallery',
                subtitle: 'Use an existing product or wardrobe image.',
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

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        toolbarHeight: 82,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Wardrobe',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              'Your personal archive of pieces, ready for styling.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
            ),
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
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              labelPadding: const EdgeInsets.symmetric(horizontal: 6),
              dividerColor: Colors.transparent,
              indicatorPadding: const EdgeInsets.symmetric(vertical: 6),
              tabs: _slots
                  .map(
                    (slot) => Tab(
                      height: 36,
                      text: slot[0].toUpperCase() + slot.substring(1),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
      body: wardrobeState.when(
        data: (items) => items.isEmpty
            ? _buildEmptyState(context)
            : GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 18,
                  childAspectRatio: 0.68,
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
        label: const Text('Add Piece'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const GlassIconOrb(
              icon: Icons.checkroom_outlined,
              size: 88,
            ),
            const SizedBox(height: 20),
            Text(
              'Your wardrobe is still empty.',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first item to start building a calmer, more useful styling archive.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: 180,
              child: OutlinedButton(
                onPressed: _addItem,
                child: const Text('Add First Piece'),
              ),
            ),
          ],
        ),
      ),
    );
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
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: FrostedGlass(
          borderRadius: BorderRadius.circular(22),
          padding: const EdgeInsets.all(16),
          backgroundColor: AppColors.glass.withValues(alpha: 0.84),
          child: Row(
            children: [
              GlassIconOrb(icon: icon, size: 46),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

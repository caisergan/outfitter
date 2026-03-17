import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:fashion_app/features/wardrobe/providers/wardrobe_provider.dart';
import 'package:fashion_app/features/wardrobe/data/wardrobe_repository.dart';
import 'package:fashion_app/core/widgets/error_view.dart';
import 'package:fashion_app/core/utils/error_helpers.dart';
import 'widgets/wardrobe_item_card.dart';
import 'widgets/tag_confirmation_sheet.dart';

class WardrobeScreen extends ConsumerStatefulWidget {
  const WardrobeScreen({super.key});

  @override
  ConsumerState<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends ConsumerState<WardrobeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _categories = ['All', 'top', 'bottom', 'shoes', 'outerwear', 'accessory', 'bag'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _refresh();
      }
    });
  }

  void _refresh() {
    final cat = _tabController.index == 0 ? null : _categories[_tabController.index];
    ref.read(wardrobeNotifierProvider.notifier).fetch(category: cat);
  }

  Future<void> _addItem() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (image == null) return;
    if (!mounted) return;

    try {
      final repo = ref.read(wardrobeRepositoryProvider);
      // 1. Upload & get AI tags (fetch() will set loading state)
      final tags = await repo.tagPhoto(image.path);
      if (!mounted) return;

      // 2. Show confirmation sheet
      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => TagConfirmationSheet(
          initialTags: tags,
          imageUrl: tags.imageUrl,
        ),
      );

      if (saved == true || saved == false) {
        _refresh();
      }
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
      appBar: AppBar(
        title: const Text('My Wardrobe'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: _categories.map((c) => Tab(text: c[0].toUpperCase() + c.substring(1))).toList(),
        ),
      ),
      body: wardrobeState.when(
        data: (items) => items.isEmpty
            ? _buildEmptyState()
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.75,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) => WardrobeItemCard(item: items[index]),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.door_sliding_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('Your wardrobe is empty.'),
          const SizedBox(height: 8),
          Text(
            'Add your first item to start building outfits!',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

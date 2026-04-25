import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../models/styling_canvas_models.dart';
import '../providers/styling_canvas_provider.dart';
import 'widgets/item_browser_sheet.dart';
import 'widgets/wardrobe_browser_sheet.dart';

class PlaygroundScreen extends ConsumerStatefulWidget {
  final Map<String, String>? prefilledSlots;
  const PlaygroundScreen({this.prefilledSlots, super.key});

  @override
  ConsumerState<PlaygroundScreen> createState() => _PlaygroundScreenState();
}

class _PlaygroundScreenState extends ConsumerState<PlaygroundScreen> {
  Future<void> _openGarmentSourcePicker() async {
    final source = await showModalBottomSheet<_GarmentSource>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _GarmentSourceSheet(),
    );

    if (!mounted || source == null) return;

    switch (source) {
      case _GarmentSource.onlinePlatform:
        _openOnlinePlatformBrowser();
        break;
      case _GarmentSource.myWardrobe:
        _openWardrobeBrowser();
        break;
    }
  }

  @override
  void initState() {
    super.initState();

    if (widget.prefilledSlots != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final notifier = ref.read(stylingCanvasProvider.notifier);

        widget.prefilledSlots!.forEach((slot, url) {
          notifier.addGarmentFromUrl(
            slot: slot,
            imageUrl: url,
          );
        });
      });
    }
  }



  void _openOnlinePlatformBrowser() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ItemBrowserSheet(
        updateSlotOnSelect: false,
        onItemSelected: (item) {
          ref.read(stylingCanvasProvider.notifier).addGarment(item);
        },
      ),
    );
  }

  void _openWardrobeBrowser() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WardrobeBrowserSheet(
        onItemSelected: (item) {
          ref.read(stylingCanvasProvider.notifier).addWardrobeGarment(item);
        },
      ),
    );
  }

  void _openLayers() {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _LayerOrderSheet(),
    );
  }

  void _openSavedOutfits() {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SavedOutfitsSheet(),
    );
  }

  Future<void> _saveCanvas() async {
    final notifier = ref.read(stylingCanvasProvider.notifier);
    final SavedStylingCanvasOutfit? saved;
    try {
      saved = await notifier.saveCurrent();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save outfit.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!mounted) return;

    final message = saved == null ? 'Add a garment first.' : 'Outfit saved.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canvas = ref.watch(stylingCanvasProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        titleSpacing: 20,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Playground'),
            Text(
              canvas.activeOutfitId == null ? 'Styling Canvas' : canvas.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          Tooltip(
            message: 'New canvas',
            child: IconButton(
              icon: const Icon(Icons.note_add_outlined),
              onPressed: canvas.garments.isEmpty
                  ? null
                  : () => ref.read(stylingCanvasProvider.notifier).newCanvas(),
            ),
          ),
          Tooltip(
            message: 'Saved outfits',
            child: IconButton(
              icon: const Icon(Icons.folder_open_outlined),
              onPressed: _openSavedOutfits,
            ),
          ),
          Tooltip(
            message: 'Save outfit',
            child: IconButton(
              icon: canvas.isSaving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              onPressed: canvas.canSave ? _saveCanvas : null,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.text,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Add garment'),
                      onPressed: _openGarmentSourcePicker,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _ToolbarIconButton(
                    icon: Icons.layers_outlined,
                    tooltip: 'Layers',
                    onPressed: canvas.garments.isEmpty ? null : _openLayers,
                  ),
                ],
              ),
            ),
            const Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: _StylingCanvasSurface(),
              ),
            ),
            _SelectionInspector(onOpenLayers: _openLayers),
          ],
        ),
      ),
    );
  }
}

class _StylingCanvasSurface extends ConsumerWidget {
  const _StylingCanvasSurface();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canvas = ref.watch(stylingCanvasProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
        final baseSize = (constraints.maxWidth * 0.34).clamp(96.0, 150.0);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () =>
              ref.read(stylingCanvasProvider.notifier).selectGarment(null),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFEFA),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.lightMint),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(painter: _CanvasGridPainter()),
                  if (canvas.garments.isEmpty)
                    const Center(
                      child: _EmptyCanvasPrompt(),
                    ),
                  for (final garment in canvas.garments)
                    _CanvasGarmentWidget(
                      key: ValueKey(garment.id),
                      garment: garment,
                      canvasSize: canvasSize,
                      baseSize: baseSize,
                      isSelected: garment.id == canvas.selectedGarmentId,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CanvasGarmentWidget extends ConsumerStatefulWidget {
  final CanvasGarment garment;
  final Size canvasSize;
  final double baseSize;
  final bool isSelected;

  const _CanvasGarmentWidget({
    required this.garment,
    required this.canvasSize,
    required this.baseSize,
    required this.isSelected,
    super.key,
  });

  @override
  ConsumerState<_CanvasGarmentWidget> createState() =>
      _CanvasGarmentWidgetState();
}

class _CanvasGarmentWidgetState extends ConsumerState<_CanvasGarmentWidget> {
  double _startScale = 1;
  double _startRotation = 0;

  @override
  Widget build(BuildContext context) {
    final garment = widget.garment;
    final left = garment.x * widget.canvasSize.width - widget.baseSize / 2;
    final top = garment.y * widget.canvasSize.height - widget.baseSize / 2;

    return Positioned(
      left: left,
      top: top,
      width: widget.baseSize,
      height: widget.baseSize,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          ref.read(stylingCanvasProvider.notifier).selectGarment(garment.id);
        },
        onScaleStart: (_) {
          final current = ref
              .read(stylingCanvasProvider)
              .garments
              .firstWhere((item) => item.id == garment.id);
          _startScale = current.scale;
          _startRotation = current.rotation;
          ref.read(stylingCanvasProvider.notifier).selectGarment(garment.id);
        },
        onScaleUpdate: (details) {
          final current = ref
              .read(stylingCanvasProvider)
              .garments
              .firstWhere((item) => item.id == garment.id);
          ref.read(stylingCanvasProvider.notifier).updateGarmentTransform(
                garment.id,
                x: current.x +
                    details.focalPointDelta.dx / widget.canvasSize.width,
                y: current.y +
                    details.focalPointDelta.dy / widget.canvasSize.height,
                scale: _startScale * details.scale,
                rotation: _startRotation + details.rotation,
              );
        },
        child: Transform.rotate(
          angle: garment.rotation,
          child: Transform.scale(
            scale: garment.scale,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: widget.isSelected
                    ? Border.all(color: AppColors.blush, width: 2)
                    : Border.all(color: Colors.white.withValues(alpha: 0)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.text.withValues(alpha: 0.10),
                    blurRadius: widget.isSelected ? 18 : 10,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: CachedItemImage(
                url: garment.item.imageUrl,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionInspector extends ConsumerWidget {
  final VoidCallback onOpenLayers;

  const _SelectionInspector({required this.onOpenLayers});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canvas = ref.watch(stylingCanvasProvider);
    final selected = canvas.selectedGarment;
    final notifier = ref.read(stylingCanvasProvider.notifier);

    return SafeArea(
      top: false,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.lightMint,
          borderRadius: BorderRadius.circular(8),
        ),
        child: selected == null
            ? Row(
                children: [
                  const Icon(Icons.touch_app_outlined, color: AppColors.text),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${canvas.garments.length} garments on canvas',
                      style: const TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _ToolbarIconButton(
                    icon: Icons.layers_outlined,
                    tooltip: 'Layers',
                    onPressed: canvas.garments.isEmpty ? null : onOpenLayers,
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: CachedItemImage(
                          url: selected.item.imageUrl,
                          width: 44,
                          height: 44,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          selected.item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _InspectorIconButton(
                          icon: Icons.remove,
                          tooltip: 'Smaller',
                          onPressed: () => notifier.scaleSelected(-0.08),
                        ),
                        _InspectorIconButton(
                          icon: Icons.add,
                          tooltip: 'Larger',
                          onPressed: () => notifier.scaleSelected(0.08),
                        ),
                        _InspectorIconButton(
                          icon: Icons.rotate_left,
                          tooltip: 'Rotate left',
                          onPressed: () =>
                              notifier.rotateSelected(-math.pi / 24),
                        ),
                        _InspectorIconButton(
                          icon: Icons.rotate_right,
                          tooltip: 'Rotate right',
                          onPressed: () =>
                              notifier.rotateSelected(math.pi / 24),
                        ),
                        _InspectorIconButton(
                          icon: Icons.layers_outlined,
                          tooltip: 'Layers',
                          onPressed: onOpenLayers,
                        ),
                        _InspectorIconButton(
                          icon: Icons.flip_to_back,
                          tooltip: 'Send backward',
                          onPressed: notifier.sendSelectedBackward,
                        ),
                        _InspectorIconButton(
                          icon: Icons.flip_to_front,
                          tooltip: 'Bring forward',
                          onPressed: notifier.bringSelectedForward,
                        ),
                        _InspectorIconButton(
                          icon: Icons.copy,
                          tooltip: 'Duplicate',
                          onPressed: notifier.duplicateSelected,
                        ),
                        _InspectorIconButton(
                          icon: Icons.delete_outline,
                          tooltip: 'Delete',
                          onPressed: notifier.deleteSelected,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

enum _GarmentSource { onlinePlatform, myWardrobe }

class _GarmentSourceSheet extends StatelessWidget {
  const _GarmentSourceSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Add garment from',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          _GarmentSourceTile(
            icon: Icons.public,
            title: 'Online Platform',
            onTap: () => Navigator.pop(context, _GarmentSource.onlinePlatform),
          ),
          const SizedBox(height: 10),
          _GarmentSourceTile(
            icon: Icons.door_sliding,
            title: 'My Wardrobe',
            onTap: () => Navigator.pop(context, _GarmentSource.myWardrobe),
          ),
        ],
      ),
    );
  }
}

class _GarmentSourceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _GarmentSourceTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.lightMint.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.lightMint),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppColors.text),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.text),
          ],
        ),
      ),
    );
  }
}

class _LayerOrderSheet extends ConsumerWidget {
  const _LayerOrderSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canvas = ref.watch(stylingCanvasProvider);

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.62,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),
          const Row(
            children: [
              Icon(Icons.layers_outlined, color: AppColors.text),
              SizedBox(width: 10),
              Text(
                'Layers',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ReorderableListView.builder(
              itemCount: canvas.garments.length,
              onReorder: (oldIndex, newIndex) {
                ref
                    .read(stylingCanvasProvider.notifier)
                    .reorderGarments(oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final garment = canvas.garments[index];
                final layerLabel = index == canvas.garments.length - 1
                    ? 'Front layer'
                    : index == 0
                        ? 'Back layer'
                        : 'Layer ${index + 1}';

                return ListTile(
                  key: ValueKey(garment.id),
                  contentPadding: EdgeInsets.zero,
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CachedItemImage(
                      url: garment.item.imageUrl,
                      width: 46,
                      height: 46,
                      fit: BoxFit.contain,
                    ),
                  ),
                  title: Text(
                    garment.item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: Text(layerLabel),
                  trailing: const Icon(Icons.drag_handle),
                  onTap: () {
                    ref
                        .read(stylingCanvasProvider.notifier)
                        .selectGarment(garment.id);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedOutfitsSheet extends ConsumerWidget {
  const _SavedOutfitsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canvas = ref.watch(stylingCanvasProvider);
    final notifier = ref.read(stylingCanvasProvider.notifier);

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.62,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),
          const Row(
            children: [
              Icon(Icons.folder_open_outlined, color: AppColors.text),
              SizedBox(width: 10),
              Text(
                'Saved outfits',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: canvas.isLoadingSaved
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.blush),
                  )
                : canvas.savedOutfits.isEmpty
                    ? const Center(
                        child: Text(
                          'No saved canvas outfits yet.',
                          style: TextStyle(
                            color: AppColors.text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: canvas.savedOutfits.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final outfit = canvas.savedOutfits[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: _OutfitPreview(outfit: outfit),
                            title: Text(
                              outfit.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.text,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle:
                                Text('${outfit.garments.length} garments'),
                            trailing: IconButton(
                              tooltip: 'Delete saved outfit',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => notifier.deleteOutfit(outfit.id),
                            ),
                            onTap: () {
                              notifier.openOutfit(outfit);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _OutfitPreview extends StatelessWidget {
  final SavedStylingCanvasOutfit outfit;

  const _OutfitPreview({required this.outfit});

  @override
  Widget build(BuildContext context) {
    final garments = outfit.garments.take(3).toList();

    return SizedBox(
      width: 54,
      height: 54,
      child: Stack(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.lightMint.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const SizedBox.expand(),
          ),
          for (final entry in garments.asMap().entries)
            Positioned(
              left: 6.0 + entry.key * 10,
              top: 6.0 + entry.key * 6,
              width: 34,
              height: 34,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CachedItemImage(
                  url: entry.value.item.imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyCanvasPrompt extends StatelessWidget {
  const _EmptyCanvasPrompt();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.checkroom_outlined, color: AppColors.blush, size: 45),
        SizedBox(height: 15),
        Text(
          'Add a garment',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _ToolbarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: 48,
        child: IconButton.filledTonal(
          style: IconButton.styleFrom(
            backgroundColor: AppColors.lightMint,
            foregroundColor: AppColors.text,
            disabledBackgroundColor: AppColors.lightMint.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: Icon(icon),
          onPressed: onPressed,
        ),
      ),
    );
  }
}

class _InspectorIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _InspectorIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: 38,
        child: IconButton(
          padding: EdgeInsets.zero,
          iconSize: 20,
          color: AppColors.text,
          icon: Icon(icon),
          onPressed: onPressed,
        ),
      ),
    );
  }
}

class _CanvasGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.lightMint.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    const spacing = 32.0;

    for (var x = spacing; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = spacing; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../discover/data/catalog_repository.dart';
import '../../wardrobe/data/wardrobe_repository.dart';
import '../providers/styling_canvas_provider.dart';
import 'playground_screen.dart';

class ResolvedPlaygroundScreen extends ConsumerStatefulWidget {
  final Map<String, String> rawSlots;

  const ResolvedPlaygroundScreen({
    required this.rawSlots,
    super.key,
  });

  @override
  ConsumerState<ResolvedPlaygroundScreen> createState() =>
      _ResolvedPlaygroundScreenState();
}

class _ResolvedPlaygroundScreenState
    extends ConsumerState<ResolvedPlaygroundScreen> {
  Map<String, String>? _resolvedSlots;
  int _missingSlotCount = 0;

  @override
  void initState() {
    super.initState();
    _resolveSlots();
  }

  Future<void> _resolveSlots() async {
    final notifier = ref.read(stylingCanvasProvider.notifier);
    final catalogRepo = ref.read(catalogRepositoryProvider);
    final wardrobeRepo = ref.read(wardrobeRepositoryProvider);
    final resolved = <String, String>{};
    var missingSlotCount = 0;

    notifier.newCanvas();

    for (final entry in widget.rawSlots.entries) {
      final value = entry.value.trim();
      if (value.isEmpty) continue;

      if (_looksLikeUrl(value)) {
        resolved[entry.key] = value;
        continue;
      }

      final catalogItem = await catalogRepo.getById(value);
      if (catalogItem != null) {
        resolved[entry.key] = catalogItem.imageUrl;
        continue;
      }

      final wardrobeItem = await wardrobeRepo.getById(value);
      if (wardrobeItem != null) {
        resolved[entry.key] = wardrobeItem.imageUrl;
        continue;
      }

      missingSlotCount++;
    }

    if (!mounted) return;
    setState(() {
      _resolvedSlots = resolved;
      _missingSlotCount = missingSlotCount;
    });

    if (missingSlotCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Some saved garments could not be restored.'),
        ),
      );
    }
  }

  bool _looksLikeUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final resolvedSlots = _resolvedSlots;
    if (resolvedSlots == null) {
      return const Scaffold(
        backgroundColor: AppColors.cream,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_missingSlotCount > 0 && resolvedSlots.isEmpty) {
      return const PlaygroundScreen();
    }

    return PlaygroundScreen(prefilledSlots: resolvedSlots);
  }
}

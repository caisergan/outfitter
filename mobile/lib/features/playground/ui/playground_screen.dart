import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/playground_models.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../discover/data/catalog_repository.dart';
import '../data/playground_repository.dart';
import '../models/styling_canvas_models.dart';
import '../providers/playground_draft_provider.dart';
import '../providers/playground_library_provider.dart';
import '../providers/playground_runs_provider.dart';
import '../providers/styling_canvas_provider.dart';
import 'widgets/item_browser_sheet.dart';
import 'widgets/recent_runs_sheet.dart';
import 'widgets/style_picker_sheet.dart';
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

  Future<void> _openTryOnExperience() async {
    final canvas = ref.read(stylingCanvasProvider);
    if (canvas.garments.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StudioTryOnSheet(garments: canvas.garments),
    );
  }

  Future<void> _openRecentRuns() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RecentRunsSheet(onReproduce: _reproduceRun),
    );
  }

  /// Refills the canvas + draft from a past run's snapshot. Catalog items
  /// that have since been deleted are silently skipped with a single
  /// snackbar mentioning the count. After reproducing, the user can tap
  /// AI Try On to see the rehydrated state.
  Future<void> _reproduceRun(PlaygroundRun run) async {
    final canvasNotifier = ref.read(stylingCanvasProvider.notifier);
    final draftNotifier = ref.read(playgroundDraftProvider.notifier);
    final library = ref.read(playgroundLibraryProvider).valueOrNull;
    final catalog = ref.read(catalogRepositoryProvider);

    canvasNotifier.newCanvas();

    int missing = 0;
    for (final id in run.catalogItemIds) {
      try {
        final item = await catalog.getItem(id);
        if (item == null) {
          missing++;
        } else {
          canvasNotifier.addGarment(item);
        }
      } catch (_) {
        missing++;
      }
    }

    final persona = library?.allPersonas
        .where((p) => p.id == run.personaId)
        .firstOrNull;
    final template = library?.templates
        .where((t) => t.id == run.templateId)
        .firstOrNull;
    final gender = persona?.gender ?? 'female';
    final composed = composeUserPrompt(template: template, persona: persona);

    draftNotifier.applyRunSnapshot(
      templateId: run.templateId,
      personaId: run.personaId,
      gender: gender,
      systemPromptText: run.systemPromptText,
      userPromptText: run.userPromptText,
      composedFromDropdowns: composed,
    );

    if (!mounted) return;
    final shortId = run.id.substring(0, 8);
    final tail =
        missing > 0 ? ' · $missing item(s) no longer exist' : '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Reproduced run $shortId$tail'),
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
        toolbarHeight: 82,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Studio',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              canvas.activeOutfitId == null
                  ? 'Compose a look with wardrobe and catalog pieces.'
                  : canvas.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
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
            message: 'Recent runs',
            child: IconButton(
              icon: const Icon(Icons.history),
              onPressed: _openRecentRuns,
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
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add Piece'),
                      onPressed: _openGarmentSourcePicker,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: const Text('AI Try On'),
                      onPressed: canvas.garments.isEmpty
                          ? null
                          : _openTryOnExperience,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.blush,
                        foregroundColor: AppColors.surface,
                        disabledBackgroundColor: AppColors.surfaceMuted,
                        disabledForegroundColor: AppColors.textMuted,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
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
                padding: EdgeInsets.symmetric(horizontal: 20),
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

class _StudioTryOnSheet extends ConsumerStatefulWidget {
  final List<CanvasGarment> garments;

  const _StudioTryOnSheet({
    required this.garments,
  });

  @override
  ConsumerState<_StudioTryOnSheet> createState() => _StudioTryOnSheetState();
}

class _StudioTryOnSheetState extends ConsumerState<_StudioTryOnSheet> {
  bool _generating = false;
  GenerateResponse? _result;
  PlaygroundCapException? _capError;
  Object? _error;

  Future<void> _openStylePicker() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const StylePickerSheet(),
    );
  }

  Future<void> _generate() async {
    final draft = ref.read(playgroundDraftProvider);
    final ids = widget.garments
        .map((g) => g.item.id)
        .toList(growable: false);
    if (ids.isEmpty) return;
    setState(() {
      _generating = true;
      _error = null;
      _capError = null;
    });
    try {
      final response = await ref.read(playgroundRepositoryProvider).generate(
            GenerateRequest(
              catalogItemIds: ids,
              systemPrompt: draft.systemPromptText,
              userPrompt: draft.userPromptText,
              templateId: draft.templateId,
              personaId: draft.personaId,
            ),
          );
      if (!mounted) return;
      setState(() {
        _result = response;
        _generating = false;
      });
      ref.read(playgroundRunsProvider.notifier).refreshAfterGenerate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Generated · ${response.dailyUsed}/${response.dailyLimit} today',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on PlaygroundCapException catch (e) {
      if (!mounted) return;
      setState(() {
        _capError = e;
        _generating = false;
      });
      ref.read(playgroundRunsProvider.notifier).refreshAfterGenerate();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _generating = false;
      });
      ref.read(playgroundRunsProvider.notifier).refreshAfterGenerate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(playgroundDraftProvider);
    final libraryAsync = ref.watch(playgroundLibraryProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.94,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Studio Try On',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Render this outfit on a model. Pick a style or use the defaults.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textMuted,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton.filledTonal(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surfaceAlt,
                      foregroundColor: AppColors.text,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              libraryAsync.when(
                loading: () => const SizedBox(
                  height: 36,
                  child: Center(child: LinearProgressIndicator()),
                ),
                error: (_, __) => const SizedBox.shrink(),
                data: (lib) => _StylePillRow(
                  draft: draft,
                  library: lib,
                  onTap: _openStylePicker,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _TryOnPreview(
                  generating: _generating,
                  result: _result,
                  capError: _capError,
                  error: _error,
                ),
              ),
              const SizedBox(height: 14),
              _TryOnLookStrip(garments: widget.garments),
              const SizedBox(height: 14),
              FilledButton.icon(
                icon: _generating
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.surface,
                        ),
                      )
                    : const Icon(Icons.auto_awesome_rounded),
                label: Text(_generating
                    ? 'Generating…'
                    : (_result == null ? 'Generate' : 'Generate again')),
                onPressed: (_generating || widget.garments.isEmpty)
                    ? null
                    : _generate,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.blush,
                  foregroundColor: AppColors.surface,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StylePillRow extends StatelessWidget {
  final PlaygroundDraft draft;
  final PlaygroundLibrary library;
  final VoidCallback onTap;

  const _StylePillRow({
    required this.draft,
    required this.library,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final template = library.templates.firstWhere(
      (t) => t.id == draft.templateId,
      orElse: () => library.templates.isNotEmpty
          ? library.templates.first
          : const PlaygroundTemplate(
              id: '',
              slug: '',
              label: '—',
              body: '',
              isActive: false,
            ),
    );
    final persona = library.allPersonas.firstWhere(
      (p) => p.id == draft.personaId,
      orElse: () => const PlaygroundPersona(
        id: '',
        slug: '',
        label: '—',
        gender: 'female',
        description: '',
        isActive: false,
      ),
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.palette_outlined,
                size: 16, color: AppColors.blush),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${template.label} · ${draft.gender == 'female' ? 'F' : 'M'} · ${persona.label}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.text,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.edit_outlined,
                size: 16, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _TryOnLookStrip extends StatelessWidget {
  final List<CanvasGarment> garments;

  const _TryOnLookStrip({required this.garments});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: garments.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final garment = garments[index];
          return Container(
            width: 74,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border),
            ),
            child: CachedItemImage(
              url: garment.item.imageUrl,
              fit: BoxFit.contain,
            ),
          );
        },
      ),
    );
  }
}

class _TryOnPreview extends StatelessWidget {
  // 1024x1536 = portrait aspect for gpt-image-2 default size
  static const _aspectRatio = 1024 / 1536;

  final bool generating;
  final GenerateResponse? result;
  final PlaygroundCapException? capError;
  final Object? error;

  const _TryOnPreview({
    required this.generating,
    required this.result,
    required this.capError,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final frameWidth = (constraints.maxHeight * _aspectRatio)
            .clamp(0.0, constraints.maxWidth)
            .toDouble();
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: frameWidth,
            height: constraints.maxHeight,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.blush.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: _buildContent(context),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context) {
    if (generating) {
      return Container(
        color: AppColors.surfaceAlt,
        alignment: Alignment.center,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 14),
            Text('Generating…',
                style: TextStyle(color: AppColors.textMuted)),
          ],
        ),
      );
    }
    if (capError != null) {
      return _StatusCard(
        icon: Icons.timer_outlined,
        tone: AppColors.danger,
        title: 'Daily limit reached',
        body:
            'Used ${capError!.used}/${capError!.limit} today. Resets at ${_formatResetTime(capError!.resetAt)}.',
      );
    }
    if (error != null) {
      return _StatusCard(
        icon: Icons.error_outline,
        tone: AppColors.danger,
        title: 'Generation failed',
        body: error.toString(),
      );
    }
    final url = result?.images.firstOrNull;
    if (url != null) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => Container(
          color: AppColors.surfaceAlt,
          alignment: Alignment.center,
          child: const Icon(
            Icons.broken_image_outlined,
            color: AppColors.textMuted,
            size: 28,
          ),
        ),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            color: AppColors.surfaceAlt,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(),
          );
        },
      );
    }
    return Container(
      color: AppColors.surfaceAlt,
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_awesome_rounded,
                size: 36, color: AppColors.blush),
            const SizedBox(height: 12),
            Text(
              'Tap Generate',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Renders this outfit on the chosen persona using the editorial style.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  static String _formatResetTime(DateTime? resetAt) {
    if (resetAt == null) return 'tomorrow';
    final local = resetAt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final Color tone;
  final String title;
  final String body;
  const _StatusCard({
    required this.icon,
    required this.tone,
    required this.title,
    required this.body,
  });

  /// Hard cap so a runaway error (e.g. a gateway HTML page) still fits
  /// inside the card without overflow even if the scroll machinery fails.
  static const _maxBodyChars = 280;

  @override
  Widget build(BuildContext context) {
    final clipped = body.length > _maxBodyChars
        ? '${body.substring(0, _maxBodyChars)}…'
        : body;
    return Container(
      color: AppColors.surfaceAlt,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          Icon(icon, size: 36, color: tone),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                clipped,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
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
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
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
            child: CachedItemImage(
              url: garment.item.imageUrl,
              fit: BoxFit.contain,
              placeholderColor: Colors.transparent,
              errorBackgroundColor: Colors.transparent,
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: selected == null
            ? Row(
                children: [
                  const Icon(
                    Icons.touch_app_outlined,
                    color: AppColors.blush,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${canvas.garments.length} pieces on canvas',
                      style: Theme.of(context).textTheme.titleMedium,
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
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontSize: 15,
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
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add piece from',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Choose whether you want to pull from the shop catalog or your own wardrobe.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                ),
          ),
          const SizedBox(height: 16),
          _GarmentSourceTile(
            icon: Icons.public,
            title: 'Shop Catalog',
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.blush),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.layers_outlined, color: AppColors.blush),
              const SizedBox(width: 10),
              Text(
                'Layers',
                style: Theme.of(context).textTheme.headlineSmall,
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
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.folder_open_outlined, color: AppColors.blush),
              const SizedBox(width: 10),
              Text(
                'Saved outfits',
                style: Theme.of(context).textTheme.headlineSmall,
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
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
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
        Icon(Icons.checkroom_outlined, color: AppColors.blush, size: 42),
        SizedBox(height: 16),
        Text(
          'Add a piece to begin',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 16,
            fontWeight: FontWeight.w700,
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
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.text,
            disabledBackgroundColor: AppColors.surfaceAlt,
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
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
        dimension: 40,
        child: IconButton.filledTonal(
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surfaceAlt,
            foregroundColor: AppColors.text,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          padding: EdgeInsets.zero,
          iconSize: 20,
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
      ..color = AppColors.border.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    const spacing = 40.0;

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

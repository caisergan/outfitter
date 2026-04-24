import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fashion_app/core/models/catalog_item.dart';
import 'package:fashion_app/core/models/slot_type.dart';
import 'package:fashion_app/core/theme/app_colors.dart';
import 'package:fashion_app/core/utils/error_helpers.dart';
import 'package:fashion_app/core/widgets/error_view.dart';
import 'package:fashion_app/core/widgets/shared_widgets.dart';
import 'package:fashion_app/features/discover/data/catalog_repository.dart';
import 'package:fashion_app/features/discover/models/catalog_filter_options.dart';
import 'package:fashion_app/features/playground/providers/slot_builder_provider.dart';

class ItemBrowserSheet extends ConsumerStatefulWidget {
  final SlotType type;
  final Function(CatalogItem) onItemSelected;
  final bool updateSlotOnSelect;

  const ItemBrowserSheet({
    required this.type,
    required this.onItemSelected,
    this.updateSlotOnSelect = true,
    super.key,
  });

  @override
  ConsumerState<ItemBrowserSheet> createState() => _ItemBrowserSheetState();
}

class _ItemBrowserSheetState extends ConsumerState<ItemBrowserSheet> {
  late Future<List<CatalogItem>> _itemsFuture;
  Future<CatalogFilterOptions?>? _filterOptionsLoadFuture;
  var _filters = const _CatalogBrowserFilters();
  var _filterOptions = const CatalogFilterOptions.empty();
  var _hasLoadedFilterOptions = false;
  var _isLoadingFilterOptions = true;
  Object? _filterOptionsError;

  @override
  void initState() {
    super.initState();
    _itemsFuture = _searchItems(_filters);
    _fetchFilterOptions(showLoadingState: false);
  }

  Future<List<CatalogItem>> _searchItems(_CatalogBrowserFilters filters) {
    return ref.read(catalogRepositoryProvider).search(
          category: widget.type.categoryString,
          subtype: filters.subtype,
          color: filters.colors.isEmpty ? null : filters.colors.join(','),
          brand: filters.brand,
          style: filters.style,
          pattern: filters.pattern,
          fit: filters.fit,
          limit: 60,
        );
  }

  Future<CatalogFilterOptions?> _fetchFilterOptions({
    bool force = false,
    bool showLoadingState = true,
  }) async {
    if (_hasLoadedFilterOptions && !force) {
      return _filterOptions;
    }

    if (_isLoadingFilterOptions && _filterOptionsLoadFuture != null && !force) {
      return _filterOptionsLoadFuture!;
    }

    if (showLoadingState && mounted) {
      setState(() {
        _isLoadingFilterOptions = true;
        _filterOptionsError = null;
      });
    }

    final request = () async {
      final options = await ref.read(catalogRepositoryProvider).getFilterOptions(
            category: widget.type.categoryString,
          );

      if (!mounted) return options;

      final shouldResetSubtype =
          _filters.subtype != null && !options.subtypes.contains(_filters.subtype);
      final nextFilters = shouldResetSubtype
          ? _filters.copyWith(subtype: null)
          : _filters;

      setState(() {
        _filterOptions = options;
        _hasLoadedFilterOptions = true;
        _isLoadingFilterOptions = false;
        _filterOptionsError = null;
        if (shouldResetSubtype) {
          _filters = nextFilters;
          _itemsFuture = _searchItems(nextFilters);
        }
      });

      return options;
    }();

    _filterOptionsLoadFuture = request;

    try {
      return await request;
    } catch (error) {
      if (!mounted) return null;
      setState(() {
        _isLoadingFilterOptions = false;
        _filterOptionsError = error;
      });
      return null;
    }
  }

  void _applyFilters(_CatalogBrowserFilters nextFilters) {
    setState(() {
      _filters = nextFilters;
      _itemsFuture = _searchItems(nextFilters);
    });
  }

  Future<void> _openFilters() async {
    final options = await _fetchFilterOptions();
    if (!mounted) return;

    if (options == null) {
      showErrorSnackbar(
        context,
        _filterOptionsError == null
            ? 'Could not load filters right now.'
            : dioErrorToMessage(_filterOptionsError!),
      );
      return;
    }

    final nextFilters = await showModalBottomSheet<_CatalogBrowserFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CatalogFilterSheet(
        categoryLabel: widget.type.displayName,
        options: options,
        initialFilters: _filters,
      ),
    );

    if (!mounted || nextFilters == null) return;
    _applyFilters(nextFilters);
  }

  void _toggleSubtype(String option, bool selected) {
    final nextSubtype = !selected || option == _allSubtypesLabel ? null : option;
    _applyFilters(_filters.copyWith(subtype: nextSubtype));
  }

  @override
  Widget build(BuildContext context) {
    final selectedInSlot = widget.updateSlotOnSelect
        ? ref.watch(slotBuilderProvider).slots[widget.type]
        : null;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.text.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<List<CatalogItem>>(
                  future: _itemsFuture,
                  builder: (context, snapshot) {
                    final items = snapshot.data ?? const <CatalogItem>[];

                    return Column(
                      children: [
                        _BrowserHeader(
                          title: 'Choose ${widget.type.displayName}',
                          itemCountLabel: snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              items.isEmpty
                              ? 'Loading...'
                              : '${items.length} items',
                          categoryLabel: widget.type.displayName,
                          activeFilterCount: _filters.activeCount,
                          onOpenFilters: _openFilters,
                        ),
                        if (_isLoadingFilterOptions && !_hasLoadedFilterOptions)
                          const _SubtypeTabPlaceholder(),
                        if (!_isLoadingFilterOptions &&
                            _filterOptions.subtypes.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 12),
                            child: _SubtypeChipRow(
                              options: [
                                _allSubtypesLabel,
                                ..._filterOptions.subtypes,
                              ],
                              selected: _filters.subtype ?? _allSubtypesLabel,
                              onChanged: _toggleSubtype,
                            ),
                          ),
                        if (_filters.activeCount > 0)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                            child: _AppliedFiltersBanner(
                              activeFilterCount: _filters.activeCount,
                              onClear: () =>
                                  _applyFilters(const _CatalogBrowserFilters()),
                            ),
                          ),
                        Expanded(
                          child: _buildGridState(
                            context: context,
                            scrollController: scrollController,
                            snapshot: snapshot,
                            items: items,
                            selectedInSlot: selectedInSlot,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGridState({
    required BuildContext context,
    required ScrollController scrollController,
    required AsyncSnapshot<List<CatalogItem>> snapshot,
    required List<CatalogItem> items,
    required CatalogItem? selectedInSlot,
  }) {
    if (snapshot.connectionState == ConnectionState.waiting && items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.blush),
      );
    }

    if (snapshot.hasError) {
      return ErrorView(
        message: dioErrorToMessage(snapshot.error!),
        onRetry: () => _applyFilters(_filters),
      );
    }

    if (items.isEmpty) {
      return _EmptyBrowserState(
        hasFilters: _filters.activeCount > 0,
        onClear: () => _applyFilters(const _CatalogBrowserFilters()),
      );
    }

    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width < 380 ? 2 : 3;

    return GridView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 18,
        childAspectRatio: crossAxisCount == 2 ? 0.72 : 0.68,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = selectedInSlot?.id == item.id;

        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            if (widget.updateSlotOnSelect) {
              ref.read(slotBuilderProvider.notifier).setSlot(widget.type, item);
            }
            widget.onItemSelected(item);
            Navigator.of(context).pop();
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F2EA),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppColors.text : Colors.transparent,
                      width: 1.6,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.text.withValues(alpha: 0.06),
                        blurRadius: 14,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: CachedItemImage(
                            url: item.imageUrl,
                            fit: BoxFit.contain,
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Positioned(
                          top: 10,
                          right: 10,
                          child: _SelectedPill(),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.brand.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.text.withValues(alpha: 0.56),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BrowserHeader extends StatelessWidget {
  final String title;
  final String itemCountLabel;
  final String categoryLabel;
  final int activeFilterCount;
  final VoidCallback onOpenFilters;

  const _BrowserHeader({
    required this.title,
    required this.itemCountLabel,
    required this.categoryLabel,
    required this.activeFilterCount,
    required this.onOpenFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _HeaderBadge(
                      icon: Icons.grid_view_rounded,
                      label: itemCountLabel,
                      backgroundColor: const Color(0xFFF2EEE5),
                    ),
                    _HeaderBadge(
                      icon: Icons.checkroom_rounded,
                      label: categoryLabel,
                      backgroundColor: AppColors.lightMint,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _FilterActionButton(
            activeFilterCount: activeFilterCount,
            onPressed: onOpenFilters,
          ),
        ],
      ),
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color backgroundColor;

  const _HeaderBadge({
    required this.icon,
    required this.label,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.text),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterActionButton extends StatelessWidget {
  final int activeFilterCount;
  final VoidCallback onPressed;

  const _FilterActionButton({
    required this.activeFilterCount,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox.square(
          dimension: 48,
          child: IconButton.filledTonal(
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF2EEE5),
              foregroundColor: AppColors.text,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            tooltip: 'Filters',
            onPressed: onPressed,
            icon: const Icon(Icons.tune_rounded),
          ),
        ),
        if (activeFilterCount > 0)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.text,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$activeFilterCount',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AppliedFiltersBanner extends StatelessWidget {
  final int activeFilterCount;
  final VoidCallback onClear;

  const _AppliedFiltersBanner({
    required this.activeFilterCount,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.lightMint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.tune_rounded, size: 16, color: AppColors.text),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$activeFilterCount filter${activeFilterCount == 1 ? '' : 's'} applied',
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          TextButton(
            onPressed: onClear,
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class _SubtypeTabPlaceholder extends StatelessWidget {
  const _SubtypeTabPlaceholder();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, __) => Container(
          width: 92,
          decoration: BoxDecoration(
            color: const Color(0xFFF2EEE5),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: 3,
      ),
    );
  }
}

class _SubtypeChipRow extends StatelessWidget {
  final List<String> options;
  final String selected;
  final void Function(String, bool) onChanged;

  const _SubtypeChipRow({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          for (final option in options) ...[
            _FilterChoiceChip(
              label: option,
              selected: selected == option,
              onTap: () => onChanged(option, selected != option),
            ),
            const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

class _SelectedPill extends StatelessWidget {
  const _SelectedPill();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.text,
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: EdgeInsets.all(4),
        child: Icon(Icons.check, size: 14, color: Colors.white),
      ),
    );
  }
}

class _EmptyBrowserState extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback onClear;

  const _EmptyBrowserState({
    required this.hasFilters,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.checkroom_outlined,
              size: 48,
              color: AppColors.blush,
            ),
            const SizedBox(height: 14),
            Text(
              hasFilters
                  ? 'No garments match these filters.'
                  : 'No garments available in this category yet.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (hasFilters) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: onClear,
                child: const Text('Clear filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CatalogFilterSheet extends StatefulWidget {
  final String categoryLabel;
  final CatalogFilterOptions options;
  final _CatalogBrowserFilters initialFilters;

  const _CatalogFilterSheet({
    required this.categoryLabel,
    required this.options,
    required this.initialFilters,
  });

  @override
  State<_CatalogFilterSheet> createState() => _CatalogFilterSheetState();
}

class _CatalogFilterSheetState extends State<_CatalogFilterSheet> {
  late _CatalogBrowserFilters _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialFilters;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.78,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.text.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Filters',
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.categoryLabel,
                        style: TextStyle(
                          color: AppColors.text.withValues(alpha: 0.6),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_draft.activeCount > 0)
                  _HeaderBadge(
                    icon: Icons.tune_rounded,
                    label: '${_draft.activeCount} active',
                    backgroundColor: AppColors.lightMint,
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.options.subtypes.isNotEmpty)
                    _FilterSection(
                      title: 'Subtype',
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _FilterChoiceChip(
                            label: _allSubtypesLabel,
                            selected: _draft.subtype == null,
                            onTap: () =>
                                setState(() => _draft = _draft.copyWith(subtype: null)),
                          ),
                          for (final option in widget.options.subtypes)
                            _FilterChoiceChip(
                              label: option,
                              selected: _draft.subtype == option,
                              onTap: () => setState(
                                () => _draft = _draft.copyWith(
                                  subtype: _draft.subtype == option ? null : option,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (widget.options.colors.isNotEmpty)
                    _FilterSection(
                      title: 'Colors',
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final option in widget.options.colors)
                            _FilterChoiceChip(
                              label: option,
                              selected: _draft.colors.contains(option),
                              onTap: () => setState(
                                () => _draft = _draft.toggleColor(option),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (widget.options.brands.isNotEmpty)
                    _FilterSection(
                      title: 'Brand',
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final option in widget.options.brands)
                            _FilterChoiceChip(
                              label: option,
                              selected: _draft.brand == option,
                              onTap: () => setState(
                                () => _draft = _draft.copyWith(
                                  brand: _draft.brand == option ? null : option,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (widget.options.fits.isNotEmpty)
                    _FilterSection(
                      title: 'Fit',
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final option in widget.options.fits)
                            _FilterChoiceChip(
                              label: option,
                              selected: _draft.fit == option,
                              onTap: () => setState(
                                () => _draft = _draft.copyWith(
                                  fit: _draft.fit == option ? null : option,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (widget.options.patterns.isNotEmpty)
                    _FilterSection(
                      title: 'Pattern',
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final option in widget.options.patterns)
                            _FilterChoiceChip(
                              label: option,
                              selected: _draft.pattern == option,
                              onTap: () => setState(
                                () => _draft = _draft.copyWith(
                                  pattern: _draft.pattern == option ? null : option,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (widget.options.styleTags.isNotEmpty)
                    _FilterSection(
                      title: 'Style',
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final option in widget.options.styleTags)
                            _FilterChoiceChip(
                              label: option,
                              selected: _draft.style == option,
                              onTap: () => setState(
                                () => _draft = _draft.copyWith(
                                  style: _draft.style == option ? null : option,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (!widget.options.hasAdvancedOptions &&
                      widget.options.subtypes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'No extra filters are available for this category yet.',
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        side: BorderSide(
                          color: AppColors.text.withValues(alpha: 0.14),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => Navigator.of(context)
                          .pop(const _CatalogBrowserFilters()),
                      child: const Text('Clear'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.text,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(_draft),
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _FilterSection({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _FilterChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      backgroundColor: const Color(0xFFF4F1E9),
      selectedColor: AppColors.text,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.text,
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide(
        color: selected ? AppColors.text : Colors.transparent,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );
  }
}

class _CatalogBrowserFilters {
  final String? subtype;
  final Set<String> colors;
  final String? brand;
  final String? fit;
  final String? pattern;
  final String? style;

  const _CatalogBrowserFilters({
    this.subtype,
    this.colors = const {},
    this.brand,
    this.fit,
    this.pattern,
    this.style,
  });

  int get activeCount {
    var count = colors.length;
    if (subtype != null) count += 1;
    if (brand != null) count += 1;
    if (fit != null) count += 1;
    if (pattern != null) count += 1;
    if (style != null) count += 1;
    return count;
  }

  _CatalogBrowserFilters copyWith({
    Object? subtype = _filterUnset,
    Set<String>? colors,
    Object? brand = _filterUnset,
    Object? fit = _filterUnset,
    Object? pattern = _filterUnset,
    Object? style = _filterUnset,
  }) {
    return _CatalogBrowserFilters(
      subtype: identical(subtype, _filterUnset) ? this.subtype : subtype as String?,
      colors: colors ?? this.colors,
      brand: identical(brand, _filterUnset) ? this.brand : brand as String?,
      fit: identical(fit, _filterUnset) ? this.fit : fit as String?,
      pattern:
          identical(pattern, _filterUnset) ? this.pattern : pattern as String?,
      style: identical(style, _filterUnset) ? this.style : style as String?,
    );
  }

  _CatalogBrowserFilters toggleColor(String color) {
    final nextColors = Set<String>.of(colors);
    if (!nextColors.add(color)) {
      nextColors.remove(color);
    }
    return copyWith(colors: nextColors);
  }
}

const _allSubtypesLabel = 'All';
const _filterUnset = Object();

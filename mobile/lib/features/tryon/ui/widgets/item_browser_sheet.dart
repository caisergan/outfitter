import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fashion_app/core/models/catalog_filter_options.dart';
import 'package:fashion_app/core/models/catalog_item.dart';
import 'package:fashion_app/core/models/slot_type.dart';
import 'package:fashion_app/core/theme/app_colors.dart';
import 'package:fashion_app/core/widgets/shared_widgets.dart';
import 'package:fashion_app/features/discover/data/catalog_repository.dart';
import 'package:fashion_app/features/tryon/models/garment_category_filter.dart';
import 'package:fashion_app/features/tryon/providers/slot_builder_provider.dart';

class ItemBrowserSheet extends ConsumerStatefulWidget {
  final SlotType? type;
  final Function(CatalogItem) onItemSelected;
  final bool updateSlotOnSelect;
  final String? initialSlot;

  const ItemBrowserSheet({
    this.type,
    required this.onItemSelected,
    this.updateSlotOnSelect = true,
    this.initialSlot,
    super.key,
  }) : assert(!updateSlotOnSelect || type != null);

  @override
  ConsumerState<ItemBrowserSheet> createState() => _ItemBrowserSheetState();
}

class _ItemBrowserSheetState extends ConsumerState<ItemBrowserSheet> {
  late GarmentCategoryFilter _selectedCategory;
  CatalogFilterOptions? _filterOptions;
  List<GarmentCategoryFilter> _backendSlotFilters = const [];
  final List<CatalogItem> _items = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  int _totalItems = 0;
  String? _selectedBrand;
  String? _selectedGender;
  String? _selectedSubcategory;
  String? _selectedFit;
  String? _selectedColor;
  String? _selectedStyleTag;
  String? _searchQuery;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialSlot == null
        ? widget.type == null
            ? allGarmentCategoryFilter
            : garmentCategoryForSlotType(widget.type!)
        : garmentCategoryForBackendSlot(widget.initialSlot!);
    _loadInitialItems();
    _loadFilterOptions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<GarmentCategoryFilter> get _categoryFilters {
    final availableFilters = _backendSlotFilters.isEmpty
        ? [
            if (widget.type == null) allGarmentCategoryFilter,
            ...garmentCategoryFilters,
          ]
        : _backendSlotFilters;

    final hasSelectedCategory = availableFilters.any(
      (filter) => filter.backendSlot == _selectedCategory.backendSlot,
    );
    if (hasSelectedCategory) return availableFilters;
    return [_selectedCategory, ...availableFilters];
  }

  List<String> get _availableSubcategoryOptions {
    final options = _filterOptions;
    if (options == null) return const [];
    final category = _selectedCategory.backendSlot;
    if (category == null) {
      return options.subcategories;
    }
    return options.subcategoriesByCategory[category] ?? const [];
  }

  int get _activeFilterCount {
    var count = 0;
    if (_selectedBrand != null) count++;
    if (_selectedGender != null) count++;
    if (_selectedSubcategory != null) count++;
    if (_selectedFit != null) count++;
    if (_selectedColor != null) count++;
    if (_selectedStyleTag != null) count++;
    if (_searchQuery != null && _searchQuery!.isNotEmpty) count++;
    return count;
  }

  Future<void> _loadFilterOptions() async {
    try {
      final options =
          await ref.read(catalogRepositoryProvider).fetchFilterOptions();
      if (!mounted) return;
      setState(() {
        _filterOptions = options;
        _backendSlotFilters = _buildBackendSlotFilters(
          options.slots,
        );
        _selectedSubcategory = _normalizeSubcategory(_selectedSubcategory);
      });
    } catch (_) {
      // Keep local fallbacks when filter options fail.
    }
  }

  List<GarmentCategoryFilter> _buildBackendSlotFilters(
    List<String> slots,
  ) {
    final uniqueSlots = slots.toSet().toList()
      ..sort((left, right) {
        final leftOrder =
            garmentCategorySortOrder[left] ?? garmentCategorySortOrder.length;
        final rightOrder =
            garmentCategorySortOrder[right] ?? garmentCategorySortOrder.length;
        if (leftOrder != rightOrder) return leftOrder.compareTo(rightOrder);
        return left.compareTo(right);
      });

    return [
      if (widget.type == null) allGarmentCategoryFilter,
      ...uniqueSlots.map(garmentCategoryForBackendSlot),
    ];
  }

  String? _normalizeSubcategory(String? subcategory) {
    if (subcategory == null) return null;
    return _availableSubcategoryOptions.contains(subcategory) ? subcategory : null;
  }

  Future<void> _loadInitialItems() async {
    setState(() {
      _isInitialLoading = true;
      _isLoadingMore = false;
      _errorMessage = null;
      _totalItems = 0;
      _items.clear();
    });

    try {
      final repository = ref.read(catalogRepositoryProvider);
      final page = await repository.searchPage(
        slot: _selectedCategory.backendSlot,
        subcategory: _selectedSubcategory,
        brand: _selectedBrand,
        gender: _selectedGender,
        fit: _selectedFit,
        color: _selectedColor,
        style: _selectedStyleTag,
        query: _searchQuery,
        limit: repository.catalogPageSize,
        offset: 0,
      );

      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _totalItems = page.total;
        _isInitialLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load garments.';
        _isInitialLoading = false;
      });
    }
  }

  Future<void> _loadMoreItems() async {
    if (_isInitialLoading || _isLoadingMore || _items.length >= _totalItems) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
      _errorMessage = null;
    });

    try {
      final repository = ref.read(catalogRepositoryProvider);
      final page = await repository.searchPage(
        slot: _selectedCategory.backendSlot,
        subcategory: _selectedSubcategory,
        brand: _selectedBrand,
        gender: _selectedGender,
        fit: _selectedFit,
        color: _selectedColor,
        style: _selectedStyleTag,
        query: _searchQuery,
        limit: repository.catalogPageSize,
        offset: _items.length,
      );

      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _totalItems = page.total;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load garments.';
        _isLoadingMore = false;
      });
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.pixels >=
        notification.metrics.maxScrollExtent - 240) {
      _loadMoreItems();
    }
    return false;
  }

  void _selectCategory(GarmentCategoryFilter filter) {
    setState(() {
      _selectedCategory = filter;
      _selectedSubcategory = _normalizeSubcategory(_selectedSubcategory);
    });
    _loadInitialItems();
  }

  void _submitSearch() {
    final nextQuery = _searchController.text.trim();
    setState(() {
      _searchQuery = nextQuery.isEmpty ? null : nextQuery;
    });
    _loadInitialItems();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = null;
    });
    _loadInitialItems();
  }

  Future<void> _openFilterSheet() async {
    final options = _filterOptions;
    if (options == null) return;

    final result = await showModalBottomSheet<_CatalogFilterSheetResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CatalogFilterSheet(
        options: options,
        currentSlot: _selectedCategory.backendSlot,
        initialBrand: _selectedBrand,
        initialGender: _selectedGender,
        initialSubcategory: _selectedSubcategory,
        initialFit: _selectedFit,
        initialColor: _selectedColor,
        initialStyleTag: _selectedStyleTag,
      ),
    );

    if (!mounted || result == null) return;

    setState(() {
      _selectedBrand = result.brand;
      _selectedGender = result.gender;
      _selectedSubcategory = _normalizeSubcategory(result.subcategory);
      _selectedFit = result.fit;
      _selectedColor = result.color;
      _selectedStyleTag = result.styleTag;
    });
    _loadInitialItems();
  }

  void _clearFilter(String key) {
    setState(() {
      switch (key) {
        case 'brand':
          _selectedBrand = null;
        case 'gender':
          _selectedGender = null;
        case 'subcategory':
          _selectedSubcategory = null;
        case 'fit':
          _selectedFit = null;
        case 'color':
          _selectedColor = null;
        case 'style':
          _selectedStyleTag = null;
        case 'search':
          _searchQuery = null;
          _searchController.clear();
      }
    });
    _loadInitialItems();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.76,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 10),
                _buildSearchField(),
                const SizedBox(height: 10),
                _buildCategoryFilters(),
                if (_activeFilterCount > 0) ...[
                  const SizedBox(height: 10),
                  _buildActiveFilters(),
                ],
                const SizedBox(height: 14),
                Expanded(child: _buildItemGrid(scrollController)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Shop catalog',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Search, filter, and place pieces directly onto the canvas.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton.filledTonal(
              onPressed: _filterOptions == null ? null : _openFilterSheet,
              icon: const Icon(Icons.tune_rounded),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surfaceAlt,
                foregroundColor: AppColors.text,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              tooltip: 'Filters',
            ),
            if (_activeFilterCount > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.blush,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$_activeFilterCount',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.surface,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      onChanged: (_) => setState(() {}),
      onSubmitted: (_) => _submitSearch(),
      decoration: InputDecoration(
        hintText: 'Search by name or vibe',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _searchController.text.isNotEmpty || _searchQuery != null
            ? IconButton(
                onPressed: _clearSearch,
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Clear search',
              )
            : IconButton(
                onPressed: _submitSearch,
                icon: const Icon(Icons.arrow_forward_rounded),
                tooltip: 'Apply search',
              ),
        filled: true,
        fillColor: AppColors.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.borderStrong),
        ),
      ),
    );
  }

  Widget _buildCategoryFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _categoryFilters.map((filter) {
          final isSelected =
              _selectedCategory.backendSlot == filter.backendSlot;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filter.label),
              selected: isSelected,
              onSelected: (_) => _selectCategory(filter),
              selectedColor: AppColors.surfaceAlt,
              backgroundColor: AppColors.surface,
              side: BorderSide(
                color: isSelected ? AppColors.borderStrong : AppColors.border,
              ),
              labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: isSelected ? AppColors.text : AppColors.textMuted,
                  ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActiveFilters() {
    final chips = <Widget>[
      if (_searchQuery != null && _searchQuery!.isNotEmpty)
        _ActiveFilterChip(
          label: 'Search: ${_searchQuery!}',
          onDeleted: () => _clearFilter('search'),
        ),
      if (_selectedGender != null)
        _ActiveFilterChip(
          label: _titleCase(_selectedGender!),
          onDeleted: () => _clearFilter('gender'),
        ),
      if (_selectedBrand != null)
        _ActiveFilterChip(
          label: _selectedBrand!,
          onDeleted: () => _clearFilter('brand'),
        ),
      if (_selectedSubcategory != null)
        _ActiveFilterChip(
          label: _titleCase(_selectedSubcategory!),
          onDeleted: () => _clearFilter('subcategory'),
        ),
      if (_selectedFit != null)
        _ActiveFilterChip(
          label: _titleCase(_selectedFit!),
          onDeleted: () => _clearFilter('fit'),
        ),
      if (_selectedColor != null)
        _ActiveFilterChip(
          label: _selectedColor!,
          onDeleted: () => _clearFilter('color'),
        ),
      if (_selectedStyleTag != null)
        _ActiveFilterChip(
          label: _titleCase(_selectedStyleTag!),
          onDeleted: () => _clearFilter('style'),
        ),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips,
    );
  }

  Widget _buildItemGrid(ScrollController scrollController) {
    final selectedInSlot = widget.updateSlotOnSelect
        ? ref.watch(slotBuilderProvider).slots[widget.type]
        : null;

    if (_isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _items.isEmpty) {
      return Center(
        child: Text(
          _errorMessage!,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textMuted,
              ),
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Text(
          'No garments found for these filters.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textMuted,
              ),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: GridView.builder(
        controller: scrollController,
        padding: const EdgeInsets.only(top: 6, bottom: 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 14,
          mainAxisSpacing: 18,
          childAspectRatio: 0.68,
        ),
        itemCount: _items.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final item = _items[index];
          final isSelected = selectedInSlot?.id == item.id;

          return GestureDetector(
            onTap: () {
              if (widget.updateSlotOnSelect && widget.type != null) {
                ref.read(slotBuilderProvider.notifier).setSlot(
                      widget.type!,
                      item,
                    );
              }
              widget.onItemSelected(item);
              Navigator.pop(context);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.borderStrong
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: CachedItemImage(
                      url: item.imageUrl,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.name.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color:
                            isSelected ? AppColors.text : AppColors.textMuted,
                        letterSpacing: 0.8,
                      ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CatalogFilterSheet extends StatefulWidget {
  const _CatalogFilterSheet({
    required this.options,
    required this.currentSlot,
    required this.initialBrand,
    required this.initialGender,
    required this.initialSubcategory,
    required this.initialFit,
    required this.initialColor,
    required this.initialStyleTag,
  });

  final CatalogFilterOptions options;
  final String? currentSlot;
  final String? initialBrand;
  final String? initialGender;
  final String? initialSubcategory;
  final String? initialFit;
  final String? initialColor;
  final String? initialStyleTag;

  @override
  State<_CatalogFilterSheet> createState() => _CatalogFilterSheetState();
}

class _CatalogFilterSheetState extends State<_CatalogFilterSheet> {
  late String? _brand = widget.initialBrand;
  late String? _gender = widget.initialGender;
  late String? _subcategory = _resolveSubcategory(widget.initialSubcategory);
  late String? _fit = widget.initialFit;
  late String? _color = widget.initialColor;
  late String? _styleTag = widget.initialStyleTag;

  List<String> get _availableSubcategoryOptions {
    return widget.options.subcategories;
  }

  String? _resolveSubcategory(String? value) {
    if (value == null) return null;
    return _availableSubcategoryOptions.contains(value) ? value : null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
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
                    child: Text(
                      'Refine catalog',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _brand = null;
                        _gender = null;
                        _subcategory = null;
                        _fit = null;
                        _color = null;
                        _styleTag = null;
                      });
                    },
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Filter by fit, brand, gender, subcategory, color, or style.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: ListView(
                  children: [
                    _buildDropdown(
                      label: 'Gender',
                      value: _gender,
                      options: widget.options.genders,
                      onChanged: (value) => setState(() => _gender = value),
                    ),
                    const SizedBox(height: 14),
                    _buildDropdown(
                      label: 'Brand',
                      value: _brand,
                      options: widget.options.brands,
                      onChanged: (value) => setState(() => _brand = value),
                    ),
                    const SizedBox(height: 14),
                    _buildDropdown(
                      label: 'Subcategory',
                      value: _subcategory,
                      options: _availableSubcategoryOptions,
                      onChanged: (value) => setState(() => _subcategory = value),
                    ),
                    const SizedBox(height: 14),
                    _buildDropdown(
                      label: 'Fit',
                      value: _fit,
                      options: widget.options.fits,
                      onChanged: (value) => setState(() => _fit = value),
                    ),
                    const SizedBox(height: 14),
                    _buildDropdown(
                      label: 'Color',
                      value: _color,
                      options: widget.options.colors,
                      onChanged: (value) => setState(() => _color = value),
                    ),
                    const SizedBox(height: 14),
                    _buildDropdown(
                      label: 'Style',
                      value: _styleTag,
                      options: widget.options.styleTags,
                      onChanged: (value) => setState(() => _styleTag = value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      _CatalogFilterSheetResult(
                        brand: _brand,
                        gender: _gender,
                        subcategory: _subcategory,
                        fit: _fit,
                        color: _color,
                        styleTag: _styleTag,
                      ),
                    );
                  },
                  child: const Text('Apply filters'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    final items = [
      const DropdownMenuItem<String?>(
        value: null,
        child: Text('Any'),
      ),
      ...options.map(
        (option) => DropdownMenuItem<String?>(
          value: option,
          child: Text(_titleCase(option)),
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          initialValue: value,
          items: items,
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surfaceAlt,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _CatalogFilterSheetResult {
  const _CatalogFilterSheetResult({
    this.brand,
    this.gender,
    this.subcategory,
    this.fit,
    this.color,
    this.styleTag,
  });

  final String? brand;
  final String? gender;
  final String? subcategory;
  final String? fit;
  final String? color;
  final String? styleTag;
}

class _ActiveFilterChip extends StatelessWidget {
  const _ActiveFilterChip({
    required this.label,
    required this.onDeleted,
  });

  final String label;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text(label),
      onDeleted: onDeleted,
      deleteIcon: const Icon(Icons.close_rounded, size: 18),
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppColors.text,
          ),
      backgroundColor: AppColors.surfaceAlt,
      side: const BorderSide(color: AppColors.border),
    );
  }
}

String _titleCase(String value) {
  final words = value.replaceAll('_', ' ').split(' ');
  return words
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

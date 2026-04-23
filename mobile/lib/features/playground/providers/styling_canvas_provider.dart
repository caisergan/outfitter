import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:fashion_app/core/models/catalog_item.dart';
import 'package:fashion_app/core/models/wardrobe_item.dart';
import 'package:fashion_app/features/playground/models/styling_canvas_models.dart';

class StylingCanvasState {
  final List<CanvasGarment> garments;
  final String? selectedGarmentId;
  final String? activeOutfitId;
  final String title;
  final List<SavedStylingCanvasOutfit> savedOutfits;
  final bool isLoadingSaved;
  final bool isSaving;

  const StylingCanvasState({
    required this.garments,
    required this.selectedGarmentId,
    required this.activeOutfitId,
    required this.title,
    required this.savedOutfits,
    required this.isLoadingSaved,
    required this.isSaving,
  });

  factory StylingCanvasState.initial() => const StylingCanvasState(
        garments: [],
        selectedGarmentId: null,
        activeOutfitId: null,
        title: 'Untitled outfit',
        savedOutfits: [],
        isLoadingSaved: true,
        isSaving: false,
      );

  CanvasGarment? get selectedGarment {
    for (final garment in garments) {
      if (garment.id == selectedGarmentId) return garment;
    }
    return null;
  }

  bool get canSave => garments.isNotEmpty && !isSaving;

  StylingCanvasState copyWith({
    List<CanvasGarment>? garments,
    Object? selectedGarmentId = _sentinel,
    Object? activeOutfitId = _sentinel,
    String? title,
    List<SavedStylingCanvasOutfit>? savedOutfits,
    bool? isLoadingSaved,
    bool? isSaving,
  }) {
    return StylingCanvasState(
      garments: garments ?? this.garments,
      selectedGarmentId: identical(selectedGarmentId, _sentinel)
          ? this.selectedGarmentId
          : selectedGarmentId as String?,
      activeOutfitId: identical(activeOutfitId, _sentinel)
          ? this.activeOutfitId
          : activeOutfitId as String?,
      title: title ?? this.title,
      savedOutfits: savedOutfits ?? this.savedOutfits,
      isLoadingSaved: isLoadingSaved ?? this.isLoadingSaved,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

const Object _sentinel = Object();

class StylingCanvasNotifier extends StateNotifier<StylingCanvasState> {
  StylingCanvasNotifier() : super(StylingCanvasState.initial()) {
    _loadSavedOutfits();
  }

  static const _storageKey = 'styling_canvas_saved_outfits';
  static const _uuid = Uuid();

  Future<void> _loadSavedOutfits() async {
    final prefs = await SharedPreferences.getInstance();
    final rawItems = prefs.getStringList(_storageKey) ?? [];
    final outfits = <SavedStylingCanvasOutfit>[];

    for (final raw in rawItems) {
      try {
        outfits.add(
          SavedStylingCanvasOutfit.fromJson(
            jsonDecode(raw) as Map<String, dynamic>,
          ),
        );
      } catch (_) {
        // Ignore malformed local drafts and keep the canvas usable.
      }
    }

    outfits.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    state = state.copyWith(savedOutfits: outfits, isLoadingSaved: false);
  }

  Future<void> _persistSavedOutfits(
    List<SavedStylingCanvasOutfit> outfits,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _storageKey,
      outfits.map((outfit) => jsonEncode(outfit.toJson())).toList(),
    );
  }

  void addGarmentFromUrl({
    required String slot,
    required String imageUrl,
  }) {
    final item = CatalogItem(
      id: _uuid.v4(),
      brand: 'Prefilled',
      category: slot,
      subtype: slot,
      name: slot,
      color: const [],
      pattern: null,
      fit: null,
      styleTags: const [],
      imageUrl: imageUrl,
    );

    addGarment(item);
  }

  void addGarment(CatalogItem item) {
    final index = state.garments.length;
    final offset = (index % 5) * 0.045;
    final garment = CanvasGarment(
      id: _uuid.v4(),
      item: item,
      x: _clampDouble(0.5 + offset, 0.1, 0.9),
      y: _clampDouble(0.48 + offset, 0.1, 0.9),
      scale: 1,
      rotation: 0,
    );

    state = state.copyWith(
      garments: [...state.garments, garment],
      selectedGarmentId: garment.id,
    );
  }

  void addWardrobeGarment(WardrobeItem item) {
    addGarment(
      CatalogItem(
        id: item.id,
        brand: 'My Wardrobe',
        category: item.category,
        subtype: item.subtype,
        name: _wardrobeItemName(item),
        color: item.color,
        pattern: item.pattern,
        fit: item.fit,
        styleTags: item.styleTags,
        imageUrl: item.imageUrl,
      ),
    );
  }

  void selectGarment(String? id) {
    state = state.copyWith(selectedGarmentId: id);
  }

  void updateGarmentTransform(
    String id, {
    double? x,
    double? y,
    double? scale,
    double? rotation,
  }) {
    state = state.copyWith(
      garments: [
        for (final garment in state.garments)
          if (garment.id == id)
            garment.copyWith(
              x: x == null ? null : _clampDouble(x, 0.04, 0.96),
              y: y == null ? null : _clampDouble(y, 0.04, 0.96),
              scale: scale == null ? null : _clampDouble(scale, 0.35, 2.8),
              rotation: rotation,
            )
          else
            garment,
      ],
    );
  }

  void rotateSelected(double delta) {
    final selected = state.selectedGarment;
    if (selected == null) return;
    updateGarmentTransform(
      selected.id,
      rotation: selected.rotation + delta,
    );
  }

  void scaleSelected(double delta) {
    final selected = state.selectedGarment;
    if (selected == null) return;
    updateGarmentTransform(
      selected.id,
      scale: selected.scale + delta,
    );
  }

  void deleteSelected() {
    final selectedId = state.selectedGarmentId;
    if (selectedId == null) return;
    state = state.copyWith(
      garments:
          state.garments.where((garment) => garment.id != selectedId).toList(),
      selectedGarmentId: null,
    );
  }

  void duplicateSelected() {
    final selected = state.selectedGarment;
    if (selected == null) return;

    final duplicate = selected.copyWith(
      x: _clampDouble(selected.x + 0.06, 0.1, 0.9),
      y: _clampDouble(selected.y + 0.06, 0.1, 0.9),
    );

    final duplicateWithId = CanvasGarment(
      id: _uuid.v4(),
      item: duplicate.item,
      x: duplicate.x,
      y: duplicate.y,
      scale: duplicate.scale,
      rotation: duplicate.rotation,
    );

    state = state.copyWith(
      garments: [...state.garments, duplicateWithId],
      selectedGarmentId: duplicateWithId.id,
    );
  }

  void bringSelectedForward() {
    final selectedId = state.selectedGarmentId;
    if (selectedId == null) return;
    final index = state.garments.indexWhere((item) => item.id == selectedId);
    if (index < 0 || index == state.garments.length - 1) return;
    _moveGarment(index, index + 1);
  }

  void sendSelectedBackward() {
    final selectedId = state.selectedGarmentId;
    if (selectedId == null) return;
    final index = state.garments.indexWhere((item) => item.id == selectedId);
    if (index <= 0) return;
    _moveGarment(index, index - 1);
  }

  void bringSelectedToFront() {
    final selectedId = state.selectedGarmentId;
    if (selectedId == null) return;
    final index = state.garments.indexWhere((item) => item.id == selectedId);
    if (index < 0 || index == state.garments.length - 1) return;
    _moveGarment(index, state.garments.length - 1);
  }

  void sendSelectedToBack() {
    final selectedId = state.selectedGarmentId;
    if (selectedId == null) return;
    final index = state.garments.indexWhere((item) => item.id == selectedId);
    if (index <= 0) return;
    _moveGarment(index, 0);
  }

  void reorderGarments(int oldIndex, int newIndex) {
    final adjustedNewIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    _moveGarment(oldIndex, adjustedNewIndex);
  }

  void _moveGarment(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    final garments = [...state.garments];
    final garment = garments.removeAt(oldIndex);
    garments.insert(newIndex.clamp(0, garments.length).toInt(), garment);
    state = state.copyWith(garments: garments);
  }

  Future<SavedStylingCanvasOutfit?> saveCurrent() async {
    if (state.garments.isEmpty) return null;

    state = state.copyWith(isSaving: true);
    final now = DateTime.now();
    final activeId = state.activeOutfitId;
    final existingIndex =
        state.savedOutfits.indexWhere((outfit) => outfit.id == activeId);

    final title = state.title == 'Untitled outfit'
        ? 'Canvas outfit ${state.savedOutfits.length + 1}'
        : state.title;

    final outfit = existingIndex >= 0
        ? state.savedOutfits[existingIndex].copyWith(
            title: title,
            garments: state.garments,
            updatedAt: now,
          )
        : SavedStylingCanvasOutfit(
            id: _uuid.v4(),
            title: title,
            garments: state.garments,
            createdAt: now,
            updatedAt: now,
          );

    final saved = [...state.savedOutfits];
    if (existingIndex >= 0) {
      saved[existingIndex] = outfit;
    } else {
      saved.insert(0, outfit);
    }
    saved.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    try {
      await _persistSavedOutfits(saved);
      state = state.copyWith(
        savedOutfits: saved,
        activeOutfitId: outfit.id,
        title: outfit.title,
        isSaving: false,
      );
      return outfit;
    } catch (_) {
      state = state.copyWith(isSaving: false);
      rethrow;
    }
  }

  void openOutfit(SavedStylingCanvasOutfit outfit) {
    state = state.copyWith(
      garments: outfit.garments
          .map((g) => CanvasGarment(
        id: g.id,
        item: g.item,
        x: g.x,
        y: g.y,
        scale: g.scale,
        rotation: g.rotation,
      ))
          .toList(),
      selectedGarmentId: null,
      activeOutfitId: outfit.id,
      title: outfit.title,
    );
  }

  Future<void> deleteOutfit(String id) async {
    final saved =
        state.savedOutfits.where((outfit) => outfit.id != id).toList();
    await _persistSavedOutfits(saved);

    state = state.copyWith(
      savedOutfits: saved,
      activeOutfitId: state.activeOutfitId == id ? null : state.activeOutfitId,
      title: state.activeOutfitId == id ? 'Untitled outfit' : state.title,
      garments: state.activeOutfitId == id ? [] : state.garments,
      selectedGarmentId:
          state.activeOutfitId == id ? null : state.selectedGarmentId,
    );
  }

  void newCanvas() {
    state = state.copyWith(
      garments: [],
      selectedGarmentId: null,
      activeOutfitId: null,
      title: 'Untitled outfit',
    );
  }

  double _clampDouble(double value, double min, double max) {
    return value.clamp(min, max).toDouble();
  }

  String _wardrobeItemName(WardrobeItem item) {
    final color = item.color.isEmpty ? null : item.color.join(', ');
    final subtype = item.subtype ?? item.category;
    return [color, subtype].whereType<String>().join(' ');
  }
}

final stylingCanvasProvider =
    StateNotifierProvider<StylingCanvasNotifier, StylingCanvasState>(
  (_) => StylingCanvasNotifier(),
);

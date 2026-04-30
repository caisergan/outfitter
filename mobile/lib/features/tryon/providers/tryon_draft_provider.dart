import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fashion_app/core/models/tryon_models.dart';
import 'tryon_library_provider.dart';

/// Draft of what will be sent on the next Generate. Holds the chosen
/// template / gender / persona, the editable system prompt, and the
/// user-prompt textarea content. The Style picker sheet mutates this; the
/// Try-On sheet reads it to drive the Generate button.
class TryOnDraft {
  final String? templateId;
  final String gender;
  final String? personaId;
  final String systemPromptText;
  final String userPromptText;
  // Tracks the last compose() result we wrote into userPromptText so we can
  // tell whether the textarea has been manually edited.
  final String lastAppliedComposed;

  const TryOnDraft({
    this.templateId,
    this.gender = 'female',
    this.personaId,
    this.systemPromptText = '',
    this.userPromptText = '',
    this.lastAppliedComposed = '',
  });

  TryOnDraft copyWith({
    String? templateId,
    bool clearTemplate = false,
    String? gender,
    String? personaId,
    bool clearPersona = false,
    String? systemPromptText,
    String? userPromptText,
    String? lastAppliedComposed,
  }) {
    return TryOnDraft(
      templateId: clearTemplate ? null : (templateId ?? this.templateId),
      gender: gender ?? this.gender,
      personaId: clearPersona ? null : (personaId ?? this.personaId),
      systemPromptText: systemPromptText ?? this.systemPromptText,
      userPromptText: userPromptText ?? this.userPromptText,
      lastAppliedComposed: lastAppliedComposed ?? this.lastAppliedComposed,
    );
  }

  bool get isUserPromptDirty =>
      userPromptText.isNotEmpty && userPromptText != lastAppliedComposed;
}

/// Compose `template.body` with `{{MODEL}}` replaced by `persona.description`.
/// Mirrors the web-side composeUserPrompt helper. Returns "" if either side
/// is missing so the textarea stays empty until both dropdowns resolve.
String composeUserPrompt({
  TryOnTemplate? template,
  TryOnPersona? persona,
}) {
  if (template == null || persona == null) return '';
  return template.body.replaceFirst('{{MODEL}}', persona.description.trim());
}

class TryOnDraftNotifier extends Notifier<TryOnDraft> {
  @override
  TryOnDraft build() {
    // Seed from the library provider once it resolves.
    ref.listen(tryonLibraryProvider, (_, next) {
      next.whenData((lib) => _seedFromLibrary(lib));
    });
    final lib = ref.read(tryonLibraryProvider).valueOrNull;
    if (lib != null) {
      return _initialFrom(lib);
    }
    return const TryOnDraft();
  }

  TryOnDraft _initialFrom(TryOnLibrary lib) {
    final template = lib.templates.isNotEmpty ? lib.templates.first : null;
    final firstFemale = lib.allPersonas.firstWhere((p) => p.gender == 'female',
        orElse: () => lib.allPersonas.isNotEmpty
            ? lib.allPersonas.first
            : _placeholderPersona());
    final composed =
        composeUserPrompt(template: template, persona: firstFemale);
    return TryOnDraft(
      templateId: template?.id,
      gender: firstFemale.gender,
      personaId: firstFemale.id,
      systemPromptText: lib.systemPrompt.content,
      userPromptText: composed,
      lastAppliedComposed: composed,
    );
  }

  void _seedFromLibrary(TryOnLibrary lib) {
    if (state.templateId == null && state.personaId == null) {
      state = _initialFrom(lib);
    }
  }

  /// Auto-update the textarea on dropdown change ONLY when it's still in sync
  /// with the last composed value (i.e. the user hasn't typed manually). This
  /// matches the web-side `lastAppliedComposed` semantics.
  void _maybeApplyComposed(String next) {
    if (state.userPromptText == state.lastAppliedComposed) {
      state = state.copyWith(userPromptText: next, lastAppliedComposed: next);
    } else {
      state = state.copyWith(lastAppliedComposed: next);
    }
  }

  void setTemplate(String? templateId) {
    final lib = ref.read(tryonLibraryProvider).valueOrNull;
    state = state.copyWith(
      templateId: templateId,
      clearTemplate: templateId == null,
    );
    if (lib == null) return;
    final template = templateId == null
        ? null
        : lib.templates.firstWhere(
            (t) => t.id == templateId,
            orElse: () => lib.templates.first,
          );
    final persona = state.personaId == null
        ? null
        : lib.allPersonas.firstWhere(
            (p) => p.id == state.personaId,
            orElse: () => _placeholderPersona(),
          );
    _maybeApplyComposed(
      composeUserPrompt(template: template, persona: persona),
    );
  }

  void setGender(String gender) {
    final lib = ref.read(tryonLibraryProvider).valueOrNull;
    if (lib == null) {
      state = state.copyWith(gender: gender);
      return;
    }
    // If the current personaId belongs to a different gender, snap to the
    // first persona of the new gender.
    final current = lib.allPersonas.firstWhere((p) => p.id == state.personaId,
        orElse: () => _placeholderPersona());
    final newPersona = current.gender == gender
        ? current
        : lib.allPersonas.firstWhere(
            (p) => p.gender == gender,
            orElse: () => _placeholderPersona(),
          );
    state = state.copyWith(
      gender: gender,
      personaId: newPersona.id.isEmpty ? null : newPersona.id,
      clearPersona: newPersona.id.isEmpty,
    );
    final template = state.templateId == null
        ? null
        : lib.templates.firstWhere(
            (t) => t.id == state.templateId,
            orElse: () => lib.templates.first,
          );
    _maybeApplyComposed(
      composeUserPrompt(
        template: template,
        persona: newPersona.id.isEmpty ? null : newPersona,
      ),
    );
  }

  void setPersona(String? personaId) {
    final lib = ref.read(tryonLibraryProvider).valueOrNull;
    state = state.copyWith(
      personaId: personaId,
      clearPersona: personaId == null,
    );
    if (lib == null) return;
    final persona = personaId == null
        ? null
        : lib.allPersonas.firstWhere(
            (p) => p.id == personaId,
            orElse: () => _placeholderPersona(),
          );
    final template = state.templateId == null
        ? null
        : lib.templates.firstWhere(
            (t) => t.id == state.templateId,
            orElse: () => lib.templates.first,
          );
    _maybeApplyComposed(
      composeUserPrompt(template: template, persona: persona),
    );
  }

  void setUserPrompt(String text) {
    state = state.copyWith(userPromptText: text);
  }

  void setSystemPrompt(String text) {
    state = state.copyWith(systemPromptText: text);
  }

  void resetUserPromptToComposed() {
    state = state.copyWith(
      userPromptText: state.lastAppliedComposed,
    );
  }

  /// Called by the reproduce flow to slam the entire draft to a past run's
  /// snapshot. Bypasses the dirty-detection auto-overwrite by leaving
  /// lastAppliedComposed pointing at the current dropdown composition; the
  /// dirty badge then accurately reflects whether the snapshot diverges.
  void applyRunSnapshot({
    required String? templateId,
    required String? personaId,
    required String gender,
    required String systemPromptText,
    required String userPromptText,
    required String composedFromDropdowns,
  }) {
    state = TryOnDraft(
      templateId: templateId,
      gender: gender,
      personaId: personaId,
      systemPromptText: systemPromptText,
      userPromptText: userPromptText,
      lastAppliedComposed: composedFromDropdowns,
    );
  }
}

TryOnPersona _placeholderPersona() => const TryOnPersona(
      id: '',
      slug: '',
      label: '',
      gender: 'female',
      description: '',
      isActive: false,
    );

final tryonDraftProvider = NotifierProvider<TryOnDraftNotifier, TryOnDraft>(
  TryOnDraftNotifier.new,
);

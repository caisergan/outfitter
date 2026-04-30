import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fashion_app/core/models/tryon_models.dart';
import 'package:fashion_app/core/theme/app_colors.dart';
import 'package:fashion_app/features/tryon/providers/tryon_draft_provider.dart';
import 'package:fashion_app/features/tryon/providers/tryon_library_provider.dart';

/// Modal bottom sheet for picking the editorial style of the next tryon
/// generation: template + gender + persona dropdowns plus a variation-notes
/// textarea. Mutates the tryonDraftProvider so the Try-On sheet can read
/// the result.
class StylePickerSheet extends ConsumerWidget {
  const StylePickerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryAsync = ref.watch(tryonLibraryProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: libraryAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load style library: $err',
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
            data: (lib) => _StylePickerBody(
              library: lib,
              scrollController: scrollController,
            ),
          ),
        );
      },
    );
  }
}

class _StylePickerBody extends ConsumerStatefulWidget {
  final TryOnLibrary library;
  final ScrollController scrollController;

  const _StylePickerBody({
    required this.library,
    required this.scrollController,
  });

  @override
  ConsumerState<_StylePickerBody> createState() => _StylePickerBodyState();
}

class _StylePickerBodyState extends ConsumerState<_StylePickerBody> {
  late TextEditingController _userPromptController;

  @override
  void initState() {
    super.initState();
    _userPromptController = TextEditingController(
        text: ref.read(tryonDraftProvider).userPromptText);
  }

  @override
  void dispose() {
    _userPromptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(tryonDraftProvider);
    final notifier = ref.read(tryonDraftProvider.notifier);
    final lib = widget.library;

    // Sync controller text if the draft changed externally (e.g. dropdowns
    // recomposed the prompt).
    if (_userPromptController.text != draft.userPromptText) {
      _userPromptController.value = TextEditingValue(
        text: draft.userPromptText,
        selection: TextSelection.collapsed(offset: draft.userPromptText.length),
      );
    }

    final visiblePersonas = lib.personasFor(draft.gender);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: ListView(
        controller: widget.scrollController,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Style',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Pick the look. Variation notes auto-compose from your choices and stay editable.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                ),
          ),
          const SizedBox(height: 16),
          _Field(
            label: 'Template',
            helper: lib.templates
                    .firstWhere(
                      (t) => t.id == draft.templateId,
                      orElse: () => lib.templates.isNotEmpty
                          ? lib.templates.first
                          : _placeholderTemplate(),
                    )
                    .description ??
                '',
            child: _styledDropdown<String>(
              value: draft.templateId,
              items: lib.templates
                  .map((t) =>
                      DropdownMenuItem(value: t.id, child: Text(t.label)))
                  .toList(),
              onChanged: (v) => notifier.setTemplate(v),
            ),
          ),
          const SizedBox(height: 14),
          _Field(
            label: 'Gender',
            helper: 'Filters which personas are available.',
            child: _styledDropdown<String>(
              value: draft.gender,
              items: const [
                DropdownMenuItem(value: 'female', child: Text('Female')),
                DropdownMenuItem(value: 'male', child: Text('Male')),
              ],
              onChanged: (v) {
                if (v != null) notifier.setGender(v);
              },
            ),
          ),
          const SizedBox(height: 14),
          _Field(
            label: 'Persona',
            child: _styledDropdown<String>(
              value: visiblePersonas.any((p) => p.id == draft.personaId)
                  ? draft.personaId
                  : null,
              items: visiblePersonas
                  .map((p) =>
                      DropdownMenuItem(value: p.id, child: Text(p.label)))
                  .toList(),
              onChanged: (v) => notifier.setPersona(v),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Text(
                'Variation notes',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(width: 8),
              if (draft.userPromptText.isNotEmpty)
                _StatusPill(
                  label: draft.isUserPromptDirty ? 'modified' : 'from style',
                  color: draft.isUserPromptDirty
                      ? AppColors.danger
                      : AppColors.success,
                ),
              const Spacer(),
              if (draft.isUserPromptDirty)
                TextButton.icon(
                  onPressed: notifier.resetUserPromptToComposed,
                  icon: const Icon(Icons.restart_alt, size: 16),
                  label: const Text('Reset'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _userPromptController,
            onChanged: notifier.setUserPrompt,
            maxLines: 8,
            minLines: 5,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.cream,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              hintText:
                  'Pick a template and persona to auto-compose, or type your own variation notes.',
            ),
          ),
          const SizedBox(height: 22),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.text,
              foregroundColor: AppColors.surface,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _styledDropdown<T>({
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          isExpanded: true,
          icon:
              const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
          dropdownColor: AppColors.surface,
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final Widget child;
  final String? helper;
  const _Field({required this.label, required this.child, this.helper});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        child,
        if (helper != null && helper!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            helper!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
          ),
        ],
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}

// Used by the helper-text fallback when templates haven't loaded yet.
TryOnTemplate _placeholderTemplate() => const TryOnTemplate(
      id: '',
      slug: '',
      label: '',
      body: '',
      isActive: false,
    );

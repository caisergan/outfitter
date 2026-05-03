import 'package:flutter/material.dart';

import 'package:fashion_app/core/models/outfit_models.dart';
import 'package:fashion_app/core/theme/app_colors.dart';

class ParameterScreen extends StatefulWidget {
  final Function(AssistantParams) onFind;
  final String? initialAnchorItemId;

  const ParameterScreen({
    required this.onFind,
    this.initialAnchorItemId,
    super.key,
  });

  @override
  State<ParameterScreen> createState() => _ParameterScreenState();
}

class _ParameterScreenState extends State<ParameterScreen> {
  String? _occasion = 'casual';
  String? _season = 'spring';
  String? _colorPreference = 'neutral';
  String _source = 'mix';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STYLING BRIEF',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.textMuted,
                        letterSpacing: 1.2,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Start with the mood, not the clutter.',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontSize: 25,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pick the occasion, season, palette, and source. The stylist will turn that into a quieter, more polished outfit direction.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textMuted,
                      ),
                ),
                if (widget.initialAnchorItemId != null) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.push_pin_outlined,
                          color: AppColors.blush,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'A selected wardrobe item will stay in focus for these suggestions.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.text),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),
          _FilterSection(
            eyebrow: 'Occasion',
            title: "What's the setting?",
            child: _buildChipGroup(
              options: const [
                'casual',
                'work',
                'brunch',
                'date',
                'party',
                'beach',
                'travel',
                'gym',
              ],
              selected: _occasion,
              onSelected: (val) => setState(() => _occasion = val),
            ),
          ),
          const SizedBox(height: 24),
          _FilterSection(
            eyebrow: 'Season',
            title: 'What climate are we dressing for?',
            child: _buildChipGroup(
              options: const ['spring', 'summer', 'autumn', 'winter'],
              selected: _season,
              onSelected: (val) => setState(() => _season = val),
            ),
          ),
          const SizedBox(height: 24),
          _FilterSection(
            eyebrow: 'Palette',
            title: 'What color mood should lead?',
            child: _buildChipGroup(
              options: const [
                'neutral',
                'bold',
                'pastel',
                'monochrome',
                'earthy',
              ],
              selected: _colorPreference,
              onSelected: (val) => setState(() => _colorPreference = val),
            ),
          ),
          const SizedBox(height: 24),
          _FilterSection(
            eyebrow: 'Source',
            title: 'Where should the stylist pull from?',
            child: _buildChipGroup(
              options: const ['wardrobe', 'catalog', 'mix'],
              selected: _source,
              onSelected: (val) => setState(() => _source = val ?? 'mix'),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => widget.onFind(
              AssistantParams(
                occasion: _occasion,
                season: _season,
                colorPreference: _colorPreference,
                source: _source,
              ),
            ),
            child: const Text('Find Outfits'),
          ),
        ],
      ),
    );
  }

  Widget _buildChipGroup({
    required List<String> options,
    required String? selected,
    required Function(String?) onSelected,
  }) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((opt) {
        final isSelected = selected == opt;
        return ChoiceChip(
          label: Text(
            _titleCase(opt),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: isSelected ? AppColors.text : AppColors.text,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                ),
          ),
          selected: isSelected,
          onSelected: (val) => onSelected(val ? opt : null),
          side: BorderSide(
            color: isSelected
                ? AppColors.borderStrong
                : AppColors.borderStrong.withValues(alpha: 0.72),
          ),
          selectedColor: AppColors.surfaceAlt,
          backgroundColor: AppColors.glassStrong.withValues(alpha: 0.88),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }).toList(),
    );
  }

  String _titleCase(String value) {
    return value
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}

class _FilterSection extends StatelessWidget {
  final String eyebrow;
  final String title;
  final Widget child;

  const _FilterSection({
    required this.eyebrow,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textMuted,
                  letterSpacing: 1.0,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 21,
                ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

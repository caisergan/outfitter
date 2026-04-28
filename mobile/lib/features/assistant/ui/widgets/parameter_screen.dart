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
    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PERSONAL STYLING',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.secondaryText,
                        letterSpacing: 1.8,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Build a refined outfit brief.',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose the occasion, season, palette, and source. Recommendation logic stays exactly the same.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.secondaryText,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _ParameterSection(
            title: "What's the occasion?",
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
          const SizedBox(height: 16),
          _ParameterSection(
            title: 'Which season?',
            child: _buildChipGroup(
              options: const ['spring', 'summer', 'autumn', 'winter'],
              selected: _season,
              onSelected: (val) => setState(() => _season = val),
            ),
          ),
          const SizedBox(height: 16),
          _ParameterSection(
            title: 'Color preference?',
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
          const SizedBox(height: 16),
          _ParameterSection(
            title: 'Item source',
            child: _buildChipGroup(
              options: const ['wardrobe', 'catalog', 'mix'],
              selected: _source,
              onSelected: (val) => setState(() => _source = val ?? 'mix'),
            ),
          ),
          const SizedBox(height: 28),
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
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSelected = selected == opt;

        return ChoiceChip(
          label: Text(
            opt[0].toUpperCase() + opt.substring(1),
            style: TextStyle(
              color: isSelected ? AppColors.background : AppColors.text,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          selected: isSelected,
          onSelected: (val) => onSelected(val ? opt : null),
          backgroundColor: AppColors.paper,
          selectedColor: AppColors.primary,
          side: BorderSide(
            color: isSelected ? AppColors.primary : AppColors.divider,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          showCheckmark: false,
        );
      }).toList(),
    );
  }
}

class _ParameterSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _ParameterSection({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

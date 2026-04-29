import 'package:fashion_app/core/models/outfit_models.dart';
import 'package:fashion_app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI STYLIST',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.textMuted,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Refine the brief, then let the stylist assemble the look.',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontSize: 30,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Choose the occasion, season, palette, and source mix. The backend stays the same; this pass is purely UI.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            if (widget.initialAnchorItemId != null) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.lightMint,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.push_pin_outlined, color: AppColors.text),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Styling around a selected wardrobe item.',
                        style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.text,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 28),
            _FilterPanel(
              title: 'Occasion',
              subtitle: 'Tell the stylist where the look needs to land.',
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
            _FilterPanel(
              title: 'Season',
              subtitle: 'Keep proportions and layers aligned to the weather.',
              child: _buildChipGroup(
                options: const ['spring', 'summer', 'autumn', 'winter'],
                selected: _season,
                onSelected: (val) => setState(() => _season = val),
              ),
            ),
            const SizedBox(height: 16),
            _FilterPanel(
              title: 'Palette',
              subtitle: 'Bias the results toward your preferred color direction.',
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
            _FilterPanel(
              title: 'Source',
              subtitle: 'Blend personal pieces with the catalog or isolate one source.',
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
              child: const Text('Find outfits'),
            ),
          ],
        ),
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
          label: Text(opt[0].toUpperCase() + opt.substring(1)),
          selected: isSelected,
          onSelected: (val) => onSelected(val ? opt : null),
        );
      }).toList(),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _FilterPanel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

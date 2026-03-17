import 'package:flutter/material.dart';

import 'package:fashion_app/core/models/outfit_models.dart';

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
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader('What\'s the occasion?'),
          const SizedBox(height: 12),
          _buildChipGroup(
            options: ['casual', 'work', 'brunch', 'date', 'party', 'beach', 'travel', 'gym'],
            selected: _occasion,
            onSelected: (val) => setState(() => _occasion = val),
          ),
          const SizedBox(height: 32),
          _buildSectionHeader('Which season?'),
          const SizedBox(height: 12),
          _buildChipGroup(
            options: ['spring', 'summer', 'autumn', 'winter'],
            selected: _season,
            onSelected: (val) => setState(() => _season = val),
          ),
          const SizedBox(height: 32),
          _buildSectionHeader('Color preference?'),
          const SizedBox(height: 12),
          _buildChipGroup(
            options: ['neutral', 'bold', 'pastel', 'monochrome', 'earthy'],
            selected: _colorPreference,
            onSelected: (val) => setState(() => _colorPreference = val),
          ),
          const SizedBox(height: 32),
          _buildSectionHeader('Item source'),
          const SizedBox(height: 12),
          _buildChipGroup(
            options: ['wardrobe', 'catalog', 'mix'],
            selected: _source,
            onSelected: (val) => setState(() => _source = val ?? 'mix'),
          ),
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: () => widget.onFind(AssistantParams(
              occasion: _occasion,
              season: _season,
              colorPreference: _colorPreference,
              source: _source,
            )),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
            child: const Text('Find Outfits'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.3));
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

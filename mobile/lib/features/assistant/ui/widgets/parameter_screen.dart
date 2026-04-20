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
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionHeader("What's the occasion?"),
            const SizedBox(height: 12),
            _buildChipGroup(
              options: const [
                'casual',
                'work',
                'brunch',
                'date',
                'party',
                'beach',
                'travel',
                'gym'
              ],
              selected: _occasion,
              onSelected: (val) => setState(() => _occasion = val),
            ),
            const SizedBox(height: 32),
            _buildSectionHeader("Which season?"),
            const SizedBox(height: 12),
            _buildChipGroup(
              options: const ['spring', 'summer', 'autumn', 'winter'],
              selected: _season,
              onSelected: (val) => setState(() => _season = val),
            ),
            const SizedBox(height: 32),
            _buildSectionHeader("Color preference?"),
            const SizedBox(height: 12),
            _buildChipGroup(
              options: const [
                'neutral',
                'bold',
                'pastel',
                'monochrome',
                'earthy'
              ],
              selected: _colorPreference,
              onSelected: (val) => setState(() => _colorPreference = val),
            ),
            const SizedBox(height: 32),
            _buildSectionHeader("Item source"),
            const SizedBox(height: 12),
            _buildChipGroup(
              options: const ['wardrobe', 'catalog', 'mix'],
              selected: _source,
              onSelected: (val) => setState(() => _source = val ?? 'mix'),
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: () => widget.onFind(
                AssistantParams(
                  occasion: _occasion,
                  season: _season,
                  colorPreference: _colorPreference,
                  source: _source,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blush,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Find Outfits'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- HEADER ----------------

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.text,
        letterSpacing: -0.3,
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
              color: isSelected
                  ? AppColors.text
                  : AppColors.text.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          selected: isSelected,
          onSelected: (val) => onSelected(val ? opt : null),
          backgroundColor: AppColors.lightMint,
          selectedColor: AppColors.mint,
          side: BorderSide(
            color: isSelected ? AppColors.mint : AppColors.lightMint,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        );
      }).toList(),
    );
  }
}

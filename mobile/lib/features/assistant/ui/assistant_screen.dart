import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/assistant_provider.dart';
import '../../../core/models/outfit_models.dart';
import 'widgets/parameter_screen.dart';
import 'swipe_outfits_screen.dart';

class AssistantScreen extends ConsumerStatefulWidget {
  final String? anchorItemId;
  const AssistantScreen({this.anchorItemId, super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  bool _loading = false;

  Future<void> _handleFindOutfits(AssistantParams params) async {
    setState(() => _loading = true);

    await ref
        .read(assistantNotifierProvider.notifier)
        .suggest(params);

    final state = ref.read(assistantNotifierProvider);

    state.whenData((outfits) {
      if (mounted && outfits.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SwipeOutfitsScreen(outfits: outfits),
          ),
        );
      }
    });

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Stylist'),
      ),
      body: Stack(
        children: [
          ParameterScreen(
            onFind: _handleFindOutfits,
            initialAnchorItemId: widget.anchorItemId,
          ),

          if (_loading)
            ColoredBox(
              color: AppColors.overlay,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 24,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.paper,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: const CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/outfit_models.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_widgets.dart';
import '../providers/assistant_provider.dart';
import 'swipe_outfits_screen.dart';
import 'widgets/parameter_screen.dart';

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

    await ref.read(assistantNotifierProvider.notifier).suggest(params);

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
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        toolbarHeight: 76,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI Stylist',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              'Build a brief and let the app curate the outfit direction.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          ParameterScreen(
            onFind: _handleFindOutfits,
            initialAnchorItemId: widget.anchorItemId,
          ),
          if (_loading)
            ColoredBox(
              color: AppColors.glassOverlay,
              child: Center(
                child: FrostedGlass(
                  blur: 28,
                  borderRadius: BorderRadius.circular(28),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 22,
                  ),
                  child: SizedBox(
                    width: 180,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 14),
                        Text(
                          'Creating looks...',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

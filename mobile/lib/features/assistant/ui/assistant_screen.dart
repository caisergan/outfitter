import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/assistant_provider.dart';
import '../../../core/models/outfit_models.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/utils/error_helpers.dart';
import 'widgets/parameter_screen.dart';
import 'widgets/outfit_carousel.dart';

class AssistantScreen extends ConsumerStatefulWidget {
  final String? anchorItemId;
  const AssistantScreen({this.anchorItemId, super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  bool _showParams = true;

  void _handleFindOutfits(AssistantParams params) {
    ref.read(assistantNotifierProvider.notifier).suggest(params);
    setState(() => _showParams = false);
  }

  @override
  Widget build(BuildContext context) {
    final assistantState = ref.watch(assistantNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Stylist'),
        actions: [
          if (!_showParams)
            IconButton(
              icon: const Icon(Icons.tune),
              onPressed: () => setState(() => _showParams = true),
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _showParams
            ? ParameterScreen(
                onFind: _handleFindOutfits,
                initialAnchorItemId: widget.anchorItemId,
              )
            : assistantState.when(
                data: (outfits) => OutfitCarousel(
                  outfits: outfits,
                  onRefresh: () =>
                      ref.read(assistantNotifierProvider.notifier).refresh(),
                ),
                loading: () => const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 24),
                      Text('Curating your personal outfits...'),
                    ],
                  ),
                ),
                error: (e, __) => ErrorView(
                  message: dioErrorToMessage(e),
                  onRetry: () => setState(() => _showParams = true),
                ),
              ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/slot_builder_provider.dart';
import '../data/tryon_repository.dart';
import '../../../core/utils/error_helpers.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/shared_widgets.dart';
import 'widgets/playground_stack_panel.dart';
import 'widgets/tryon_result_view.dart';

class PlaygroundScreen extends ConsumerStatefulWidget {
  final Map<String, String>? prefilledSlots;
  const PlaygroundScreen({this.prefilledSlots, super.key});

  @override
  ConsumerState<PlaygroundScreen> createState() => _PlaygroundScreenState();
}

class _PlaygroundScreenState extends ConsumerState<PlaygroundScreen> {
  bool _isLoading = false;
  String? _generatedImageUrl;

  Future<void> _handleGenerate() async {
    final slots = ref.read(slotBuilderProvider);
    if (!slots.isValid) return;

    setState(() {
      _isLoading = true;
      _generatedImageUrl = null;
    });

    try {
      final imageUrl =
      await ref.read(tryonRepositoryProvider).submitAndWait(slots.slotIds);
      setState(() => _generatedImageUrl = imageUrl);
    } catch (e) {
      if (mounted) showErrorSnackbar(context, dioErrorToMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slots = ref.watch(slotBuilderProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      extendBodyBehindAppBar: true,

      body: LoadingOverlay(
        isVisible: _isLoading,
        message: 'Generating your try-on...',

        child: _generatedImageUrl != null
            ? TryOnResultView(
          imageUrl: _generatedImageUrl!,
          onEdit: () => setState(() => _generatedImageUrl = null),
        )
            : Stack(
          fit: StackFit.expand,
          children: [
            // Background image
            const CachedItemImage(
              url:
              'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?q=80&w=1000&auto=format&fit=crop',
            ),

            // Soft theme gradient overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AppColors.cream.withOpacity(0.2),
                      AppColors.text.withOpacity(0.25),
                    ],
                    stops: const [0.5, 0.8, 1.0],
                  ),
                ),
              ),
            ),

            // Stack panel
            const Positioned(
              right: 20,
              top: 140,
              bottom: 120,
              child: PlaygroundStackPanel(),
            ),

            // Bottom action bar
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.lightMint.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(
                    color: AppColors.lightMint,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        color: AppColors.cream,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.share_outlined,
                          color: AppColors.text,
                        ),
                        onPressed: () {},
                      ),
                    ),

                    const SizedBox(width: 8),

                    // GENERATE BUTTON
                    GestureDetector(
                      onTap: slots.isValid ? _handleGenerate : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 28,
                        ),
                        decoration: BoxDecoration(
                          color: slots.isValid
                              ? AppColors.blush
                              : AppColors.blush.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(40),
                          boxShadow: [
                            if (slots.isValid)
                              BoxShadow(
                                color: AppColors.blush.withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              color: Colors.white,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'GENERATE',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
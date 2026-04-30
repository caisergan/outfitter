import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '/core/theme/app_colors.dart';

class MainScaffold extends StatelessWidget {
  final Widget child;
  const MainScaffold({required this.child, super.key});

  static const _tabs = ['/discover', '/tryon', '/assistant', '/wardrobe'];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _tabs.indexWhere((t) => location.startsWith(t));
    final showBottomNav = currentIndex >= 0;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: child,
      bottomNavigationBar: showBottomNav
          ? ColoredBox(
              color: AppColors.cream,
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(12, 4, 12, 14),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: NavigationBar(
                      backgroundColor: Colors.transparent,
                      indicatorColor: AppColors.surfaceAlt,
                      labelBehavior:
                          NavigationDestinationLabelBehavior.alwaysShow,
                      selectedIndex: currentIndex,
                      onDestinationSelected: (i) => context.go(_tabs[i]),
                      destinations: const [
                        NavigationDestination(
                          icon: Icon(Icons.explore_outlined),
                          selectedIcon: Icon(Icons.explore),
                          label: 'Discover',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.checkroom_outlined),
                          selectedIcon: Icon(Icons.checkroom),
                          label: 'Studio',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.auto_awesome_outlined),
                          selectedIcon: Icon(Icons.auto_awesome),
                          label: 'Stylist',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.door_sliding_outlined),
                          selectedIcon: Icon(Icons.door_sliding),
                          label: 'Wardrobe',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

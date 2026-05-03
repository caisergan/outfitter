import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '/core/theme/app_colors.dart';
import 'glass_widgets.dart';

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
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF7FAFF),
              Color(0xFFE6EDF5),
              Color(0xFFDCE4EF),
            ],
            stops: [0, 0.52, 1],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -80,
              left: -30,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.38),
                ),
              ),
            ),
            Positioned(
              top: 120,
              right: -50,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface.withValues(alpha: 0.5),
                ),
              ),
            ),
            Positioned(
              bottom: 120,
              left: -40,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.16),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
      bottomNavigationBar: showBottomNav
          ? ColoredBox(
              color: Colors.transparent,
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(14, 6, 14, 16),
                child: FrostedGlass(
                  blur: 30,
                  backgroundColor: AppColors.glassUltra.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.shadowSoft,
                      blurRadius: 18,
                      offset: Offset(0, 6),
                    ),
                    BoxShadow(
                      color: AppColors.shadowStrong,
                      blurRadius: 40,
                      offset: Offset(0, 16),
                    ),
                  ],
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: NavigationBar(
                      backgroundColor: Colors.transparent,
                      indicatorColor: AppColors.glassStrong,
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

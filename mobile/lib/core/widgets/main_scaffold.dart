import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '/core/theme/app_colors.dart';

class MainScaffold extends StatelessWidget {
  final Widget child;
  const MainScaffold({required this.child, super.key});

  static const _tabs = ['/discover', '/playground', '/assistant', '/wardrobe'];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _tabs.indexWhere((t) => location.startsWith(t));

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: child,
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.divider),
          ),
          child: NavigationBar(
            backgroundColor: Colors.transparent,
            selectedIndex: currentIndex < 0 ? 0 : currentIndex,
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
                label: 'Playground',
              ),
              NavigationDestination(
                icon: Icon(Icons.auto_awesome_outlined),
                selectedIcon: Icon(Icons.auto_awesome),
                label: 'Assistant',
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
    );
  }
}

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

      bottomNavigationBar: NavigationBar(
        backgroundColor: AppColors.cream,

        indicatorColor: AppColors.mint,

        labelTextStyle: MaterialStateProperty.all(
          const TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.w500,
          ),
        ),

        selectedIndex: currentIndex < 0 ? 0 : currentIndex,

        onDestinationSelected: (i) => context.go(_tabs[i]),

        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined, color: AppColors.text),
            selectedIcon: Icon(Icons.explore, color: AppColors.text),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Icon(Icons.checkroom_outlined, color: AppColors.text),
            selectedIcon: Icon(Icons.checkroom, color: AppColors.text),
            label: 'Playground',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined, color: AppColors.text),
            selectedIcon: Icon(Icons.auto_awesome, color: AppColors.text),
            label: 'Assistant',
          ),
          NavigationDestination(
            icon: Icon(Icons.door_sliding_outlined, color: AppColors.text),
            selectedIcon: Icon(Icons.door_sliding, color: AppColors.text),
            label: 'Wardrobe',
          ),
        ],
      ),
    );
  }
}

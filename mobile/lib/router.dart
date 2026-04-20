import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/auth/auth_provider.dart';
import 'features/auth/ui/login_screen.dart';
import 'features/auth/ui/signup_screen.dart';
import 'features/discover/ui/discover_screen.dart';
import 'features/playground/ui/playground_screen.dart';
import 'features/assistant/ui/assistant_screen.dart';
import 'features/profile/ui/profile_screen.dart';
import 'features/wardrobe/ui/wardrobe_screen.dart';
import 'features/wardrobe/ui/wardrobe_item_detail_screen.dart';
import 'core/widgets/main_scaffold.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authNotifierProvider);

  return GoRouter(
    initialLocation: '/discover',
    redirect: (context, state) {
      final isLoading = authState == AuthStatus.loading;
      final isAuthenticated = authState == AuthStatus.authenticated;
      final isAuthRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup';

      if (isLoading) return null;
      if (!isAuthenticated && !isAuthRoute) return '/login';
      if (isAuthenticated && isAuthRoute) return '/discover';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (_, __) => const SignupScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(
            path: '/discover',
            builder: (_, __) => const DiscoverScreen(),
            routes: [
              GoRoute(
                path: 'profile',
                builder: (_, __) => const ProfileScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/playground',
            builder: (_, state) {
              final extra = state.extra as Map<String, dynamic>?;
              final slots = (extra?['slots'] as Map?)
                  ?.map((k, v) => MapEntry(k.toString(), v.toString()));
              return PlaygroundScreen(prefilledSlots: slots);
            },
          ),
          GoRoute(
            path: '/assistant',
            builder: (_, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return AssistantScreen(anchorItemId: extra?['anchorItemId'] as String?);
            },
          ),
          GoRoute(
            path: '/wardrobe',
            builder: (_, __) => const WardrobeScreen(),
            routes: [
              GoRoute(
                path: 'item/:id',
                builder: (_, state) => WardrobeItemDetailScreen(
                  itemId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

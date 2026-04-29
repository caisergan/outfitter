import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fashion_app/core/auth/auth_provider.dart';
import 'package:fashion_app/core/models/outfit_models.dart';
import 'package:fashion_app/core/theme/app_colors.dart';
import 'package:fashion_app/core/utils/error_helpers.dart';
import 'package:fashion_app/core/widgets/error_view.dart';
import 'package:fashion_app/features/assistant/providers/assistant_provider.dart';
import 'package:fashion_app/features/profile/data/profile_repository.dart';
import 'package:fashion_app/features/profile/providers/profile_provider.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_outfit_section.dart';
import 'widgets/profile_preferences_section.dart';
import 'widgets/profile_settings_section.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.text),
          onPressed: () => context.go('/discover'),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PROFILE',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textMuted,
                    letterSpacing: 2,
                  ),
            ),
            Text(
              'Profile',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      body: profileState.when(
        data: (state) => RefreshIndicator(
          color: AppColors.blush,
          onRefresh: () => ref.read(profileNotifierProvider.notifier).load(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              ProfileHeader(
                user: state.user,
                onEdit: () => _showEditProfileSheet(context, ref, state.user),
                onSettings: () => _showSettingsSheet(context, ref, state),
              ),
              const SizedBox(height: 16),
              _ProfileStatsRow(state: state),
              const SizedBox(height: 28),
              ProfileOutfitSection(
                title: 'Saved Outfits',
                emptyTitle: 'No saved outfits yet',
                emptyMessage: 'Generate or save a look to build your lookbook.',
                emptyIcon: Icons.bookmark_border_outlined,
                outfits: state.savedOutfits,
                likedOutfitIds: state.likedOutfitIds,
                onTap: (outfit) => _openOutfit(context, ref, outfit),
                onToggleLike: (id) => ref
                    .read(profileNotifierProvider.notifier)
                    .toggleLikedOutfit(id),
              ),
              const SizedBox(height: 28),
              ProfileOutfitSection(
                title: 'Liked Outfits',
                emptyTitle: 'No liked outfits',
                emptyMessage:
                    'Tap the heart on saved looks to collect favorites.',
                emptyIcon: Icons.favorite_border_outlined,
                outfits: state.likedOutfits,
                likedOutfitIds: state.likedOutfitIds,
                onTap: (outfit) => _openOutfit(context, ref, outfit),
                onToggleLike: (id) => ref
                    .read(profileNotifierProvider.notifier)
                    .toggleLikedOutfit(id),
              ),
              const SizedBox(height: 28),
              ProfileOutfitSection(
                title: 'Recently Viewed',
                emptyTitle: 'Nothing viewed yet',
                emptyMessage: 'Open a saved outfit and it will appear here.',
                emptyIcon: Icons.history,
                outfits: state.recentlyViewedOutfits,
                likedOutfitIds: state.likedOutfitIds,
                onTap: (outfit) => _openOutfit(context, ref, outfit),
                onToggleLike: (id) => ref
                    .read(profileNotifierProvider.notifier)
                    .toggleLikedOutfit(id),
              ),
              const SizedBox(height: 28),
              ProfilePreferencesSection(
                preferences: state.stylePreferences,
                onEdit: () => _showStylePreferencesSheet(
                  context,
                  ref,
                  state.stylePreferences,
                ),
              ),
              const SizedBox(height: 16),
              ProfileSettingsSection(
                settings: state.settings,
                onChanged: (settings) => ref
                    .read(profileNotifierProvider.notifier)
                    .updateSettings(settings),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _logout(context, ref),
                icon: const Icon(Icons.logout),
                label: const Text('Log Out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.text,
                  backgroundColor: AppColors.backgroundElevated,
                  side: const BorderSide(color: AppColors.lineStrong),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.blush),
        ),
        error: (error, _) => ErrorView(
          message: dioErrorToMessage(error),
          onRetry: () => ref.read(profileNotifierProvider.notifier).load(),
        ),
      ),
    );
  }

  Future<void> _openOutfit(
    BuildContext context,
    WidgetRef ref,
    SavedOutfit outfit,
  ) async {
    await ref
        .read(profileNotifierProvider.notifier)
        .markRecentlyViewed(outfit.id);
    if (!context.mounted) return;
    context.go('/playground', extra: {'slots': outfit.slots});
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    await ref.read(authNotifierProvider.notifier).logout();
    ref.invalidate(profileNotifierProvider);
    ref.invalidate(savedOutfitsProvider);
    if (context.mounted) context.go('/login');
  }

  void _showEditProfileSheet(
    BuildContext context,
    WidgetRef ref,
    ProfileUser user,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.cream,
      builder: (context) => _EditProfileSheet(
        user: user,
        onSave: (username, bio, photoUrl) async {
          await ref.read(profileNotifierProvider.notifier).updateProfile(
                username: username,
                bio: bio,
                photoUrl: photoUrl,
              );
        },
      ),
    );
  }

  void _showStylePreferencesSheet(
    BuildContext context,
    WidgetRef ref,
    StylePreferences preferences,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.cream,
      builder: (context) => _StylePreferencesSheet(
        preferences: preferences,
        onSave: (nextPreferences) async {
          await ref
              .read(profileNotifierProvider.notifier)
              .updateStylePreferences(nextPreferences);
        },
      ),
    );
  }

  void _showSettingsSheet(
    BuildContext context,
    WidgetRef ref,
    ProfileState state,
  ) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: AppColors.cream,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final settings =
              ref.watch(profileNotifierProvider).valueOrNull?.settings ??
                  state.settings;

          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: ProfileSettingsSection(
              settings: settings,
              onChanged: (settings) => ref
                  .read(profileNotifierProvider.notifier)
                  .updateSettings(settings),
            ),
          );
        },
      ),
    );
  }
}

class _ProfileStatsRow extends StatelessWidget {
  final ProfileState state;

  const _ProfileStatsRow({required this.state});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ProfileStatTile(
            label: 'Saved',
            value: state.savedOutfits.length.toString(),
            icon: Icons.bookmark_border_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ProfileStatTile(
            label: 'Liked',
            value: state.likedOutfits.length.toString(),
            icon: Icons.favorite_border_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ProfileStatTile(
            label: 'Viewed',
            value: state.recentlyViewedOutfits.length.toString(),
            icon: Icons.history,
          ),
        ),
      ],
    );
  }
}

class _ProfileStatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ProfileStatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.textMuted, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: AppColors.text.withValues(alpha: 0.68),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  final ProfileUser user;
  final Future<void> Function(String username, String bio, String? photoUrl)
      onSave;

  const _EditProfileSheet({
    required this.user,
    required this.onSave,
  });

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _usernameController;
  late final TextEditingController _bioController;
  late final TextEditingController _photoUrlController;
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.user.displayName);
    _bioController = TextEditingController(text: widget.user.bio);
    _photoUrlController = TextEditingController(text: widget.user.photoUrl);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    _photoUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Edit Profile',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.text,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _usernameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Username',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter a username';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bioController,
              minLines: 2,
              maxLines: 4,
              maxLength: 160,
              decoration: const InputDecoration(
                labelText: 'Bio',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _photoUrlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Profile photo URL',
                prefixIcon: Icon(Icons.image_outlined),
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blush,
                foregroundColor: Colors.white,
              ),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(
        _usernameController.text,
        _bioController.text,
        _photoUrlController.text,
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) showErrorSnackbar(context, dioErrorToMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _StylePreferencesSheet extends StatefulWidget {
  final StylePreferences preferences;
  final Future<void> Function(StylePreferences preferences) onSave;

  const _StylePreferencesSheet({
    required this.preferences,
    required this.onSave,
  });

  @override
  State<_StylePreferencesSheet> createState() => _StylePreferencesSheetState();
}

class _StylePreferencesSheetState extends State<_StylePreferencesSheet> {
  static const _occasions = [
    'Work Wear',
    'Brunch Date',
    'Night Out',
    'Travel',
    'Gym Ready',
  ];
  static const _seasons = ['Spring', 'Summer', 'Autumn', 'Winter'];
  static const _colors = ['Neutral', 'Bold', 'Pastel', 'Monochrome', 'Earthy'];

  late Set<String> _occasionsSelected;
  late Set<String> _seasonsSelected;
  late Set<String> _colorsSelected;
  late String _sourcePreference;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _occasionsSelected = {...widget.preferences.occasions};
    _seasonsSelected = {...widget.preferences.seasons};
    _colorsSelected = {...widget.preferences.colorPalettes};
    _sourcePreference = widget.preferences.sourcePreference;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Style Preferences',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.text,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
            ),
            const SizedBox(height: 18),
            _PreferenceChoiceGroup(
              title: 'Outfit source',
              children: [
                ChoiceChip(
                  label: const Text('Mix Both'),
                  selected: _sourcePreference == 'mix',
                  onSelected: (_) => setState(() => _sourcePreference = 'mix'),
                ),
                ChoiceChip(
                  label: const Text('My Wardrobe'),
                  selected: _sourcePreference == 'wardrobe',
                  onSelected: (_) =>
                      setState(() => _sourcePreference = 'wardrobe'),
                ),
                ChoiceChip(
                  label: const Text('Shop Catalog'),
                  selected: _sourcePreference == 'catalog',
                  onSelected: (_) =>
                      setState(() => _sourcePreference = 'catalog'),
                ),
              ],
            ),
            _PreferenceChoiceGroup(
              title: 'Occasions',
              children: _occasions
                  .map(
                    (option) => FilterChip(
                      label: Text(option),
                      selected: _occasionsSelected.contains(option),
                      onSelected: (selected) => setState(
                        () => _toggle(_occasionsSelected, option, selected),
                      ),
                    ),
                  )
                  .toList(),
            ),
            _PreferenceChoiceGroup(
              title: 'Seasons',
              children: _seasons
                  .map(
                    (option) => FilterChip(
                      label: Text(option),
                      selected: _seasonsSelected.contains(option),
                      onSelected: (selected) => setState(
                        () => _toggle(_seasonsSelected, option, selected),
                      ),
                    ),
                  )
                  .toList(),
            ),
            _PreferenceChoiceGroup(
              title: 'Color palettes',
              children: _colors
                  .map(
                    (option) => FilterChip(
                      label: Text(option),
                      selected: _colorsSelected.contains(option),
                      onSelected: (selected) => setState(
                        () => _toggle(_colorsSelected, option, selected),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blush,
                foregroundColor: Colors.white,
              ),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Save Preferences'),
            ),
          ],
        ),
      ),
    );
  }

  void _toggle(Set<String> values, String option, bool selected) {
    if (selected) {
      values.add(option);
    } else {
      values.remove(option);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.onSave(
        StylePreferences(
          occasions: _occasionsSelected,
          seasons: _seasonsSelected,
          colorPalettes: _colorsSelected,
          sourcePreference: _sourcePreference,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) showErrorSnackbar(context, dioErrorToMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _PreferenceChoiceGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _PreferenceChoiceGroup({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: children,
          ),
        ],
      ),
    );
  }
}

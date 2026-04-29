import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  static ThemeData light() {
    const colorScheme = ColorScheme.light(
      primary: AppColors.blush,
      onPrimary: AppColors.surface,
      secondary: AppColors.mint,
      onSecondary: AppColors.surface,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      error: AppColors.danger,
      onError: AppColors.surface,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      splashFactory: InkRipple.splashFactory,
    );

    final textTheme = base.textTheme.copyWith(
      displayLarge: base.textTheme.displayLarge?.copyWith(
        color: AppColors.text,
        fontSize: 54,
        height: 0.96,
        fontWeight: FontWeight.w700,
        letterSpacing: -2.4,
      ),
      displaySmall: base.textTheme.displaySmall?.copyWith(
        color: AppColors.text,
        fontSize: 40,
        height: 1.02,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.8,
      ),
      headlineLarge: base.textTheme.headlineLarge?.copyWith(
        color: AppColors.text,
        fontSize: 34,
        height: 1.04,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.2,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        color: AppColors.text,
        fontSize: 30,
        height: 1.08,
        fontWeight: FontWeight.w700,
        letterSpacing: -1,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        color: AppColors.text,
        fontSize: 24,
        height: 1.08,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.7,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        color: AppColors.text,
        fontSize: 20,
        height: 1.15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        color: AppColors.text,
        fontSize: 16,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
      ),
      titleSmall: base.textTheme.titleSmall?.copyWith(
        color: AppColors.text,
        fontSize: 13,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(
        color: AppColors.text,
        fontSize: 15,
        height: 1.45,
        fontWeight: FontWeight.w500,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        color: AppColors.text,
        fontSize: 14,
        height: 1.45,
        fontWeight: FontWeight.w500,
      ),
      bodySmall: base.textTheme.bodySmall?.copyWith(
        color: AppColors.textMuted,
        fontSize: 12,
        height: 1.4,
        fontWeight: FontWeight.w500,
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        color: AppColors.text,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
      ),
      labelMedium: base.textTheme.labelMedium?.copyWith(
        color: AppColors.textMuted,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
      labelSmall: base.textTheme.labelSmall?.copyWith(
        color: AppColors.textSoft,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
      ),
    );

    return base.copyWith(
      textTheme: textTheme,
      dividerColor: AppColors.line,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      canvasColor: AppColors.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 24,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        iconTheme: const IconThemeData(color: AppColors.text),
        actionsIconTheme: const IconThemeData(color: AppColors.text),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.text,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.surface,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.blush,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.backgroundElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 78,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        indicatorColor: AppColors.lightMint,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.text, size: 22);
          }
          return const IconThemeData(color: AppColors.textMuted, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelMedium!.copyWith(
            color: selected ? AppColors.text : AppColors.textMuted,
            letterSpacing: 0.3,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.backgroundElevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: AppColors.textSoft),
        labelStyle: textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
        prefixIconColor: AppColors.textMuted,
        suffixIconColor: AppColors.textMuted,
        border: _inputBorder(AppColors.line),
        enabledBorder: _inputBorder(AppColors.line),
        focusedBorder: _inputBorder(AppColors.lineStrong),
        errorBorder: _inputBorder(AppColors.danger),
        focusedErrorBorder: _inputBorder(AppColors.danger),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightMint,
        selectedColor: AppColors.blush,
        disabledColor: AppColors.lightMint.withValues(alpha: 0.5),
        secondarySelectedColor: AppColors.blush,
        surfaceTintColor: Colors.transparent,
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        labelStyle: textTheme.bodySmall!.copyWith(
          color: AppColors.text,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: textTheme.bodySmall!.copyWith(
          color: AppColors.surface,
          fontWeight: FontWeight.w700,
        ),
        showCheckmark: false,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        space: 1,
        thickness: 1,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        iconColor: AppColors.textMuted,
        titleTextStyle: textTheme.bodyLarge?.copyWith(
          color: AppColors.text,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: textTheme.bodySmall,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.text,
        unselectedLabelColor: AppColors.textMuted,
        indicatorColor: AppColors.blush,
        dividerColor: Colors.transparent,
        labelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: textTheme.labelLarge,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.surface;
          }
          return AppColors.surface;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.blush;
          }
          return AppColors.lineStrong;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.blush,
          foregroundColor: AppColors.surface,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size.fromHeight(56),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.blush,
          foregroundColor: AppColors.surface,
          elevation: 0,
          minimumSize: const Size.fromHeight(56),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          side: const BorderSide(color: AppColors.lineStrong),
          minimumSize: const Size.fromHeight(54),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.blush,
        foregroundColor: AppColors.surface,
        elevation: 0,
        highlightElevation: 0,
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide(color: color, width: 1.1),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'app_colors.dart';

class AppTheme {
  static ThemeData build() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.blush,
      brightness: Brightness.light,
      primary: AppColors.blush,
      onPrimary: AppColors.surface,
      secondary: AppColors.mint,
      onSecondary: AppColors.text,
      surface: AppColors.surface,
      onSurface: AppColors.text,
    ).copyWith(
      surfaceContainerHighest: AppColors.surfaceAlt,
      outline: AppColors.border,
      outlineVariant: AppColors.surfaceMuted,
      shadow: AppColors.shadow,
      scrim: AppColors.glassOverlay,
      error: AppColors.danger,
      onError: Colors.white,
    );

    final baseTextTheme = Typography.blackCupertino;

    TextStyle displayStyle(TextStyle? style, {double? size}) {
      return (style ?? const TextStyle()).copyWith(
        fontSize: size,
        color: AppColors.text,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.9,
        height: 1.0,
      );
    }

    TextStyle bodyStyle(TextStyle? style) {
      return (style ?? const TextStyle()).copyWith(
        color: AppColors.text,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.15,
        height: 1.35,
      );
    }

    final textTheme = baseTextTheme.copyWith(
      displayLarge: displayStyle(baseTextTheme.displayLarge, size: 52),
      displayMedium: displayStyle(baseTextTheme.displayMedium, size: 42),
      displaySmall: displayStyle(baseTextTheme.displaySmall, size: 34),
      headlineLarge: displayStyle(baseTextTheme.headlineLarge, size: 30),
      headlineMedium: displayStyle(baseTextTheme.headlineMedium, size: 26),
      headlineSmall: displayStyle(baseTextTheme.headlineSmall, size: 22),
      titleLarge: displayStyle(baseTextTheme.titleLarge, size: 20),
      titleMedium: bodyStyle(baseTextTheme.titleMedium).copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.35,
      ),
      titleSmall: bodyStyle(baseTextTheme.titleSmall).copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
      ),
      bodyLarge: bodyStyle(baseTextTheme.bodyLarge).copyWith(fontSize: 16),
      bodyMedium: bodyStyle(baseTextTheme.bodyMedium).copyWith(fontSize: 14),
      bodySmall: bodyStyle(baseTextTheme.bodySmall).copyWith(
        fontSize: 12,
        color: AppColors.textMuted,
      ),
      labelLarge: bodyStyle(baseTextTheme.labelLarge).copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
      ),
      labelMedium: bodyStyle(baseTextTheme.labelMedium).copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    );

    OutlineInputBorder inputBorder(Color color) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: color),
      );
    }

    RoundedRectangleBorder largeShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      cupertinoOverrideTheme: const CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: AppColors.blush,
        scaffoldBackgroundColor: AppColors.cream,
      ),
      scaffoldBackgroundColor: AppColors.cream,
      canvasColor: AppColors.surface,
      textTheme: textTheme,
      splashColor: AppColors.blush.withValues(alpha: 0.06),
      highlightColor: Colors.transparent,
      dividerColor: AppColors.border,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.headlineSmall?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(
          color: AppColors.text,
          size: 22,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        height: 72,
        indicatorColor: AppColors.glassStrong,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return textTheme.labelMedium?.copyWith(
            color: isSelected ? AppColors.text : AppColors.textMuted,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            letterSpacing: 0.45,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: isSelected ? AppColors.text : AppColors.textMuted,
            size: 22,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.glassStrong.withValues(alpha: 0.72),
        hintStyle: textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
        labelStyle: textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
        prefixIconColor: AppColors.textMuted,
        suffixIconColor: AppColors.textMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: inputBorder(AppColors.border),
        enabledBorder: inputBorder(AppColors.border),
        focusedBorder: inputBorder(AppColors.borderStrong),
        errorBorder: inputBorder(AppColors.danger),
        focusedErrorBorder: inputBorder(AppColors.danger),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.glass.withValues(alpha: 0.75),
        selectedColor: AppColors.glassStrong,
        secondarySelectedColor: AppColors.glassStrong,
        disabledColor: AppColors.surfaceMuted,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: AppColors.text,
          fontWeight: FontWeight.w700,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        showCheckmark: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.blush,
          foregroundColor: AppColors.surface,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.textMuted,
          minimumSize: const Size.fromHeight(54),
          shape: largeShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.blush,
          foregroundColor: AppColors.surface,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.textMuted,
          minimumSize: const Size.fromHeight(54),
          shape: largeShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          backgroundColor: AppColors.glass.withValues(alpha: 0.58),
          side: const BorderSide(color: AppColors.border),
          minimumSize: const Size.fromHeight(52),
          shape: largeShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.blush,
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.text,
          backgroundColor: AppColors.glassStrong.withValues(alpha: 0.65),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.glassStrong,
        foregroundColor: AppColors.text,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(22)),
        ),
        extendedTextStyle: textTheme.labelLarge,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: AppColors.borderStrong,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.glass,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.textMuted,
        textColor: AppColors.text,
        tileColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.glassStrong,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.text.withValues(alpha: 0.94),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.surface,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.blush,
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        labelColor: AppColors.text,
        unselectedLabelColor: AppColors.textMuted,
        labelStyle: textTheme.labelMedium,
        unselectedLabelStyle: textTheme.labelMedium?.copyWith(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w600,
        ),
        indicator: BoxDecoration(
          color: AppColors.glassStrong,
          borderRadius: BorderRadius.circular(999),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        splashFactory: NoSplash.splashFactory,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.glassStrong;
          }
          return AppColors.surface;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.blush;
          }
          return AppColors.surfaceMuted;
        }),
        trackOutlineColor: WidgetStateProperty.all(AppColors.border),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
    );
  }
}

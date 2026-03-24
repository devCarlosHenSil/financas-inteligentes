import 'package:flutter/material.dart';

class AppTheme {
  // Paleta "caderno financeiro": papel, tinta e destaque esmeralda.
  static const Color _paper = Color(0xFFF7F3EA);
  static const Color _ink = Color(0xFF1F2937);
  static const Color _graphite = Color(0xFF5F6B7A);
  static const Color _mint = Color(0xFF177E6B);
  static const Color _clay = Color(0xFFDDE6DD);
  static const Color _charcoal = Color(0xFF111827);

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      brightness: Brightness.light,
      seedColor: _mint,
      surface: _paper,
    ).copyWith(
      primary: _mint,
      onPrimary: Colors.white,
      primaryContainer: _clay,
      onPrimaryContainer: _ink,
      secondary: const Color(0xFF355D4D),
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFE3EADF),
      onSecondaryContainer: _ink,
      tertiary: const Color(0xFF89644F),
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFFF2E3D9),
      onTertiaryContainer: const Color(0xFF362117),
      onSurface: _ink,
      onSurfaceVariant: _graphite,
      error: const Color(0xFFAF2E1B),
      onError: Colors.white,
      errorContainer: const Color(0xFFF8DED9),
      onErrorContainer: const Color(0xFF3D0F09),
      outline: const Color(0xFFB8C3B5),
      outlineVariant: const Color(0xFFD0D8CC),
      inverseSurface: _charcoal,
      onInverseSurface: const Color(0xFFF6F5EF),
      inversePrimary: const Color(0xFF80D6C0),
      shadow: const Color(0x1A2D332C),
      scrim: const Color(0x660A0D0A),
    );
    final textTheme = Typography.material2021().black.apply(
          bodyColor: _ink,
          displayColor: _ink,
        );

    return _baseTheme(colorScheme, textTheme);
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      brightness: Brightness.dark,
      seedColor: _mint,
      surface: const Color(0xFF121613),
    ).copyWith(
      primary: const Color(0xFF69C9B1),
      onPrimary: const Color(0xFF00382D),
      primaryContainer: const Color(0xFF0F4438),
      onPrimaryContainer: const Color(0xFFB8F2E3),
      secondary: const Color(0xFF9ECBB7),
      onSecondary: const Color(0xFF093124),
      secondaryContainer: const Color(0xFF284338),
      onSecondaryContainer: const Color(0xFFC0E9D6),
      tertiary: const Color(0xFFE2C4B2),
      onTertiary: const Color(0xFF442A1C),
      tertiaryContainer: const Color(0xFF5D3F2F),
      onTertiaryContainer: const Color(0xFFFFDCC8),
      onSurface: const Color(0xFFE8ECE5),
      onSurfaceVariant: const Color(0xFFAFBCB1),
      error: const Color(0xFFFFB4A7),
      onError: const Color(0xFF670E00),
      errorContainer: const Color(0xFF8C1D10),
      onErrorContainer: const Color(0xFFFFDAD2),
      outline: const Color(0xFF5E6E64),
      outlineVariant: const Color(0xFF3A4740),
      inverseSurface: const Color(0xFFE8ECE5),
      onInverseSurface: const Color(0xFF1A201C),
      inversePrimary: const Color(0xFF006B58),
      shadow: Colors.black,
      scrim: Colors.black54,
    );
    final textTheme = Typography.material2021().white.apply(
          bodyColor: colorScheme.onSurface,
          displayColor: colorScheme.onSurface,
        );

    return _baseTheme(colorScheme, textTheme);
  }

  static ThemeData _baseTheme(ColorScheme colorScheme, TextTheme textTheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: colorScheme.outline),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          side: WidgetStateProperty.all(
            BorderSide(color: colorScheme.outlineVariant),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? colorScheme.surfaceContainerHighest
                : colorScheme.surfaceContainerLow,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? colorScheme.onSurface
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: colorScheme.outlineVariant),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        backgroundColor: colorScheme.surfaceContainerLow,
        selectedColor: colorScheme.secondaryContainer,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        iconColor: colorScheme.onSurfaceVariant,
        textColor: colorScheme.onSurface,
        tileColor: colorScheme.surface,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onInverseSurface,
        ),
        actionTextColor: colorScheme.inversePrimary,
      ),
      tooltipTheme: TooltipThemeData(
        textStyle: textTheme.bodySmall?.copyWith(
          color: colorScheme.onInverseSurface,
        ),
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

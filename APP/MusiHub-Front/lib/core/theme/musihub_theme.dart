import 'package:flutter/material.dart';

class MusiHubColors {
  const MusiHubColors._();

  static const primary = Color(0xFF737DFF);
  static const textGrey = Color(0xFF6B6B6B);
  static const fieldGrey = Color(0xFFF2F2F2);
  static const borderGrey = Color(0xFFE4E4E4);
}

class MusiHubTheme {
  const MusiHubTheme._();

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: MusiHubColors.primary,
      primary: MusiHubColors.primary,
      surface: Colors.white,
    );
    final baseTheme = ThemeData(useMaterial3: true, colorScheme: colorScheme);

    return baseTheme.copyWith(
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 65,
        titleTextStyle: TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      textTheme: baseTheme.textTheme.copyWith(
        headlineLarge: const TextStyle(
          color: Colors.black,
          fontSize: 32,
          fontWeight: FontWeight.w900,
        ),
        titleLarge: const TextStyle(
          color: Colors.black,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: const TextStyle(
          color: Colors.black,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: const TextStyle(
          color: Colors.black,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: const TextStyle(color: Colors.black, fontSize: 14),
        bodySmall: const TextStyle(color: MusiHubColors.textGrey, fontSize: 12),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MusiHubColors.fieldGrey,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: MusiHubColors.primary),
        ),
        labelStyle: const TextStyle(color: MusiHubColors.textGrey),
        hintStyle: const TextStyle(color: MusiHubColors.textGrey),
        helperStyle: const TextStyle(color: MusiHubColors.textGrey),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(51),
          backgroundColor: MusiHubColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          foregroundColor: MusiHubColors.primary,
          side: const BorderSide(color: MusiHubColors.borderGrey),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: baseTheme.chipTheme.copyWith(
        backgroundColor: MusiHubColors.fieldGrey,
        selectedColor: MusiHubColors.primary,
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(
          color: WidgetStateColor.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return MusiHubColors.textGrey;
            }

            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }

            return Colors.black;
          }),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        side: WidgetStateBorderSide.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const BorderSide(color: MusiHubColors.primary, width: 1.2);
          }

          return const BorderSide(color: MusiHubColors.borderGrey);
        }),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

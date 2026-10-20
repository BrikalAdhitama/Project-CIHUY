import 'package:flutter/material.dart';

abstract final class CihuyColors {
  static const teal = Color(0xFF31C5C2);
  static const tealInk = Color(0xFF008D8A);
  static const ink = Color(0xFF172333);
  static const muted = Color(0xFF75849A);
  static const border = Color(0xFFE3E6EB);
  static const surface = Color(0xFFF7F8FA);
  static const paleTeal = Color(0xFFE1F9F9);
  static const green = Color(0xFFCAF9E3);
  static const greenInk = Color(0xFF007B5E);
  static const success = Color(0xFF00BB86);
  static const pink = Color(0xFFFFE1E4);
  static const red = Color(0xFFE32636);
  static const amber = Color(0xFFFFF2D6);
  static const amberInk = Color(0xFF9A6A00);
}

ThemeData cihuyTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: CihuyColors.teal,
    primary: CihuyColors.tealInk,
    surface: Colors.white,
  );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: CihuyColors.border),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.white,
    fontFamily: 'Roboto',
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: CihuyColors.ink,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: CihuyColors.ink,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: CihuyColors.ink,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: CihuyColors.ink,
      ),
      bodyLarge: TextStyle(fontSize: 14, color: CihuyColors.ink, height: 1.5),
      bodyMedium: TextStyle(fontSize: 13, color: CihuyColors.ink, height: 1.45),
      bodySmall: TextStyle(fontSize: 12, color: CihuyColors.muted, height: 1.4),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: CihuyColors.ink,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFF0F1F4),
      space: 1,
      thickness: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: CihuyColors.teal, width: 1.5),
      ),
      errorBorder: border.copyWith(
        borderSide: const BorderSide(color: CihuyColors.red),
      ),
      hintStyle: const TextStyle(fontSize: 13, color: CihuyColors.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: CihuyColors.teal,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        foregroundColor: CihuyColors.ink,
        side: const BorderSide(color: CihuyColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: CihuyColors.tealInk,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: CihuyColors.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

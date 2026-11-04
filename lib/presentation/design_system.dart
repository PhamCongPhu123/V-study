import 'package:flutter/material.dart';

abstract final class VstudyColors {
  static const navy = Color(0xFF202B48);
  static const ink = navy;
  static const gold = Color(0xFFD5AD1C);
  static const cream = Color(0xFFF6F0E5);
  static const paper = Color(0xFFFFFCF5);
  static const footer = Color(0xFFCBD2E6);
  static const blue = Color(0xFFCAD2E4);
  static const muted = Color(0xFF777B88);
  static const red = Color(0xFFD94C4C);
  static const green = Color(0xFF3B9B70);
  static const paleGold = Color(0xFFF8EDC3);
  static const divider = Color(0xFFDAD7D0);

  static const background = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF1DDB7), Color(0xFFF9F6EF), Color(0xFFE0E7F6)],
    stops: [0, .40, 1],
  );
}

ThemeData vstudyTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: VstudyColors.navy,
    primary: VstudyColors.navy,
    secondary: VstudyColors.gold,
    surface: VstudyColors.paper,
    onSurface: VstudyColors.ink,
  ),
  scaffoldBackgroundColor: Colors.transparent,
  appBarTheme: const AppBarThemeData(
    backgroundColor: Colors.transparent,
    foregroundColor: VstudyColors.ink,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
  ),
  textTheme: ThemeData.light().textTheme.apply(
    bodyColor: VstudyColors.ink,
    displayColor: VstudyColors.ink,
  ),
  inputDecorationTheme: InputDecorationThemeData(
    filled: true,
    fillColor: VstudyColors.paper,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: VstudyColors.navy,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: VstudyColors.gold,
    foregroundColor: VstudyColors.navy,
    shape: CircleBorder(),
  ),
  dividerColor: VstudyColors.divider,
);

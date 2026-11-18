import 'package:flutter/material.dart';

const pine = Color(0xFF205B45);
const pineDark = Color(0xFF183F33);
const paper = Color(0xFFF4F6F1);
const amber = Color(0xFFD89350);
const muted = Color(0xFF758078);

ThemeData buildAppTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: paper,
  colorScheme: ColorScheme.fromSeed(
    seedColor: pine,
  ).copyWith(primary: pine, secondary: amber, surface: Colors.white),
  appBarTheme: const AppBarTheme(
    backgroundColor: paper,
    foregroundColor: pineDark,
    surfaceTintColor: Colors.transparent,
    titleTextStyle: TextStyle(
      color: pineDark,
      fontSize: 17,
      fontWeight: FontWeight.w700,
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFDDE4DC)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFDDE4DC)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: pine, width: 1.4),
    ),
  ),
);

ThemeData buildAppDarkTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme.fromSeed(
    seedColor: pine,
    brightness: Brightness.dark,
  ).copyWith(primary: const Color(0xff79c49d), secondary: amber),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xff17221c),
    foregroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
  ),
);

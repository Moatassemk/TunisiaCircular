import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// CLAC design tokens
// ---------------------------------------------------------------------------
const pine = Color(0xFF1E5A43);
const pineDark = Color(0xFF123528);
const pineLight = Color(0xFF2F7A5B);
const paper = Color(0xFFF4F6F1);
const amber = Color(0xFFD89350);
const amberDark = Color(0xFF9A5F27);
const muted = Color(0xFF6B7A70);

const clacInk = Color(0xFF16241D);
const clacLine = Color(0xFFE2E8E0);
const clacLineStrong = Color(0xFFCBD8CE);
const clacSurface = Color(0xFFFFFFFF);
const clacSurfaceMuted = Color(0xFFEDF2EA);
const clacGreenSoft = Color(0xFFE4F0E7);
const clacAmberSoft = Color(0xFFFBF0E1);
const clacDanger = Color(0xFFB3453A);
const clacDangerSoft = Color(0xFFFBEAE7);
const clacInfo = Color(0xFF3C6E8F);
const clacInfoSoft = Color(0xFFE9F1F7);

const clacRadiusSm = 10.0;
const clacRadius = 14.0;
const clacRadiusLg = 20.0;
const clacGap = 16.0;

const _serif = 'serif';

ThemeData buildAppTheme() => _theme(Brightness.light);

ThemeData buildAppDarkTheme() => _theme(Brightness.dark);

ThemeData _theme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: pine, brightness: brightness)
      .copyWith(
        primary: isDark ? const Color(0xFF7FC6A1) : pine,
        onPrimary: isDark ? const Color(0xFF0C241A) : Colors.white,
        primaryContainer: isDark
            ? const Color(0xFF1D4635)
            : const Color(0xFFDCEFE2),
        onPrimaryContainer: isDark ? const Color(0xFFD6F1DE) : pineDark,
        secondary: amber,
        onSecondary: const Color(0xFF2C1B09),
        secondaryContainer: isDark
            ? const Color(0xFF4B3620)
            : const Color(0xFFFFEBD2),
        onSecondaryContainer: isDark
            ? const Color(0xFFFFE1BE)
            : const Color(0xFF4A2C0B),
        surface: isDark ? const Color(0xFF18231D) : clacSurface,
        onSurface: isDark ? const Color(0xFFF0F4EE) : clacInk,
        error: isDark ? const Color(0xFFFFB4A9) : clacDanger,
        outline: isDark ? const Color(0xFF3B4A40) : clacLineStrong,
        outlineVariant: isDark ? const Color(0xFF2C3A31) : clacLine,
        surfaceTint: Colors.transparent,
      );
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: isDark ? const Color(0xFF101914) : paper,
  );
  final ink = scheme.onSurface;
  final subdued = isDark ? const Color(0xFFA9BCAF) : muted;
  final line = scheme.outlineVariant;
  final card = isDark ? const Color(0xFF1C2A22) : Colors.white;
  final field = isDark ? const Color(0xFF223229) : Colors.white;

  final textTheme = base.textTheme
      .apply(bodyColor: ink, displayColor: ink)
      .copyWith(
        displayLarge: TextStyle(
          fontFamily: _serif,
          fontSize: 44,
          height: 1.04,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.2,
          color: ink,
        ),
        displayMedium: TextStyle(
          fontFamily: _serif,
          fontSize: 34,
          height: 1.08,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
          color: ink,
        ),
        displaySmall: TextStyle(
          fontFamily: _serif,
          fontSize: 28,
          height: 1.12,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: ink,
        ),
        headlineLarge: TextStyle(
          fontFamily: _serif,
          fontSize: 25,
          height: 1.15,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: ink,
        ),
        headlineMedium: TextStyle(
          fontFamily: _serif,
          fontSize: 22,
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          height: 1.25,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: ink,
        ),
        titleLarge: TextStyle(
          fontSize: 17,
          height: 1.3,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        titleMedium: TextStyle(
          fontSize: 14.5,
          height: 1.35,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        titleSmall: TextStyle(
          fontSize: 12.5,
          height: 1.35,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        bodyLarge: TextStyle(fontSize: 15, height: 1.5, color: ink),
        bodyMedium: TextStyle(fontSize: 13.5, height: 1.5, color: ink),
        bodySmall: TextStyle(fontSize: 12, height: 1.45, color: subdued),
        labelLarge: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
        labelMedium: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: subdued,
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: subdued,
        ),
      );

  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? const Color(0xFF101914) : paper,
      foregroundColor: ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: _serif,
        color: ink,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      iconTheme: IconThemeData(color: ink, size: 22),
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(clacRadius),
        side: BorderSide(color: line),
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: field,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      hintStyle: TextStyle(color: subdued, fontSize: 13.5),
      labelStyle: TextStyle(color: subdued, fontSize: 13.5),
      prefixIconColor: subdued,
      suffixIconColor: subdued,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(clacRadiusSm),
        borderSide: BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(clacRadiusSm),
        borderSide: BorderSide(color: line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(clacRadiusSm),
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(clacRadiusSm),
        borderSide: const BorderSide(color: clacDanger, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(clacRadiusSm),
        borderSide: const BorderSide(color: clacDanger, width: 1.6),
      ),
      errorStyle: const TextStyle(color: clacDanger, fontSize: 11.5),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        minimumSize: const Size(0, 50),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(clacRadiusSm),
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        minimumSize: const Size(0, 50),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(clacRadiusSm),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: isDark ? scheme.onSurface : pineDark,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        side: BorderSide(color: line),
        textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(clacRadiusSm),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: isDark ? const Color(0xFF26352C) : Colors.white,
      selectedColor: scheme.primaryContainer,
      disabledColor: line,
      side: BorderSide(color: line),
      shape: const StadiumBorder(),
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      secondaryLabelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: scheme.onPrimaryContainer,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      showCheckmark: false,
    ),
    dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
    listTileTheme: ListTileThemeData(
      iconColor: subdued,
      textColor: ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primaryContainer
              : Colors.transparent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimaryContainer
              : subdued,
        ),
        side: WidgetStateProperty.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.selected)
                ? scheme.primary.withValues(alpha: .45)
                : line,
          ),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        iconSize: const WidgetStatePropertyAll(17),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primaryContainer,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 10.5,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : subdued,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 22,
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : subdued,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? const Color(0xFF2B3B31) : pineDark,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
      actionTextColor: const Color(0xFFF5C77C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(clacRadiusSm),
      ),
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      elevation: 4,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(clacRadiusLg),
      ),
      titleTextStyle: textTheme.headlineSmall,
      contentTextStyle: textTheme.bodyMedium,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: card,
      showDragHandle: true,
      dragHandleColor: line,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: const BoxConstraints(maxWidth: 640),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: line,
      circularTrackColor: line,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(clacRadius),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: scheme.primary,
      unselectedLabelColor: subdued,
      indicatorColor: scheme.primary,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: line,
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      unselectedLabelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(clacRadiusSm),
        side: BorderSide(color: line),
      ),
      textStyle: textTheme.bodyMedium,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: pineDark,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(color: Colors.white, fontSize: 11.5),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? scheme.onPrimary : null,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? scheme.primary : null,
      ),
    ),
    badgeTheme: const BadgeThemeData(
      backgroundColor: Color(0xFFCC5A43),
      textColor: Colors.white,
      textStyle: TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
    ),
  );
}

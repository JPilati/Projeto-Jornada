import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const navy950 = Color(0xFF071A2F);
  static const navy900 = Color(0xFF0A2038);
  static const navy850 = Color(0xFF0D2745);
  static const navy800 = Color(0xFF12355B);
  static const navy700 = Color(0xFF1B456F);
  static const orange = Color(0xFFE87722);
  static const blue = Color(0xFF2E9DF7);
  static const green = Color(0xFF43A047);
  static const red = Color(0xFFE53935);
  static const yellow = Color(0xFFF6A623);

  static const lightBackground = Color(0xFFF4F7FB);
  static const lightSurface = Colors.white;
  static const lightText = Color(0xFF1A202C);
  static const lightMuted = Color(0xFF718096);

  static const darkText = Colors.white;
  static const darkMuted = Color(0xFFD9D9D9);
  static const darkInfo = Color(0xFFB8C7D9);

  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static Color pageBackground(BuildContext context) {
    return Theme.of(context).scaffoldBackgroundColor;
  }

  static Color surface(BuildContext context) {
    return Theme.of(context).colorScheme.surface;
  }

  static Color elevatedSurface(BuildContext context) {
    return isDark(context) ? navy800 : lightSurface;
  }

  static Color textPrimary(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface;
  }

  static Color textSecondary(BuildContext context) {
    return isDark(context) ? darkMuted : lightMuted;
  }

  static Color border(BuildContext context) {
    return isDark(context)
        ? Colors.white.withValues(alpha: 0.12)
        : const Color(0xFFDDE3EC);
  }

  static List<BoxShadow> cardShadow(BuildContext context) {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark(context) ? 0.22 : 0.06),
        blurRadius: isDark(context) ? 22 : 14,
        offset: const Offset(0, 8),
      ),
    ];
  }

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: orange,
      brightness: Brightness.light,
      primary: orange,
      secondary: blue,
      surface: lightSurface,
      onSurface: lightText,
    );

    return _base(colorScheme).copyWith(
      scaffoldBackgroundColor: lightBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: navy950,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  static ThemeData dark() {
    const colorScheme = ColorScheme.dark(
      primary: orange,
      onPrimary: Colors.white,
      secondary: blue,
      onSecondary: Colors.white,
      surface: navy850,
      onSurface: darkText,
      error: red,
      onError: Colors.white,
    );

    return _base(colorScheme).copyWith(
      scaffoldBackgroundColor: navy950,
      canvasColor: navy950,
      cardColor: navy850,
      dividerColor: Colors.white.withValues(alpha: 0.10),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF041426),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      textTheme: _base(colorScheme).textTheme.apply(
            bodyColor: darkText,
            displayColor: darkText,
          ),
    );
  }

  static ThemeData _base(ColorScheme colorScheme) {
    final isDark = colorScheme.brightness == Brightness.dark;
    final outline = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : const Color(0xFFDDE3EC);
    final inputFill = isDark ? navy900 : const Color(0xFFF7F9FC);

    return ThemeData(
      useMaterial3: true,
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
      primaryColor: orange,
      visualDensity: VisualDensity.standard,
      fontFamily: null,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? navy800 : lightText,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: outline),
        ),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: TextStyle(
          color: isDark ? darkMuted : lightMuted,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        hintStyle: TextStyle(color: isDark ? darkInfo : lightMuted),
        labelStyle: TextStyle(color: isDark ? darkMuted : lightMuted),
        prefixIconColor: isDark ? darkInfo : lightMuted,
        suffixIconColor: isDark ? darkInfo : lightMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: blue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: red, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: orange,
          foregroundColor: Colors.white,
          disabledBackgroundColor: orange.withValues(alpha: 0.45),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.72),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? Colors.white : orange,
          side: BorderSide(color: isDark ? navy700 : orange),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? darkText : orange,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return isDark ? darkInfo : Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return orange;
          return isDark ? navy700 : const Color(0xFFDDE3EC);
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return orange;
          return isDark ? darkInfo : lightMuted;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return orange;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: BorderSide(color: isDark ? darkInfo : lightMuted),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? navy900 : const Color(0xFFF4F7FB),
        selectedColor: orange,
        secondarySelectedColor: orange,
        labelStyle: TextStyle(color: colorScheme.onSurface),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        side: BorderSide(color: outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(isDark ? navy800 : lightBackground),
        dataRowColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary.withValues(alpha: 0.14);
          }
          return isDark ? navy850 : lightSurface;
        }),
        headingTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
        dataTextStyle: TextStyle(color: colorScheme.onSurface),
        dividerThickness: 0.7,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: inputFill,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: outline),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: isDark ? darkInfo : lightMuted,
        textColor: colorScheme.onSurface,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        subtitleTextStyle: TextStyle(
          color: isDark ? darkInfo : lightMuted,
          fontSize: 13,
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(
          isDark ? navy700 : const Color(0xFFC9D3E0),
        ),
      ),
    );
  }
}

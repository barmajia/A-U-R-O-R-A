import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aurora/config/performance_config.dart';

// ============================================================================
// 1. Constants & Design System
// ============================================================================

class AppColors {
  AppColors._();

  static const Color auroraPrimary = Color(0xFF260361);
  static const Color auroraSecondary = Color(0xFF4C2A8C);
  static const Color auroraAccent = Color(0xFF667EEA);

  // Light Mode Surfaces
  static const Color lightSurface = Colors.white;
  static const Color lightBackground = Color(0xFFF5F5FA);

  // Dark Mode Surfaces
  static const Color darkSurface = Color(0xFF1E1E23);
  static const Color darkBackground = Color(0xFF121214);
}

class AppDimensions {
  AppDimensions._();

  static const double borderRadius = 12.0;
  static const double buttonHeight = 16.0;
  static const double buttonHorizontalPadding = 24.0;
  static const double inputPadding = 16.0;
}

// ============================================================================
// 2. Theme Configuration (FIXED CONTRAST)
// ============================================================================

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => _buildThemeData(Brightness.light);
  static ThemeData get darkTheme => _buildThemeData(Brightness.dark);

  static ThemeData _buildThemeData(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    // Define colors based on brightness
    final primaryColor = isDark
        ? AppColors.auroraAccent
        : AppColors.auroraPrimary;
    final surfaceColor = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;
    final cardColor = isDark ? const Color(0xFF2A2A30) : Colors.white;
    final snackBarColor = isDark
        ? const Color(0xFF3C3C41)
        : const Color(0xFF323232);

    // ✅ FIXED: High contrast colors for text
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.grey[300]! : Colors.grey[700]!;
    final textMuted = isDark ? Colors.grey[500]! : Colors.grey[600]!;
    final inputFill = isDark ? const Color(0xFF2A2A30) : Colors.grey[100]!;
    final borderDefault = isDark ? Colors.grey[500]! : Colors.grey[400]!;
    final borderFocused = isDark ? Colors.grey[300]! : primaryColor;

    // Create the ColorScheme
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.auroraPrimary,
      brightness: brightness,
      primary: primaryColor,
      secondary: AppColors.auroraSecondary,
      tertiary: AppColors.auroraAccent,
      surface: surfaceColor,
      onSurface: textPrimary,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,

      // Scaffold background
      scaffoldBackgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,

      // Component Themes
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark
            ? AppColors.darkSurface
            : AppColors.auroraPrimary,
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: _borderShape,
        color: cardColor,
        margin: const EdgeInsets.all(8),
        surfaceTintColor: isDark ? Colors.grey[800] : null,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[400],
          disabledForegroundColor: Colors.white70,
          padding: _buttonPadding,
          shape: _borderShape,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          disabledForegroundColor: Colors.grey[400],
          padding: _buttonPadding,
          shape: _borderShape,
          side: BorderSide(color: primaryColor, width: 1.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          disabledForegroundColor: Colors.grey[400],
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),

      // ✅ FIXED: Input Decoration with High Contrast
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.inputPadding,
          vertical: AppDimensions.inputPadding,
        ),
        border: _inputBorder(color: borderDefault),
        enabledBorder: _inputBorder(color: borderDefault),
        focusedBorder: _inputBorder(color: borderFocused, width: 2),
        errorBorder: _inputBorder(color: Colors.red.shade400),
        focusedErrorBorder: _inputBorder(color: Colors.red.shade400, width: 2),
        // ✅ HIGH CONTRAST: Label and hint text
        labelStyle: TextStyle(
          color: isDark ? Colors.grey[200] : Colors.grey[800],
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(color: textMuted, fontWeight: FontWeight.normal),
        // ✅ Error text color
        errorStyle: const TextStyle(
          color: Colors.red,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        // ✅ Helper text
        helperStyle: TextStyle(color: textSecondary, fontSize: 12),
      ),

      // ✅ FIXED: Icon theme with high contrast
      iconTheme: IconThemeData(
        color: isDark ? Colors.grey[100] : Colors.grey[900],
        size: 24,
      ),
      primaryIconTheme: const IconThemeData(color: Colors.white, size: 24),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
      ),

      // ✅ FIXED: SnackBar with better contrast
      snackBarTheme: SnackBarThemeData(
        backgroundColor: snackBarColor,
        contentTextStyle: TextStyle(
          color: isDark ? Colors.grey[100] : Colors.white,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
        elevation: 6,
      ),

      // ✅ FIXED: Text Theme with explicit high contrast
      textTheme: _buildTextTheme(textPrimary, textSecondary, textMuted),

      // ✅ FIXED: Primary text theme
      primaryTextTheme: TextTheme(
        bodyLarge: const TextStyle(color: Colors.white),
        bodyMedium: const TextStyle(color: Colors.white),
        bodySmall: const TextStyle(color: Colors.white70),
      ),

      // ✅ FIXED: Chip theme for filters/status
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
        disabledColor: isDark ? Colors.grey[900] : Colors.grey[300],
        selectedColor: primaryColor.withValues(alpha: 0.3),
        secondarySelectedColor: primaryColor.withValues(alpha: 0.3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        labelStyle: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        brightness: brightness,
      ),

      // ✅ FIXED: Dropdown theme
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(
            isDark ? const Color(0xFF2A2A30) : Colors.white,
          ),
          elevation: const WidgetStatePropertyAll(8),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
              ),
            ),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: 8),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: inputFill,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: borderDefault),
          ),
          labelStyle: TextStyle(
            color: isDark ? Colors.grey[200] : Colors.grey[800],
          ),
        ),
      ),

      // ✅ FIXED: Divider theme
      dividerTheme: DividerThemeData(
        color: isDark ? Colors.grey[700] : Colors.grey[300],
        thickness: 1,
        space: 1,
      ),

      // ✅ FIXED: List tile theme
      listTileTheme: ListTileThemeData(
        textColor: textPrimary,
        iconColor: isDark ? Colors.grey[200] : Colors.grey[800],
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        subtitleTextStyle: TextStyle(color: textSecondary, fontSize: 14),
      ),
    );
  }

  // Reusable Shapes & Paddings
  static final RoundedRectangleBorder _borderShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
  );

  static const EdgeInsets _buttonPadding = EdgeInsets.symmetric(
    horizontal: AppDimensions.buttonHorizontalPadding,
    vertical: AppDimensions.buttonHeight,
  );

  static OutlineInputBorder _inputBorder({
    required Color color,
    double width = 1.0,
  }) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  static TextTheme _buildTextTheme(
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
  ) {
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
      displaySmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: textPrimary,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        color: textPrimary,
        fontWeight: FontWeight.normal,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: textPrimary,
        fontWeight: FontWeight.normal,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        color: textMuted,
        fontWeight: FontWeight.normal,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: textSecondary,
      ),
      labelSmall: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: textMuted,
      ),
    );
  }
}

// ============================================================================
// 3. State Management (Provider)
// ============================================================================

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  bool _useSystemTheme = false;
  Brightness? _systemBrightness;

  bool get isDarkMode => _isDarkMode;
  bool get useSystemTheme => _useSystemTheme;
  Brightness? get systemBrightness => _systemBrightness;

  ThemeData get themeData =>
      _isDarkMode ? AppTheme.darkTheme : AppTheme.lightTheme;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      _useSystemTheme = prefs.getBool('useSystemTheme') ?? false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading theme preference: $e');
    }
  }

  /// Public method to manually reload theme from preferences
  /// (Useful if preferences are changed externally)
  Future<void> loadTheme() async {
    await _loadTheme();
  }

  /// Enable/disable system theme detection
  Future<void> setUseSystemTheme(bool value) async {
    try {
      _useSystemTheme = value;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('useSystemTheme', value);

      if (value && _systemBrightness != null) {
        _isDarkMode = _systemBrightness == Brightness.dark;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error saving system theme preference: $e');
    }
  }

  /// Update system brightness (call this from MaterialApp builder)
  void updateSystemBrightness(Brightness brightness) {
    if (_systemBrightness != brightness) {
      _systemBrightness = brightness;

      // Auto-switch if using system theme
      if (_useSystemTheme) {
        _isDarkMode = brightness == Brightness.dark;
        notifyListeners();
      }
    }
  }

  Future<void> toggleTheme() async {
    try {
      // Disable system theme if manually toggling
      if (_useSystemTheme) {
        await setUseSystemTheme(false);
      }

      _isDarkMode = !_isDarkMode;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', _isDarkMode);
    } catch (e) {
      debugPrint('Error saving theme preference: $e');
    }
  }
}

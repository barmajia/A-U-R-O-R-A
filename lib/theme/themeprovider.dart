import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    final cardColor = isDark
        ? const Color(0xFF2A2A30)
        : Colors.white; // ↑ Lighter for contrast
    final snackBarColor = isDark
        ? const Color(0xFF3C3C41)
        : const Color(0xFF323232);

    // Create the ColorScheme
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.auroraPrimary,
      brightness: brightness,
      primary: primaryColor,
      secondary: AppColors.auroraSecondary,
      tertiary: AppColors.auroraAccent,
      surface: surfaceColor,
      onSurface: isDark
          ? Colors.grey[100]!
          : Colors.grey[900]!, // ↑ Explicit contrast
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,

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
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: _buttonPadding,
          shape: _borderShape,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          padding: _buttonPadding,
          shape: _borderShape,
          side: BorderSide(color: primaryColor, width: 1.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),

      // ✅ FIXED: Input Decoration with Adaptive Colors
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? cardColor : Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.inputPadding,
          vertical: AppDimensions.inputPadding,
        ),
        border: _inputBorder(
          color: isDark ? Colors.grey[600]! : Colors.grey[400]!,
        ),
        enabledBorder: _inputBorder(
          color: isDark ? Colors.grey[600]! : Colors.grey[400]!,
        ),
        focusedBorder: _inputBorder(color: primaryColor, width: 2),
        errorBorder: _inputBorder(color: Colors.red.shade400),
        focusedErrorBorder: _inputBorder(color: Colors.red.shade400, width: 2),
        // ✅ FIXED: Adaptive label/hint colors
        labelStyle: TextStyle(
          color: isDark ? Colors.grey[300] : Colors.grey[700],
        ),
        hintStyle: TextStyle(
          color: isDark ? Colors.grey[500] : Colors.grey[500],
        ),
        // ✅ FIXED: Error text color
        errorStyle: const TextStyle(
          color: Colors.red,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),

      // ✅ FIXED: Icon theme with adaptive color
      iconTheme: IconThemeData(
        color: isDark ? Colors.grey[200] : Colors.grey[800],
        size: 24,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),

      // ✅ FIXED: SnackBar with better contrast
      snackBarTheme: SnackBarThemeData(
        backgroundColor: snackBarColor,
        contentTextStyle: TextStyle(
          color: isDark ? Colors.grey[100] : Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),

      // ✅ FIXED: Text Theme with explicit contrast
      textTheme: _buildTextTheme(colorScheme, isDark),

      // ✅ FIXED: Chip theme for filters/status
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
        disabledColor: isDark ? Colors.grey[900] : Colors.grey[300],
        selectedColor: primaryColor.withValues(alpha: 0.2),
        secondarySelectedColor: primaryColor.withValues(alpha: 0.2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        labelStyle: TextStyle(
          color: isDark ? Colors.grey[200] : Colors.grey[900],
          fontSize: 14,
        ),
        secondaryLabelStyle: TextStyle(
          color: isDark ? Colors.grey[200] : Colors.grey[900],
          fontSize: 14,
        ),
        brightness: brightness,
      ),

      // ✅ FIXED: Dropdown theme for Color, Category, Subcategory, Currency
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(
            isDark ? Colors.grey[850]! : Colors.white,
          ),
          elevation: WidgetStatePropertyAll(8),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
          ),
          padding: WidgetStatePropertyAll(
            const EdgeInsets.symmetric(vertical: 8),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: isDark ? cardColor : Colors.grey[50],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? Colors.grey[600]! : Colors.grey[400]!,
            ),
          ),
          labelStyle: TextStyle(
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
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

  static TextTheme _buildTextTheme(ColorScheme colorScheme, bool isDark) {
    final onSurface = colorScheme.onSurface;
    final mutedColor = isDark
        ? Colors.grey[400]! // ↑ Lighter grey for dark mode
        : Colors.grey[600]!; // ↑ Darker grey for light mode

    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: onSurface,
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: onSurface,
      ),
      displaySmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: onSurface,
      ),
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: onSurface,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: onSurface),
      bodyMedium: TextStyle(fontSize: 14, color: onSurface),
      bodySmall: TextStyle(
        fontSize: 12,
        color: mutedColor,
      ), // ✅ Explicit muted style
    );
  }
}

// ============================================================================
// 3. State Management (Provider)
// ============================================================================

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  ThemeData get themeData =>
      _isDarkMode ? AppTheme.darkTheme : AppTheme.lightTheme;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
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

  Future<void> toggleTheme() async {
    try {
      _isDarkMode = !_isDarkMode;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', _isDarkMode);
    } catch (e) {
      debugPrint('Error saving theme preference: $e');
    }
  }
}

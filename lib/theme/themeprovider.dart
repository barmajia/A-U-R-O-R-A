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

// ============================================================================
// 1.1 VS Code–inspired Theme Presets
// ============================================================================

enum AppThemeId {
  vscodeLight,
  vscodeDark,
  dracula,
  monokai,
  solarizedDark,
  highContrast,
}

class ThemePalette {
  final AppThemeId id;
  final String name;
  final String description;
  final Brightness brightness;
  final Color seed;
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color surface;
  final Color background;
  final Color card;
  final List<Color> preview;

  const ThemePalette({
    required this.id,
    required this.name,
    required this.description,
    required this.brightness,
    required this.seed,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.surface,
    required this.background,
    required this.card,
    required this.preview,
  });
}

class AppThemes {
  AppThemes._();

  static const List<ThemePalette> palettes = [
    ThemePalette(
      id: AppThemeId.vscodeLight,
      name: 'VS Code Light+',
      description: 'Classic Light+ palette from VS Code',
      brightness: Brightness.light,
      seed: Color(0xFF007ACC),
      primary: Color(0xFF007ACC),
      secondary: Color(0xFF2B88D8),
      accent: Color(0xFF0E639C),
      surface: Colors.white,
      background: Color(0xFFF5F5F7),
      card: Colors.white,
      preview: [Color(0xFF007ACC), Color(0xFF2B88D8), Color(0xFF0E639C)],
    ),
    ThemePalette(
      id: AppThemeId.vscodeDark,
      name: 'VS Code Dark+',
      description: 'Default Dark+ theme used in VS Code',
      brightness: Brightness.dark,
      seed: Color(0xFF569CD6),
      primary: Color(0xFF569CD6),
      secondary: Color(0xFF4EC9B0),
      accent: Color(0xFFD4D4D4),
      surface: Color(0xFF1E1E1E),
      background: Color(0xFF111111),
      card: Color(0xFF252526),
      preview: [Color(0xFF569CD6), Color(0xFF4EC9B0), Color(0xFFD4D4D4)],
    ),
    ThemePalette(
      id: AppThemeId.dracula,
      name: 'Dracula',
      description: 'Popular purple/green Dracula palette',
      brightness: Brightness.dark,
      seed: Color(0xFFBD93F9),
      primary: Color(0xFFBD93F9),
      secondary: Color(0xFF50FA7B),
      accent: Color(0xFFFF79C6),
      surface: Color(0xFF1E1F29),
      background: Color(0xFF13141A),
      card: Color(0xFF232433),
      preview: [Color(0xFFBD93F9), Color(0xFF50FA7B), Color(0xFFFF79C6)],
    ),
    ThemePalette(
      id: AppThemeId.monokai,
      name: 'Monokai',
      description: 'Warm Monokai classic colors',
      brightness: Brightness.dark,
      seed: Color(0xFF66D9EF),
      primary: Color(0xFF66D9EF),
      secondary: Color(0xFFA6E22E),
      accent: Color(0xFFF92672),
      surface: Color(0xFF2D2A2E),
      background: Color(0xFF211F22),
      card: Color(0xFF2F2B30),
      preview: [Color(0xFF66D9EF), Color(0xFFA6E22E), Color(0xFFF92672)],
    ),
    ThemePalette(
      id: AppThemeId.solarizedDark,
      name: 'Solarized Dark',
      description: 'Teal/amber Solarized Dark palette',
      brightness: Brightness.dark,
      seed: Color(0xFF268BD2),
      primary: Color(0xFF268BD2),
      secondary: Color(0xFF2AA198),
      accent: Color(0xFFB58900),
      surface: Color(0xFF002B36),
      background: Color(0xFF00212B),
      card: Color(0xFF073642),
      preview: [Color(0xFF268BD2), Color(0xFF2AA198), Color(0xFFB58900)],
    ),
    ThemePalette(
      id: AppThemeId.highContrast,
      name: 'High Contrast',
      description: 'Max contrast for accessibility',
      brightness: Brightness.dark,
      seed: Color(0xFFFFFFFF),
      primary: Color(0xFFFFFFFF),
      secondary: Color(0xFF00E8FF),
      accent: Color(0xFFFF4081),
      surface: Color(0xFF000000),
      background: Color(0xFF000000),
      card: Color(0xFF0F0F0F),
      preview: [Color(0xFFFFFFFF), Color(0xFF00E8FF), Color(0xFFFF4081)],
    ),
  ];

  static ThemePalette palette(AppThemeId id) {
    return palettes.firstWhere((p) => p.id == id);
  }
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

  static ThemeData fromPalette(
    ThemePalette palette, {
    Brightness? brightnessOverride,
  }) =>
      _buildThemeData(palette, brightnessOverride: brightnessOverride);

  static ThemeData get lightTheme =>
      _buildThemeData(AppThemes.palette(AppThemeId.vscodeLight));
  static ThemeData get darkTheme =>
      _buildThemeData(AppThemes.palette(AppThemeId.vscodeDark));

  static ThemeData _buildThemeData(
    ThemePalette palette, {
    Brightness? brightnessOverride,
  }) {
    final brightness = brightnessOverride ?? palette.brightness;
    final isDark = brightness == Brightness.dark;

    // Define colors based on palette
    final primaryColor = palette.primary;
    final surfaceColor = palette.surface;
    final cardColor = palette.card;
    final backgroundColor = palette.background;
    final snackBarColor =
        isDark ? const Color(0xFF3C3C41) : const Color(0xFF323232);

    // ✅ FIXED: High contrast colors for text
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.grey[300]! : Colors.grey[700]!;
    final textMuted = isDark ? Colors.grey[500]! : Colors.grey[600]!;
    final inputFill = isDark ? const Color(0xFF2A2A30) : Colors.grey[100]!;
    final borderDefault = isDark ? Colors.grey[500]! : Colors.grey[400]!;
    final borderFocused = isDark ? Colors.grey[300]! : primaryColor;

    // Create the ColorScheme
    final baseScheme = ColorScheme.fromSeed(
      seedColor: palette.seed,
      brightness: brightness,
      primary: primaryColor,
      secondary: palette.secondary,
      tertiary: palette.accent,
      surface: surfaceColor,
      onSurface: textPrimary,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
    ).copyWith(background: backgroundColor, surface: surfaceColor);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: baseScheme,

      // Scaffold background
      scaffoldBackgroundColor: backgroundColor,

      // Component Themes
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? surfaceColor : primaryColor,
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
  AppThemeId _themeId = AppThemeId.vscodeLight;
  bool _useSystemTheme = false;
  Brightness? _systemBrightness;

  AppThemeId get currentThemeId => _themeId;
  bool get useSystemTheme => _useSystemTheme;
  Brightness? get systemBrightness => _systemBrightness;
  List<ThemePalette> get availableThemes => AppThemes.palettes;
  String get currentThemeName => AppThemes.palette(_themeId).name;
  String get currentThemeDescription => AppThemes.palette(_themeId).description;

  AppThemeId get _effectiveThemeId {
    if (_useSystemTheme && _systemBrightness != null) {
      return _systemBrightness == Brightness.dark
          ? AppThemeId.vscodeDark
          : AppThemeId.vscodeLight;
    }
    return _themeId;
  }

  bool get isDarkMode =>
      AppThemes.palette(_effectiveThemeId).brightness == Brightness.dark;

  ThemeData get themeData => AppTheme.fromPalette(
        AppThemes.palette(_effectiveThemeId),
        brightnessOverride: _useSystemTheme ? _systemBrightness : null,
      );

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString('themeId');
      if (savedTheme != null) {
        _themeId = AppThemeId.values.firstWhere(
          (t) => t.name == savedTheme,
          orElse: () => AppThemeId.vscodeLight,
        );
      } else {
        final legacyDark = prefs.getBool('isDarkMode') ?? false;
        _themeId =
            legacyDark ? AppThemeId.vscodeDark : AppThemeId.vscodeLight;
      }
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

  Future<void> setTheme(AppThemeId id) async {
    try {
      _themeId = id;
      // Manual choice disables auto system following
      _useSystemTheme = false;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('themeId', id.name);
      await prefs.setBool(
        'isDarkMode',
        AppThemes.palette(id).brightness == Brightness.dark,
      );
      await prefs.setBool('useSystemTheme', _useSystemTheme);
    } catch (e) {
      debugPrint('Error saving theme preference: $e');
    }
  }

  /// Enable/disable system theme detection
  Future<void> setUseSystemTheme(bool value) async {
    try {
      _useSystemTheme = value;

      if (value && _systemBrightness != null) {
        _themeId = _systemBrightness == Brightness.dark
            ? AppThemeId.vscodeDark
            : AppThemeId.vscodeLight;
      }
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('useSystemTheme', value);
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
        _themeId = brightness == Brightness.dark
            ? AppThemeId.vscodeDark
            : AppThemeId.vscodeLight;
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

      final nextTheme = _themeId == AppThemeId.vscodeDark
          ? AppThemeId.vscodeLight
          : AppThemeId.vscodeDark;

      await setTheme(nextTheme);
    } catch (e) {
      debugPrint('Error saving theme preference: $e');
    }
  }
}

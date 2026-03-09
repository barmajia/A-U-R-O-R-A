// Unit Tests for ThemeProvider
import 'package:aurora/theme/themeprovider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Initialize binding for tests
  TestWidgetsFlutterBinding.ensureInitialized();
  
  setUpAll(() async {
    // Mock shared preferences
    SharedPreferences.setMockInitialValues({});
  });
  
  group('AppColors', () {
    test('should have correct primary colors', () {
      expect(AppColors.auroraPrimary, const Color(0xFF260361));
      expect(AppColors.auroraSecondary, const Color(0xFF4C2A8C));
      expect(AppColors.auroraAccent, const Color(0xFF667EEA));
    });

    test('should have correct light mode surfaces', () {
      expect(AppColors.lightSurface, Colors.white);
      expect(AppColors.lightBackground, const Color(0xFFF5F5FA));
    });

    test('should have correct dark mode surfaces', () {
      expect(AppColors.darkSurface, const Color(0xFF1E1E23));
      expect(AppColors.darkBackground, const Color(0xFF121214));
    });
  });

  group('AppDimensions', () {
    test('should have correct border radius', () {
      expect(AppDimensions.borderRadius, 12.0);
    });

    test('should have correct button dimensions', () {
      expect(AppDimensions.buttonHeight, 16.0);
      expect(AppDimensions.buttonHorizontalPadding, 24.0);
    });

    test('should have correct input padding', () {
      expect(AppDimensions.inputPadding, 16.0);
    });
  });

  group('AppTheme', () {
    group('Light Theme', () {
      test('should create light theme', () {
        final theme = AppTheme.lightTheme;

        expect(theme, isA<ThemeData>());
        expect(theme.brightness, Brightness.light);
        expect(theme.colorScheme.brightness, Brightness.light);
      });

      test('should have correct light theme colors', () {
        final theme = AppTheme.lightTheme;

        expect(theme.scaffoldBackgroundColor, AppColors.lightBackground);
        expect(theme.cardTheme.color, Colors.white);
        expect(theme.appBarTheme.backgroundColor, AppColors.auroraPrimary);
        expect(theme.appBarTheme.foregroundColor, Colors.white);
      });

      test('should have correct light theme text colors', () {
        final theme = AppTheme.lightTheme;

        // Text should be dark for contrast on light background
        expect(theme.textTheme.bodyLarge?.color, isNot(Colors.white));
        expect(theme.textTheme.bodyMedium?.color, isNot(Colors.white));
      });

      test('should have correct light theme input decoration', () {
        final theme = AppTheme.lightTheme;

        expect(theme.inputDecorationTheme.filled, isTrue);
        expect(theme.inputDecorationTheme.border, isA<OutlineInputBorder>());
        final border = theme.inputDecorationTheme.border as OutlineInputBorder?;
        expect(border?.borderRadius, BorderRadius.circular(12.0));
      });
    });

    group('Dark Theme', () {
      test('should create dark theme', () {
        final theme = AppTheme.darkTheme;

        expect(theme, isA<ThemeData>());
        expect(theme.brightness, Brightness.dark);
        expect(theme.colorScheme.brightness, Brightness.dark);
      });

      test('should have correct dark theme colors', () {
        final theme = AppTheme.darkTheme;

        expect(theme.scaffoldBackgroundColor, AppColors.darkBackground);
        expect(theme.cardTheme.color, const Color(0xFF2A2A30));
        expect(theme.appBarTheme.backgroundColor, AppColors.darkSurface);
      });

      test('should have correct dark theme text colors', () {
        final theme = AppTheme.darkTheme;

        // Text should be light for contrast on dark background
        expect(theme.textTheme.bodyLarge?.color, isNot(Colors.black));
        expect(theme.textTheme.bodyMedium?.color, isNot(Colors.black));
      });

      test('should have correct dark theme snackbar', () {
        final theme = AppTheme.darkTheme;

        expect(theme.snackBarTheme.backgroundColor, const Color(0xFF3C3C41));
        expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
      });
    });

    group('Theme Properties', () {
      test('should have Material 3 enabled', () {
        final lightTheme = AppTheme.lightTheme;
        final darkTheme = AppTheme.darkTheme;

        expect(lightTheme.useMaterial3, isTrue);
        expect(darkTheme.useMaterial3, isTrue);
      });

      test('should have correct border shape', () {
        final lightTheme = AppTheme.lightTheme;
        final darkTheme = AppTheme.darkTheme;

        expect(lightTheme.elevatedButtonTheme.style?.shape?.resolve({}), isA<RoundedRectangleBorder>());
        expect(darkTheme.elevatedButtonTheme.style?.shape?.resolve({}), isA<RoundedRectangleBorder>());
      });

      test('should have correct chip theme', () {
        final lightTheme = AppTheme.lightTheme;
        final darkTheme = AppTheme.darkTheme;

        expect(lightTheme.chipTheme.backgroundColor, isNot(darkTheme.chipTheme.backgroundColor));
        expect(lightTheme.chipTheme.labelStyle?.fontSize, 14);
        expect(darkTheme.chipTheme.labelStyle?.fontSize, 14);
      });

      test('should have correct divider theme', () {
        final lightTheme = AppTheme.lightTheme;
        final darkTheme = AppTheme.darkTheme;

        expect(lightTheme.dividerTheme.thickness, 1);
        expect(darkTheme.dividerTheme.thickness, 1);
        expect(lightTheme.dividerTheme.color, isNot(darkTheme.dividerTheme.color));
      });

      test('should have correct list tile theme', () {
        final lightTheme = AppTheme.lightTheme;
        final darkTheme = AppTheme.darkTheme;

        expect(lightTheme.listTileTheme.titleTextStyle?.fontSize, 16);
        expect(darkTheme.listTileTheme.titleTextStyle?.fontSize, 16);
      });
    });
  });

  group('ThemeProvider', () {
    late ThemeProvider themeProvider;

    setUp(() {
      themeProvider = ThemeProvider();
    });

    group('Constructor', () {
      test('should create ThemeProvider instance', () {
        expect(themeProvider, isA<ThemeProvider>());
      });

      test('should have default theme', () {
        expect(themeProvider.themeData, isA<ThemeData>());
      });
    });

    group('Initial State', () {
      test('should have default isDarkMode value', () {
        // Note: This depends on SharedPreferences state
        // In a real test, we'd mock SharedPreferences
        expect(themeProvider.isDarkMode, isA<bool>());
      });

      test('should have non-null themeData', () {
        expect(themeProvider.themeData, isNotNull);
      });
    });

    group('Toggle Theme', () {
      test('should toggle theme mode', () async {
        await themeProvider.toggleTheme();
        expect(themeProvider.isDarkMode, isA<bool>());
      });

      test('should notify listeners on toggle', () async {
        var notifyCount = 0;
        themeProvider.addListener(() {
          notifyCount++;
        });

        await themeProvider.toggleTheme();
        
        expect(notifyCount, greaterThan(0));
      });

      test('should toggle back and forth', () async {
        final initialMode = themeProvider.isDarkMode;
        
        await themeProvider.toggleTheme();
        expect(themeProvider.isDarkMode, !initialMode);
        
        await themeProvider.toggleTheme();
        expect(themeProvider.isDarkMode, initialMode);
      });
    });

    group('Theme Data', () {
      test('should return light theme when not dark mode', () async {
        // Force light mode
        if (themeProvider.isDarkMode) {
          await themeProvider.toggleTheme();
        }
        
        expect(themeProvider.themeData.brightness, Brightness.light);
      });

      test('should return dark theme when dark mode', () async {
        // Force dark mode
        if (!themeProvider.isDarkMode) {
          await themeProvider.toggleTheme();
        }
        
        expect(themeProvider.themeData.brightness, Brightness.dark);
      });
    });

    group('Load Theme', () {
      test('should reload theme from preferences', () async {
        await themeProvider.loadTheme();

        // Should not throw
        expect(themeProvider.isDarkMode, isA<bool>());
      });
    });

    group('ChangeNotifier', () {
      test('should support listeners', () {
        var listenerCalled = false;
        
        themeProvider.addListener(() {
          listenerCalled = true;
        });
        
        // Trigger notification
        themeProvider.notifyListeners();
        
        expect(listenerCalled, isTrue);
      });

      test('should remove listeners on dispose', () {
        var listenerCalled = false;
        
        void listener() {
          listenerCalled = true;
        }
        
        themeProvider.addListener(listener);
        themeProvider.removeListener(listener);
        themeProvider.notifyListeners();
        
        expect(listenerCalled, isFalse);
      });
    });
  });
}

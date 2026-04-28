/// Reusable button component with consistent styling across the application.
library;

import 'package:flutter/material.dart';

/// Button types for different use cases.
enum AppButtonType {
  /// Primary action button (filled, prominent)
  primary,

  /// Secondary action button (outlined)
  secondary,

  /// Tertiary action button (text-only)
  text,

  /// Destructive action button (red/warning)
  destructive,

  /// Disabled state button
  disabled,
}

/// Button sizes for different contexts.
enum AppButtonSize {
  /// Small button for compact spaces
  small,

  /// Medium button (default)
  medium,

  /// Large button for prominent actions
  large,
}

/// A customizable button widget with consistent styling.
/// 
/// Example usage:
/// ```dart
/// AppButton(
///   label: 'Save Product',
///   onPressed: () => saveProduct(),
///   type: AppButtonType.primary,
///   isLoading: isSaving,
/// )
/// ```
class AppButton extends StatelessWidget {
  /// Creates an [AppButton].
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.type = AppButtonType.primary,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.icon,
    this.fullWidth = false,
    this.height,
  });

  /// The text label displayed on the button.
  final String label;

  /// Callback when the button is pressed.
  /// If null, the button will be disabled.
  final VoidCallback? onPressed;

  /// The visual style of the button.
  final AppButtonType type;

  /// The size of the button.
  final AppButtonSize size;

  /// Whether to show a loading indicator instead of the label.
  final bool isLoading;

  /// Optional icon to display before the label.
  final Widget? icon;

  /// Whether the button should expand to full width.
  final bool fullWidth;

  /// Custom height override (optional).
  final double? height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isEnabled = onPressed != null && !isLoading;

    final buttonStyle = _getButtonStyle(theme, colors, isEnabled);
    final contentPadding = _getContentPadding();
    final textStyle = _getTextStyle(theme, isEnabled);
    final buttonHeight = height ?? _getButtonHeight();

    Widget buttonContent = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                _getLoadingColor(colors),
              ),
            ),
          ),
        ] else ...[
          if (icon != null) ...[
            icon!,
            const SizedBox(width: 8),
          ],
          Text(label, style: textStyle),
        ],
      ],
    );

    if (fullWidth) {
      buttonContent = SizedBox(
        width: double.infinity,
        child: buttonContent,
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: buttonHeight,
      child: Material(
        color: buttonStyle.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        elevation: buttonStyle.elevation,
        child: InkWell(
          onTap: isEnabled ? onPressed : null,
          borderRadius: BorderRadius.circular(8),
          splashColor: _getSplashColor(colors),
          highlightColor: _getHighlightColor(colors),
          child: Container(
            padding: contentPadding,
            alignment: Alignment.center,
            child: buttonContent,
          ),
        ),
      ),
    );
  }

  ButtonStyleData _getButtonStyle(
    ThemeData theme,
    ColorScheme colors,
    bool isEnabled,
  ) {
    switch (type) {
      case AppButtonType.primary:
        return ButtonStyleData(
          backgroundColor: isEnabled
              ? colors.primary
              : colors.primary.withOpacity(0.5),
          foregroundColor: colors.onPrimary,
          elevation: isEnabled ? 2 : 0,
        );

      case AppButtonType.secondary:
        return ButtonStyleData(
          backgroundColor: isEnabled ? Colors.transparent : Colors.transparent,
          foregroundColor: isEnabled ? colors.primary : colors.onSurface.withOpacity(0.3),
          elevation: 0,
          border: Border.all(
            color: isEnabled ? colors.primary : colors.onSurface.withOpacity(0.3),
            width: 1.5,
          ),
        );

      case AppButtonType.text:
        return ButtonStyleData(
          backgroundColor: Colors.transparent,
          foregroundColor: isEnabled ? colors.primary : colors.onSurface.withOpacity(0.3),
          elevation: 0,
        );

      case AppButtonType.destructive:
        return ButtonStyleData(
          backgroundColor: isEnabled ? Colors.red : Colors.red.withOpacity(0.5),
          foregroundColor: Colors.white,
          elevation: isEnabled ? 2 : 0,
        );

      case AppButtonType.disabled:
        return ButtonStyleData(
          backgroundColor: colors.surfaceVariant,
          foregroundColor: colors.onSurfaceVariant,
          elevation: 0,
        );
    }
  }

  EdgeInsetsGeometry _getContentPadding() {
    switch (size) {
      case AppButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 6);
      case AppButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: 24, vertical: 12);
      case AppButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 32, vertical: 16);
    }
  }

  TextStyle _getTextStyle(ThemeData theme, bool isEnabled) {
    final baseStyle = theme.textTheme.labelLarge;
    final color = _getButtonStyle(
      theme,
      theme.colorScheme,
      isEnabled,
    ).foregroundColor;

    switch (size) {
      case AppButtonSize.small:
        return theme.textTheme.labelMedium?.copyWith(color: color) ??
            baseStyle!.copyWith(color: color, fontSize: 12);
      case AppButtonSize.medium:
        return baseStyle!.copyWith(color: color);
      case AppButtonSize.large:
        return theme.textTheme.titleMedium?.copyWith(color: color) ??
            baseStyle.copyWith(color: color, fontSize: 18);
    }
  }

  double _getButtonHeight() {
    switch (size) {
      case AppButtonSize.small:
        return 32;
      case AppButtonSize.medium:
        return 48;
      case AppButtonSize.large:
        return 56;
    }
  }

  Color _getLoadingColor(ColorScheme colors) {
    switch (type) {
      case AppButtonType.primary:
        return colors.onPrimary;
      case AppButtonType.secondary:
      case AppButtonType.text:
        return colors.primary;
      case AppButtonType.destructive:
        return Colors.white;
      case AppButtonType.disabled:
        return colors.onSurfaceVariant;
    }
  }

  Color _getSplashColor(ColorScheme colors) {
    switch (type) {
      case AppButtonType.primary:
        return colors.onPrimary.withOpacity(0.1);
      case AppButtonType.secondary:
      case AppButtonType.text:
        return colors.primary.withOpacity(0.1);
      case AppButtonType.destructive:
        return Colors.white.withOpacity(0.1);
      case AppButtonType.disabled:
        return Colors.transparent;
    }
  }

  Color _getHighlightColor(ColorScheme colors) {
    switch (type) {
      case AppButtonType.primary:
        return colors.onPrimary.withOpacity(0.05);
      case AppButtonType.secondary:
      case AppButtonType.text:
        return colors.primary.withOpacity(0.05);
      case AppButtonType.destructive:
        return Colors.white.withOpacity(0.05);
      case AppButtonType.disabled:
        return Colors.transparent;
    }
  }
}

class ButtonStyleData {
  final Color backgroundColor;
  final Color foregroundColor;
  final double elevation;
  final BoxBorder? border;

  const ButtonStyleData({
    required this.backgroundColor,
    required this.foregroundColor,
    this.elevation = 0,
    this.border,
  });
}

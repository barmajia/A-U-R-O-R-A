/// Reusable text field component with consistent styling and validation.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Text field types for different input scenarios.
enum AppTextFieldType {
  /// Standard single-line text input
  text,

  /// Multi-line text input
  multiline,

  /// Email input with email keyboard
  email,

  /// Password input with obscuring
  password,

  /// Numeric input
  number,

  /// Phone number input
  phone,

  /// URL input
  url,
}

/// A customizable text field widget with consistent styling.
/// 
/// Example usage:
/// ```dart
/// AppTextField(
///   label: 'Product Name',
///   hintText: 'Enter product name',
///   controller: nameController,
///   type: AppTextFieldType.text,
///   validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
/// )
/// ```
class AppTextField extends StatefulWidget {
  /// Creates an [AppTextField].
  const AppTextField({
    super.key,
    this.label,
    this.hintText,
    this.controller,
    this.type = AppTextFieldType.text,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines,
    this.maxLength,
    this.readOnly = false,
    this.enabled = true,
    this.obscureText = false,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.helperText,
    this.errorMaxLines,
  });

  /// The label displayed above the text field.
  final String? label;

  /// The hint text displayed when the field is empty.
  final String? hintText;

  /// The controller for the text field.
  final TextEditingController? controller;

  /// The type of input expected.
  final AppTextFieldType type;

  /// Validation function that returns error message or null.
  final String? Function(String?)? validator;

  /// Callback when text changes.
  final void Function(String)? onChanged;

  /// Callback when submit action is triggered.
  final void Function(String)? onSubmitted;

  /// Optional icon to display before the text input.
  final Widget? prefixIcon;

  /// Optional icon to display after the text input.
  final Widget? suffixIcon;

  /// Number of lines for multiline input.
  final int? maxLines;

  /// Maximum character count.
  final int? maxLength;

  /// Whether the field is read-only.
  final bool readOnly;

  /// Whether the field is enabled.
  final bool enabled;

  /// Whether to obscure text (for passwords).
  final bool obscureText;

  /// Whether to autofocus on build.
  final bool autofocus;

  /// Text capitalization behavior.
  final TextCapitalization textCapitalization;

  /// Custom keyboard type override.
  final TextInputType? keyboardType;

  /// Action button on the keyboard.
  final TextInputAction? textInputAction;

  /// Input formatters for custom validation/formatting.
  final List<TextInputFormatter>? inputFormatters;

  /// Helper text displayed below the field.
  final String? helperText;

  /// Maximum lines for error text.
  final int? errorMaxLines;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscureText = false;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              widget.label!,
              style: theme.textTheme.labelLarge?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
        TextFormField(
          controller: widget.controller,
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: TextStyle(color: colors.onSurface.withOpacity(0.4)),
            prefixIcon: widget.prefixIcon,
            suffixIcon: _buildSuffixIcon(),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: colors.outline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: colors.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: colors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: colors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: colors.error, width: 2),
            ),
            filled: true,
            fillColor: widget.enabled
                ? colors.surface
                : colors.surfaceVariant.withOpacity(0.3),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: widget.enabled ? colors.onSurface : colors.onSurface.withOpacity(0.5),
          ),
          validator: widget.validator,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          maxLines: widget.type == AppTextFieldType.multiline
              ? (widget.maxLines ?? 4)
              : 1,
          maxLength: widget.maxLength,
          readOnly: widget.readOnly,
          enabled: widget.enabled,
          obscureText: _obscureText,
          autofocus: widget.autofocus,
          textCapitalization: widget.textCapitalization,
          keyboardType: widget.keyboardType ?? _getKeyboardType(),
          textInputAction: widget.textInputAction,
          inputFormatters: widget.inputFormatters ?? _getInputFormatters(),
          errorMaxLines: widget.errorMaxLines,
        ),
        if (widget.helperText != null) ...[
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              widget.helperText!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withOpacity(0.6),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget? _buildSuffixIcon() {
    // Show password toggle for password fields
    if (widget.type == AppTextFieldType.password) {
      return IconButton(
        icon: Icon(
          _obscureText ? Icons.visibility_off : Icons.visibility,
          size: 20,
          color: Colors.grey,
        ),
        onPressed: () {
          setState(() {
            _obscureText = !_obscureText;
          });
        },
      );
    }

    // Show clear button when there's text and no custom suffix
    if (widget.suffixIcon == null &&
        widget.controller != null &&
        widget.controller!.text.isNotEmpty &&
        widget.enabled &&
        !widget.readOnly) {
      return IconButton(
        icon: Icon(
          Icons.clear,
          size: 20,
          color: Colors.grey,
        ),
        onPressed: () {
          widget.controller!.clear();
          widget.onChanged?.call('');
        },
      );
    }

    return widget.suffixIcon;
  }

  TextInputType _getKeyboardType() {
    switch (widget.type) {
      case AppTextFieldType.email:
        return TextInputType.emailAddress;
      case AppTextFieldType.number:
        return TextInputType.number;
      case AppTextFieldType.phone:
        return TextInputType.phone;
      case AppTextFieldType.url:
        return TextInputType.url;
      case AppTextFieldType.multiline:
        return TextInputType.multiline;
      case AppTextFieldType.text:
      case AppTextFieldType.password:
        return TextInputType.text;
    }
  }

  List<TextInputFormatter>? _getInputFormatters() {
    if (widget.maxLength != null) {
      return [LengthLimitingTextInputFormatter(widget.maxLength)];
    }

    if (widget.type == AppTextFieldType.number) {
      return [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];
    }

    if (widget.type == AppTextFieldType.phone) {
      return [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]'))];
    }

    return null;
  }
}

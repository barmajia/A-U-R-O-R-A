import 'package:aurora/models/customer.dart';
import 'package:aurora/services/supabase.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────
// 🧩 Reusable Input Field Widget (Reduces 70% of decoration code)
// ─────────────────────────────────────────────────────────────
class _LabeledInputField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final Widget? prefixIcon;
  final int? maxLines;
  final bool? enabled;
  final VoidCallback? onFieldSubmitted;
  final String? semanticLabel;

  const _LabeledInputField({
    required this.label,
    this.hint,
    required this.controller,
    this.validator,
    this.keyboardType,
    this.prefixIcon,
    this.maxLines = 1,
    this.enabled = true,
    this.onFieldSubmitted,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final inputDecoration = InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.7)),
      hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.4)),
      border: _border(colorScheme.outline),
      enabledBorder: _border(colorScheme.outline),
      focusedBorder: _border(colorScheme.primary, width: 2),
      errorBorder: _border(colorScheme.error),
      focusedErrorBorder: _border(colorScheme.error, width: 2),
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest,
      prefixIcon: prefixIcon,
      // enabled: enabled,
    );

    return Semantics(
      label: semanticLabel ?? label,
      child: TextFormField(
        controller: controller,
        style: TextStyle(color: colorScheme.onSurface),
        decoration: inputDecoration,
        keyboardType: keyboardType,
        validator: validator,
        maxLines: maxLines,
        enabled: enabled,
        textInputAction: TextInputAction.next,
        onFieldSubmitted: (_) => onFieldSubmitted?.call(),
        inputFormatters: keyboardType == TextInputType.phone
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
      ),
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );
}

// ─────────────────────────────────────────────────────────────
// 🖼️ Main Screen
// ─────────────────────────────────────────────────────────────
class AddCustomerScreen extends StatefulWidget {
  const AddCustomerScreen({super.key});

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedAgeRange;
  bool _isLoading = false;
  bool _isFormDirty = false; // Track if user made changes

  // Age range options - extracted for reusability & i18n
  static const List<Map<String, String>> ageRangeOptions = [
    {'value': 'under_18', 'label': 'Under 18'},
    {'value': '18_25', 'label': '18 - 25'},
    {'value': '26_35', 'label': '26 - 35'},
    {'value': '36_50', 'label': '36 - 50'},
    {'value': '50_plus', 'label': '50+'},
  ];

  // Email validation regex
  static final _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────
  // 🎯 Validation Logic
  // ─────────────────────────────────────────────────────────
  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Name is required';
    if (value.trim().length < 2) return 'Name must be at least 2 characters';
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Phone is required';
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 8) return 'Enter a valid phone number';
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return null; // Optional field
    if (!_emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────
  // 💾 Save Logic
  // ─────────────────────────────────────────────────────────
  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) {
      // Announce validation errors for accessibility
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fix the errors above'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabaseProvider = context.read<SupabaseProvider>();
      final result = await supabaseProvider.addCustomer(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim().replaceAll(RegExp(r'\D'), ''),
        ageRange: _selectedAgeRange,
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (!mounted) return;

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text(result.message),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        Navigator.pop(context, true);
      } else {
        _showError(result.message);
      }
    } catch (e) {
      _showError('Save failed: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // 🎨 Build Method
  // ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Add Customer'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        actions: [
          // Cancel button for better UX
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            tooltip: 'Cancel',
          ),
          const SizedBox(width: 4),
          // Save button with loading state
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveCustomer,
            tooltip: 'Save Customer',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingOverlay(colorScheme)
          : _buildForm(colorScheme, textTheme),
      // Prevent accidental back navigation while saving
      // popScope: PopScope(
      //   canPop: !_isLoading,
      //   onPopInvokedWithResult: (didPop, result) {
      //     if (!didPop && _isFormDirty && !_isLoading) {
      //       _showDiscardConfirmation();
      //     }
      //   },
      // ),
    );
  }

  Widget _buildLoadingOverlay(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surface.withOpacity(0.9),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Saving customer...',
              style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(ColorScheme colorScheme, TextTheme textTheme) {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: ListView(
        padding: const EdgeInsets.all(16),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          // Header section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.person_add,
                      color: colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Customer Information',
                      style: textTheme.titleMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Fields marked with * are required',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onPrimaryContainer.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Name Field
          _LabeledInputField(
            label: 'Name *',
            hint: 'Enter customer full name',
            controller: _nameController,
            validator: _validateName,
            prefixIcon: Icon(
              Icons.person_outline,
              color: colorScheme.onSurface,
            ),
            semanticLabel: 'Customer name, required',
            onFieldSubmitted: () => FocusScope.of(context).nextFocus(),
          ),
          const SizedBox(height: 16),

          // Phone Field
          _LabeledInputField(
            label: 'Phone *',
            hint: 'Enter phone number',
            controller: _phoneController,
            validator: _validatePhone,
            keyboardType: TextInputType.phone,
            prefixIcon: Icon(
              Icons.phone_outlined,
              color: colorScheme.onSurface,
            ),
            semanticLabel: 'Phone number, required',
            onFieldSubmitted: () => FocusScope.of(context).nextFocus(),
          ),
          const SizedBox(height: 16),

          // Age Range Dropdown
          Semantics(
            label: 'Age range selector',
            child: DropdownButtonFormField<String>(
              value: _selectedAgeRange,
              decoration: InputDecoration(
                labelText: 'Age Range',
                labelStyle: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
                border: _border(colorScheme.outline),
                enabledBorder: _border(colorScheme.outline),
                focusedBorder: _border(colorScheme.primary, width: 2),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                prefixIcon: Icon(
                  Icons.calendar_today_outlined,
                  color: colorScheme.onSurface,
                ),
              ),
              dropdownColor: colorScheme.surface,
              items: ageRangeOptions.map((option) {
                return DropdownMenuItem(
                  value: option['value'],
                  child: Text(
                    option['label']!,
                    style: TextStyle(color: colorScheme.onSurface),
                  ),
                );
              }).toList(),
              onChanged: _isLoading
                  ? null
                  : (value) {
                      setState(() {
                        _selectedAgeRange = value;
                        _isFormDirty = true;
                      });
                    },
              borderRadius: BorderRadius.circular(12),
              elevation: 8,
            ),
          ),
          const SizedBox(height: 16),

          // Email Field (Optional)
          _LabeledInputField(
            label: 'Email (Optional)',
            hint: 'customer@example.com',
            controller: _emailController,
            validator: _validateEmail,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icon(
              Icons.email_outlined,
              color: colorScheme.onSurface,
            ),
            semanticLabel: 'Email address, optional',
            onFieldSubmitted: () => FocusScope.of(context).nextFocus(),
          ),
          const SizedBox(height: 16),

          // Notes Field (Optional)
          _LabeledInputField(
            label: 'Notes (Optional)',
            hint: 'Add preferences, history, or special requests...',
            controller: _notesController,
            maxLines: 4,
            prefixIcon: Icon(
              Icons.note_alt_outlined,
              color: colorScheme.onSurface,
            ),
            semanticLabel: 'Additional notes about customer',
          ),
          const SizedBox(height: 32),

          // Save Button - Full width with elevation
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _saveCustomer,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.save, size: 20),
              label: Text(
                _isLoading ? 'Saving...' : 'Save Customer',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );

  void _showDiscardConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
          'You have unsaved changes. Are you sure you want to leave?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context); // Close screen
            },
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }
}

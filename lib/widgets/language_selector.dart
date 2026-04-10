import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aurora/services/user_preferences_service.dart';
import 'package:aurora/l10n/app_localizations.dart';

/// Language selection dialog
class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final userPrefs = context.watch<UserPreferencesService>();
    final currentLanguage = userPrefs.language;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).language,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _LanguageOption(
              languageCode: 'en',
              title: 'English',
              subtitle: 'English',
              isSelected: currentLanguage == 'en',
              onTap: () => _changeLanguage(context, 'en'),
            ),
            const SizedBox(height: 8),
            _LanguageOption(
              languageCode: 'ar',
              title: 'العربية',
              subtitle: 'Arabic',
              isSelected: currentLanguage == 'ar',
              onTap: () => _changeLanguage(context, 'ar'),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(AppLocalizations.of(context).close),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _changeLanguage(BuildContext context, String languageCode) {
    context.read<UserPreferencesService>().setLanguage(languageCode);
    Navigator.of(context).pop();

    // Show restart message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).change_language),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String languageCode;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.languageCode,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isRTL = languageCode == 'ar';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Colors.grey.shade300,
          ),
        ),
        child: Row(
          textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
          children: [
            if (isSelected)
              Icon(Icons.check_circle, color: Theme.of(context).primaryColor),
            if (isSelected) const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: isRTL ? 'Tahoma' : null,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontFamily: isRTL ? 'Tahoma' : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Language selector tile for settings
class LanguageSelectorTile extends StatelessWidget {
  const LanguageSelectorTile({super.key});

  @override
  Widget build(BuildContext context) {
    final userPrefs = context.watch<UserPreferencesService>();
    final currentLanguage = userPrefs.language;

    return ListTile(
      leading: const Icon(Icons.language),
      title: Text(AppLocalizations.of(context).language),
      subtitle: Text(
        currentLanguage == 'ar'
            ? AppLocalizations.of(context).arabic
            : AppLocalizations.of(context).english,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => const LanguageSelector(),
        );
      },
    );
  }
}

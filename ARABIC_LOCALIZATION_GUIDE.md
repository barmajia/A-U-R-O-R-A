# Arabic Language Support Guide

## Overview

This guide explains the Arabic localization implementation in the Aurora E-commerce app.

## Features Added

✅ **Full Arabic (ar) and English (en) support**
✅ **RTL (Right-to-Left) layout support**
✅ **Language switching from settings**
✅ **Persistent language preference**
✅ **Cloud sync for language settings**

## Files Created/Modified

### New Files
- `lib/l10n/app_en.arb` - English translations
- `lib/l10n/app_ar.arb` - Arabic translations  
- `lib/widgets/language_selector.dart` - Language selection widget
- `l10n.yaml` - Localization configuration

### Modified Files
- `pubspec.yaml` - Added `flutter_localizations` and `generate: true`
- `lib/main.dart` - Added localization delegates and locale support
- `lib/services/user_preferences_service.dart` - Added locale getter
- `lib/pages/singup/login.dart` - Example of localized UI

## How to Use Translations

### 1. Import the Localizations

```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
```

### 2. Use Translations in Widgets

```dart
Text(AppLocalizations.of(context).login)
Text(AppLocalizations.of(context).welcome_back)
Text(AppLocalizations.of(context).email)
```

### 3. Use in Validation

```dart
validator: (value) {
  if (value == null || value.isEmpty) {
    return AppLocalizations.of(context).email_required;
  }
  return null;
}
```

## Available Translation Keys

### Authentication
- `login`, `signup`, `logout`, `register`
- `email`, `password`, `confirm_password`
- `forgot_password`, `reset_password`
- `dont_have_account`, `already_have_account`
- `full_name`, `first_name`, `second_name`, `third_name`, `fourth_name`

### Navigation
- `home`, `profile`, `settings`, `notifications`
- `products`, `cart`, `wishlist`, `orders`
- `chat`, `messages`, `analytics`

### Actions
- `save`, `edit`, `delete`, `cancel`, `confirm`
- `next`, `back`, `continue_btn`, `skip`
- `loading`, `retry`, `search`

### Messages
- `login_success`, `login_failed`
- `signup_success`, `signup_failed`
- `profile_updated`, `product_added`
- `invalid_email`, `password_required`

### Settings
- `language`, `english`, `arabic`
- `dark_mode`, `light_mode`, `system_theme`
- `change_language`, `change_password`

## Language Selector Widget

### In Settings Page

```dart
import 'package:aurora/widgets/language_selector.dart';

// Use the tile
LanguageSelectorTile()

// Or show dialog
showDialog(
  context: context,
  builder: (context) => const LanguageSelector(),
);
```

## RTL Support

The app automatically switches to RTL layout when Arabic is selected:

```dart
// Text direction is automatic based on locale
Text(
  AppLocalizations.of(context).welcome,
  textDirection: TextDirection.rtl, // For Arabic
)
```

## Changing Language Programmatically

```dart
// From anywhere in the app
context.read<UserPreferencesService>().setLanguage('ar');
// or
context.read<UserPreferencesService>().setLanguage('en');
```

## Getting Current Locale

```dart
final userPrefs = context.watch<UserPreferencesService>();
final locale = userPrefs.locale; // Returns Locale('ar') or Locale('en')
final language = userPrefs.language; // Returns 'ar' or 'en'
```

## Adding New Translations

### Step 1: Add to English (app_en.arb)

```json
{
  "my_new_key": "My New Translation",
  "@my_new_key": {
    "description": "Description for translators"
  }
}
```

### Step 2: Add to Arabic (app_ar.arb)

```json
{
  "my_new_key": "ترجمتي الجديدة",
  "@my_new_key": {
    "description": "وصف للمترجمين"
  }
}
```

### Step 3: Regenerate

```bash
flutter gen-l10n
```

## Best Practices

1. **Always use `AppLocalizations.of(context)`** for user-facing text
2. **Don't hardcode strings** in your widgets
3. **Use meaningful key names** (e.g., `login_button` instead of `button1`)
4. **Add descriptions** for complex translations using `@key`
5. **Test both languages** before deploying
6. **Consider text length** - Arabic text can be longer than English

## Common Patterns

### Buttons
```dart
ElevatedButton(
  onPressed: () {},
  child: Text(AppLocalizations.of(context).save),
)
```

### Input Fields
```dart
TextFormField(
  decoration: InputDecoration(
    labelText: AppLocalizations.of(context).email,
    hintText: AppLocalizations.of(context).email_placeholder,
  ),
)
```

### Dialogs
```dart
AlertDialog(
  title: Text(AppLocalizations.of(context).are_you_sure),
  content: Text(AppLocalizations.of(context).delete_product_confirm),
  actions: [
    TextButton(
      onPressed: () => Navigator.pop(context),
      child: Text(AppLocalizations.of(context).cancel),
    ),
    TextButton(
      onPressed: () {},
      child: Text(AppLocalizations.of(context).delete),
    ),
  ],
)
```

### SnackBars
```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text(AppLocalizations.of(context).product_added),
  ),
);
```

## Testing

### Test Language Switching
1. Open app settings
2. Tap on Language
3. Select Arabic
4. Verify all text changes to Arabic
5. Verify layout is RTL
6. Switch back to English
7. Verify everything returns to English

### Test Persistence
1. Select Arabic
2. Close the app
3. Reopen the app
4. Verify Arabic is still selected

## Troubleshooting

### "The method 'of' wasn't found"
Make sure you imported:
```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
```

### "Null check operator used on a null value"
Ensure `MaterialApp` has `localizationsDelegates` set up correctly.

### Arabic text not showing RTL
Check that the locale is set correctly:
```dart
locale: Locale('ar'),
```

### Generated files not found
Run:
```bash
flutter clean
flutter pub get
flutter gen-l10n
```

## Next Steps

1. Update all pages to use translations
2. Add more translation keys as needed
3. Test with native Arabic speakers
4. Consider adding more languages
5. Add locale-specific formatting (dates, numbers, currency)

## Resources

- [Flutter Internationalization](https://docs.flutter.dev/development/accessibility-and-localization/internationalization)
- [ARB Format](https://github.com/google/app-resource-bundle)
- [RTL Guidelines](https://material.io/design/communication/writing-systems.html#rtl-support)

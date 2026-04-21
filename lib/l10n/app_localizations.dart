import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @app_title.
  ///
  /// In en, this message translates to:
  /// **'Aurora E-commerce'**
  String get app_title;

  /// No description provided for @app_title_desc.
  ///
  /// In en, this message translates to:
  /// **'Aurora E-commerce Platform'**
  String get app_title_desc;

  /// No description provided for @welcome_back.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back!'**
  String get welcome_back;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @signup.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signup;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @confirm_password.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirm_password;

  /// No description provided for @forgot_password.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgot_password;

  /// No description provided for @reset_password.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get reset_password;

  /// No description provided for @send_reset_link.
  ///
  /// In en, this message translates to:
  /// **'Send Reset Link'**
  String get send_reset_link;

  /// No description provided for @back_to_login.
  ///
  /// In en, this message translates to:
  /// **'Back to Login'**
  String get back_to_login;

  /// No description provided for @or_continue_with.
  ///
  /// In en, this message translates to:
  /// **'Or continue with'**
  String get or_continue_with;

  /// No description provided for @dont_have_account.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get dont_have_account;

  /// No description provided for @already_have_account.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get already_have_account;

  /// No description provided for @create_account.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get create_account;

  /// No description provided for @full_name.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get full_name;

  /// No description provided for @first_name.
  ///
  /// In en, this message translates to:
  /// **'First Name'**
  String get first_name;

  /// No description provided for @second_name.
  ///
  /// In en, this message translates to:
  /// **'Second Name'**
  String get second_name;

  /// No description provided for @third_name.
  ///
  /// In en, this message translates to:
  /// **'Third Name'**
  String get third_name;

  /// No description provided for @fourth_name.
  ///
  /// In en, this message translates to:
  /// **'Fourth Name'**
  String get fourth_name;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// No description provided for @account_type.
  ///
  /// In en, this message translates to:
  /// **'Account Type'**
  String get account_type;

  /// No description provided for @buyer.
  ///
  /// In en, this message translates to:
  /// **'Buyer'**
  String get buyer;

  /// No description provided for @seller.
  ///
  /// In en, this message translates to:
  /// **'Seller'**
  String get seller;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @save_changes.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get save_changes;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @warning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get warning;

  /// No description provided for @info.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get info;

  /// No description provided for @user.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get user;

  /// No description provided for @guest.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get guest;

  /// No description provided for @login_success.
  ///
  /// In en, this message translates to:
  /// **'Login successful'**
  String get login_success;

  /// No description provided for @login_failed.
  ///
  /// In en, this message translates to:
  /// **'Login failed'**
  String get login_failed;

  /// No description provided for @signup_success.
  ///
  /// In en, this message translates to:
  /// **'Account created successfully'**
  String get signup_success;

  /// No description provided for @signup_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create account'**
  String get signup_failed;

  /// No description provided for @logout_success.
  ///
  /// In en, this message translates to:
  /// **'Logged out successfully'**
  String get logout_success;

  /// No description provided for @password_reset_sent.
  ///
  /// In en, this message translates to:
  /// **'Password reset link sent to your email'**
  String get password_reset_sent;

  /// No description provided for @password_reset_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send password reset link'**
  String get password_reset_failed;

  /// No description provided for @invalid_email.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get invalid_email;

  /// No description provided for @invalid_password.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get invalid_password;

  /// No description provided for @passwords_do_not_match.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwords_do_not_match;

  /// No description provided for @email_required.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get email_required;

  /// No description provided for @password_required.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get password_required;

  /// No description provided for @name_required.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get name_required;

  /// No description provided for @phone_required.
  ///
  /// In en, this message translates to:
  /// **'Phone number is required'**
  String get phone_required;

  /// No description provided for @location_required.
  ///
  /// In en, this message translates to:
  /// **'Location is required'**
  String get location_required;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @notification_settings.
  ///
  /// In en, this message translates to:
  /// **'Notification Settings'**
  String get notification_settings;

  /// No description provided for @mark_all_read.
  ///
  /// In en, this message translates to:
  /// **'Mark All as Read'**
  String get mark_all_read;

  /// No description provided for @no_notifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get no_notifications;

  /// No description provided for @delete_notification.
  ///
  /// In en, this message translates to:
  /// **'Delete Notification'**
  String get delete_notification;

  /// No description provided for @delete_notification_confirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this notification?'**
  String get delete_notification_confirm;

  /// No description provided for @notification_deleted.
  ///
  /// In en, this message translates to:
  /// **'Notification deleted'**
  String get notification_deleted;

  /// No description provided for @my_profile.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get my_profile;

  /// No description provided for @edit_profile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get edit_profile;

  /// No description provided for @profile_updated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully'**
  String get profile_updated;

  /// No description provided for @profile_save_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save profile'**
  String get profile_save_failed;

  /// No description provided for @profile_load_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load profile'**
  String get profile_load_failed;

  /// No description provided for @first_name_placeholder.
  ///
  /// In en, this message translates to:
  /// **'Enter your first name'**
  String get first_name_placeholder;

  /// No description provided for @second_name_placeholder.
  ///
  /// In en, this message translates to:
  /// **'Enter your second name'**
  String get second_name_placeholder;

  /// No description provided for @third_name_placeholder.
  ///
  /// In en, this message translates to:
  /// **'Enter your third name'**
  String get third_name_placeholder;

  /// No description provided for @fourth_name_placeholder.
  ///
  /// In en, this message translates to:
  /// **'Enter your fourth name'**
  String get fourth_name_placeholder;

  /// No description provided for @email_placeholder.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get email_placeholder;

  /// No description provided for @phone_placeholder.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number'**
  String get phone_placeholder;

  /// No description provided for @location_placeholder.
  ///
  /// In en, this message translates to:
  /// **'Enter your location'**
  String get location_placeholder;

  /// No description provided for @products.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get products;

  /// No description provided for @product.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get product;

  /// No description provided for @all_products.
  ///
  /// In en, this message translates to:
  /// **'All Products'**
  String get all_products;

  /// No description provided for @my_products.
  ///
  /// In en, this message translates to:
  /// **'My Products'**
  String get my_products;

  /// No description provided for @add_product.
  ///
  /// In en, this message translates to:
  /// **'Add Product'**
  String get add_product;

  /// No description provided for @edit_product.
  ///
  /// In en, this message translates to:
  /// **'Edit Product'**
  String get edit_product;

  /// No description provided for @delete_product.
  ///
  /// In en, this message translates to:
  /// **'Delete Product'**
  String get delete_product;

  /// No description provided for @delete_product_confirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this product?'**
  String get delete_product_confirm;

  /// No description provided for @product_name.
  ///
  /// In en, this message translates to:
  /// **'Product Name'**
  String get product_name;

  /// No description provided for @product_description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get product_description;

  /// No description provided for @product_price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get product_price;

  /// No description provided for @product_category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get product_category;

  /// No description provided for @product_brand.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get product_brand;

  /// No description provided for @product_stock.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get product_stock;

  /// No description provided for @product_images.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get product_images;

  /// No description provided for @product_added.
  ///
  /// In en, this message translates to:
  /// **'Product added successfully'**
  String get product_added;

  /// No description provided for @product_updated.
  ///
  /// In en, this message translates to:
  /// **'Product updated successfully'**
  String get product_updated;

  /// No description provided for @product_deleted.
  ///
  /// In en, this message translates to:
  /// **'Product deleted successfully'**
  String get product_deleted;

  /// No description provided for @product_save_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save product'**
  String get product_save_failed;

  /// No description provided for @out_of_stock.
  ///
  /// In en, this message translates to:
  /// **'Out of Stock'**
  String get out_of_stock;

  /// No description provided for @in_stock.
  ///
  /// In en, this message translates to:
  /// **'In Stock'**
  String get in_stock;

  /// No description provided for @search_products.
  ///
  /// In en, this message translates to:
  /// **'Search products...'**
  String get search_products;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sort;

  /// No description provided for @sort_by.
  ///
  /// In en, this message translates to:
  /// **'Sort By'**
  String get sort_by;

  /// No description provided for @price_low_to_high.
  ///
  /// In en, this message translates to:
  /// **'Price: Low to High'**
  String get price_low_to_high;

  /// No description provided for @price_high_to_low.
  ///
  /// In en, this message translates to:
  /// **'Price: High to Low'**
  String get price_high_to_low;

  /// No description provided for @name_a_to_z.
  ///
  /// In en, this message translates to:
  /// **'Name: A to Z'**
  String get name_a_to_z;

  /// No description provided for @name_z_to_a.
  ///
  /// In en, this message translates to:
  /// **'Name: Z to A'**
  String get name_z_to_a;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @all_categories.
  ///
  /// In en, this message translates to:
  /// **'All Categories'**
  String get all_categories;

  /// No description provided for @electronics.
  ///
  /// In en, this message translates to:
  /// **'Electronics'**
  String get electronics;

  /// No description provided for @clothing.
  ///
  /// In en, this message translates to:
  /// **'Clothing'**
  String get clothing;

  /// No description provided for @home_garden.
  ///
  /// In en, this message translates to:
  /// **'Home & Garden'**
  String get home_garden;

  /// No description provided for @sports.
  ///
  /// In en, this message translates to:
  /// **'Sports'**
  String get sports;

  /// No description provided for @books.
  ///
  /// In en, this message translates to:
  /// **'Books'**
  String get books;

  /// No description provided for @toys.
  ///
  /// In en, this message translates to:
  /// **'Toys'**
  String get toys;

  /// No description provided for @health_beauty.
  ///
  /// In en, this message translates to:
  /// **'Health & Beauty'**
  String get health_beauty;

  /// No description provided for @automotive.
  ///
  /// In en, this message translates to:
  /// **'Automotive'**
  String get automotive;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @cart.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get cart;

  /// No description provided for @my_cart.
  ///
  /// In en, this message translates to:
  /// **'My Cart'**
  String get my_cart;

  /// No description provided for @add_to_cart.
  ///
  /// In en, this message translates to:
  /// **'Add to Cart'**
  String get add_to_cart;

  /// No description provided for @remove_from_cart.
  ///
  /// In en, this message translates to:
  /// **'Remove from Cart'**
  String get remove_from_cart;

  /// No description provided for @view_cart.
  ///
  /// In en, this message translates to:
  /// **'View Cart'**
  String get view_cart;

  /// No description provided for @checkout.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get checkout;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @subtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get subtotal;

  /// No description provided for @tax.
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get tax;

  /// No description provided for @shipping.
  ///
  /// In en, this message translates to:
  /// **'Shipping'**
  String get shipping;

  /// No description provided for @discount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get discount;

  /// No description provided for @apply_discount.
  ///
  /// In en, this message translates to:
  /// **'Apply Discount'**
  String get apply_discount;

  /// No description provided for @promo_code.
  ///
  /// In en, this message translates to:
  /// **'Promo Code'**
  String get promo_code;

  /// No description provided for @empty_cart.
  ///
  /// In en, this message translates to:
  /// **'Your cart is empty'**
  String get empty_cart;

  /// No description provided for @continue_shopping.
  ///
  /// In en, this message translates to:
  /// **'Continue Shopping'**
  String get continue_shopping;

  /// No description provided for @wishlist.
  ///
  /// In en, this message translates to:
  /// **'Wishlist'**
  String get wishlist;

  /// No description provided for @my_wishlist.
  ///
  /// In en, this message translates to:
  /// **'My Wishlist'**
  String get my_wishlist;

  /// No description provided for @add_to_wishlist.
  ///
  /// In en, this message translates to:
  /// **'Add to Wishlist'**
  String get add_to_wishlist;

  /// No description provided for @remove_from_wishlist.
  ///
  /// In en, this message translates to:
  /// **'Remove from Wishlist'**
  String get remove_from_wishlist;

  /// No description provided for @remove_item.
  ///
  /// In en, this message translates to:
  /// **'Remove Item'**
  String get remove_item;

  /// No description provided for @remove_from_wishlist_confirm.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{productName}\" from your wishlist?'**
  String remove_from_wishlist_confirm(Object productName);

  /// No description provided for @removed_from_wishlist.
  ///
  /// In en, this message translates to:
  /// **'Removed from wishlist'**
  String get removed_from_wishlist;

  /// No description provided for @empty_wishlist.
  ///
  /// In en, this message translates to:
  /// **'Your wishlist is empty'**
  String get empty_wishlist;

  /// No description provided for @browse_products.
  ///
  /// In en, this message translates to:
  /// **'Browse Products'**
  String get browse_products;

  /// No description provided for @orders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get orders;

  /// No description provided for @my_orders.
  ///
  /// In en, this message translates to:
  /// **'My Orders'**
  String get my_orders;

  /// No description provided for @order.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get order;

  /// No description provided for @order_id.
  ///
  /// In en, this message translates to:
  /// **'Order ID'**
  String get order_id;

  /// No description provided for @order_date.
  ///
  /// In en, this message translates to:
  /// **'Order Date'**
  String get order_date;

  /// No description provided for @order_status.
  ///
  /// In en, this message translates to:
  /// **'Order Status'**
  String get order_status;

  /// No description provided for @order_total.
  ///
  /// In en, this message translates to:
  /// **'Order Total'**
  String get order_total;

  /// No description provided for @order_details.
  ///
  /// In en, this message translates to:
  /// **'Order Details'**
  String get order_details;

  /// No description provided for @order_placed.
  ///
  /// In en, this message translates to:
  /// **'Order placed successfully'**
  String get order_placed;

  /// No description provided for @order_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to place order'**
  String get order_failed;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @confirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get confirmed;

  /// No description provided for @processing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get processing;

  /// No description provided for @shipped.
  ///
  /// In en, this message translates to:
  /// **'Shipped'**
  String get shipped;

  /// No description provided for @delivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get delivered;

  /// No description provided for @cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelled;

  /// No description provided for @refunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get refunded;

  /// No description provided for @track_order.
  ///
  /// In en, this message translates to:
  /// **'Track Order'**
  String get track_order;

  /// No description provided for @cancel_order.
  ///
  /// In en, this message translates to:
  /// **'Cancel Order'**
  String get cancel_order;

  /// No description provided for @cancel_order_confirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to cancel this order?'**
  String get cancel_order_confirm;

  /// No description provided for @chat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// No description provided for @chats.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chats;

  /// No description provided for @messages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messages;

  /// No description provided for @message.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get message;

  /// No description provided for @type_message.
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get type_message;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @send_message.
  ///
  /// In en, this message translates to:
  /// **'Send Message'**
  String get send_message;

  /// No description provided for @no_chats.
  ///
  /// In en, this message translates to:
  /// **'No chats yet'**
  String get no_chats;

  /// No description provided for @no_messages.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get no_messages;

  /// No description provided for @start_chat.
  ///
  /// In en, this message translates to:
  /// **'Start Chat'**
  String get start_chat;

  /// No description provided for @chat_with.
  ///
  /// In en, this message translates to:
  /// **'Chat with'**
  String get chat_with;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @typing.
  ///
  /// In en, this message translates to:
  /// **'Typing...'**
  String get typing;

  /// No description provided for @seen.
  ///
  /// In en, this message translates to:
  /// **'Seen'**
  String get seen;

  /// No description provided for @image_message.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get image_message;

  /// No description provided for @file_message.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get file_message;

  /// No description provided for @deal_proposal.
  ///
  /// In en, this message translates to:
  /// **'Deal Proposal'**
  String get deal_proposal;

  /// No description provided for @view_deal.
  ///
  /// In en, this message translates to:
  /// **'View Deal'**
  String get view_deal;

  /// No description provided for @accept_deal.
  ///
  /// In en, this message translates to:
  /// **'Accept Deal'**
  String get accept_deal;

  /// No description provided for @reject_deal.
  ///
  /// In en, this message translates to:
  /// **'Reject Deal'**
  String get reject_deal;

  /// No description provided for @deal_accepted.
  ///
  /// In en, this message translates to:
  /// **'Deal accepted'**
  String get deal_accepted;

  /// No description provided for @deal_rejected.
  ///
  /// In en, this message translates to:
  /// **'Deal rejected'**
  String get deal_rejected;

  /// No description provided for @commission_rate.
  ///
  /// In en, this message translates to:
  /// **'Commission Rate'**
  String get commission_rate;

  /// No description provided for @negotiate.
  ///
  /// In en, this message translates to:
  /// **'Negotiate'**
  String get negotiate;

  /// No description provided for @analytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get analytics;

  /// No description provided for @sales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get sales;

  /// No description provided for @revenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get revenue;

  /// No description provided for @views.
  ///
  /// In en, this message translates to:
  /// **'Views'**
  String get views;

  /// No description provided for @customers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get customers;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @this_week.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get this_week;

  /// No description provided for @this_month.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get this_month;

  /// No description provided for @this_year.
  ///
  /// In en, this message translates to:
  /// **'This Year'**
  String get this_year;

  /// No description provided for @total_sales.
  ///
  /// In en, this message translates to:
  /// **'Total Sales'**
  String get total_sales;

  /// No description provided for @total_revenue.
  ///
  /// In en, this message translates to:
  /// **'Total Revenue'**
  String get total_revenue;

  /// No description provided for @total_orders.
  ///
  /// In en, this message translates to:
  /// **'Total Orders'**
  String get total_orders;

  /// No description provided for @total_products.
  ///
  /// In en, this message translates to:
  /// **'Total Products'**
  String get total_products;

  /// No description provided for @average_order_value.
  ///
  /// In en, this message translates to:
  /// **'Average Order Value'**
  String get average_order_value;

  /// No description provided for @top_products.
  ///
  /// In en, this message translates to:
  /// **'Top Products'**
  String get top_products;

  /// No description provided for @recent_sales.
  ///
  /// In en, this message translates to:
  /// **'Recent Sales'**
  String get recent_sales;

  /// No description provided for @sales_chart.
  ///
  /// In en, this message translates to:
  /// **'Sales Chart'**
  String get sales_chart;

  /// No description provided for @revenue_chart.
  ///
  /// In en, this message translates to:
  /// **'Revenue Chart'**
  String get revenue_chart;

  /// No description provided for @seller_dashboard.
  ///
  /// In en, this message translates to:
  /// **'Seller Dashboard'**
  String get seller_dashboard;

  /// No description provided for @become_seller.
  ///
  /// In en, this message translates to:
  /// **'Become a Seller'**
  String get become_seller;

  /// No description provided for @seller_profile.
  ///
  /// In en, this message translates to:
  /// **'Seller Profile'**
  String get seller_profile;

  /// No description provided for @seller_info.
  ///
  /// In en, this message translates to:
  /// **'Seller Information'**
  String get seller_info;

  /// No description provided for @seller_verified.
  ///
  /// In en, this message translates to:
  /// **'Verified Seller'**
  String get seller_verified;

  /// No description provided for @seller_not_verified.
  ///
  /// In en, this message translates to:
  /// **'Not Verified'**
  String get seller_not_verified;

  /// No description provided for @is_verified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get is_verified;

  /// No description provided for @verification_status.
  ///
  /// In en, this message translates to:
  /// **'Verification Status'**
  String get verification_status;

  /// No description provided for @account_balance.
  ///
  /// In en, this message translates to:
  /// **'Account Balance'**
  String get account_balance;

  /// No description provided for @withdraw.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get withdraw;

  /// No description provided for @withdrawal_history.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal History'**
  String get withdrawal_history;

  /// No description provided for @settings_general.
  ///
  /// In en, this message translates to:
  /// **'General Settings'**
  String get settings_general;

  /// No description provided for @settings_account.
  ///
  /// In en, this message translates to:
  /// **'Account Settings'**
  String get settings_account;

  /// No description provided for @settings_privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Settings'**
  String get settings_privacy;

  /// No description provided for @settings_security.
  ///
  /// In en, this message translates to:
  /// **'Security Settings'**
  String get settings_security;

  /// No description provided for @settings_notifications.
  ///
  /// In en, this message translates to:
  /// **'Notification Settings'**
  String get settings_notifications;

  /// No description provided for @settings_language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settings_language;

  /// No description provided for @settings_theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settings_theme;

  /// No description provided for @dark_mode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get dark_mode;

  /// No description provided for @light_mode.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get light_mode;

  /// No description provided for @system_theme.
  ///
  /// In en, this message translates to:
  /// **'System Theme'**
  String get system_theme;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @arabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get arabic;

  /// No description provided for @change_language.
  ///
  /// In en, this message translates to:
  /// **'Change Language'**
  String get change_language;

  /// No description provided for @change_password.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get change_password;

  /// No description provided for @current_password.
  ///
  /// In en, this message translates to:
  /// **'Current Password'**
  String get current_password;

  /// No description provided for @new_password.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get new_password;

  /// No description provided for @confirm_new_password.
  ///
  /// In en, this message translates to:
  /// **'Confirm New Password'**
  String get confirm_new_password;

  /// No description provided for @password_changed.
  ///
  /// In en, this message translates to:
  /// **'Password changed successfully'**
  String get password_changed;

  /// No description provided for @password_change_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to change password'**
  String get password_change_failed;

  /// No description provided for @biometric.
  ///
  /// In en, this message translates to:
  /// **'Biometric Authentication'**
  String get biometric;

  /// No description provided for @enable_biometric.
  ///
  /// In en, this message translates to:
  /// **'Enable Biometric'**
  String get enable_biometric;

  /// No description provided for @disable_biometric.
  ///
  /// In en, this message translates to:
  /// **'Disable Biometric'**
  String get disable_biometric;

  /// No description provided for @biometric_enabled.
  ///
  /// In en, this message translates to:
  /// **'Biometric authentication enabled'**
  String get biometric_enabled;

  /// No description provided for @biometric_disabled.
  ///
  /// In en, this message translates to:
  /// **'Biometric authentication disabled'**
  String get biometric_disabled;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @search_hint.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get search_hint;

  /// No description provided for @no_results.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get no_results;

  /// No description provided for @try_different_search.
  ///
  /// In en, this message translates to:
  /// **'Try a different search term'**
  String get try_different_search;

  /// No description provided for @filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// No description provided for @price_range.
  ///
  /// In en, this message translates to:
  /// **'Price Range'**
  String get price_range;

  /// No description provided for @min_price.
  ///
  /// In en, this message translates to:
  /// **'Min Price'**
  String get min_price;

  /// No description provided for @max_price.
  ///
  /// In en, this message translates to:
  /// **'Max Price'**
  String get max_price;

  /// No description provided for @apply_filters.
  ///
  /// In en, this message translates to:
  /// **'Apply Filters'**
  String get apply_filters;

  /// No description provided for @clear_filters.
  ///
  /// In en, this message translates to:
  /// **'Clear Filters'**
  String get clear_filters;

  /// No description provided for @shipping_address.
  ///
  /// In en, this message translates to:
  /// **'Shipping Address'**
  String get shipping_address;

  /// No description provided for @billing_address.
  ///
  /// In en, this message translates to:
  /// **'Billing Address'**
  String get billing_address;

  /// No description provided for @address_line_1.
  ///
  /// In en, this message translates to:
  /// **'Address Line 1'**
  String get address_line_1;

  /// No description provided for @address_line_2.
  ///
  /// In en, this message translates to:
  /// **'Address Line 2'**
  String get address_line_2;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// No description provided for @state.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get state;

  /// No description provided for @country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// No description provided for @postal_code.
  ///
  /// In en, this message translates to:
  /// **'Postal Code'**
  String get postal_code;

  /// No description provided for @zip_code.
  ///
  /// In en, this message translates to:
  /// **'ZIP Code'**
  String get zip_code;

  /// No description provided for @select_country.
  ///
  /// In en, this message translates to:
  /// **'Select Country'**
  String get select_country;

  /// No description provided for @select_city.
  ///
  /// In en, this message translates to:
  /// **'Select City'**
  String get select_city;

  /// No description provided for @payment_method.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get payment_method;

  /// No description provided for @payment_methods.
  ///
  /// In en, this message translates to:
  /// **'Payment Methods'**
  String get payment_methods;

  /// No description provided for @add_payment_method.
  ///
  /// In en, this message translates to:
  /// **'Add Payment Method'**
  String get add_payment_method;

  /// No description provided for @credit_card.
  ///
  /// In en, this message translates to:
  /// **'Credit Card'**
  String get credit_card;

  /// No description provided for @debit_card.
  ///
  /// In en, this message translates to:
  /// **'Debit Card'**
  String get debit_card;

  /// No description provided for @cash_on_delivery.
  ///
  /// In en, this message translates to:
  /// **'Cash on Delivery'**
  String get cash_on_delivery;

  /// No description provided for @bank_transfer.
  ///
  /// In en, this message translates to:
  /// **'Bank Transfer'**
  String get bank_transfer;

  /// No description provided for @wallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get wallet;

  /// No description provided for @card_number.
  ///
  /// In en, this message translates to:
  /// **'Card Number'**
  String get card_number;

  /// No description provided for @card_holder.
  ///
  /// In en, this message translates to:
  /// **'Card Holder Name'**
  String get card_holder;

  /// No description provided for @expiry_date.
  ///
  /// In en, this message translates to:
  /// **'Expiry Date'**
  String get expiry_date;

  /// No description provided for @cvv.
  ///
  /// In en, this message translates to:
  /// **'CVV'**
  String get cvv;

  /// No description provided for @reviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get reviews;

  /// No description provided for @review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// No description provided for @write_review.
  ///
  /// In en, this message translates to:
  /// **'Write a Review'**
  String get write_review;

  /// No description provided for @rating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get rating;

  /// No description provided for @ratings.
  ///
  /// In en, this message translates to:
  /// **'Ratings'**
  String get ratings;

  /// No description provided for @no_reviews.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet'**
  String get no_reviews;

  /// No description provided for @add_review.
  ///
  /// In en, this message translates to:
  /// **'Add Review'**
  String get add_review;

  /// No description provided for @review_title.
  ///
  /// In en, this message translates to:
  /// **'Review Title'**
  String get review_title;

  /// No description provided for @review_comment.
  ///
  /// In en, this message translates to:
  /// **'Your Review'**
  String get review_comment;

  /// No description provided for @review_submitted.
  ///
  /// In en, this message translates to:
  /// **'Review submitted successfully'**
  String get review_submitted;

  /// No description provided for @review_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit review'**
  String get review_failed;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @help_center.
  ///
  /// In en, this message translates to:
  /// **'Help Center'**
  String get help_center;

  /// No description provided for @faq.
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get faq;

  /// No description provided for @contact_us.
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get contact_us;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @about_us.
  ///
  /// In en, this message translates to:
  /// **'About Us'**
  String get about_us;

  /// No description provided for @terms_of_service.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get terms_of_service;

  /// No description provided for @privacy_policy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacy_policy;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @are_you_sure.
  ///
  /// In en, this message translates to:
  /// **'Are you sure?'**
  String get are_you_sure;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @finish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get finish;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @continue_btn.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continue_btn;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @learn_more.
  ///
  /// In en, this message translates to:
  /// **'Learn More'**
  String get learn_more;

  /// No description provided for @view_all.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get view_all;

  /// No description provided for @see_more.
  ///
  /// In en, this message translates to:
  /// **'See More'**
  String get see_more;

  /// No description provided for @see_less.
  ///
  /// In en, this message translates to:
  /// **'See Less'**
  String get see_less;

  /// No description provided for @image_pick_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to pick image'**
  String get image_pick_failed;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @take_photo.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get take_photo;

  /// No description provided for @choose_from_gallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get choose_from_gallery;

  /// No description provided for @upload_image.
  ///
  /// In en, this message translates to:
  /// **'Upload Image'**
  String get upload_image;

  /// No description provided for @remove_image.
  ///
  /// In en, this message translates to:
  /// **'Remove Image'**
  String get remove_image;

  /// No description provided for @permission_required.
  ///
  /// In en, this message translates to:
  /// **'Permission Required'**
  String get permission_required;

  /// No description provided for @permission_denied.
  ///
  /// In en, this message translates to:
  /// **'Permission denied'**
  String get permission_denied;

  /// No description provided for @permission_location.
  ///
  /// In en, this message translates to:
  /// **'Location permission is required for this feature'**
  String get permission_location;

  /// No description provided for @permission_camera.
  ///
  /// In en, this message translates to:
  /// **'Camera permission is required'**
  String get permission_camera;

  /// No description provided for @permission_storage.
  ///
  /// In en, this message translates to:
  /// **'Storage permission is required'**
  String get permission_storage;

  /// No description provided for @permission_notification.
  ///
  /// In en, this message translates to:
  /// **'Notification permission is required'**
  String get permission_notification;

  /// No description provided for @open_settings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get open_settings;

  /// No description provided for @connection_lost.
  ///
  /// In en, this message translates to:
  /// **'Connection lost'**
  String get connection_lost;

  /// No description provided for @check_internet.
  ///
  /// In en, this message translates to:
  /// **'Please check your internet connection'**
  String get check_internet;

  /// No description provided for @server_error.
  ///
  /// In en, this message translates to:
  /// **'Server error, please try again later'**
  String get server_error;

  /// No description provided for @something_went_wrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get something_went_wrong;

  /// No description provided for @try_again.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get try_again;

  /// No description provided for @copied_to_clipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copied_to_clipboard;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @qr_code.
  ///
  /// In en, this message translates to:
  /// **'QR Code'**
  String get qr_code;

  /// No description provided for @scan_qr.
  ///
  /// In en, this message translates to:
  /// **'Scan QR Code'**
  String get scan_qr;

  /// No description provided for @qr_product_info.
  ///
  /// In en, this message translates to:
  /// **'Product Information'**
  String get qr_product_info;

  /// No description provided for @nearby.
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get nearby;

  /// No description provided for @nearby_sellers.
  ///
  /// In en, this message translates to:
  /// **'Nearby Sellers'**
  String get nearby_sellers;

  /// No description provided for @nearby_products.
  ///
  /// In en, this message translates to:
  /// **'Nearby Products'**
  String get nearby_products;

  /// No description provided for @distance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distance;

  /// No description provided for @km.
  ///
  /// In en, this message translates to:
  /// **'km'**
  String get km;

  /// No description provided for @m.
  ///
  /// In en, this message translates to:
  /// **'m'**
  String get m;

  /// No description provided for @deals.
  ///
  /// In en, this message translates to:
  /// **'Deals'**
  String get deals;

  /// No description provided for @my_deals.
  ///
  /// In en, this message translates to:
  /// **'My Deals'**
  String get my_deals;

  /// No description provided for @active_deals.
  ///
  /// In en, this message translates to:
  /// **'Active Deals'**
  String get active_deals;

  /// No description provided for @completed_deals.
  ///
  /// In en, this message translates to:
  /// **'Completed Deals'**
  String get completed_deals;

  /// No description provided for @deal_status.
  ///
  /// In en, this message translates to:
  /// **'Deal Status'**
  String get deal_status;

  /// No description provided for @create_deal.
  ///
  /// In en, this message translates to:
  /// **'Create Deal'**
  String get create_deal;

  /// No description provided for @update_deal.
  ///
  /// In en, this message translates to:
  /// **'Update Deal'**
  String get update_deal;

  /// No description provided for @presence_online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get presence_online;

  /// No description provided for @presence_offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get presence_offline;

  /// No description provided for @presence_away.
  ///
  /// In en, this message translates to:
  /// **'Away'**
  String get presence_away;

  /// No description provided for @presence_busy.
  ///
  /// In en, this message translates to:
  /// **'Busy'**
  String get presence_busy;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @pull_to_refresh.
  ///
  /// In en, this message translates to:
  /// **'Pull to refresh'**
  String get pull_to_refresh;

  /// No description provided for @last_updated.
  ///
  /// In en, this message translates to:
  /// **'Last updated'**
  String get last_updated;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

  // Product Form Screen
  String get productFormTitle;
  String get productNameLabel;
  String get productNameHint;
  String get categoryLabel;
  String get subcategoryLabel;
  String get brandLabel;
  String get priceLabel;
  String get priceHint;
  String get stockLabel;
  String get stockHint;
  String get descriptionLabel;
  String get descriptionHint;
  String get imagesLabel;
  String get addImageBtn;
  String get removeImageBtn;
  String get saveBtn;
  String get cancelBtn;
  String get requiredFieldError;
  String get invalidPriceError;
  String get invalidStockError;
  String get minOneImageError;

  // Categories
  String get categoryFashion;
  String get categoryElectronics;
  String get categoryLighting;
  String get categoryHome;
  String get categoryBeauty;
  String get categorySports;

  // Fashion Subcategories
  String get subcatMenShirts;
  String get subcatMenPants;
  String get subcatWomenDresses;
  String get subcatWomenTops;
  String get subcatKidsClothing;
  String get subcatShoes;
  String get subcatAccessories;

  // Electronics Subcategories
  String get subcatSmartphones;
  String get subcatLaptops;
  String get subcatTablets;
  String get subcatAudio;
  String get subcatCameras;
  String get subcatWearables;
  String get subcatGaming;

  // Lighting Subcategories
  String get subcatBulbs;
  String get subcatFixtures;
  String get subcatSmartLights;
  String get subcatOutdoorLights;
  String get subcatCommercialLights;

  // Home Subcategories
  String get subcatFurniture;
  String get subcatDecor;
  String get subcatKitchen;
  String get subcatBedding;
  String get subcatStorage;
  String get subcatBath;

  // Beauty Subcategories
  String get subcatSkincare;
  String get subcatMakeup;
  String get subcatHaircare;
  String get subcatFragrance;
  String get subcatPersonalCare;

  // Sports Subcategories
  String get subcatFitness;
  String get subcatOutdoorSports;
  String get subcatTeamSports;
  String get subcatWaterSports;
  String get subcatCycling;

  // Product Attributes
  String get attrColor;
  String get attrSize;
  String get attrMaterial;
  String get attrWeight;
  String get attrDimensions;
  String get attrWarranty;
  String get attrModel;
  String get attrPowerConsumption;
  String get attrBrightness;
  String get attrColorTemperature;
  String get attrDimmable;
  String get attrEnergyRating;
  String get attrRoomType;
  String get attrStyle;
  String get attrPattern;
  String get attrSeason;
  String get attrGender;
  String get attrAgeGroup;
  String get attrSkinType;
  String get attrVolume;
  String get attrSPF;
  String get attrBatteryLife;
  String get attrConnectivity;
  String get attrScreenSize;
  String get attrStorageCapacity;
  String get attrProcessor;
  String get attrRAM;
  String get attrResolution;
  String get attrFrameRate;
  String get attrLensType;
  String get attrOpticalZoom;
  String get attrMegapixels;
  String get attrSportType;
  String get attrSkillLevel;
  String get attrSurfaceType;
  String get attrWaterResistance;
  String get attrLoadCapacity;
  String get attrAssemblyRequired;
  String get attrCareInstructions;
  String get attrCountryOfOrigin;
  String get attrCertifications;
  String get attrFeatures;

  // Units
  String get unitKg;
  String get unitG;
  String get unitCm;
  String get unitInches;
  String get unitWatts;
  String get unitLumens;
  String get unitKelvin;
  String get unitHours;
  String get unitMonths;
  String get unitYears;
  String get unitLiters;
  String get unitML;
  String get unitOz;

  // Yes/No
  String get yes;
  String get no;

  // Validation Messages
  String get validateProductName;
  String get validatePrice;
  String get validateStock;
  String get validateDescription;
  String get validateBrand;
  String get validateCategory;
  String get validateSubcategory;

  // Success Messages
  String get productSavedSuccess;
  String get productUpdatedSuccess;
  String get imageAddedSuccess;
  String get imageRemovedSuccess;

  // Confirmation Dialogs
  String get confirmDiscardChanges;
  String get confirmDeleteImage;
  String get unsavedChangesTitle;
  String get discardBtn;
  String get keepEditingBtn;

  // Placeholders
  String get selectOption;
  String get selectCategory;
  String get selectSubcategory;
}

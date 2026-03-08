# 🌌 Aurora - E-commerce Marketplace Platform

A comprehensive Flutter-based e-commerce application with multi-vendor marketplace capabilities, powered by Supabase backend.

![Flutter](https://img.shields.io/badge/Flutter-3.10.7-blue)
![Dart](https://img.shields.io/badge/Dart-3.10.7-blue)
![Supabase](https://img.shields.io/badge/Supabase-PostgreSQL-green)
![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20Android%20%7C%20Web-lightgrey)
![License](https://img.shields.io/badge/License-Private-red)

---

## 📖 Table of Contents

- [Features](#-features)
- [Tech Stack](#-tech-stack)
- [Project Structure](#-project-structure)
- [Getting Started](#-getting-started)
- [Installation](#-installation)
- [Configuration](#-configuration)
- [Database Setup](#-database-setup)
- [Usage](#-usage)
- [Key Modules](#-key-modules)
- [Security](#-security)
- [Documentation](#-documentation)
- [Contributing](#-contributing)
- [License](#-license)

---

## ✨ Features

### 🛍️ Sales Management

- Record sales with customer linkage (or walk-in customers)
- Product catalog integration with Amazon products
- Multiple payment methods (Cash, Card, Transfer, Other)
- Payment status tracking
- Discount and pricing management
- Real-time total calculation

### 👥 Customer Management

- Complete customer profiles with contact details
- Automatic statistics calculation (total orders, total spent, last purchase)
- Customer status tracking (Active, At Risk, Churned)
- Advanced search capabilities
- Age range demographics

### 📊 Analytics Dashboard

- Real-time KPI tracking (Revenue, Sales, Items, Customers, Average Order Value)
- Top products analysis
- Top customers identification
- Sales by payment method breakdown
- Daily sales trends
- Business insights and recommendations
- Intelligent caching system for optimal performance

### 💳 User Payment Methods

- Save and manage multiple payment cards
- Set default payment method
- Beautiful card preview with real-time input
- Support for Visa, Mastercard, Amex
- Secure card information storage
- Easy card removal with confirmation

### 🏭 Factory System

- Factory account management
- Factory discovery and linking
- Multi-factory support
- Production tracking capabilities

### 💬 Chat System

- Real-time messaging
- Seller-buyer communication
- Chat history persistence
- Message notifications

### 📦 Product Management

- Complete product catalog
- ASIN generation and tracking
- QR code / SKU integration
- Image upload support
- Product variants management

### 🏠 User Features

- User home page with personalized content
- Order history and tracking
- Wishlist management
- Address management
- User profile settings

### 🔐 Authentication & Security

- Supabase Auth integration
- Row Level Security (RLS) for data isolation
- Multi-seller support with complete data separation
- Multi-role system (Admin, Seller, Buyer, Factory)
- Secure local storage
- Biometric authentication support

### 📍 Location Services

- Geolocation integration
- Geocoding support
- Location-based features

### 🎨 User Experience

- Material Design 3 theming
- Responsive layouts
- Smooth animations
- Intuitive navigation
- Dark/Light theme support

---

## 🛠️ Tech Stack

### Frontend

- **Flutter** - Cross-platform UI framework
- **Provider** - State management
- **Material Design 3** - UI components and theming

### Backend

- **Supabase** - Backend-as-a-Service
  - PostgreSQL database
  - Real-time subscriptions
  - Authentication
  - Row Level Security

### Key Dependencies

| Package                  | Purpose                  |
| ------------------------ | ------------------------ |
| `supabase_flutter`       | Backend connectivity     |
| `provider`               | State management         |
| `flutter_secure_storage` | Secure data storage      |
| `local_auth`             | Biometric authentication |
| `geolocator`             | Location services        |
| `qr_flutter`             | QR code generation       |
| `image_picker`           | Image handling           |
| `firebase_messaging`     | Push notifications       |
| `connectivity_plus`      | Network monitoring       |
| `http`                   | HTTP client for edge functions |
| `shared_preferences`     | Local caching            |
| `intl`                   | Internationalization     |
| `uuid`                   | UUID generation          |

---

## 📁 Project Structure

```
A-U-R-O-R-A/
├── lib/
│   ├── backend/          # Backend integration layer
│   ├── models/           # Data models
│   │   ├── customer.dart
│   │   ├── product.dart
│   │   ├── sale.dart
│   │   ├── payment_method.dart
│   │   └── chat_message.dart
│   ├── pages/            # Application screens
│   │   ├── sales/
│   │   │   ├── record_sale_screen.dart
│   │   │   └── sales_page.dart
│   │   ├── customers/
│   │   │   ├── customers_page.dart
│   │   │   ├── add_customer_screen.dart
│   │   │   └── customer_details_screen.dart
│   │   ├── analytics/
│   │   │   └── analytics_page.dart
│   │   ├── product/
│   │   │   ├── products_page.dart
│   │   │   └── product_details_screen.dart
│   │   ├── factory/
│   │   │   ├── factory_page.dart
│   │   │   └── factory_discovery_page.dart
│   │   ├── chat/
│   │   │   └── chat_page.dart
│   │   ├── user/
│   │   │   ├── user_home_page.dart
│   │   │   ├── user_orders_page.dart
│   │   │   ├── user_payment_methods_page.dart
│   │   │   ├── user_wishlist_page.dart
│   │   │   ├── user_addresses_page.dart
│   │   │   └── user_profile_page.dart
│   │   ├── seller/
│   │   │   └── seller_dashboard.dart
│   │   ├── setting/
│   │   │   └── settings_page.dart
│   │   └── auth/
│   │       ├── login_page.dart
│   │       └── signup_page.dart
│   ├── services/         # Business logic & API calls
│   │   ├── supabase.dart
│   │   ├── auth_service.dart
│   │   └── edge_functions.dart
│   ├── theme/            # App theming
│   ├── widgets/          # Reusable components
│   │   └── drawer.dart
│   └── main.dart         # App entry point
├── supabase/
│   ├── functions/        # Edge functions
│   │   ├── payment-methods/
│   │   ├── chat/
│   │   └── factory/
│   └── migrations/       # Database migrations
│       └── 005_customers_sales_analytics_complete.sql
├── test/                 # Unit and widget tests
└── pubspec.yaml          # Dependencies
```

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (>= 3.10.7)
- Dart SDK (>= 3.10.7)
- Supabase account
- Android Studio / VS Code
- Xcode (for iOS development)
- CocoaPods (for iOS)

### Installation

1. **Clone the repository**

   ```bash
   git clone <repository-url>
   cd A-U-R-O-R-A
   ```

2. **Install dependencies**

   ```bash
   flutter pub get
   ```

3. **Configure environment**
   - Create a `.env` file or update configuration in `lib/services/supabase.dart`
   - Add your Supabase URL and Anon Key

4. **Run the app**
   ```bash
   flutter run
   ```

---

## ⚙️ Configuration

### Supabase Setup

1. Create a new project at [supabase.com](https://supabase.com)
2. Navigate to **Settings** → **API**
3. Copy your **Project URL** and **anon public key**
4. Update in your configuration:

```dart
// lib/services/supabase.dart
const String supabaseUrl = 'YOUR_SUPABASE_URL';
const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
```

---

## 🗄️ Database Setup

### Running Migrations

1. Open **Supabase Dashboard** → **SQL Editor**
2. Copy the content of `supabase/migrations/005_customers_sales_analytics_complete.sql`
3. Paste and execute
4. Verify all tables, functions, and triggers are created

### Database Schema

```
┌─────────────────────────────────────────────────────────────┐
│                      auth.users                              │
│                   (Supabase Auth)                            │
└─────────────────────┬───────────────────────────────────────┘
                      │ seller_id (UUID)
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  customers            │  sales              │  analytics_   │
│  ─────────────────    │  ─────────────────  │  snapshots    │
│  id (UUID)            │  id (UUID)          │  ───────────  │
│  seller_id (FK)       │  customer_id (FK)   │  id (UUID)    │
│  name                 │  product_id (FK)    │  seller_id    │
│  phone                │  quantity           │  period_type  │
│  email                │  unit_price         │  period_start │
│  age_range            │  total_price        │  period_end   │
│  notes                │  discount           │  analytics_   │
│  total_orders ⚡      │  payment_method     │    data (JSON)│
│  total_spent ⚡       │  payment_status     │  is_current   │
│  last_purchase_date ⚡│  sale_date          │               │
│                       │  payment_status     │               │
└─────────────────────────────────────────────────────────────┘
                         ⚡ = Auto-updated by triggers
```

---

## 📱 Usage

### Recording a Sale

1. Navigate to **Sales** from the main menu
2. Tap **Record Sale**
3. Select a customer (optional for walk-in)
4. Select a product (optional for general sales)
5. Enter quantity and unit price
6. Apply discount if applicable
7. Choose payment method
8. Tap **Record Sale**

### Adding a Customer

1. Navigate to **Customers** from the main menu
2. Tap **Add Customer**
3. Fill in customer details
4. Save

### Viewing Analytics

1. Navigate to **Analytics** from the main menu
2. Select time period (7d, 30d, 90d, All)
3. View KPIs, top customers, and business insights

---

## 🔑 Key Modules

### Sales Module

- [`record_sale_screen.dart`](lib/pages/sales/record_sale_screen.dart) - Complete sale recording interface
- [`sales_page.dart`](lib/pages/sales/sales_page.dart) - Sales history and management

### Customer Module

- [`customers_page.dart`](lib/pages/customers/customers_page.dart) - Customer list and search
- [`add_customer_screen.dart`](lib/pages/customers/add_customer_screen.dart) - New customer form
- [`customer_details_screen.dart`](lib/pages/customers/customer_details_screen.dart) - Customer profile view

### Analytics Module

- [`analytics_page.dart`](lib/pages/analytics/analytics_page.dart) - Business intelligence dashboard

### Payment Methods Module

- [`user_payment_methods_page.dart`](lib/pages/user/user_payment_methods_page.dart) - Manage saved payment cards

### Product Module

- [`products_page.dart`](lib/pages/product/products_page.dart) - Product catalog management
- [`product_details_screen.dart`](lib/pages/product/product_details_screen.dart) - Product details and editing

### Factory Module

- [`factory_page.dart`](lib/pages/factory/factory_page.dart) - Factory management
- [`factory_discovery_page.dart`](lib/pages/factory/factory_discovery_page.dart) - Discover and link factories

### Chat Module

- [`chat_page.dart`](lib/pages/chat/chat_page.dart) - Real-time messaging

### User Module

- [`user_home_page.dart`](lib/pages/user/user_home_page.dart) - User home dashboard
- [`user_orders_page.dart`](lib/pages/user/user_orders_page.dart) - Order history
- [`user_wishlist_page.dart`](lib/pages/user/user_wishlist_page.dart) - Saved items
- [`user_addresses_page.dart`](lib/pages/user/user_addresses_page.dart) - Address management
- [`user_profile_page.dart`](lib/pages/user/user_profile_page.dart) - Profile settings

### Services

- [`supabase.dart`](lib/services/supabase.dart) - Database operations and business logic
- [`auth_service.dart`](lib/services/auth_service.dart) - Authentication management
- [`edge_functions.dart`](lib/services/edge_functions.dart) - Edge function integration

---

## 🔐 Security

### Row Level Security (RLS)

All tables implement RLS policies ensuring:

- Sellers can only access their own data
- Complete data isolation between sellers
- Service role bypass for calculations
- Multi-role access control (Admin, Seller, Buyer, Factory)

```sql
-- Example RLS Policy
CREATE POLICY "Sellers can only see their own customers"
ON customers
FOR ALL
USING (seller_id = auth.uid());
```

### Authentication

- Supabase Auth for user management
- Secure token storage
- Biometric authentication support
- Session management
- Multi-role system

### Edge Functions Security

- JWT validation for all edge functions
- CORS configuration
- Rate limiting
- Input validation

---

## 📚 Documentation

Additional documentation files:

| Document                                                                   | Description                              |
| -------------------------------------------------------------------------- | ---------------------------------------- |
| [`COMPLETE_IMPLEMENTATION_SUMMARY.md`](COMPLETE_IMPLEMENTATION_SUMMARY.md) | Full implementation overview             |
| [`SQL_IMPLEMENTATION_GUIDE.md`](SQL_IMPLEMENTATION_GUIDE.md)               | Database setup guide                     |
| [`DEPLOYMENT_GUIDE.md`](DEPLOYMENT_GUIDE.md)                               | Production deployment                    |
| [`COMPLETE_DEPLOYMENT_GUIDE.md`](COMPLETE_DEPLOYMENT_GUIDE.md)             | Complete deployment instructions         |
| [`ENHANCED_FEATURES_GUIDE.md`](ENHANCED_FEATURES_GUIDE.md)                 | Advanced features                        |
| [`FACTORY_SYSTEM_SUMMARY.md`](FACTORY_SYSTEM_SUMMARY.md)                   | Factory module documentation             |
| [`FACTORY_ACCOUNT_IMPLEMENTATION.md`](FACTORY_ACCOUNT_IMPLEMENTATION.md)   | Factory account setup                    |
| [`FACTORY_DISCOVERY_IMPLEMENTATION.md`](FACTORY_DISCOVERY_IMPLEMENTATION.md)| Factory discovery feature               |
| [`CHAT_SYSTEM_IMPLEMENTATION.md`](CHAT_SYSTEM_IMPLEMENTATION.md)           | Chat system implementation               |
| [`BIOMETRIC_IMPLEMENTATION.md`](BIOMETRIC_IMPLEMENTATION.md)               | Biometric authentication setup           |
| [`EDGE_FUNCTIONS_COMPLETE_GUIDE.md`](EDGE_FUNCTIONS_COMPLETE_GUIDE.md)     | Edge functions complete guide            |
| [`EDGE_FUNCTIONS_DEPLOYMENT.md`](EDGE_FUNCTIONS_DEPLOYMENT.md)             | Edge functions deployment                |
| [`PRODUCT_SYSTEM_GUIDE.md`](PRODUCT_SYSTEM_GUIDE.md)                       | Product management system                |
| [`QR_CODE_SKU_GUIDE.md`](QR_CODE_SKU_GUIDE.md)                             | QR code and SKU integration              |
| [`IMAGE_UPLOAD_SETUP.md`](IMAGE_UPLOAD_SETUP.md)                           | Image upload configuration               |
| [`MULTI_ROLE_SYSTEM_IMPLEMENTATION.md`](MULTI_ROLE_SYSTEM_IMPLEMENTATION.md)| Multi-role access control               |
| [`PGMQ_QUEUE_SERVICE.md`](PGMQ_QUEUE_SERVICE.md)                           | Message queue service                    |
| [`SECURITY_FIXES_COMPLETE.md`](SECURITY_FIXES_COMPLETE.md)                 | Security implementation details          |
| [`TROUBLESHOOTING_GUIDE.md`](TROUBLESHOOTING_GUIDE.md)                     | Common issues and solutions              |
| [`FINAL_DEPLOYMENT_CHECKLIST.md`](FINAL_DEPLOYMENT_CHECKLIST.md)           | Pre-deployment checklist                 |

---

## 🧪 Testing

Run tests:

```bash
flutter test
```

Run with coverage:

```bash
flutter test --coverage
```

---

## 📦 Building for Production

### Android

```bash
flutter build apk --release
flutter build appbundle --release
```

### iOS

```bash
flutter build ios --release
```

### Web

```bash
flutter build web --release
```

---

## 🤝 Contributing

This is a private project. For internal development only.

---

## 📄 License

Private - All rights reserved

---

## 👥 Development Team

**Aurora E-commerce Platform**

For questions or support, contact the development team.

---

## 🙏 Acknowledgments

- Flutter Team
- Supabase
- All open-source contributors

---

<div align="center">

**Built with ❤️ using Flutter & Supabase**

</div>

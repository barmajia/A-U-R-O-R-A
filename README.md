# 🌌 Aurora - E-commerce Marketplace Platform

A comprehensive Flutter-based e-commerce application with multi-vendor marketplace capabilities, powered by Supabase backend.

![Flutter](https://img.shields.io/badge/Flutter-3.10.7-blue)
![Dart](https://img.shields.io/badge/Dart-3.10.7-blue)
![Supabase](https://img.shields.io/badge/Supabase-PostgreSQL-green)
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

### 🔐 Authentication & Security

- Supabase Auth integration
- Row Level Security (RLS) for data isolation
- Multi-seller support with complete data separation
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

---

## 📁 Project Structure

```
A-U-R-O-R-A/
├── lib/
│   ├── backend/          # Backend integration layer
│   ├── models/           # Data models
│   │   ├── customer.dart
│   │   ├── product.dart
│   │   └── sale.dart
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
│   │   └── ...
│   ├── services/         # Business logic & API calls
│   │   └── supabase.dart
│   ├── theme/            # App theming
│   ├── widgets/          # Reusable components
│   │   └── drawer.dart
│   └── main.dart         # App entry point
├── supabase/
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

### Services

- [`supabase.dart`](lib/services/supabase.dart) - Database operations and business logic

---

## 🔐 Security

### Row Level Security (RLS)

All tables implement RLS policies ensuring:

- Sellers can only access their own data
- Complete data isolation between sellers
- Service role bypass for calculations

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

---

## 📚 Documentation

Additional documentation files:

| Document                                                                   | Description                  |
| -------------------------------------------------------------------------- | ---------------------------- |
| [`COMPLETE_IMPLEMENTATION_SUMMARY.md`](COMPLETE_IMPLEMENTATION_SUMMARY.md) | Full implementation overview |
| [`SQL_IMPLEMENTATION_GUIDE.md`](SQL_IMPLEMENTATION_GUIDE.md)               | Database setup guide         |
| [`DEPLOYMENT_GUIDE.md`](DEPLOYMENT_GUIDE.md)                               | Production deployment        |
| [`ENHANCED_FEATURES_GUIDE.md`](ENHANCED_FEATURES_GUIDE.md)                 | Advanced features            |
| [`FACTORY_SYSTEM_SUMMARY.md`](FACTORY_SYSTEM_SUMMARY.md)                   | Factory module documentation |
| [`EDGE_FUNCTIONS_GUIDE.md`](EDGE_FUNCTIONS_GUIDE.md)                       | Edge functions setup         |

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

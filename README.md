# 🌌 Aurora - E-commerce Marketplace Platform

A comprehensive Flutter-based e-commerce application with multi-vendor marketplace capabilities, powered by Supabase backend.

![Flutter](https://img.shields.io/badge/Flutter-3.10.7-blue)
![Dart](https://img.shields.io/badge/Dart-3.10.7-blue)
![Supabase](https://img.shields.io/badge/Supabase-PostgreSQL-green)
![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20Android%20%7C%20Web-lightgrey)
![License](https://img.shields.io/badge/License-Private-red)
![Last Updated](https://img.shields.io/badge/Updated-April%202026-blue)

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
- [Architecture](#-architecture)
- [Key Modules](#-key-modules)
- [Security](#-security)
- [Documentation](#-documentation)
- [Testing](#-testing)
- [Building for Production](#-building-for-production)
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
- Deal proposals and negotiations

### 📦 Product Management

- Complete product catalog with ASIN generation
- **QR Code / SKU integration** with sharing capabilities
- Product images upload and management
- Product variants management
- **Product link sharing** for deals
- **Share QR codes** via WhatsApp, Messenger, SMS, Email
- **Copy SKU to clipboard** for easy reference
- Brand and category management
- Inventory tracking

### 🏠 User Features

- User home page with personalized content
- Order history and tracking
- Wishlist management
- Address management
- User profile settings

### 👤 Seller Profile Management

- Complete seller profile with verification status
- Account information with UUID identification
- Contact details (email, phone)
- Location & currency settings
- Real-time sync with Supabase backend
- Local database caching for offline access
- Copy UUID to clipboard
- Refresh data from Supabase or local DB
- Verification badge and status tracking

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
- Nearby sellers/factories discovery

### 🎨 User Experience

- Material Design 3 theming
- Responsive layouts
- Smooth animations
- Intuitive navigation
- Dark/Light theme support
- **Enhanced product details** with copy/share features

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

| Package                  | Purpose                        |
| ------------------------ | ------------------------------ |
| `supabase_flutter`       | Backend connectivity           |
| `provider`               | State management               |
| `flutter_secure_storage` | Secure data storage            |
| `local_auth`             | Biometric authentication       |
| `geolocator`             | Location services              |
| `qr_flutter`             | QR code generation             |
| `image_picker`           | Image handling                 |
| `firebase_messaging`     | Push notifications             |
| `connectivity_plus`      | Network monitoring             |
| `http`                   | HTTP client for edge functions |
| `shared_preferences`     | Local caching                  |
| `intl`                   | Internationalization           |
| `uuid`                   | UUID generation                |
| `share_plus`             | Product/QR code sharing        |
| `country_picker`         | Country selection              |
| `cached_network_image`   | Image caching                  |
| `path_provider`          | File path management           |
| `sqlite3`                | Local database                 |

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

### For New Developers

**Quick Start Guide:**

1. **Clone & Install**

   ```bash
   git clone <repository-url>
   cd A-U-R-O-R-A
   flutter pub get
   ```

2. **Configure Supabase**
   - Copy `.env.example` to `.env`
   - Update with your Supabase credentials
   - Or use command-line flags:

   ```bash
   flutter run --dart-define=SUPABASE_URL=your_url --dart-define=SUPABASE_ANON_KEY=your_key
   ```

3. **Run Database Migrations**
   - Open Supabase Dashboard → SQL Editor
   - Execute migrations in order:
     - `supabase/migrations/005_customers_sales_analytics_complete.sql`
     - Additional migrations as needed

4. **Run the App**

   ```bash
   flutter run
   ```

5. **Explore Documentation**
   - Start with [`COMPLETE_IMPLEMENTATION_SUMMARY.md`](COMPLETE_IMPLEMENTATION_SUMMARY.md)
   - Read [`QUICK_TESTING_GUIDE.md`](QUICK_TESTING_GUIDE.md) for testing
   - Check [`TROUBLESHOOTING_GUIDE.md`](TROUBLESHOOTING_GUIDE.md) for common issues

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
                      │ seller_id / user_id (UUID)
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  sellers              │  sales              │  analytics_   │
│  ─────────────────    │  ─────────────────  │  snapshots    │
│  id (UUID, PK)        │  id (UUID)          │  ───────────  │
│  user_id (FK)         │  customer_id (FK)   │  id (UUID)    │
│  firstname            │  product_id (FK)    │  seller_id    │
│  secondname           │  quantity           │  period_type  │
│  thirdname            │  unit_price         │  period_start │
│  fourthname           │  total_price        │  period_end   │
│  full_name            │  discount           │  analytics_   │
│  email                │  payment_method     │    data (JSON)│
│  location             │  payment_status     │  is_current   │
│  phone                │  sale_date          │               │
│  currency             │  created_at         │               │
│  account_type         │                     │               │
│  is_verified          │  customers          │               │
│  latitude             │  ─────────────────  │               │
│  longitude            │  id (UUID)          │               │
│  chat_room_id         │  seller_id (FK)     │               │
│  created_at           │  name               │               │
│  updated_at           │  phone              │               │
│                       │  email              │               │
│  products             │  age_range          │               │
│  ─────────────────    │  notes              │               │
│  id (UUID)            │  total_orders ⚡     │               │
│  seller_id (FK)       │  total_spent ⚡      │               │
│  asin                 │  last_purchase ⚡    │               │
│  sku                  │                     │               │
│  qr_data              │                     │               │
│  title                │                     │               │
│  price                │                     │               │
│  images               │                     │               │
│                       │                     │               │
└─────────────────────────────────────────────────────────────┘
                         ⚡ = Auto-updated by triggers
```

---

## 📱 Usage

### Seller Profile

1. Navigate to **Seller Profile** from the main menu
2. View your complete profile information:
   - **Profile Header**: Avatar, full name, email, account type badge
   - **Account Information**: UUID (copyable), full name, account type
   - **Contact Card**: Email and phone number
   - **Location & Currency**: Physical location and currency setting
   - **Verification Status**: Verified badge or pending verification
3. **Refresh Data**:
   - Pull down to refresh from Supabase
   - Use "Refresh from Supabase" button for UUID-based fetch
   - Use "Refresh from Local DB" button for offline cache
4. **Copy UUID**: Tap the copy icon next to your UUID to share with support

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
- [`product_details_screen.dart`](lib/pages/product/product_details_screen.dart) - Product details with SKU/QR display
- [`product_form_screen.dart`](lib/pages/product/product_form_screen.dart) - Create/edit product form
- **Features:**
  - View/copy SKU to clipboard
  - Share product QR codes
  - Share product links
  - Product image management
  - Real-time sync with Supabase

### Factory Module

- [`factory_page.dart`](lib/pages/factory/factory_page.dart) - Factory management
- [`factory_discovery_page.dart`](lib/pages/factory/factory_discovery_page.dart) - Discover and link factories

### Seller Module

- [`sellerProfile.dart`](lib/pages/seller/sellerProfile.dart) - Complete seller profile management
  - Profile header with avatar and account type badge
  - Account information section (UUID, full name, account type)
  - Contact card (email, phone)
  - Location & currency card
  - Verification status with badge
  - Refresh from Supabase (UUID-based)
  - Refresh from local database
  - Copy UUID to clipboard
  - Pull-to-refresh functionality
  - Error handling and loading states

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

### Backend & Local Database

- [`sellerdb.dart`](lib/backend/sellerdb.dart) - Local SQLite seller database
  - Seller data caching
  - Chat room ID management
  - Location storage
  - CRUD operations
- [`products_db.dart`](lib/backend/products_db.dart) - Local SQLite product database
  - Product catalog caching
  - Offline product access

---

## 🏗️ Architecture

### Seller Profile Architecture

The seller profile system uses a dual-source data architecture:

```
┌──────────────────────────────────────────────────────────────┐
│                    Seller Profile UI                          │
│  (lib/pages/seller/sellerProfile.dart)                       │
└────────────────────┬─────────────────────────────────────────┘
                     │
         ┌───────────┴───────────┐
         │                       │
         ▼                       ▼
┌─────────────────┐     ┌─────────────────┐
│  Supabase       │     │  Local SQLite   │
│  (Primary)      │     │  (Cache)        │
│                 │     │                 │
│  - sellers      │     │  - sellers.db   │
│    table        │     │    (offline)    │
│  - Real-time    │     │  - Fast access  │
│  - UUID-based   │     │  - Fallback     │
└─────────────────┘     └─────────────────┘
```

**Data Flow:**

1. **Primary Source**: Fetch from Supabase `sellers` table by UUID
2. **Fallback**: Load from local SQLite if offline
3. **Cache**: Store fetched data locally for quick access
4. **Chat Room ID**: Generate/persist unique chat room ID per seller

**Key Features:**

- UUID-based primary key integration
- Pull-to-refresh with Supabase sync
- Local database caching for offline access
- Error handling with retry functionality
- Loading states for smooth UX
- Verification status tracking
- Copy UUID to clipboard

### Local Database Schema (SQLite)

```sql
CREATE TABLE sellers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT NOT NULL UNIQUE,
  firstname TEXT NOT NULL,
  secondname TEXT NOT NULL DEFAULT '',
  thirdname TEXT NOT NULL DEFAULT '',
  fourthname TEXT NOT NULL DEFAULT '',
  full_name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  location TEXT NOT NULL,
  phone TEXT NOT NULL,
  currency TEXT,
  account_type TEXT DEFAULT 'seller',
  is_verified INTEGER DEFAULT 0,
  latitude REAL,
  longitude REAL,
  chat_room_id TEXT,
  created_at TEXT,
  updated_at TEXT
);
```

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

### Core Implementation

| Document                                                                   | Description                      |
| -------------------------------------------------------------------------- | -------------------------------- |
| [`COMPLETE_IMPLEMENTATION_SUMMARY.md`](COMPLETE_IMPLEMENTATION_SUMMARY.md) | Full implementation overview     |
| [`SQL_IMPLEMENTATION_GUIDE.md`](SQL_IMPLEMENTATION_GUIDE.md)               | Database setup guide             |
| [`DEPLOYMENT_GUIDE.md`](DEPLOYMENT_GUIDE.md)                               | Production deployment            |
| [`COMPLETE_DEPLOYMENT_GUIDE.md`](COMPLETE_DEPLOYMENT_GUIDE.md)             | Complete deployment instructions |
| [`ENHANCED_FEATURES_GUIDE.md`](ENHANCED_FEATURES_GUIDE.md)                 | Advanced features                |
| [`TROUBLESHOOTING_GUIDE.md`](TROUBLESHOOTING_GUIDE.md)                     | Common issues and solutions      |
| [`FINAL_DEPLOYMENT_CHECKLIST.md`](FINAL_DEPLOYMENT_CHECKLIST.md)           | Pre-deployment checklist         |

### Multi-Role & Security

| Document                                                                     | Description                     |
| ---------------------------------------------------------------------------- | ------------------------------- |
| [`MULTI_ROLE_SYSTEM_IMPLEMENTATION.md`](MULTI_ROLE_SYSTEM_IMPLEMENTATION.md) | Multi-role access control       |
| [`SECURITY_FIXES_COMPLETE.md`](SECURITY_FIXES_COMPLETE.md)                   | Security implementation details |
| [`SECURE_CONFIG_IMPLEMENTATION.md`](SECURE_CONFIG_IMPLEMENTATION.md)         | Secure configuration setup      |

### Factory & Chat Systems

| Document                                                                     | Description                    |
| ---------------------------------------------------------------------------- | ------------------------------ |
| [`FACTORY_SYSTEM_SUMMARY.md`](FACTORY_SYSTEM_SUMMARY.md)                     | Factory module documentation   |
| [`FACTORY_ACCOUNT_IMPLEMENTATION.md`](FACTORY_ACCOUNT_IMPLEMENTATION.md)     | Factory account setup          |
| [`FACTORY_DISCOVERY_IMPLEMENTATION.md`](FACTORY_DISCOVERY_IMPLEMENTATION.md) | Factory discovery feature      |
| [`CHAT_SYSTEM_IMPLEMENTATION.md`](CHAT_SYSTEM_IMPLEMENTATION.md)             | Chat system implementation     |
| [`CHAT_SYSTEM_ARCHITECTURE.md`](CHAT_SYSTEM_ARCHITECTURE.md)                 | Chat architecture overview     |
| [`BIOMETRIC_IMPLEMENTATION.md`](BIOMETRIC_IMPLEMENTATION.md)                 | Biometric authentication setup |

### Edge Functions & Backend

| Document                                                                     | Description                      |
| ---------------------------------------------------------------------------- | -------------------------------- |
| [`EDGE_FUNCTIONS_COMPLETE_GUIDE.md`](EDGE_FUNCTIONS_COMPLETE_GUIDE.md)       | Edge functions complete guide    |
| [`EDGE_FUNCTIONS_DEPLOYMENT.md`](EDGE_FUNCTIONS_DEPLOYMENT.md)               | Edge functions deployment        |
| [`BACKEND_FUNCTIONS_COMPLETE_GUIDE.md`](BACKEND_FUNCTIONS_COMPLETE_GUIDE.md) | Backend functions implementation |
| [`CREATE_ORDER_FUNCTION_GUIDE.md`](CREATE_ORDER_FUNCTION_GUIDE.md)           | Order creation function guide    |
| [`SERVER_ASIN_GENERATION.md`](SERVER_ASIN_GENERATION.md)                     | Server-side ASIN generation      |

### Product & QR Code System

| Document                                                                         | Description                       |
| -------------------------------------------------------------------------------- | --------------------------------- |
| [`PRODUCT_SYSTEM_GUIDE.md`](PRODUCT_SYSTEM_GUIDE.md)                             | Product management system         |
| [`QR_CODE_SKU_GUIDE.md`](QR_CODE_SKU_GUIDE.md)                                   | QR code and SKU integration       |
| [`QR_CODE_FULL_PRODUCT_DATA_GUIDE.md`](QR_CODE_FULL_PRODUCT_DATA_GUIDE.md)       | Complete QR data implementation   |
| [`QR_CODE_LINK_GUIDE.md`](QR_CODE_LINK_GUIDE.md)                                 | Product link in QR codes          |
| [`QR_DIALOG_REBUILD_COMPLETE.md`](QR_DIALOG_REBUILD_COMPLETE.md)                 | QR dialog enhancement             |
| [`SKU_GENERATION_GUIDE.md`](SKU_GENERATION_GUIDE.md)                             | Automatic SKU generation          |
| [`SKU_QR_COMPLETE_REBUILD.md`](SKU_QR_COMPLETE_REBUILD.md)                       | Complete SKU/QR rebuild           |
| [`PRODUCT_DETAILS_SKU_QR_ENHANCEMENT.md`](PRODUCT_DETAILS_SKU_QR_ENHANCEMENT.md) | Product details page enhancements |
| [`QR_CODE_SHARE_FEATURE.md`](QR_CODE_SHARE_FEATURE.md)                           | QR code sharing functionality     |
| [`PRODUCT_LINK_BLACK_THEME.md`](PRODUCT_LINK_BLACK_THEME.md)                     | Product link UI theme             |

### Image & Storage

| Document                                                                           | Description                |
| ---------------------------------------------------------------------------------- | -------------------------- |
| [`IMAGE_UPLOAD_SETUP.md`](IMAGE_UPLOAD_SETUP.md)                                   | Image upload configuration |
| [`PRODUCT_IMAGE_UPLOAD_IMPLEMENTATION.md`](PRODUCT_IMAGE_UPLOAD_IMPLEMENTATION.md) | Product image upload guide |
| [`SUPABASE_STORAGE_GUIDE.md`](SUPABASE_STORAGE_GUIDE.md)                           | Supabase storage setup     |

### Database & Queues

| Document                                                     | Description                  |
| ------------------------------------------------------------ | ---------------------------- |
| [`PGMQ_QUEUE_SERVICE.md`](PGMQ_QUEUE_SERVICE.md)             | Message queue service        |
| [`PGMQ_QUICK_REFERENCE.md`](PGMQ_QUICK_REFERENCE.md)         | PGMQ quick reference         |
| [`LOCAL_DATABASE_FIX.md`](LOCAL_DATABASE_FIX.md)             | Local database configuration |
| [`UNIVERSAL_METADATA_GUIDE.md`](UNIVERSAL_METADATA_GUIDE.md) | Metadata system guide        |

### Testing & Quality

| Document                                                           | Description                 |
| ------------------------------------------------------------------ | --------------------------- |
| [`TEST_IMPLEMENTATION_SUMMARY.md`](TEST_IMPLEMENTATION_SUMMARY.md) | Testing implementation      |
| [`TEST_COMPLETE.md`](TEST_COMPLETE.md)                             | Complete testing guide      |
| [`TEST_FINAL_STATUS.md`](TEST_FINAL_STATUS.md)                     | Final testing status        |
| [`CODE_CLEANUP_COMPLETE.md`](CODE_CLEANUP_COMPLETE.md)             | Code cleanup summary        |
| [`CODE_ANALYSIS_REPORT.md`](CODE_ANALYSIS_REPORT.md)               | Comprehensive code analysis |

### Fixes & Updates

| Document                                                               | Description                 |
| ---------------------------------------------------------------------- | --------------------------- |
| [`FIXES_APPLIED.md`](FIXES_APPLIED.md)                                 | Applied fixes summary       |
| [`PRODUCT_PAGE_LOADING_FIX.md`](PRODUCT_PAGE_LOADING_FIX.md)           | Product page loading fix    |
| [`PRODUCT_PAGE_UPDATE.md`](PRODUCT_PAGE_UPDATE.md)                     | Product page updates        |
| [`DEPLOY_SKU_QR_FIX.md`](DEPLOY_SKU_QR_FIX.md)                         | SKU/QR deployment fix       |
| [`QR_DATA_FIX_DEPLOYMENT.md`](QR_DATA_FIX_DEPLOYMENT.md)               | QR data column fix          |
| [`FIX_QR_DATA_COLUMN.md`](FIX_QR_DATA_COLUMN.md)                       | QR data column migration    |
| [`FIX_EDGE_FUNCTION_503_ERROR.md`](FIX_EDGE_FUNCTION_503_ERROR.md)     | Edge function error fix     |
| [`SHARE_FEATURE_FIX.md`](SHARE_FEATURE_FIX.md)                         | Share feature Android fix   |
| [`TYPO_FIX_COMPLETE.md`](TYPO_FIX_COMPLETE.md)                         | Typo fixes                  |
| [`THEME_CONTRAST_FIX.md`](THEME_CONTRAST_FIX.md)                       | Theme contrast improvements |
| [`SETTINGS_REFACTORING_COMPLETE.md`](SETTINGS_REFACTORING_COMPLETE.md) | Settings refactoring        |
| [`LOCAL_DATABASE_UPDATES.md`](LOCAL_DATABASE_UPDATES.md)               | Local database updates      |

### Configuration & Metadata

| Document                                                             | Description               |
| -------------------------------------------------------------------- | ------------------------- |
| [`CONFIGURATION_FINAL_STATUS.md`](CONFIGURATION_FINAL_STATUS.md)     | Configuration status      |
| [`UNIVERSAL_METADATA_GUIDE.md`](UNIVERSAL_METADATA_GUIDE.md)         | Universal metadata system |
| [`SKU_STORAGE_CONFIRMATION.md`](SKU_STORAGE_CONFIRMATION.md)         | SKU storage confirmation  |
| [`INTEGRATION_COMPLETE_SUMMARY.md`](INTEGRATION_COMPLETE_SUMMARY.md) | Integration summary       |
| [`INTEGRATION_SUMMARY.md`](INTEGRATION_SUMMARY.md)                   | Integration overview      |
| [`IMPLEMENTATION_COMPLETE.md`](IMPLEMENTATION_COMPLETE.md)           | Implementation completion |

### Seller Profile & Management

| Document            | Description                                        |
| ------------------- | -------------------------------------------------- |
| Seller Profile      | Built into `lib/pages/seller/sellerProfile.dart`   |
| Seller Database     | `lib/backend/sellerdb.dart` - Local SQLite caching |
| Verification System | In-app verification status tracking                |

### Backup & Recovery

| Document                                                 | Description               |
| -------------------------------------------------------- | ------------------------- |
| [`BACKUP_GUIDE.md`](BACKUP_GUIDE.md)                     | Backup and recovery guide |
| [`FINAL_CLEANUP_SUMMARY.md`](FINAL_CLEANUP_SUMMARY.md)   | Final cleanup summary     |
| [`DUPLICATE_FILE_REMOVED.md`](DUPLICATE_FILE_REMOVED.md) | Duplicate file removal    |

### GitHub & Deployment

| Document                                             | Description                  |
| ---------------------------------------------------- | ---------------------------- |
| [`GITHUB_SECRETS_SETUP.md`](GITHUB_SECRETS_SETUP.md) | GitHub secrets configuration |
| [`DEPLOY_SKU_QR_FIX.md`](DEPLOY_SKU_QR_FIX.md)       | Deployment fixes             |

---

**Quick Links:**

- [📊 Code Analysis Report](CODE_ANALYSIS_REPORT.md) - Latest code quality report
- [🔧 Troubleshooting Guide](TROUBLESHOOTING_GUIDE.md) - Common issues and solutions
- [🚀 Deployment Guide](DEPLOYMENT_GUIDE.md) - How to deploy to production
- [📱 QR Share Feature](QR_CODE_SHARE_FEATURE.md) - Product sharing documentation

---

## 🆕 Recent Updates (March - April 2026)

### Seller Profile Management

- ✅ **Seller Profile Page** - Complete profile management with verification status
- ✅ **UUID-Based Identification** - Primary key integration with Supabase
- ✅ **Dual Data Source** - Sync from Supabase or local SQLite cache
- ✅ **Account Information Card** - Display UUID, full name, account type
- ✅ **Contact & Location Cards** - Split view for contact info and location/currency
- ✅ **Verification Badge** - Visual verification status with pending/verified states
- ✅ **Copy UUID to Clipboard** - One-tap UUID copying for seller identification
- ✅ **Pull-to-Refresh** - Refresh profile data with swipe gesture
- ✅ **Error Handling** - Comprehensive error states and retry functionality
- ✅ **Loading States** - Smooth loading indicators during data fetch

### Product QR Code & Sharing Features

- ✅ **QR Code Sharing** - Share product QR codes via WhatsApp, Messenger, SMS, Email
- ✅ **Product Link Sharing** - Quick share product URLs for deals
- ✅ **Copy SKU to Clipboard** - One-tap SKU copying from product details
- ✅ **Enhanced Product Details** - Display SKU with copy button in black theme
- ✅ **Share Plus Integration** - Native sharing on Android & iOS
- ✅ **Android Manifest Updates** - Package visibility for Android 11+

### Code Quality

- ✅ **Comprehensive Code Analysis** - 278 issues identified and documented
- ✅ **Test Coverage** - Unit tests for backend and models
- ✅ **Documentation** - 95+ markdown documentation files

### Bug Fixes

- ✅ **QR Data Column** - Added missing `qr_data` column to Supabase
- ✅ **Edge Function 503** - Fixed deployment issues
- ✅ **Share Feature** - Fixed Android package visibility
- ✅ **Theme Issues** - Fixed color contrast and deprecated APIs

### Documentation

- ✅ [`CODE_ANALYSIS_REPORT.md`](CODE_ANALYSIS_REPORT.md) - Complete code quality analysis
- ✅ [`QR_CODE_SHARE_FEATURE.md`](QR_CODE_SHARE_FEATURE.md) - Sharing functionality guide
- ✅ [`PRODUCT_DETAILS_SKU_QR_ENHANCEMENT.md`](PRODUCT_DETAILS_SKU_QR_ENHANCEMENT.md) - Product details enhancement
- ✅ [`PRODUCT_LINK_BLACK_THEME.md`](PRODUCT_LINK_BLACK_THEME.md) - UI theme updates
- ✅ [`FIX_EDGE_FUNCTION_503_ERROR.md`](FIX_EDGE_FUNCTION_503_ERROR.md) - Edge function troubleshooting
- ✅ [`SHARE_FEATURE_FIX.md`](SHARE_FEATURE_FIX.md) - Android sharing fix

---

## 🧪 Testing

### Test Coverage Status

| Test Type             | Coverage | Status     | Files   |
| --------------------- | -------- | ---------- | ------- |
| **Unit Tests**        | ~20%     | ✅ Active  | 6 files |
| **Widget Tests**      | ~5%      | ✅ Active  | 1 file  |
| **Database Tests**    | 100% SQL | ✅ Active  | 1 file  |
| **Integration Tests** | 0%       | ⏳ Planned | -       |
| **Overall Goal**      | 75%      | 🎯 Target  | -       |

### Run Tests

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test file
flutter test test/unit/utils/qr_data_generator_test.dart

# Run widget tests
flutter test test/widget/

# Run database tests (in Supabase SQL Editor)
# Open test/sql/database_tests.sql and execute
```

### Test Files

#### Unit Tests

- ✅ `test/unit/models/aurora_product_test.dart` - Product model tests
- ✅ `test/unit/models/chat_models_test.dart` - Chat model tests
- ✅ `test/unit/backend/productsdb_test.dart` - Local database tests
- ✅ `test/unit/backend/sellerdb_test.dart` - Seller database tests
- ✅ `test/unit/services/theme_provider_test.dart` - Theme service tests
- ✅ `test/unit/utils/qr_data_generator_test.dart` - QR data generation tests

#### Widget Tests

- ✅ `test/widget/widgets/qr_code_dialog_test.dart` - QR dialog UI tests

#### Database Tests (SQL)

- ✅ `test/sql/database_tests.sql` - RLS policies, triggers, functions

### Testing Strategy

See [`TESTING_STRATEGY_AND_GAPS.md`](TESTING_STRATEGY_AND_GAPS.md) for comprehensive testing plan including:

- RLS policy testing
- Integration tests
- E2E tests
- Security testing
- Performance testing

### Identified Gaps & Fixes

#### Gap #1: QR Data Column Missing ✅ FIXED

**Issue:** `qr_data` column not in Supabase  
**Test Found:** `test_column_qr_data_exists()`  
**Fix:** Run migration in `supabase/migrations/007_add_qr_data_column.sql`

#### Gap #2: getProductUrl() Returns Null ✅ FIXED

**Issue:** Method returned null when qrData is null  
**Test Found:** `getProductUrl generates URL if qrData is null`  
**Fix:** Updated `AuroraProduct.getProductUrl()` to generate URL from sellerId + asin

#### Gap #3: Share Feature on Android ✅ FIXED

**Issue:** Share button not working on Android 11+  
**Test Found:** Manual testing  
**Fix:** Added SEND intents to `AndroidManifest.xml`

#### Gap #4: Edge Function 503 Error ⏳ PENDING

**Issue:** create-product function returns 503  
**Test Found:** Integration testing  
**Fix Required:** Deploy edge function to Supabase

### Continuous Integration

Tests run automatically on:

- Push to main branch
- Pull requests
- Before deployment

See `.github/workflows/test.yml` for CI configuration.

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

## 📊 Project Summary

### Key Statistics

| Metric                  | Count     |
| ----------------------- | --------- |
| **Total Pages**         | 30+       |
| **Documentation Files** | 100+      |
| **Test Files**          | 8         |
| **Edge Functions**      | 10+       |
| **Database Tables**     | 15+       |
| **Dependencies**        | 35+       |
| **Supported Locales**   | 2 (EN/AR) |
| **Platforms**           | 4         |

### Core Features

✅ **Multi-Vendor Marketplace** - Complete seller management with UUID-based identification  
✅ **Product Management** - ASIN/SKU generation, QR codes, image uploads  
✅ **Sales Tracking** - Customer linkage, payment methods, analytics  
✅ **Customer Management** - Profiles, statistics, age demographics  
✅ **Real-time Chat** - Buyer-seller communication with deal proposals  
✅ **Factory System** - Factory discovery and production tracking  
✅ **Analytics Dashboard** - KPIs, trends, business insights  
✅ **User Payment Methods** - Saved cards with secure storage  
✅ **Location Services** - Geolocation and nearby discovery  
✅ **Biometric Auth** - Fingerprint/Face ID authentication  
✅ **Seller Profile** - Verification status, contact info, location

### Technology Highlights

- **Backend**: Supabase (PostgreSQL + Realtime + Auth + Storage)
- **Local Storage**: SQLite for offline caching
- **State Management**: Provider pattern
- **UI Framework**: Material Design 3
- **Testing**: Unit, Widget, and SQL tests
- **CI/CD**: GitHub Actions for automated testing

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

![Aurora Platform](https://img.shields.io/badge/Aurora-E--commerce%20Platform-blue?style=for-the-badge)

</div>

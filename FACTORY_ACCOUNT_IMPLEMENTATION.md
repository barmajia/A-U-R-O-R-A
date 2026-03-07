# 🏭 Factory Account Implementation - Complete Guide

## Overview

This document describes the complete factory account implementation in the Aurora multi-role e-commerce system. Factory accounts are designed for manufacturers and wholesalers who want to sell products in bulk to sellers (retailers).

---

## 📁 Files Created/Updated

### New Files

| File | Purpose |
|------|---------|
| `lib/models/factory/factory_dashboard_models.dart` | Data models for dashboard statistics, revenue data, order distribution |
| `lib/pages/factory/factory_dashboard.dart` | Main factory dashboard with stats overview |
| `lib/pages/factory/factory_settings_page.dart` | Factory profile and settings management |
| `lib/pages/factory/factory_orders_page.dart` | Wholesale and retail order management |
| `lib/pages/factory/factory_analytics_page.dart` | Business analytics with charts and insights |

### Updated Files

| File | Changes |
|------|---------|
| `lib/services/supabase.dart` | Added 8 factory-specific backend methods |
| `lib/widgets/drawer.dart` | Added factory navigation menu (6 items) |
| `lib/models/factory/factory_models.dart` | Added export for dashboard models |
| `lib/pages/factory/factory_pages.dart` | Added exports for new pages |

---

## 🎯 Factory Account Features

### 1. **Factory Dashboard** (`FactoryDashboard`)

**Location:** `lib/pages/factory/factory_dashboard.dart`

**Features:**
- Welcome header with greeting
- Quick stats grid (Products, Orders, Connections, Rating)
- Revenue overview card with total and monthly revenue
- Recent orders list with status badges
- Top products by sales
- Connection management widget
- Customer ratings overview
- Quick action buttons

**Key Components:**
- `_buildWelcomeHeader()` - Personalized greeting
- `_buildStatsGrid()` - 4 stat cards
- `_buildRevenueCard()` - Revenue with trend indicator
- `_buildRecentOrdersCard()` - Last 5 orders
- `_buildTopProductsCard()` - Best sellers
- `_buildConnectionsCard()` - Connection stats
- `_buildRatingsCard()` - Overall rating display
- `_buildQuickActions()` - Quick access buttons

---

### 2. **Factory Settings** (`FactorySettingsPage`)

**Location:** `lib/pages/factory/factory_settings_page.dart`

**Features:**
- Basic information editing (company name, phone)
- Location management with GPS integration
- Wholesale settings (min order, discount %, returns policy)
- Production capacity configuration
- Business license upload
- Verification status display

**Sections:**
1. **Basic Information**
   - Company/Factory Name
   - Phone Number

2. **Location**
   - GPS coordinates auto-detection
   - Manual entry support
   - Current location display

3. **Wholesale Settings**
   - Minimum Order Quantity (MOQ)
   - Wholesale Discount Percentage
   - Accepts Returns toggle

4. **Production Capacity**
   - Production capacity description
   - Average production time
   - Customization options

5. **Business License**
   - Image upload
   - Verification badge

---

### 3. **Factory Orders** (`FactoryOrdersPage`)

**Location:** `lib/pages/factory/factory_orders_page.dart`

**Features:**
- Tabbed view (All, Pending, Processing, Completed)
- Search functionality
- Order status management
- Bulk actions support
- Order details bottom sheet
- Status update workflow

**Order Statuses:**
- `pending` - Awaiting confirmation
- `confirmed` - Confirmed by factory
- `processing` - Being prepared
- `shipped` - Sent to customer
- `delivered` - Completed
- `cancelled` - Cancelled

**Order Details Sheet:**
- Customer information
- Product list with quantities
- Order summary with pricing
- Status action buttons

---

### 4. **Factory Analytics** (`FactoryAnalyticsPage`)

**Location:** `lib/pages/factory/factory_analytics_page.dart`

**Features:**
- Revenue overview with growth percentage
- Interactive revenue chart (LineChart)
- Order status distribution (PieChart)
- Top products ranking
- Performance metrics
- Sales insights
- Customer insights

**Period Selection:**
- Last 7 Days
- Last 30 Days
- Last 90 Days
- Last Year

**Charts:**
- **Revenue Trend** - Line chart with area fill
- **Order Distribution** - Pie chart with legend
- **Top Products** - Ranked list with badges

**Metrics:**
- Total products (active count)
- Total orders (pending count)
- Active connections (requests count)
- Average rating (reviews count)
- Wholesale orders percentage

---

## 🔧 Backend Methods (SupabaseProvider)

### Factory Data Methods

```dart
/// Get factory info by user ID
Future<FactoryInfo?> getFactoryInfo(String userId)

/// Get current authenticated factory's profile
Future<MiddlemanProfile?> getCurrentFactoryProfile()

/// Update factory profile settings
Future<AuthResult> updateFactoryProfile({...})
```

### Dashboard & Analytics Methods

```dart
/// Get comprehensive dashboard statistics
Future<FactoryDashboardStats> getFactoryDashboardStats()

/// Get revenue data for charts (7d, 30d, 90d, 1y)
Future<List<RevenueDataPoint>> getFactoryRevenueData({String period})

/// Get order status distribution for pie chart
Future<OrderStatusDistribution> getFactoryOrderDistribution()

/// Get top selling products
Future<List<TopProduct>> getFactoryTopProducts({int limit})
```

### Order Management Methods

```dart
/// Get recent orders (default: 10)
Future<List<FactoryOrderItem>> getFactoryRecentOrders({int limit})

/// Get all orders (up to 100)
Future<List<FactoryOrderItem>> getFactoryOrders()

/// Update order status
Future<AuthResult> updateOrderStatus({String orderId, String status})
```

---

## 📊 Data Models

### FactoryDashboardStats
```dart
- totalProducts: int
- activeProducts: int
- outOfStockProducts: int
- totalOrders: int
- pendingOrders: int
- completedOrders: int
- totalRevenue: double
- monthlyRevenue: double
- connectionRequests: int
- activeConnections: int
- averageRating: double
- totalReviews: int
- totalWholesaleOrders: int
- wholesaleRevenue: double
```

### RevenueDataPoint
```dart
- label: String
- value: double
- date: DateTime
```

### OrderStatusDistribution
```dart
- pending: int
- confirmed: int
- processing: int
- shipped: int
- delivered: int
- cancelled: int
```

### TopProduct
```dart
- productId: String
- productName: String
- unitsSold: int
- revenue: double
- imageUrl: String?
```

### FactoryOrderItem
```dart
- orderId: String
- customerName: String
- productNames: List<String>
- totalAmount: double
- status: String
- orderDate: DateTime
- isWholesale: bool
- quantity: int
```

---

## 🧭 Navigation Structure

### Factory Menu Items (in Drawer)

1. **Dashboard** - `FactoryDashboard`
2. **Products** - `ProductPage` (shared with sellers)
3. **Orders** - `FactoryOrdersPage`
4. **Connections** - `FactoryConnectionsPage`
5. **Analytics** - `FactoryAnalyticsPage`
6. **Factory Settings** - `FactorySettingsPage`

### Access Pattern

```dart
// Factory accounts see this menu automatically
if (accountType == AccountType.factory) {
  // Show factory-specific menu items
}
```

---

## 🎨 UI Components

### Common Design Elements

- **Color Scheme:**
  - Primary: Blue/Purple gradient
  - Success: Green
  - Warning: Orange
  - Error: Red
  - Wholesale: Purple accent

- **Card Design:**
  - Elevation: 2
  - Border Radius: 16
  - Padding: 16-20

- **Icons:**
  - Dashboard: `Icons.dashboard`
  - Products: `Icons.inventory_2`
  - Orders: `Icons.shopping_bag`
  - Connections: `Icons.people`
  - Analytics: `Icons.analytics`
  - Settings: `Icons.settings`

### Charts (fl_chart package)

```dart
// Line Chart for Revenue
LineChart(
  LineChartData(
    lineBarsData: [LineChartBarData(...)],
    titlesData: FlTitlesData(...),
    gridData: FlGridData(...),
  ),
)

// Pie Chart for Order Distribution
PieChart(
  PieChartData(
    sections: [...],
    sectionsSpace: 2,
    centerSpaceRadius: 40,
  ),
)
```

---

## 🔄 Order Management Workflow

### Factory Order Lifecycle

```
1. Order Placed (pending)
   ↓
2. Factory Confirms (confirmed)
   ↓
3. Production/Preparation (processing)
   ↓
4. Shipped to Customer (shipped)
   ↓
5. Delivered (delivered/completed)
```

### Status Update Actions

| Current Status | Available Actions |
|---------------|-------------------|
| `pending` | Confirm, Process |
| `confirmed` | Process |
| `processing` | Ship |
| `shipped` | (Auto-complete on delivery) |
| `delivered` | (Final state) |

---

## 📈 Analytics Features

### Revenue Calculations

- **Total Revenue:** Sum of all completed orders
- **Monthly Revenue:** Revenue from current month
- **Growth Percentage:** Comparison with previous period
- **Average Order Value:** Total revenue / Total orders

### Performance Metrics

- **Product Performance:** Active vs total products
- **Order Fulfillment:** Pending vs completed ratio
- **Customer Satisfaction:** Average rating from reviews
- **Wholesale Ratio:** Wholesale orders / Total orders

### Sales Insights

- **Best Day:** Day with highest sales
- **Peak Hour:** Time with most orders
- **Average Items per Order**
- **Return Rate:** Percentage of returned orders

---

## 🔐 Security & Permissions

### Factory-Specific Permissions

- ✅ View own products and inventory
- ✅ Manage own orders
- ✅ Update factory profile
- ✅ View analytics and reports
- ✅ Manage seller connections
- ✅ Receive and respond to connection requests
- ❌ Cannot access other factories' data
- ❌ Cannot modify system settings

---

## 🧪 Testing Checklist

### Dashboard
- [ ] Stats load correctly
- [ ] Revenue displays with proper formatting
- [ ] Recent orders show latest first
- [ ] Top products sorted by sales
- [ ] Quick actions navigate correctly

### Settings
- [ ] Form validation works
- [ ] GPS location detection
- [ ] Image upload for license
- [ ] Settings save successfully
- [ ] Profile updates reflect immediately

### Orders
- [ ] Tab filtering works
- [ ] Search filters correctly
- [ ] Status updates persist
- [ ] Order details display all info
- [ ] Bulk actions function properly

### Analytics
- [ ] Period selection updates data
- [ ] Charts render correctly
- [ ] Revenue trend shows accurate data
- [ ] Order distribution pie chart accurate
- [ ] Top products ranked correctly

---

## 🚀 Future Enhancements

### Planned Features

1. **Inventory Management**
   - Stock level alerts
   - Automatic reorder points
   - Batch tracking

2. **Production Planning**
   - Production schedule calendar
   - Capacity utilization tracking
   - Lead time estimation

3. **B2B Marketplace**
   - Factory discovery by sellers
   - Request for quotation (RFQ)
   - Bulk order negotiation

4. **Advanced Analytics**
   - Sales forecasting
   - Seasonal trends analysis
   - Customer segmentation

5. **Integration**
   - Shipping provider APIs
   - Payment gateway webhooks
   - Email/SMS notifications

---

## 📝 Usage Example

### Accessing Factory Dashboard

```dart
// In your app, factory users will see this automatically
import 'package:aurora/pages/factory/factory_pages.dart';

// Navigate to factory dashboard
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => const FactoryDashboard()),
);
```

### Getting Factory Stats

```dart
final supabase = context.read<SupabaseProvider>();

// Get dashboard statistics
final stats = await supabase.getFactoryDashboardStats();

print('Total Revenue: \$${stats.totalRevenue}');
print('Pending Orders: ${stats.pendingOrders}');
print('Active Connections: ${stats.activeConnections}');
```

### Updating Order Status

```dart
final result = await supabase.updateOrderStatus(
  orderId: 'order-123',
  status: 'processing',
);

if (result.success) {
  print('Order updated successfully');
}
```

---

## 📞 Support

For issues or questions about the factory account implementation:

1. Check the existing factory system documentation
2. Review the Supabase edge functions
3. Verify database schema for factory tables
4. Test with a factory test account

---

**Implementation Date:** March 2026  
**Version:** 1.0.0  
**Author:** Aurora Development Team

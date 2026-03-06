# 🏭 Factory Discovery & Connection System - Implementation Guide

**Version:** 1.0.0  
**Date:** March 5, 2026  
**Status:** ✅ Implementation Complete

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Database Setup](#database-setup)
4. [Edge Functions](#edge-functions)
5. [Flutter Integration](#flutter-integration)
6. [UI Components](#ui-components)
7. [Usage Guide](#usage-guide)
8. [Testing](#testing)
9. [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

The Factory Discovery System enables **Sellers** to find, connect with, and order from **verified Factories** in their geographic area. This creates a B2B wholesale marketplace within your existing Aurora e-commerce platform.

### Key Features

- ✅ **Location-Based Discovery**: Find factories within a customizable radius (5-200 km)
- ✅ **Connection Requests**: Sellers send requests to factories; factories accept/decline
- ✅ **Rating System**: Multi-dimensional ratings (delivery, quality, communication)
- ✅ **Wholesale Pricing**: Automatic discount calculation for factory connections
- ✅ **Verified Badges**: Factory verification system for trust
- ✅ **Real-time Notifications**: Connection request updates via notifications

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     FACTORY DISCOVERY FLOW                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────┐      ┌──────────┐      ┌──────────┐              │
│  │  Seller  │─────▶│  Search  │─────▶│  Factory │              │
│  │   App    │      │ Factories│      │ Profiles │              │
│  └──────────┘      └──────────┘      └──────────┘              │
│       │                                      │                  │
│       │                                      ▼                  │
│       │                              ┌──────────────┐          │
│       │                              │   Connect    │          │
│       │                              │   Request    │          │
│       │                              └──────────────┘          │
│       │                                      │                  │
│       ▼                                      ▼                  │
│  ┌──────────┐      ┌──────────┐      ┌──────────────┐          │
│  │ Factory  │─────▶│  Accept  │─────▶│   Wholesale  │          │
│  │   App    │      │  Request │      │   Ordering   │          │
│  └──────────┘      └──────────┘      └──────────────┘          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🗄️ Database Setup

### Step 1: Run SQL Migration

Execute the migration file in your Supabase SQL Editor:

```bash
# File location
supabase/migrations/20260305000000_create_factory_discovery_system.sql
```

**Or** run via Supabase CLI:

```bash
supabase db push
```

### Step 2: Verify Tables

After migration, verify these tables exist:

```sql
-- Check factory_connections table
SELECT * FROM factory_connections LIMIT 5;

-- Check factory_ratings table
SELECT * FROM factory_ratings LIMIT 5;

-- Check sellers table has factory columns
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'sellers' 
  AND column_name IN ('is_factory', 'latitude', 'longitude', 'wholesale_discount');
```

### Step 3: Test Database Functions

```sql
-- Test distance calculation
SELECT calculate_distance(51.5074, -0.1278, 48.8566, 2.3522) as distance_km;
-- Expected: ~344 km (London to Paris)

-- Test factory rating function (replace with actual factory UUID)
SELECT * FROM get_factory_rating('your-factory-uuid-here');
```

---

## ⚡ Edge Functions

### Deployed Functions

| Function | Purpose | Endpoint |
|----------|---------|----------|
| `find-nearby-factories` | Search factories by location | `/functions/v1/find-nearby-factories` |
| `request-factory-connection` | Send connection request | `/functions/v1/request-factory-connection` |
| `rate-factory` | Submit factory rating | `/functions/v1/rate-factory` |

### Deploy Functions

```bash
cd supabase/functions

# Deploy all at once
deno task deploy

# Or deploy individually
supabase functions deploy find-nearby-factories
supabase functions deploy request-factory-connection
supabase functions deploy rate-factory
```

### Test Edge Functions

```bash
# Test find-nearby-factories
curl -X POST 'https://ofovfxsfazlwvcakpuer.supabase.co/functions/v1/find-nearby-factories' \
  -H 'Authorization: Bearer YOUR_JWT_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{
    "latitude": 51.5074,
    "longitude": -0.1278,
    "radius": 50,
    "limit": 10
  }'
```

---

## 📱 Flutter Integration

### New Files Created

```
lib/
├── models/
│   └── factory/
│       ├── factory_info.dart          # Factory data model
│       ├── factory_connection.dart    # Connection relationship model
│       ├── factory_rating.dart        # Rating & review model
│       └── factory_models.dart        # Export barrel file
│
├── pages/
│   └── factory/
│       ├── factory_discovery_page.dart     # Search & list factories
│       ├── factory_profile_page.dart       # Factory details & connect
│       ├── factory_connections_page.dart   # Manage connections
│       └── factory_pages.dart              # Export barrel file
│
└── services/
    └── supabase.dart (updated)
        ├── findNearbyFactories()
        ├── requestFactoryConnection()
        ├── getFactoryConnections()
        ├── respondToConnectionRequest()
        ├── rateFactory()
        ├── getFactoryRating()
        └── updateFactorySettings()
```

### Import Factory System

```dart
// Import models
import 'package:aurora/models/factory/factory_models.dart';

// Import pages
import 'package:aurora/pages/factory/factory_pages.dart';

// Use SupabaseService methods
final supabase = context.read<SupabaseService>();

// Find nearby factories
final result = await supabase.findNearbyFactories(
  latitude: 51.5074,
  longitude: -0.1278,
  radiusKm: 50,
);

// Request connection
await supabase.requestFactoryConnection(
  factoryId: 'factory-uuid',
  notes: 'Interested in wholesale',
);
```

---

## 🎨 UI Components

### 1. Factory Discovery Page

**Route:** `/factory/discovery`

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const FactoryDiscoveryPage(),
  ),
);
```

**Features:**
- Location permission handling
- Search radius filter (5-200 km)
- Factory cards with distance, rating, product count
- Pull-to-refresh
- Empty state with CTA

### 2. Factory Profile Page

**Route:** `/factory/profile/:id`

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => FactoryProfilePage(factory: factoryInfo),
  ),
);
```

**Features:**
- Factory header with verification badge
- Statistics (distance, products, rating)
- Detailed ratings breakdown
- Connection status indicator
- Wholesale information
- Connect action button

### 3. Factory Connections Page

**Route:** `/factory/connections`

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const FactoryConnectionsPage(),
  ),
);
```

**Features:**
- Tabbed interface (My Connections / Requests)
- Accept/Decline actions for factories
- Connection status badges
- Request timestamps
- Notes display

---

## 📖 Usage Guide

### For Sellers (Buyers)

1. **Open Factory Discovery**
   - Navigate to Factory Discovery from menu
   - Grant location permissions

2. **Search Factories**
   - Tap "Search Nearby" or use search bar
   - Adjust radius with filter if needed

3. **View Factory Profile**
   - Tap on any factory card
   - Review ratings, products, wholesale info

4. **Send Connection Request**
   - Tap "Connect with Factory"
   - Wait for factory approval

5. **Order Wholesale**
   - Once accepted, browse factory products
   - Wholesale prices auto-applied at checkout

### For Factories (Sellers)

1. **Enable Factory Mode**
   - Go to Settings → Factory Settings
   - Toggle "Enable as Factory"
   - Set location coordinates
   - Configure wholesale discount & min order

2. **Get Verified** (Optional)
   - Upload factory license
   - Submit for admin verification

3. **Manage Connection Requests**
   - Open Factory Connections → Requests tab
   - Accept or decline incoming requests

4. **Set Wholesale Pricing**
   - Products automatically show wholesale prices
   - Configure discount percentage in settings

---

## 🧪 Testing

### Manual Testing Checklist

#### Database
- [ ] Run SQL migration successfully
- [ ] Verify `factory_connections` table exists
- [ ] Verify `factory_ratings` table exists
- [ ] Test `calculate_distance()` function
- [ ] Test `find_nearby_factories()` function
- [ ] Verify RLS policies work correctly

#### Edge Functions
- [ ] Deploy `find-nearby-factories`
- [ ] Deploy `request-factory-connection`
- [ ] Deploy `rate-factory`
- [ ] Test with valid authentication
- [ ] Test error handling (invalid input, unauthorized)

#### Flutter App
- [ ] Request location permissions
- [ ] Search for nearby factories
- [ ] View factory profile
- [ ] Send connection request
- [ ] Accept/decline request (as factory)
- [ ] Submit factory rating
- [ ] View connection status
- [ ] Test pull-to-refresh
- [ ] Test empty states

### Unit Tests

Create tests in `test/services/factory_discovery_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:aurora/models/factory/factory_models.dart';

void main() {
  group('FactoryInfo', () {
    test('fromJson creates valid object', () {
      final json = {
        'user_id': 'test-uuid',
        'full_name': 'Test Factory',
        'distance_km': 10.5,
        'is_verified': true,
        'product_count': 50,
        'average_rating': 4.5,
      };
      
      final factory = FactoryInfo.fromJson(json);
      
      expect(factory.userId, 'test-uuid');
      expect(factory.fullName, 'Test Factory');
      expect(factory.distanceKm, 10.5);
      expect(factory.isVerified, true);
    });
    
    test('getWholesalePrice calculates correctly', () {
      final factory = FactoryInfo(
        userId: 'test',
        fullName: 'Test',
        distanceKm: 10,
        isVerified: false,
        productCount: 0,
        averageRating: 0,
        wholesaleDiscount: 20,
      );
      
      expect(factory.getWholesalePrice(100), 80);
    });
  });
}
```

---

## 🔧 Troubleshooting

### Common Issues

#### 1. "Location permission denied"

**Solution:**
- Android: Check `AndroidManifest.xml` has location permissions
- iOS: Check `Info.plist` has `NSLocationWhenInUseUsageDescription`
- Re-install app if permissions were denied permanently

#### 2. "No factories found"

**Causes:**
- No factories registered in database
- Search radius too small
- Location services disabled

**Solution:**
```sql
-- Check if any factories exist
SELECT COUNT(*) FROM sellers WHERE is_factory = true;

-- Register a test factory
UPDATE sellers 
SET is_factory = true, latitude = 51.5074, longitude = -0.1278
WHERE user_id = 'your-user-uuid';
```

#### 3. Edge Function returns 401

**Solution:**
- Verify JWT token is valid
- Check Supabase anon key in function
- Ensure user is logged in

#### 4. Connection request fails

**Check:**
- RLS policies allow INSERT
- Factory ID is valid UUID
- No duplicate request exists

```sql
-- Check for existing requests
SELECT * FROM factory_connections 
WHERE factory_id = 'factory-uuid' 
  AND seller_id = 'seller-uuid';
```

#### 5. Ratings not showing

**Solution:**
```sql
-- Verify ratings exist
SELECT * FROM factory_ratings WHERE factory_id = 'factory-uuid';

-- Check function permissions
GRANT EXECUTE ON FUNCTION get_factory_rating TO authenticated;
```

---

## 📊 Database Schema Reference

### factory_connections

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `factory_id` | UUID | Reference to sellers(user_id) |
| `seller_id` | UUID | Reference to sellers(user_id) |
| `status` | TEXT | pending, accepted, rejected, blocked |
| `requested_at` | TIMESTAMPTZ | When request was sent |
| `accepted_at` | TIMESTAMPTZ | When request was accepted |
| `rejected_at` | TIMESTAMPTZ | When request was rejected |
| `notes` | TEXT | Optional notes from seller |

### factory_ratings

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `factory_id` | UUID | Reference to sellers(user_id) |
| `seller_id` | UUID | Reference to sellers(user_id) |
| `rating` | INTEGER | Overall rating (1-5) |
| `review` | TEXT | Written review |
| `delivery_rating` | INTEGER | Delivery rating (1-5) |
| `quality_rating` | INTEGER | Quality rating (1-5) |
| `communication_rating` | INTEGER | Communication rating (1-5) |

---

## 🚀 Next Steps

### Phase 2 Features (Recommended)

1. **Factory Products View**
   - Dedicated page showing factory's wholesale products
   - Bulk order quantity selector
   - Wholesale cart integration

2. **Messaging System**
   - Direct chat between seller and factory
   - Order negotiation
   - Custom quote requests

3. **Analytics Dashboard**
   - Factory: Views, connection requests, conversion rate
   - Seller: Orders from factories, savings from wholesale

4. **Advanced Search**
   - Filter by product category
   - Filter by minimum order quantity
   - Sort by rating, distance, products

5. **Factory Verification**
   - Admin panel for verifying factories
   - Document upload (business license, certifications)
   - Verification badge display

---

## 📞 Support

For issues or questions:
- Check the [Troubleshooting](#troubleshooting) section
- Review Supabase logs: `supabase logs --function <function-name>`
- Inspect Flutter console for errors
- Verify database permissions and RLS policies

---

**Implementation Complete! 🎉**

All components are ready for testing and deployment. Start with the database migration, then deploy edge functions, and finally test the Flutter app.

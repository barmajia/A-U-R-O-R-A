# 🚀 Factory Discovery System - Quick Start Guide

## ⚡ 5-Minute Setup

### Step 1: Database Migration (2 minutes)

Open Supabase Studio → SQL Editor and run:

```sql
-- Copy entire contents of:
-- supabase/migrations/20260305000000_create_factory_discovery_system.sql
```

**✅ Verify:** You should see "Success. No rows returned"

---

### Step 2: Deploy Edge Functions (2 minutes)

```bash
# Navigate to functions directory
cd supabase/functions

# Deploy all three functions
supabase functions deploy find-nearby-factories
supabase functions deploy request-factory-connection
supabase functions deploy rate-factory
```

**✅ Verify:** Each should return "Deployment complete"

---

### Step 3: Test in Flutter App (1 minute)

Add factory discovery to your app navigation:

```dart
// In your menu/drawer/home page
import 'package:aurora/pages/factory/factory_pages.dart';

// Add navigation button
ListTile(
  leading: const Icon(Icons.business),
  title: const Text('Find Factories'),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FactoryDiscoveryPage()),
    );
  },
),
```

**✅ Verify:** App compiles without errors

---

## 🧪 Quick Test Flow

### As a Seller (Buyer):

1. **Open Factory Discovery**
   ```
   Menu → Find Factories
   ```

2. **Grant Location Permission**
   - Tap "Search Nearby"
   - Allow location access when prompted

3. **View Results**
   - Should see factories within 50km
   - If no factories, see empty state

### As a Factory (Seller):

1. **Enable Factory Mode** (Run in app)
   ```dart
   final supabase = context.read<SupabaseService>();
   await supabase.updateFactorySettings(
     isFactory: true,
     latitude: 51.5074,  // Your latitude
     longitude: -0.1278, // Your longitude
     wholesaleDiscount: 15, // 15% discount
     minOrderQuantity: 10,  // Minimum 10 units
   );
   ```

2. **View Connection Requests**
   ```
   Menu → Factory Connections → Requests tab
   ```

---

## 📁 Files Created

```
✅ Database
   └─ supabase/migrations/20260305000000_create_factory_discovery_system.sql

✅ Edge Functions
   ├─ supabase/functions/find-nearby-factories/index.ts
   ├─ supabase/functions/request-factory-connection/index.ts
   └─ supabase/functions/rate-factory/index.ts

✅ Flutter Models
   ├─ lib/models/factory/factory_info.dart
   ├─ lib/models/factory/factory_connection.dart
   ├─ lib/models/factory/factory_rating.dart
   └─ lib/models/factory/factory_models.dart

✅ Flutter Pages
   ├─ lib/pages/factory/factory_discovery_page.dart
   ├─ lib/pages/factory/factory_profile_page.dart
   ├─ lib/pages/factory/factory_connections_page.dart
   └─ lib/pages/factory/factory_pages.dart

✅ Updated Files
   ├─ lib/services/supabase.dart (added 10 factory methods)
   └─ lib/models/seller.dart (added factory fields)

✅ Documentation
   ├─ FACTORY_DISCOVERY_IMPLEMENTATION.md (full guide)
   └─ FACTORY_DISCOVERY_QUICKSTART.md (this file)
```

---

## 🔑 Key Methods

### SupabaseService Methods

```dart
// Find factories near you
final result = await supabase.findNearbyFactories(
  latitude: 51.5074,
  longitude: -0.1278,
  radiusKm: 50,
);

// Connect with a factory
await supabase.requestFactoryConnection(
  factoryId: 'uuid',
  notes: 'Interested in wholesale',
);

// Get your connections
final connections = await supabase.getFactoryConnections();

// Accept/decline request (as factory)
await supabase.respondToConnectionRequest(
  connectionId: 'uuid',
  accept: true,
);

// Rate a factory
await supabase.rateFactory(
  factoryId: 'uuid',
  rating: 5,
  deliveryRating: 5,
  qualityRating: 5,
  communicationRating: 5,
  review: 'Great experience!',
);

// Update factory settings
await supabase.updateFactorySettings(
  isFactory: true,
  wholesaleDiscount: 20,
  minOrderQuantity: 5,
);
```

---

## ⚠️ Common Issues

### "No factories found"
**Fix:** Register a test factory
```sql
UPDATE sellers 
SET is_factory = true, latitude = 51.5074, longitude = -0.1278
WHERE email = 'your-test-email@example.com';
```

### "Location permission denied"
**Fix:** Check permissions in app settings or re-install app

### "Function not found"
**Fix:** Redeploy edge functions
```bash
supabase functions deploy find-nearby-factories --no-verify-jwt
```

---

## 📊 Database Tables

### Check Factory Connections
```sql
SELECT 
  fc.id,
  sf.full_name as factory,
  ss.full_name as seller,
  fc.status,
  fc.requested_at
FROM factory_connections fc
JOIN sellers sf ON fc.factory_id = sf.user_id
JOIN sellers ss ON fc.seller_id = ss.user_id
ORDER BY fc.requested_at DESC;
```

### Check Factory Ratings
```sql
SELECT 
  s.full_name as factory,
  COUNT(*) as total_ratings,
  AVG(fr.rating) as avg_rating,
  AVG(fr.delivery_rating) as delivery,
  AVG(fr.quality_rating) as quality
FROM factory_ratings fr
JOIN sellers s ON fr.factory_id = s.user_id
GROUP BY s.full_name;
```

---

## 🎯 Next Actions

1. **Test the flow** with two test accounts (seller & factory)
2. **Add navigation** from your existing menu
3. **Customize styling** to match your app theme
4. **Configure production** location services (Google Maps API key if needed)

---

## 📚 Full Documentation

See `FACTORY_DISCOVERY_IMPLEMENTATION.md` for:
- Complete architecture diagrams
- Detailed API reference
- Testing strategies
- Production deployment guide

---

**Ready to go! 🎉**

Your Factory Discovery System is now live and ready for testing!

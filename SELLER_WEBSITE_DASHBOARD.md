# Seller Website Dashboard Implementation

## ✅ Created: `lib/pages/website/seller_website_dashboard.dart`

A production-ready Flutter Seller Website Dashboard with responsive split-page layout.

### 🎯 Features Implemented

1. **Responsive Layout**
   - Mobile: Tab-based navigation (Control | Analytics)
   - Desktop (≥1024px): Side-by-side split view (3:4 ratio)

2. **Website Control Tab**
   - 🌐 Site Status toggle (Publish/Unpublish)
   - 🎨 Template & Settings access points
   - 📦 Catalog Control with KPI cards
   - Progress bar for catalog limit tracking
   - "Add Products to Site" action button

3. **Website Analytics Tab**
   - 📈 Line chart for sales performance (fl_chart)
   - 🎯 Key Metrics cards (Visitors, Conversions, Revenue, Avg Order)
   - 🔥 Top Products list

4. **Supabase Integration**
   - Fetches `website_settings` table
   - Fetches `site_catalog` table
   - Calculates catalog count and total value
   - Publish/unpublish toggle with database update
   - Error handling and loading states

### 📦 Dependencies Required

Already available in your `pubspec.yaml`:
- `supabase_flutter: ^2.5.0` ✓
- `fl_chart: ^1.1.1` ✓
- `intl: ^0.20.2` ✓

### 🔌 Database Schema Requirements

Ensure these tables exist in Supabase:

```sql
-- website_settings table
CREATE TABLE IF NOT EXISTS website_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  site_slug TEXT UNIQUE,
  template_id TEXT,
  status TEXT DEFAULT 'draft', -- 'draft' or 'active'
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- site_catalog table
CREATE TABLE IF NOT EXISTS site_catalog (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  product_id UUID,
  display_price NUMERIC,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### 🚀 Usage

Add to your app routes or navigate directly:

```dart
// In your router or navigation logic
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const SellerWebsiteDashboard(),
  ),
);
```

### 🔧 TODO Items (Marked in Code)

1. **Template Picker UI** - Open template selection screen
2. **Settings Editor** - Open customization screen
3. **Product Picker** - Open product selection to add to site
4. **Real Analytics** - Replace `_generateMockAnalytics()` with actual Supabase queries
5. **Tier Limits** - Fetch dynamic limits from `middleman_profiles.tier`

### 📊 Next Steps

To complete the integration:

1. **Create Database Tables** (if not exists)
   ```bash
   cd supabase
   # Run the SQL schema above
   ```

2. **Add Navigation Entry Point**
   - Add to your drawer or settings menu
   - Example: Add to `AppDrawer` widget

3. **Implement Real Analytics Query**
   Replace mock data with:
   ```dart
   final analytics = await Supabase.instance.client
       .from('analytics_snapshots')
       .select('period_start, analytics_data->kpis')
       .eq('seller_id', userId)
       .order('period_start', ascending: false)
       .limit(7);
   ```

4. **Add RLS Policies**
   ```sql
   ALTER TABLE website_settings ENABLE ROW LEVEL SECURITY;
   
   CREATE POLICY "Users can view own settings"
     ON website_settings FOR SELECT
     USING (auth.uid() = user_id);
   
   CREATE POLICY "Users can update own settings"
     ON website_settings FOR UPDATE
     USING (auth.uid() = user_id);
   ```

### 🎨 Customization Points

- Change currency symbol in `NumberFormat.currency(symbol: 'EGP ')`
- Adjust catalog limit (currently hardcoded to 75000)
- Modify color scheme in metric cards
- Update progress bar threshold (currently 90% for orange warning)

### 📱 Responsive Breakpoints

- **Mobile**: < 1024px → Tabs layout
- **Desktop**: ≥ 1024px → Split view (40% Control | 60% Analytics)

---

**Status**: ✅ Ready for integration  
**Lines of Code**: 459  
**Components**: 8 widgets  
**Test Coverage**: Manual testing required (no Flutter test environment)

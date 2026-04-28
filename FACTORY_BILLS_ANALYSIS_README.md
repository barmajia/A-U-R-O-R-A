# Factory Bills & Analysis Storage Implementation

## Overview
This implementation provides a complete solution for factory-seller bill management with JSON storage in Supabase buckets and automatic analysis generation.

## What Was Created

### 1. **Bill Analysis Storage Service** (`lib/services/bill_analysis_storage_service.dart`)
A comprehensive service for managing bills and analysis data as JSON files in Supabase Storage.

#### Features:
- **Two Storage Buckets:**
  - `factory-bills`: Stores individual bill JSON files
  - `factory-analysis`: Stores analysis result JSON files

- **Bill Operations:**
  - `saveBillToJson()` - Save bill data as JSON to storage
  - `loadBillFromJson()` - Download and parse bill JSON
  - `listFactoryBills()` - List all bills for a factory
  - `deleteBillJson()` - Delete a bill JSON file

- **Analysis Operations:**
  - `saveAnalysisToJson()` - Save analysis data as JSON
  - `loadAnalysisFromJson()` - Load analysis from JSON
  - `getLatestFactoryAnalysis()` - Get most recent factory-wide analysis
  - `getLatestSellerAnalysis()` - Get latest analysis for specific seller
  - `listFactoryAnalysis()` - List all analysis files

#### File Structure in Storage:
```
factory-bills/
  {factory_id}/
    bills/
      {seller_id}_{bill_id}_{timestamp}.json

factory-analysis/
  {factory_id}/
    analysis/
      factory/
        {analysis_type}_{date}_{timestamp}.json
      sellers/
        {seller_id}_{analysis_type}_{date}_{timestamp}.json
```

### 2. **Updated Factory Bill Create Page** (`lib/pages/factory_bill_create_page.dart`)
Enhanced to automatically save bills as JSON and trigger analysis.

#### Key Changes:
- Integrated `BillAnalysisStorageService`
- `_saveToLocalStorage()` now saves to Supabase Storage bucket
- `_triggerAnalysisEngine()` automatically generates analysis after saving bill
- `_generateAnalysisData()` creates KPIs including:
  - Total revenue, bills count, average bill value
  - Payment status breakdown (paid/pending/partial)
  - Tax and discount totals
  - Revenue breakdown by seller

### 3. **Updated Factory Analysis Page** (`lib/pages/factory_analysis_page.dart`)
Modified to load analysis from Supabase Storage instead of local file.

#### Key Changes:
- Uses `BillAnalysisStorageService` instead of local file storage
- `_loadAnalysisData()` fetches latest analysis from `factory-analysis` bucket
- `_saveAnalysisToFile()` saves to storage bucket instead of local JSON file
- Automatic fallback to database if no analysis exists in storage

### 4. **Database Migration** (`migrations/factory_bills_analysis_migration.sql`)
Complete SQL migration for setting up the bills table and storage infrastructure.

#### Includes:
- **Bills Table** with:
  - UUID primary key
  - Seller and factory references
  - JSONB items array
  - Financial fields (subtotal, tax, discount, total)
  - Payment status and method
  - Indexes for performance

- **Storage Buckets:**
  - `factory-bills` for bill JSON files
  - `factory-analysis` for analysis JSON files

- **RLS Policies:**
  - Factories can view/insert/update their bills
  - Sellers can view their own bills
  - Storage bucket access policies

- **Triggers:**
  - Auto-update `updated_at` timestamp

## How It Works

### Bill Creation Flow:
1. Factory creates a new bill for a seller via `FactoryBillCreatePage`
2. Bill is saved to `bills` table in Supabase Database
3. Bill data is converted to JSON and uploaded to `factory-bills` bucket
4. Analysis engine is triggered automatically
5. Analysis aggregates all bills and calculates KPIs
6. Analysis JSON is saved to `factory-analysis` bucket

### Analysis Viewing Flow:
1. Factory opens `FactoryAnalysisPage`
2. App loads latest analysis from `factory-analysis` bucket
3. If no analysis exists, it generates from database
4. KPIs are displayed in dashboard format
5. Analysis can be refreshed manually

## Setup Instructions

### Step 1: Run Database Migration
1. Go to your Supabase Dashboard
2. Navigate to SQL Editor
3. Copy contents of `migrations/factory_bills_analysis_migration.sql`
4. Execute the migration

### Step 2: Verify Storage Buckets
Ensure these buckets exist in Supabase Storage:
- `factory-bills` (public, JSON files only, 10MB limit)
- `factory-analysis` (public, JSON files only, 10MB limit)

The migration creates these automatically, but you may need admin privileges.

### Step 3: Update Flutter Dependencies
Make sure you have these packages in `pubspec.yaml`:
```yaml
dependencies:
  supabase_flutter: ^2.0.0
  path_provider: ^2.0.0
  uuid: ^4.0.0
```

Run:
```bash
flutter pub get
```

### Step 4: Test the Implementation
1. Login as a factory user
2. Navigate to Sellers page
3. Select a seller and create a new bill
4. Verify bill is saved to database AND storage bucket
5. Check Analysis page shows updated KPIs
6. Verify analysis.json is created in storage bucket

## JSON File Examples

### Bill JSON Structure:
```json
{
  "id": "uuid-here",
  "seller_id": "seller-uuid",
  "factory_id": "factory-uuid",
  "customer_id": "seller-uuid",
  "customer_name": "Seller Name",
  "items": [
    {
      "productId": "prod-1",
      "productName": "Product A",
      "quantity": 10,
      "unitPrice": 25.00,
      "totalPrice": 250.00
    }
  ],
  "subtotal": 250.00,
  "tax": 37.50,
  "discount": 0.00,
  "total": 287.50,
  "payment_status": "pending",
  "payment_method": "cash",
  "notes": "",
  "created_at": "2024-01-15T10:30:00Z"
}
```

### Analysis JSON Structure:
```json
{
  "summary": {
    "total_revenue": 15000.00,
    "total_bills": 50,
    "average_bill_value": 300.00,
    "total_tax": 2250.00,
    "total_discount": 150.00
  },
  "payment_status": {
    "paid_count": 35,
    "pending_count": 10,
    "partial_count": 5,
    "paid_percentage": 70.0
  },
  "seller_breakdown": {
    "seller-uuid-1": {
      "revenue": 5000.00,
      "bills_count": 15
    },
    "seller-uuid-2": {
      "revenue": 10000.00,
      "bills_count": 35
    }
  },
  "generated_at": "2024-01-15T12:00:00Z",
  "factory_id": "factory-uuid",
  "_metadata": {
    "factory_id": "factory-uuid",
    "analysis_type": "realtime",
    "generated_at": "2024-01-15T12:00:00Z",
    "file_name": "realtime_2024-01-15_1705320000000.json"
  }
}
```

## API Reference

### BillAnalysisStorageService

```dart
// Initialize
final supabase = SupabaseProvider.of(context).client;
final storage = BillAnalysisStorageService(supabase);

// Save bill
await storage.saveBillToJson(
  billData: billMap,
  factoryId: factoryId,
  sellerId: sellerId,
);

// Get latest analysis
final analysis = await storage.getLatestFactoryAnalysis(factoryId);

// Save analysis
await storage.saveAnalysisToJson(
  analysisData: analysisMap,
  factoryId: factoryId,
  analysisType: 'monthly',
  sellerId: optionalSellerId, // null for factory-wide
);
```

## Next Steps / Recommendations

1. **Chat System**: Implement real-time chat between factories and sellers
2. **Export Features**: Add PDF export for bills
3. **Notifications**: Trigger push notifications when new bills are created
4. **Offline Support**: Cache recent bills locally for offline access
5. **Advanced Analytics**: Add charts and graphs to analysis page
6. **Scheduled Analysis**: Create edge function for nightly analysis updates

## Troubleshooting

### Issue: Storage bucket creation fails
**Solution**: Create buckets manually in Supabase Dashboard → Storage

### Issue: RLS policy blocks access
**Solution**: Check that user is authenticated and has correct role (factory/seller)

### Issue: Analysis not updating
**Solution**: Verify bills are being saved correctly and trigger function is called

### Issue: JSON parsing errors
**Solution**: Check that bill items structure matches expected format

## Support
For issues or questions, check the Supabase logs and Flutter debug console for error messages.

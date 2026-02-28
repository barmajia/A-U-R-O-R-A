# Supabase Edge Functions

This folder contains Supabase Edge Functions for the Aurora E-commerce app.

## 📁 Functions

### 1. `process-signup`
Handles user signup with automatic seller profile creation.

**Triggers:** After user signs up via Supabase Auth

**Input:**
```json
{
  "userId": "uuid",
  "email": "user@example.com",
  "fullName": "John Doe",
  "accountType": "seller",
  "phone": "+1234567890",
  "location": "New York, USA",
  "currency": "USD"
}
```

**Output:**
```json
{
  "success": true,
  "message": "Seller account created successfully",
  "data": {
    "userId": "uuid",
    "email": "user@example.com",
    "sellerId": "uuid"
  }
}
```

### 2. `process-login`
Verifies seller login and updates last login timestamp.

**Triggers:** After user logs in

**Input:**
```json
{
  "userId": "uuid",
  "email": "user@example.com"
}
```

**Output:**
```json
{
  "success": true,
  "message": "Seller login verified",
  "isSeller": true,
  "isVerified": true,
  "data": {
    "userId": "uuid",
    "email": "user@example.com",
    "fullName": "John Doe",
    "storeName": "John's Store",
    "accountType": "seller"
  }
}
```

## 🚀 Deployment

### Prerequisites

1. Install Supabase CLI:
```bash
npm install -g supabase
```

2. Login to Supabase:
```bash
supabase login
```

3. Link to your project:
```bash
supabase link --project-ref ofovfxsfazlwvcakpuer
```

### Deploy Functions

**Deploy all functions:**
```bash
cd supabase/functions
supabase functions deploy process-signup
supabase functions deploy process-login
```

**Deploy specific function:**
```bash
supabase functions deploy process-signup
```

### Set Environment Variables

The functions use these environment variables (automatically set by Supabase):
- `SUPABASE_URL` - Your Supabase project URL
- `SUPABASE_SERVICE_ROLE_KEY` - Service role key (auto-injected)

## 📝 Database Schema

Make sure you have this in your Supabase SQL Editor:

```sql
-- Add missing columns to sellers table
ALTER TABLE sellers ADD COLUMN IF NOT EXISTS firstname TEXT;
ALTER TABLE sellers ADD COLUMN IF NOT EXISTS secoundname TEXT;
ALTER TABLE sellers ADD COLUMN IF NOT EXISTS thirdname TEXT;
ALTER TABLE sellers ADD COLUMN IF NOT EXISTS forthname TEXT;
ALTER TABLE sellers ADD COLUMN IF NOT EXISTS store_name TEXT;
ALTER TABLE sellers ADD COLUMN IF NOT EXISTS store_description TEXT;
ALTER TABLE sellers ADD COLUMN IF NOT EXISTS last_login TIMESTAMP WITH TIME ZONE;
ALTER TABLE sellers ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT FALSE;
ALTER TABLE sellers ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_sellers_email ON sellers(email);
CREATE INDEX IF NOT EXISTS idx_sellers_last_login ON sellers(last_login);
```

## 🔧 Usage in Flutter App

### Call Edge Function

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

// Call process-signup
final result = await supabase.functions.invoke(
  'process-signup',
  body: {
    'userId': user.id,
    'email': user.email,
    'fullName': fullName,
    'accountType': 'seller',
    'phone': phone,
    'location': location,
    'currency': currency,
  },
);

print(result.data);
```

## 🧪 Local Testing

### Run function locally:

```bash
supabase functions serve process-signup --env-file .env
```

### Test with curl:

```bash
curl -i --location --request POST 'http://localhost:54321/functions/v1/process-signup' \
  --header 'Authorization: Bearer YOUR_ANON_KEY' \
  --header 'Content-Type: application/json' \
  --data '{
    "userId": "test-uuid",
    "email": "test@example.com",
    "fullName": "Test User",
    "accountType": "seller",
    "phone": "+1234567890",
    "location": "Test City",
    "currency": "USD"
  }'
```

## 🔐 Security

- Functions use `SUPABASE_SERVICE_ROLE_KEY` (admin privileges)
- Always validate input data
- Enable RLS (Row Level Security) on tables
- Use policies to control access
- Functions are protected by Supabase auth by default

## 📊 Monitoring

View function logs in Supabase Dashboard:
1. Go to your project
2. Click "Edge Functions" in sidebar
3. Select function name
4. View logs and metrics

## 🐛 Troubleshooting

**Function returns 404:**
- Make sure function is deployed
- Check function name matches exactly

**Function returns 500:**
- Check logs in Supabase Dashboard
- Verify environment variables are set
- Check database permissions

**CORS errors:**
- Ensure CORS headers are set correctly
- Check if calling from authorized domain

## 📚 Resources

- [Supabase Edge Functions Docs](https://supabase.com/docs/guides/functions)
- [Deno Documentation](https://deno.land/manual)
- [Supabase Discord](https://discord.supabase.com)

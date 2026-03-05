# 📨 PGMQ Queue Service - Usage Guide for Aurora E-Commerce

## ✅ Setup Complete

The PGMQ integration has been added to your Aurora app:

- **`lib/services/queue_service.dart`** - PGMQ client service
- **`lib/main.dart`** - Updated to provide QueueService via Provider
- **`lib/services/supabase.dart`** - Updated with `queue` property
- **`supabase_pgmq_setup.sql`** - Complete SQL migration script

---

## 🚀 Quick Start (3 Steps)

### Step 1: Run SQL Migration

1. Go to **Supabase Dashboard** → Your Project → **SQL Editor**
2. Copy the contents of `supabase_pgmq_setup.sql`
3. Click **Run** to execute the migration

This will:
- ✅ Install PGMQ extension
- ✅ Create 5 queues (order_processing, notifications, image_processing, analytics_batch, cleanup_tasks)
- ✅ Create fallback `async_jobs` table
- ✅ Create helper functions
- ✅ Set up Row Level Security

### Step 2: Verify Setup

Run this query in SQL Editor to verify:

```sql
SELECT '✅ PGMQ Extension' AS component, 
       CASE WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pgmq') 
            THEN 'Installed' ELSE 'Not Installed' END AS status
UNION ALL
SELECT '✅ Queues Created', 
       COUNT(*)::text || ' queues'
FROM pgmq.list_queues();
```

Expected output:
```
component         | status
------------------+----------------
✅ PGMQ Extension | Installed
✅ Queues Created | 5 queues
```

### Step 3: Use in Flutter App

```dart
import 'package:aurora/services/queue_service.dart';
import 'package:provider/provider.dart';

// In your widget
final queueService = context.read<QueueService>();

// Send order confirmation
await queueService.sendOrderConfirmation(
  orderId: '123',
  userId: 'user-id',
  email: 'customer@example.com',
  orderDetails: {...},
);
```

### 1. Access QueueService via Provider

```dart
import 'package:aurora/services/queue_service.dart';
import 'package:provider/provider.dart';

// In your widget
final queueService = context.read<QueueService>();
```

### 2. Send Order Confirmation

```dart
// After creating an order
Future<void> recordSale() async {
  final supabaseProvider = context.read<SupabaseProvider>();
  
  // Record the sale
  final result = await supabaseProvider.recordSale(...);
  
  if (result.success) {
    // Queue order confirmation email/SMS
    await supabaseProvider.queue.sendOrderConfirmation(
      orderId: result.saleId,
      userId: supabaseProvider.currentUser!.id,
      email: 'customer@example.com',
      orderDetails: {
        'items': [...],
        'total': 99.99,
        'shippingAddress': '...',
      },
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sale recorded & confirmation queued!')),
    );
  }
}
```

### 3. Send Push Notification

```dart
// Notify user about low stock
Future<void> notifyLowStock(String productId) async {
  final supabaseProvider = context.read<SupabaseProvider>();
  
  await supabaseProvider.queue.sendNotification(
    type: 'low_stock_alert',
    userId: supabaseProvider.currentUser!.id,
    title: 'Low Stock Alert',
    body: 'Product is running low on inventory',
    data: {'productId': productId},
  );
}
```

### 4. Queue Image Processing

```dart
// After uploading product image
Future<void> uploadProductImage(File imageFile) async {
  final supabaseProvider = context.read<SupabaseProvider>();
  
  // Upload image
  final imageUrl = await supabaseProvider.uploadProductImage(imageFile);
  
  // Queue image optimization
  await supabaseProvider.queue.sendImageProcessing(
    imageUrl: imageUrl,
    userId: supabaseProvider.currentUser!.id,
    transformations: ['thumbnail', 'optimize', 'watermark'],
  );
}
```

### 5. Trigger Analytics Aggregation

```dart
// Manually trigger analytics refresh
Future<void> refreshAnalytics() async {
  final supabaseProvider = context.read<SupabaseProvider>();
  
  await supabaseProvider.queue.sendAnalyticsBatch(
    period: '30d',
    sellerId: supabaseProvider.currentUser!.id,
  );
  
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Analytics refresh queued!')),
  );
}
```

### 6. Schedule Cleanup Task

```dart
// Queue cleanup of orphaned data
Future<void> cleanupOrphanedImages() async {
  final supabaseProvider = context.read<SupabaseProvider>();
  
  await supabaseProvider.queue.sendCleanupTask(
    taskType: 'orphaned_images',
    params: {'olderThanDays': 7},
  );
}
```

---

## 📊 Check Queue Status

```dart
// Check if PGMQ is installed
final isInstalled = await supabaseProvider.queue.isPGMQInstalled();
print('PGMQ installed: $isInstalled');

// Get queue stats
final stats = await supabaseProvider.queue.getQueueStats('order_processing');
print('Queue stats: $stats');
// Output: {queueName: order_processing, total: 15, ready: 10, delayed: 5}

// List all queues
final queues = await supabaseProvider.queue.listQueues();
print('Available queues: $queues');

// Peek at messages (without consuming)
final messages = await supabaseProvider.queue.peekMessages(
  queueName: 'notifications',
  limit: 5,
);
print('Pending messages: $messages');
```

---

## 🗄️ Database Setup (Required)

Run these SQL commands in your **Supabase SQL Editor** to set up PGMQ:

### Step 1: Install PGMQ Extension

```sql
-- Install PGMQ extension
CREATE EXTENSION IF NOT EXISTS pgmq;

-- Verify installation
SELECT * FROM pg_extension WHERE extname = 'pgmq';
```

### Step 2: Create Queues

```sql
-- Create queues for different purposes
SELECT pgmq.create('order_processing');
SELECT pgmq.create('notifications');
SELECT pgmq.create('image_processing');
SELECT pgmq.create('analytics_batch');
SELECT pgmq.create('cleanup_tasks');

-- List all queues
SELECT * FROM pgmq.list_queues();
```

### Step 3: Set Up Cron Jobs (Optional)

```sql
-- Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule order processor to run every minute
SELECT cron.schedule(
  'process-orders-every-minute',
  '* * * * *',
  $$
    SELECT net.http_post(
      url := 'https://ofovfxsfazlwvcakpuer.supabase.co/functions/v1/order-worker',
      headers := '{"Authorization": "Bearer YOUR_SERVICE_ROLE_KEY"}'::jsonb,
      body := '{}'::jsonb
    );
  $$
);

-- Schedule analytics hourly
SELECT cron.schedule(
  'analytics-hourly',
  '0 * * * *',
  $$
    SELECT net.http_post(
      url := 'https://ofovfxsfazlwvcakpuer.supabase.co/functions/v1/analytics-worker',
      headers := '{"Authorization": "Bearer YOUR_SERVICE_ROLE_KEY"}'::jsonb,
      body := '{}'::jsonb
    );
  $$
);
```

---

## 🔧 Edge Functions (Workers)

To process messages, you'll need Supabase Edge Functions. Here's a template:

### Example: Order Worker

```typescript
// supabase/functions/order-worker/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  const supabaseClient = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  );

  try {
    // Read messages from queue
    const { data: messages } = await supabaseClient.rpc('pgmq_read', {
      queue_name: 'order_processing',
      vt: 30, // 30 second visibility timeout
      qty: 10, // Process up to 10 messages
    });

    if (!messages || messages.length === 0) {
      return new Response(JSON.stringify({ processed: 0 }));
    }

    let processed = 0;

    for (const msg of messages) {
      const { msg_id, message } = msg;
      
      try {
        // Process order confirmation
        await processOrderConfirmation(supabaseClient, message);
        
        // Delete message after success
        await supabaseClient.rpc('pgmq_delete', {
          queue_name: 'order_processing',
          msg_id: msg_id,
        });
        
        processed++;
      } catch (error) {
        console.error('Failed to process message:', error);
        // Handle retry logic here
      }
    }

    return new Response(JSON.stringify({ processed }));
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }
});

async function processOrderConfirmation(client: any, message: any) {
  console.log(`Processing order ${message.orderId}`);
  
  // Send email via SendGrid/Mailgun API
  // Update order status in database
  await client
    .from('orders')
    .update({ status: 'confirmed', confirmed_at: new Date().toISOString() })
    .eq('id', message.orderId);
}
```

---

## 🎯 Complete Example: Record Sale with Queue

```dart
// In your RecordSaleScreen
class _RecordSaleScreenState extends State<RecordSaleScreen> {
  final _formKey = GlobalKey<FormState>();
  
  Future<void> _submitSale() async {
    if (!_formKey.currentState!.validate()) return;

    final supabaseProvider = context.read<SupabaseProvider>();
    
    try {
      // Record the sale
      final result = await supabaseProvider.recordSale(
        customerId: _selectedCustomerId,
        productId: _selectedProductId,
        quantity: _quantity,
        unitPrice: _price,
        paymentMethod: _paymentMethod,
      );

      if (result.success) {
        // ✅ Queue order confirmation
        await supabaseProvider.queue.sendOrderConfirmation(
          orderId: result.saleId,
          userId: supabaseProvider.currentUser!.id,
          email: _customerEmail,
          orderDetails: {
            'quantity': _quantity,
            'unitPrice': _price,
            'total': _quantity * _price,
            'paymentMethod': _paymentMethod,
          },
        );

        // ✅ Queue analytics update
        await supabaseProvider.queue.sendAnalyticsBatch(
          period: 'daily',
          sellerId: supabaseProvider.currentUser!.id,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sale recorded successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        throw Exception(result.message);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to record sale: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
```

---

## 🚨 Troubleshooting

### PGMQ Extension Not Found

```sql
-- Check if installed
SELECT * FROM pg_extension WHERE extname = 'pgmq';

-- If not found, request via Supabase support or install manually
```

### Permission Denied

Make sure you're using the **service role key** in Edge Functions:
```typescript
const supabaseClient = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '' // Must be service role
);
```

### Messages Not Being Processed

1. Check cron jobs are running:
   ```sql
   SELECT * FROM cron.job;
   ```

2. Check Edge Function logs in Supabase Dashboard

3. Verify queue has messages:
   ```sql
   SELECT count(*) FROM pgmq_q_order_processing;
   ```

---

## 📋 Next Steps

1. **Run SQL setup** in Supabase SQL Editor
2. **Deploy Edge Functions** for each queue type
3. **Set up cron jobs** to trigger workers
4. **Test the flow** by sending a test message
5. **Monitor queues** via SQL or dashboard

---

**Need Help?**

- PGMQ Docs: https://github.com/pgmq/pgmq
- Supabase Edge Functions: https://supabase.com/docs/guides/functions
- Supabase Cron: https://supabase.com/docs/guides/database/extensions/pg_cron

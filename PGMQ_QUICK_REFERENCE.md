# 🚀 PGMQ Queue System - Quick Reference

## 📋 Files Created

| File | Purpose |
|------|---------|
| `lib/services/queue_service.dart` | Flutter service for PGMQ operations |
| `supabase_pgmq_setup.sql` | Complete SQL migration script |
| `PGMQ_QUEUE_SERVICE.md` | Detailed usage guide |
| `PGMQ_QUICK_REFERENCE.md` | This file - quick start guide |

---

## ⚡ 3-Minute Setup

### 1️⃣ Run SQL Migration (1 minute)

```
Supabase Dashboard → SQL Editor → Paste supabase_pgmq_setup.sql → Run
```

### 2️⃣ Verify Installation (30 seconds)

```sql
SELECT * FROM pgmq.list_queues();
SELECT * FROM get_queue_stats();
```

### 3️⃣ Use in App (1 minute)

```dart
// Get queue service
final queue = context.read<QueueService>();

// Send message
await queue.sendNotification(
  type: 'order_confirmed',
  userId: 'user-123',
  title: 'Order Confirmed!',
  body: 'Your order is being processed',
);
```

---

## 📦 Available Queues

| Queue | Purpose | Example Use |
|-------|---------|-------------|
| `order_processing` | Order confirmations, inventory updates | Send receipt email after purchase |
| `notifications` | Push/email/SMS notifications | Low stock alerts, promotions |
| `image_processing` | Image optimization | Generate thumbnails after upload |
| `analytics_batch` | Scheduled analytics | Hourly sales aggregation |
| `cleanup_tasks` | Maintenance tasks | Delete orphaned files |

---

## 🎯 Common Operations

### Send Order Confirmation
```dart
await queue.sendOrderConfirmation(
  orderId: 'ORD-123',
  userId: 'USR-456',
  email: 'customer@example.com',
  orderDetails: {'total': 99.99, 'items': 3},
);
```

### Send Notification
```dart
await queue.sendNotification(
  type: 'low_stock',
  userId: 'USR-456',
  title: 'Low Stock Alert',
  body: 'Product XYZ is running low',
  data: {'productId': 'PROD-789'},
);
```

### Queue Image Processing
```dart
await queue.sendImageProcessing(
  imageUrl: 'https://.../image.jpg',
  userId: 'USR-456',
  transformations: ['thumbnail', 'optimize'],
);
```

### Trigger Analytics
```dart
await queue.sendAnalyticsBatch(
  period: '30d',
  sellerId: 'SELLER-123',
);
```

### Schedule Cleanup
```dart
await queue.sendCleanupTask(
  taskType: 'orphaned_images',
  params: {'olderThanDays': 7},
);
```

---

## 🔍 Monitoring

### Check Queue Stats (SQL)
```sql
-- PGMQ queues
SELECT * FROM pgmq.list_queues();

-- Fallback table stats
SELECT * FROM get_queue_stats();

-- Pending jobs
SELECT id, queue_name, payload, scheduled_for 
FROM async_jobs 
WHERE status = 'pending' 
ORDER BY scheduled_for 
LIMIT 10;
```

### Check Queue Stats (Flutter)
```dart
final stats = await queue.getQueueStats('order_processing');
print('Total: ${stats['total']}, Ready: ${stats['ready']}');

final isInstalled = await queue.isPGMQInstalled();
print('PGMQ installed: $isInstalled');
```

---

## 🛠️ Troubleshooting

### Error: "relation pgmq_q_... does not exist"

**Solution:** Run the SQL migration script `supabase_pgmq_setup.sql`

### Error: "function pgmq_send does not exist"

**Solution:** PGMQ extension not installed. Run:
```sql
CREATE EXTENSION pgmq;
SELECT pgmq.create('your_queue_name');
```

### Messages not being processed

**Solution:** 
1. Check if messages are in queue: `SELECT count(*) FROM pgmq_q_order_processing;`
2. Deploy Edge Functions to consume messages
3. Set up cron jobs to trigger workers

### PGMQ not available on my Supabase plan

**Solution:** Use the fallback `async_jobs` table (automatically created by migration script)
```dart
// The QueueService automatically falls back to async_jobs if PGMQ is unavailable
```

---

## 📚 Next Steps

1. **Deploy Edge Functions** - See `PGMQ_QUEUE_SERVICE.md` for worker templates
2. **Set Up Cron Jobs** - Schedule automatic queue processing
3. **Add Monitoring** - Set up alerts for queue backlogs
4. **Test End-to-End** - Send test message, verify processing

---

## 🔗 Resources

- **Full Guide:** `PGMQ_QUEUE_SERVICE.md`
- **SQL Migration:** `supabase_pgmq_setup.sql`
- **PGMQ Docs:** https://github.com/pgmq/pgmq
- **Supabase Functions:** https://supabase.com/docs/guides/functions
- **Supabase Cron:** https://supabase.com/docs/guides/database/extensions/pg_cron

---

## 🎯 Quick Copy-Paste Snippets

### Verify Setup
```sql
SELECT 'PGMQ: ' || CASE WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pgmq') THEN '✅' ELSE '❌' END;
SELECT 'Queues: ' || COUNT(*) || ' ✅' FROM pgmq.list_queues();
SELECT 'Fallback: ' || CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'async_jobs') THEN '✅' ELSE '❌' END;
```

### Test Message (PGMQ)
```sql
SELECT pgmq.send('notifications', '{"test": true, "message": "Hello World"}'::jsonb);
```

### Test Message (Fallback)
```sql
SELECT enqueue_job('notifications', '{"test": true, "message": "Hello World"}'::jsonb);
```

### Clean Old Jobs
```sql
SELECT cleanup_old_jobs(NULL, 7); -- Delete jobs older than 7 days
```

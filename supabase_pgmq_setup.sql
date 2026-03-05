-- ============================================================================
-- Aurora E-Commerce - PGMQ Queue System Setup
-- ============================================================================
-- Description: Complete queue system setup for async task processing
-- Usage: Run this entire script in Supabase Dashboard → SQL Editor
-- Date: 2026-03-01
-- ============================================================================

-- ============================================================================
-- STEP 1: Install PGMQ Extension
-- ============================================================================

-- Check if PGMQ extension exists and install it
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_extension WHERE extname = 'pgmq'
  ) THEN
    RAISE NOTICE 'Installing PGMQ extension...';
    CREATE EXTENSION IF NOT EXISTS pgmq;
    RAISE NOTICE 'PGMQ extension installed successfully!';
  ELSE
    RAISE NOTICE 'PGMQ extension is already installed.';
  END IF;
END $$;

-- Verify PGMQ installation
SELECT 
  extname AS extension_name,
  extversion AS version,
  extnamespace::regnamespace AS schema
FROM pg_extension 
WHERE extname = 'pgmq';

-- ============================================================================
-- STEP 2: Create Queues
-- ============================================================================

-- Create queue for order processing (high priority)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pgmq.list_queues() WHERE queue_name = 'order_processing') THEN
    PERFORM pgmq.create('order_processing');
    RAISE NOTICE 'Created queue: order_processing';
  ELSE
    RAISE NOTICE 'Queue order_processing already exists.';
  END IF;
END $$;

-- Create queue for notifications (medium priority)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pgmq.list_queues() WHERE queue_name = 'notifications') THEN
    PERFORM pgmq.create('notifications');
    RAISE NOTICE 'Created queue: notifications';
  ELSE
    RAISE NOTICE 'Queue notifications already exists.';
  END IF;
END $$;

-- Create queue for image processing (low priority)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pgmq.list_queues() WHERE queue_name = 'image_processing') THEN
    PERFORM pgmq.create('image_processing');
    RAISE NOTICE 'Created queue: image_processing';
  ELSE
    RAISE NOTICE 'Queue image_processing already exists.';
  END IF;
END $$;

-- Create queue for analytics batch jobs (scheduled)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pgmq.list_queues() WHERE queue_name = 'analytics_batch') THEN
    PERFORM pgmq.create('analytics_batch');
    RAISE NOTICE 'Created queue: analytics_batch';
  ELSE
    RAISE NOTICE 'Queue analytics_batch already exists.';
  END IF;
END $$;

-- Create queue for cleanup tasks (lowest priority)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pgmq.list_queues() WHERE queue_name = 'cleanup_tasks') THEN
    PERFORM pgmq.create('cleanup_tasks');
    RAISE NOTICE 'Created queue: cleanup_tasks';
  ELSE
    RAISE NOTICE 'Queue cleanup_tasks already exists.';
  END IF;
END $$;

-- ============================================================================
-- STEP 3: Verify Queue Creation
-- ============================================================================

SELECT 
  queue_name,
  created_at
FROM pgmq.list_queues()
ORDER BY created_at;

-- ============================================================================
-- STEP 4: Create Fallback async_jobs Table (if PGMQ unavailable)
-- ============================================================================

-- Create fallback table for projects without PGMQ
CREATE TABLE IF NOT EXISTS public.async_jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  queue_name TEXT NOT NULL,
  payload JSONB NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
  attempts INTEGER DEFAULT 0,
  max_attempts INTEGER DEFAULT 3,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  processed_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  error_message TEXT,
  scheduled_for TIMESTAMPTZ DEFAULT NOW(),
  metadata JSONB DEFAULT '{}'::jsonb
);

-- Add comment to table
COMMENT ON TABLE public.async_jobs IS 'Fallback job queue when PGMQ is not available';

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_async_jobs_queue_status 
ON public.async_jobs(queue_name, status, scheduled_for);

CREATE INDEX IF NOT EXISTS idx_async_jobs_scheduled 
ON public.async_jobs(scheduled_for) 
WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS idx_async_jobs_created 
ON public.async_jobs(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_async_jobs_metadata 
ON public.async_jobs USING GIN (metadata);

-- ============================================================================
-- STEP 5: Create Helper Functions for Fallback Queue
-- ============================================================================

-- Function to add job to queue
CREATE OR REPLACE FUNCTION public.enqueue_job(
  p_queue_name TEXT,
  p_payload JSONB,
  p_scheduled_for TIMESTAMPTZ DEFAULT NOW(),
  p_metadata JSONB DEFAULT '{}'::jsonb
) RETURNS UUID AS $$
DECLARE
  v_job_id UUID;
BEGIN
  INSERT INTO public.async_jobs (queue_name, payload, scheduled_for, metadata)
  VALUES (p_queue_name, p_payload, p_scheduled_for, p_metadata)
  RETURNING id INTO v_job_id;
  
  -- Notify listeners (optional - for real-time processing)
  PERFORM pg_notify('job_queue_' || p_queue_name, v_job_id::text);
  
  RETURN v_job_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to claim next job from queue
CREATE OR REPLACE FUNCTION public.dequeue_job(
  p_queue_name TEXT,
  p_visibility_timeout_seconds INTEGER DEFAULT 30
) RETURNS TABLE (
  id UUID,
  payload JSONB,
  attempts INTEGER,
  metadata JSONB
) AS $$
BEGIN
  RETURN QUERY
  UPDATE public.async_jobs
  SET 
    status = 'processing',
    attempts = attempts + 1,
    processed_at = NOW()
  WHERE id = (
    SELECT id 
    FROM public.async_jobs 
    WHERE queue_name = p_queue_name 
      AND status = 'pending' 
      AND scheduled_for <= NOW()
    ORDER BY scheduled_for ASC, created_at ASC
    LIMIT 1
    FOR UPDATE SKIP LOCKED
  )
  RETURNING id, payload, attempts, metadata;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to mark job as completed
CREATE OR REPLACE FUNCTION public.complete_job(
  p_job_id UUID
) RETURNS BOOLEAN AS $$
BEGIN
  UPDATE public.async_jobs
  SET 
    status = 'completed',
    completed_at = NOW()
  WHERE id = p_job_id;
  
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to mark job as failed
CREATE OR REPLACE FUNCTION public.fail_job(
  p_job_id UUID,
  p_error_message TEXT
) RETURNS BOOLEAN AS $$
BEGIN
  UPDATE public.async_jobs
  SET 
    status = 'failed',
    error_message = p_error_message,
    completed_at = NOW()
  WHERE id = p_job_id;
  
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to retry a failed job
CREATE OR REPLACE FUNCTION public.retry_job(
  p_job_id UUID,
  p_delay_seconds INTEGER DEFAULT 0
) RETURNS BOOLEAN AS $$
BEGIN
  UPDATE public.async_jobs
  SET 
    status = 'pending',
    error_message = NULL,
    processed_at = NULL,
    scheduled_for = NOW() + (p_delay_seconds || ' seconds')::INTERVAL
  WHERE id = p_job_id AND status = 'failed';
  
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get queue stats
CREATE OR REPLACE FUNCTION public.get_queue_stats(
  p_queue_name TEXT DEFAULT NULL
) RETURNS TABLE (
  queue_name TEXT,
  total_jobs BIGINT,
  pending_jobs BIGINT,
  processing_jobs BIGINT,
  completed_jobs BIGINT,
  failed_jobs BIGINT,
  oldest_pending_job TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    aj.queue_name,
    COUNT(*) FILTER (WHERE TRUE) AS total_jobs,
    COUNT(*) FILTER (WHERE aj.status = 'pending') AS pending_jobs,
    COUNT(*) FILTER (WHERE aj.status = 'processing') AS processing_jobs,
    COUNT(*) FILTER (WHERE aj.status = 'completed') AS completed_jobs,
    COUNT(*) FILTER (WHERE aj.status = 'failed') AS failed_jobs,
    MIN(aj.scheduled_for) FILTER (WHERE aj.status = 'pending') AS oldest_pending_job
  FROM public.async_jobs aj
  WHERE p_queue_name IS NULL OR aj.queue_name = p_queue_name
  GROUP BY aj.queue_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- STEP 6: Create Cleanup Function
-- ============================================================================

-- Function to clean up old completed/failed jobs
CREATE OR REPLACE FUNCTION public.cleanup_old_jobs(
  p_queue_name TEXT DEFAULT NULL,
  p_older_than_days INTEGER DEFAULT 7
) RETURNS INTEGER AS $$
DECLARE
  v_deleted_count INTEGER;
BEGIN
  DELETE FROM public.async_jobs
  WHERE status IN ('completed', 'failed')
    AND completed_at < NOW() - (p_older_than_days || ' days')::INTERVAL
    AND (p_queue_name IS NULL OR queue_name = p_queue_name);
  
  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
  
  RETURN v_deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- STEP 7: Set Up Row Level Security (RLS)
-- ============================================================================

-- Enable RLS on async_jobs table
ALTER TABLE public.async_jobs ENABLE ROW LEVEL SECURITY;

-- Policy: Allow service role to do everything
CREATE POLICY "Service role has full access"
  ON public.async_jobs
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Policy: Allow authenticated users to view their own jobs
CREATE POLICY "Users can view their own pending jobs"
  ON public.async_jobs
  FOR SELECT
  TO authenticated
  USING (
    auth.uid()::text = (payload->>'userId')::text
    OR status = 'pending'
  );

-- ============================================================================
-- STEP 8: Insert Sample Test Data (Optional - Comment out in production)
-- ============================================================================

-- Uncomment to add test data:
-- SELECT enqueue_job('order_processing', '{"orderId": "test-123", "userId": "user-456"}'::jsonb);
-- SELECT enqueue_job('notifications', '{"type": "welcome", "userId": "user-456"}'::jsonb);

-- ============================================================================
-- STEP 9: Verification Queries
-- ============================================================================

-- Show setup summary
SELECT '✅ PGMQ Extension' AS component, 
       CASE WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pgmq') 
            THEN 'Installed' ELSE 'Not Installed' END AS status
UNION ALL
SELECT '✅ Queues Created', 
       COUNT(*)::text || ' queues'
FROM pgmq.list_queues()
UNION ALL
SELECT '✅ Fallback Table', 
       CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'async_jobs') 
            THEN 'Created' ELSE 'Not Created' END
UNION ALL
SELECT '✅ Helper Functions', 
       COUNT(*)::text || ' functions'
FROM pg_proc 
WHERE proname IN ('enqueue_job', 'dequeue_job', 'complete_job', 'fail_job', 'retry_job', 'get_queue_stats', 'cleanup_old_jobs');

-- ============================================================================
-- STEP 10: Useful Monitoring Queries (for reference)
-- ============================================================================

-- View queue stats (fallback table)
-- SELECT * FROM get_queue_stats();

-- View specific queue stats
-- SELECT * FROM get_queue_stats('order_processing');

-- View pending jobs
-- SELECT id, queue_name, payload, scheduled_for 
-- FROM async_jobs 
-- WHERE status = 'pending' 
-- ORDER BY scheduled_for 
-- LIMIT 10;

-- Clean up old jobs (older than 7 days)
-- SELECT cleanup_old_jobs(NULL, 7);

-- ============================================================================
-- END OF MIGRATION
-- ============================================================================

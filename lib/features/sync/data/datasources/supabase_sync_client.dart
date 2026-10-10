import 'dart:async';
import '../../domain/entities/batch_sync_payload.dart';

const String supabaseRlsSqlSchema = '''
-- ChronoHub Supabase Database Schema & Row-Level Security (RLS) Policies
-- Free-tier PostgreSQL single source of truth for remote sync

-- 1. calendar_spaces
CREATE TABLE IF NOT EXISTS public.calendar_spaces (
    id UUID PRIMARY KEY,
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    color INTEGER NOT NULL,
    icon TEXT,
    is_personal BOOLEAN NOT NULL DEFAULT true,
    version INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    is_deleted BOOLEAN NOT NULL DEFAULT false
);
ALTER TABLE public.calendar_spaces ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can access their own spaces"
    ON public.calendar_spaces FOR ALL
    USING (auth.uid() = owner_id);

-- 2. calendar_events
CREATE TABLE IF NOT EXISTS public.calendar_events (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    location TEXT,
    start_time TIMESTAMPTZ,
    end_time TIMESTAMPTZ,
    is_all_day BOOLEAN NOT NULL DEFAULT false,
    is_anchored BOOLEAN NOT NULL DEFAULT false,
    status TEXT NOT NULL DEFAULT 'pending',
    priority INTEGER NOT NULL DEFAULT 0,
    estimated_minutes INTEGER NOT NULL DEFAULT 30,
    actual_minutes INTEGER NOT NULL DEFAULT 0,
    color INTEGER,
    recurrence_rule TEXT,
    task_score REAL NOT NULL DEFAULT 0.0,
    version INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    is_deleted BOOLEAN NOT NULL DEFAULT false
);
ALTER TABLE public.calendar_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can access their own events"
    ON public.calendar_events FOR ALL
    USING (auth.uid() = user_id);

-- 3. event_space_links (Junction for Linked Mirroring)
CREATE TABLE IF NOT EXISTS public.event_space_links (
    id UUID PRIMARY KEY,
    event_id UUID NOT NULL REFERENCES public.calendar_events(id) ON DELETE CASCADE,
    space_id UUID NOT NULL REFERENCES public.calendar_spaces(id) ON DELETE CASCADE,
    version INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    is_deleted BOOLEAN NOT NULL DEFAULT false
);
ALTER TABLE public.event_space_links ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can access their linked spaces"
    ON public.event_space_links FOR ALL
    USING (EXISTS (
        SELECT 1 FROM public.calendar_events e
        WHERE e.id = event_space_links.event_id AND e.user_id = auth.uid()
    ));

-- 4. event_comments
CREATE TABLE IF NOT EXISTS public.event_comments (
    id UUID PRIMARY KEY,
    event_id UUID NOT NULL REFERENCES public.calendar_events(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES auth.users(id),
    author_name TEXT NOT NULL,
    content TEXT NOT NULL,
    version INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    is_deleted BOOLEAN NOT NULL DEFAULT false
);
ALTER TABLE public.event_comments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can access comments on visible events"
    ON public.event_comments FOR ALL
    USING (EXISTS (
        SELECT 1 FROM public.calendar_events e
        WHERE e.id = event_comments.event_id AND e.user_id = auth.uid()
    ));

-- 5. event_checklists
CREATE TABLE IF NOT EXISTS public.event_checklists (
    id UUID PRIMARY KEY,
    event_id UUID NOT NULL REFERENCES public.calendar_events(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    is_completed BOOLEAN NOT NULL DEFAULT false,
    sort_order INTEGER NOT NULL DEFAULT 0,
    category TEXT,
    version INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    is_deleted BOOLEAN NOT NULL DEFAULT false
);
ALTER TABLE public.event_checklists ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can access checklists on visible events"
    ON public.event_checklists FOR ALL
    USING (EXISTS (
        SELECT 1 FROM public.calendar_events e
        WHERE e.id = event_checklists.event_id AND e.user_id = auth.uid()
    ));

-- 6. keep_items
CREATE TABLE IF NOT EXISTS public.keep_items (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    content TEXT,
    priority INTEGER NOT NULL DEFAULT 0,
    estimated_minutes INTEGER NOT NULL DEFAULT 30,
    version INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    is_deleted BOOLEAN NOT NULL DEFAULT false
);
ALTER TABLE public.keep_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can access their own keep items"
    ON public.keep_items FOR ALL
    USING (auth.uid() = user_id);

-- 7. processed_idempotency_keys (For Feature #43 Idempotent RPC Fallback)
CREATE TABLE IF NOT EXISTS public.processed_idempotency_keys (
    key UUID PRIMARY KEY,
    device_id TEXT NOT NULL,
    user_id UUID NOT NULL REFERENCES auth.users(id),
    applied_count INTEGER NOT NULL,
    processed_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);
ALTER TABLE public.processed_idempotency_keys ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can access their own idempotency keys"
    ON public.processed_idempotency_keys FOR ALL
    USING (auth.uid() = user_id);
''';

abstract class SupabaseSyncClient {
  Future<bool> ping();

  Future<void> upsert({
    required String table,
    required Map<String, dynamic> data,
  });

  Future<void> delete({
    required String table,
    required String id,
  });

  Future<List<Map<String, dynamic>>> query({
    required String table,
    required DateTime since,
    int limit = 100,
  });

  Future<BatchSyncResult> executeBatchRpc(BatchSyncPayload payload);

  Stream<Map<String, dynamic>> realtimeStream(String table);
}

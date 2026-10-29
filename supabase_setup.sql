-- ============================================================================
-- DASTAK V2 SCHEMA (PRODUCTION READY)
-- Run this ENTIRE file in the Supabase SQL Editor.
-- WARNING: This will DROP existing tables to apply the V2 architecture cleanly.
-- ============================================================================

-- 0. EXTENSIONS & CLEANUP
create extension if not exists pgcrypto;
create extension if not exists "uuid-ossp";

drop table if exists public.scans cascade;
drop table if exists public.passes cascade;
drop table if exists public.events cascade;
drop table if exists public.society_gates cascade;
drop table if exists public.societies cascade;
drop table if exists public.profiles cascade;

-- Drop old functions/triggers
drop function if exists public.record_scan(uuid, text, text, text, uuid) cascade;
drop function if exists public.event_stats(uuid) cascade;
drop function if exists public.reissue_pass(uuid, uuid) cascade;
drop function if exists public.handle_new_user() cascade;

-- 1. TABLES
-- ----------------------------------------------------------------------------

-- SOCIETIES
create table public.societies (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  join_code text not null unique,
  guard_code text not null unique,
  admin_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

-- SOCIETY GATES (Fixed list of gates per society)
create table public.society_gates (
  id uuid primary key default gen_random_uuid(),
  society_id uuid not null references public.societies(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now(),
  unique(society_id, name)
);

-- PROFILES (Source of truth for user identity)
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  full_name text,
  role text check (role in ('resident', 'organizer', 'guard', 'admin')),
  society_id uuid references public.societies(id) on delete set null,
  event_id uuid, -- Populated later for event guards
  gate_name text,
  phone text,
  status text not null default 'active' check (status in ('active', 'revoked')),
  setup_complete boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- EVENTS (Organizer)
create table public.events (
  id uuid primary key default gen_random_uuid(),
  organizer_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  event_type text not null,
  guard_code text not null unique,
  gates text[] not null default '{"Main Entrance"}',
  start_at timestamptz not null,
  end_at timestamptz,
  venue_name text,
  address text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

-- PASSES (Visitor & Event)
create table public.passes (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('visitor', 'event')),
  qr_token uuid not null default gen_random_uuid(), -- Rotated on reissue
  status text not null default 'active' check (status in ('active', 'used', 'expired', 'revoked')),
  
  -- Foreign Keys
  event_id uuid references public.events(id) on delete cascade,
  society_id uuid references public.societies(id) on delete cascade,
  created_by uuid not null references public.profiles(id) on delete cascade,
  
  -- Visitor details
  visitor_name text not null,
  visitor_phone text,
  visitor_email text,
  visitor_type text,
  company text,
  visitor_count integer not null default 1,
  vehicle text,
  apartment text,
  purpose text,
  
  -- Photo Storage (Supabase Storage paths, NOT base64)
  photo_path text,
  photo_thumb_path text,
  
  -- Validity
  valid_from timestamptz,
  valid_until timestamptz,
  multiple_entries boolean not null default false,
  entries_used integer not null default 0,
  
  -- Recurring (Residents only)
  recurrence_days integer[] default null, -- 1=Mon, 7=Sun
  window_start time,
  window_end time,
  
  created_at timestamptz not null default now(),
  revoked_at timestamptz
);

-- SCANS (Audit log & Race condition protection)
create table public.scans (
  id uuid primary key default gen_random_uuid(),
  pass_id uuid not null references public.passes(id) on delete cascade,
  scanned_by uuid not null references public.profiles(id) on delete cascade,
  society_id uuid references public.societies(id) on delete cascade,
  event_id uuid references public.events(id) on delete cascade,
  gate_name text,
  result text not null check (result in ('allowed', 'rejected')),
  reason text,
  request_id uuid not null unique, -- Idempotency key from client
  scanned_at timestamptz not null default now()
);

-- 2. INDEXES (Performance)
-- ----------------------------------------------------------------------------
create index if not exists idx_profiles_society on public.profiles(society_id);
create index if not exists idx_passes_created_by on public.passes(created_by);
create index if not exists idx_passes_event on public.passes(event_id);
create index if not exists idx_passes_society on public.passes(society_id);
create index if not exists idx_scans_pass on public.scans(pass_id);
create index if not exists idx_scans_society on public.scans(society_id);
create index if not exists idx_scans_event on public.scans(event_id);

-- 3. TRIGGERS (Immutability & Setup)
-- ----------------------------------------------------------------------------

-- Prevent role changes after setup
create or replace function public.prevent_role_change()
returns trigger as $$
begin
  if old.role is not null and old.role != new.role then
    raise exception 'Role cannot be changed once set.';
  end if;
  return new;
end;
$$ language plpgsql;

drop trigger if exists tr_prevent_role_change on public.profiles;
create trigger tr_prevent_role_change
  before update on public.profiles
  for each row execute function public.prevent_role_change();

-- Automatically create profile on auth signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email, full_name)
  values (new.id, new.email, new.raw_user_meta_data->>'full_name');
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 4. RPC FUNCTIONS (Business Logic)
-- ----------------------------------------------------------------------------

-- Resident creates a society
create or replace function public.create_society(
  p_name text, p_join_code text, p_guard_code text
) returns uuid as $$
declare
  v_society_id uuid;
begin
  insert into public.societies (name, join_code, guard_code, admin_id)
  values (p_name, p_join_code, p_guard_code, auth.uid())
  returning id into v_society_id;

  update public.profiles
  set role = 'admin', society_id = v_society_id, setup_complete = true
  where id = auth.uid();

  return v_society_id;
end;
$$ language plpgsql security definer;

-- Guard joins society or event
create or replace function public.join_as_guard(
  p_code text, p_gate_name text, p_is_event boolean default false
) returns boolean as $$
declare
  v_society_id uuid;
  v_event_id uuid;
begin
  if p_is_event then
    select id into v_event_id from public.events where guard_code = p_code;
    if not found then raise exception 'Invalid event guard code.'; end if;
    
    update public.profiles
    set role = 'guard', event_id = v_event_id, gate_name = p_gate_name, setup_complete = true
    where id = auth.uid();
  else
    select id into v_society_id from public.societies where guard_code = p_code;
    if not found then raise exception 'Invalid society guard code.'; end if;
    
    update public.profiles
    set role = 'guard', society_id = v_society_id, gate_name = p_gate_name, setup_complete = true
    where id = auth.uid();
  end if;
  return true;
end;
$$ language plpgsql security definer;

-- Organizer re-issues a pass (rotates qr_token)
create or replace function public.reissue_pass(p_pass_id uuid, p_organizer_id uuid)
returns uuid as $$
declare
  v_new_token uuid;
begin
  if not exists (select 1 from public.events where id = (select event_id from public.passes where id = p_pass_id) and organizer_id = p_organizer_id) then
    raise exception 'Not authorized to re-issue this pass.';
  end if;

  update public.passes
  set qr_token = gen_random_uuid(), status = 'active', entries_used = 0
  where id = p_pass_id
  returning qr_token into v_new_token;

  return v_new_token;
end;
$$ language plpgsql security definer;

-- Atomic scan recording (Prevents double scanning / race conditions)
create or replace function public.record_scan(
  p_pass_id uuid,
  p_result text,
  p_reason text,
  p_gate_name text,
  p_request_id uuid
) returns jsonb as $$
declare
  v_pass record;
  v_profile record;
  v_scan_id uuid;
  v_existing_scan uuid;
begin
  -- 1. Check for idempotency (prevent double submission from network retries)
  select id into v_existing_scan from public.scans where request_id = p_request_id;
  if found then
    return jsonb_build_object('status', 'already_processed', 'scan_id', v_existing_scan);
  end if;

  -- 2. Lock the pass row for update to prevent simultaneous scans
  select * into v_pass from public.passes where id = p_pass_id for update;
  if not found then raise exception 'Pass not found.'; end if;

  -- 3. Get guard profile
  select * into v_profile from public.profiles where id = auth.uid();

  -- 4. Insert the scan record
  insert into public.scans (
    pass_id, scanned_by, society_id, event_id, gate_name, result, reason, request_id
  ) values (
    p_pass_id, auth.uid(), v_pass.society_id, v_pass.event_id, p_gate_name, p_result, p_reason, p_request_id
  ) returning id into v_scan_id;

  -- 5. Update pass state if allowed
  if p_result = 'allowed' then
    if v_pass.multiple_entries then
      update public.passes set entries_used = entries_used + 1 where id = p_pass_id;
    else
      update public.passes set status = 'used', entries_used = 1 where id = p_pass_id;
    end if;
  end if;

  return jsonb_build_object('status', 'success', 'scan_id', v_scan_id);
end;
$$ language plpgsql security definer;

-- Event stats for live dashboard
create or replace function public.event_stats(p_event_id uuid)
returns jsonb as $$
declare
  v_total int;
  v_checked_in int;
begin
  select count(*) into v_total from public.passes where event_id = p_event_id;
  
  select count(distinct pass_id) into v_checked_in 
  from public.scans 
  where event_id = p_event_id and result = 'allowed';

  return jsonb_build_object(
    'total', v_total,
    'checked_in', v_checked_in,
    'pending', v_total - v_checked_in
  );
end;
$$ language plpgsql security definer;

-- 5. ROW LEVEL SECURITY (RLS)
-- ----------------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.societies enable row level security;
alter table public.society_gates enable row level security;
alter table public.events enable row level security;
alter table public.passes enable row level security;
alter table public.scans enable row level security;

-- Profiles: Users can read their own. Admins can read their society's profiles.
create policy "Users can read own profile" on public.profiles for select using (auth.uid() = id);
create policy "Admins can read society profiles" on public.profiles for select using (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin' and p.society_id = profiles.society_id)
);

-- Societies: Users can read societies they belong to.
create policy "Read own society" on public.societies for select using (
  id = (select society_id from public.profiles where id = auth.uid())
);

-- Events: Organizers read/write own. Guards can read if assigned.
create policy "Organizers manage own events" on public.events for all using (organizer_id = auth.uid());
create policy "Guards read assigned events" on public.events for select using (
  id = (select event_id from public.profiles where id = auth.uid())
);

-- Passes: 
-- Residents read own. Organizers read for their events. Guards read for their society/event.
create policy "Residents manage own passes" on public.passes for all using (created_by = auth.uid());
create policy "Organizers read event passes" on public.passes for select using (
  exists (select 1 from public.events e where e.id = passes.event_id and e.organizer_id = auth.uid())
);
create policy "Guards read society/event passes" on public.passes for select using (
  society_id = (select society_id from public.profiles where id = auth.uid()) or
  event_id = (select event_id from public.profiles where id = auth.uid())
);

-- Scans:
-- Guards can insert their own. Residents/Organizers can read scans for their passes.
create policy "Guards insert scans" on public.scans for insert with check (scanned_by = auth.uid());
create policy "Guards read society/event scans" on public.scans for select using (
  society_id = (select society_id from public.profiles where id = auth.uid()) or
  event_id = (select event_id from public.profiles where id = auth.uid())
);
create policy "Residents read pass scans" on public.scans for select using (
  pass_id in (select id from public.passes where created_by = auth.uid())
);
create policy "Organizers read event scans" on public.scans for select using (
  event_id in (select id from public.events where organizer_id = auth.uid())
);

-- 6. STORAGE BUCKET (Photos)
-- ----------------------------------------------------------------------------
insert into storage.buckets (id, name, public) values ('pass-photos', 'pass-photos', false) on conflict do nothing;

create policy "Authenticated can upload photos" on storage.objects for insert with check (
  bucket_id = 'pass-photos' and auth.role() = 'authenticated'
);

create policy "Authenticated can read photos" on storage.objects for select using (
  bucket_id = 'pass-photos' and auth.role() = 'authenticated'
);
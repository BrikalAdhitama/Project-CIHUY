-- CIHUY: run ONCE in the SQL Editor of the NEW Supabase project.
-- No DROP/TRUNCATE. Existing table names cause a transaction rollback.
begin;

create schema if not exists extensions;
create extension if not exists btree_gist with schema extensions;
set local search_path = public, extensions, pg_catalog;
create schema cihuy_private;
revoke all on schema cihuy_private from public, anon, authenticated;

-- Login, email and password belong to Supabase Auth, not this profile table.
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '' check (char_length(display_name) <= 120),
  avatar_url text,
  reason text not null default '' check (char_length(reason) <= 4000),
  started_at timestamptz not null default now() check (isfinite(started_at)),
  onboarding_completed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.consumption_habits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  kind text not null check (kind in ('cigarette', 'vape')),
  unit text generated always as
    (case kind when 'cigarette' then 'batang' else 'hisapan' end) stored,
  baseline_daily integer check (baseline_daily >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, kind),
  unique (id, user_id)
);

create table public.daily_targets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  habit_id uuid not null,
  daily_limit integer not null check (daily_limit >= 0),
  starts_on date not null check (isfinite(starts_on)),
  ends_on date check (isfinite(ends_on) and ends_on > starts_on),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (habit_id, user_id) references public.consumption_habits(id, user_id) on delete cascade,
  -- [start, end): same semantics as DailyTarget.appliesOn in Flutter.
  constraint daily_targets_no_overlap exclude using gist
    (habit_id with =, daterange(starts_on, ends_on, '[)') with &&)
    deferrable initially immediate
);
create index daily_targets_owner_day on public.daily_targets(user_id, starts_on);

create table public.consumption_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  habit_id uuid not null,
  consumed_at timestamptz not null check (isfinite(consumed_at)),
  amount integer not null check (amount > 0),
  note text not null default '' check (char_length(note) <= 4000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (habit_id, user_id) references public.consumption_habits(id, user_id) on delete cascade
);
create index consumption_records_owner_time on public.consumption_records(user_id, consumed_at);
create index consumption_records_habit_time on public.consumption_records(habit_id, consumed_at);

create table public.craving_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  habit_id uuid not null,
  occurred_at timestamptz not null check (isfinite(occurred_at)),
  intensity text not null default 'medium' check (intensity in ('light', 'medium', 'heavy')),
  triggers text[] not null default '{}',
  coping text not null default '' check (char_length(coping) <= 4000),
  resisted boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (habit_id, user_id) references public.consumption_habits(id, user_id) on delete cascade
);
create index craving_records_owner_time on public.craving_records(user_id, occurred_at);
create index craving_records_habit_time on public.craving_records(habit_id, occurred_at);

create table public.notification_preferences (
  user_id uuid primary key default auth.uid() references public.profiles(id) on delete cascade,
  enabled boolean not null default false,
  exceeded_enabled boolean not null default true,
  mode text not null default 'local' check (mode in ('local', 'push')),
  progress_time time(0) not null default '20:00'
    check (progress_time < time '24:00' and extract(second from progress_time) = 0),
  motivation_time time(0) not null default '08:00'
    check (motivation_time < time '24:00' and extract(second from motivation_time) = 0),
  timezone text not null default 'Asia/Makassar',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Backend-only: a client cannot register a token under an arbitrary user.
-- The backend must derive user_id from a verified Supabase access token.
create table public.notification_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  fcm_token text not null unique check (char_length(fcm_token) between 20 and 4096),
  platform text not null default 'android' check (platform in ('android', 'ios')),
  enabled boolean not null default true,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, user_id)
);
create index notification_devices_owner on public.notification_devices(user_id);

-- Durable send claims. Backend must INSERT a claim before calling FCM.
-- Duplicate conflict means SKIP sending; never retry an ambiguous send blindly.
-- device_id intentionally has no FK: deleting/re-registering a device must not
-- erase its claims. Retain the same installation ID through token rotation.
create table public.notification_deliveries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  device_id uuid not null,
  kind text not null check (kind in ('progress', 'motivation', 'exceeded')),
  habit_kind text not null default '' check (habit_kind in ('', 'cigarette', 'vape')),
  local_date date not null check (isfinite(local_date)),
  status text not null default 'claimed' check (status in ('claimed', 'sent', 'failed')),
  claimed_at timestamptz not null default now(),
  sent_at timestamptz,
  check ((kind = 'exceeded' and habit_kind <> '') or (kind <> 'exceeded' and habit_kind = '')),
  unique (user_id, device_id, kind, habit_kind, local_date)
);

create table public.motivational_quotes (
  id uuid primary key default gen_random_uuid(),
  body text not null check (char_length(trim(body)) between 1 and 1000),
  author text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create function cihuy_private.stamp_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create function cihuy_private.validate_timezone()
returns trigger language plpgsql set search_path = '' as $$
begin
  if not exists (select 1 from pg_catalog.pg_timezone_names where name = new.timezone) then
    raise exception 'Unknown timezone' using errcode = '23514';
  end if;
  return new;
end;
$$;
create trigger notification_preferences_timezone
before insert or update on public.notification_preferences
for each row execute function cihuy_private.validate_timezone();

-- Metadata is used only for display; never for ownership or authorization.
create function cihuy_private.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles(id, display_name)
  values (new.id, left(coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name', ''), 120));
  insert into public.notification_preferences(user_id) values (new.id);
  return new;
end;
$$;
revoke all on all functions in schema cihuy_private from public, anon, authenticated;
create trigger cihuy_on_auth_user_created
after insert on auth.users
for each row execute function cihuy_private.handle_new_user();

-- Support any accounts already created in this NEW project before this script.
insert into public.profiles(id, display_name)
select id, left(coalesce(raw_user_meta_data ->> 'full_name', raw_user_meta_data ->> 'name', ''), 120)
from auth.users;
insert into public.notification_preferences(user_id) select id from public.profiles;

-- Explicit grants: works with "Automatically expose new tables" disabled.
-- Only the tables declared above are affected; no project-wide grant changes.
do $$
declare t text;
begin
  foreach t in array array[
    'profiles', 'consumption_habits', 'daily_targets', 'consumption_records',
    'craving_records', 'notification_preferences', 'notification_devices',
    'notification_deliveries', 'motivational_quotes'
  ] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on table public.%I from public, anon, authenticated, service_role', t);
    execute format('grant select, insert, update, delete on table public.%I to service_role', t);
    if t <> 'notification_deliveries' then
      execute format('create trigger stamp_updated_at before update on public.%I for each row execute function cihuy_private.stamp_updated_at()', t);
    end if;
  end loop;
  foreach t in array array[
    'consumption_habits', 'daily_targets', 'consumption_records',
    'craving_records', 'notification_preferences'
  ] loop
    if t = 'consumption_habits' then
      execute format('grant select, insert, delete on table public.%I to authenticated', t);
      execute format('grant update(baseline_daily, is_active) on table public.%I to authenticated', t);
    else
      execute format('grant select, insert, update, delete on table public.%I to authenticated', t);
    end if;
    execute format('create policy owner_access on public.%I for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id)', t);
  end loop;
end;
$$;
grant usage on schema public to authenticated, service_role;
grant select on public.profiles to authenticated;
grant update(display_name, avatar_url, reason, started_at, onboarding_completed) on public.profiles to authenticated;
create policy profile_read on public.profiles for select to authenticated using ((select auth.uid()) = id);
create policy profile_update on public.profiles for update to authenticated
using ((select auth.uid()) = id) with check ((select auth.uid()) = id);
grant select on public.motivational_quotes to authenticated;
create policy active_quotes on public.motivational_quotes for select to authenticated using (is_active);
-- Devices/deliveries deliberately have no client policies or client grants.

commit;

select tablename, rowsecurity as rls_enabled
from pg_tables where schemaname = 'public' and tablename in (
  'profiles', 'consumption_habits', 'daily_targets', 'consumption_records',
  'craving_records', 'notification_preferences', 'notification_devices',
  'notification_deliveries', 'motivational_quotes'
) order by tablename;

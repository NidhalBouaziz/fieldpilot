-- Run this in Supabase SQL Editor for project uljaorybezvnzedjveek.
-- It creates the FieldPilot cloud database and locks rows to the signed-in user.

create table if not exists public.customers (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  first_name text not null default '',
  last_name text not null default '',
  company_name text not null default '',
  phone text not null default '',
  phone2 text,
  email text,
  address text,
  city text not null default '',
  governorate text not null default '',
  latitude double precision,
  longitude double precision,
  speciality text,
  notes text,
  status text not null default 'neverVisited',
  favorite boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_visit timestamptz,
  next_visit timestamptz,
  tags text[] not null default '{}',
  photo text,
  deleted_at timestamptz
);

create index if not exists customers_user_updated_idx
  on public.customers (user_id, updated_at desc);

create index if not exists customers_user_status_idx
  on public.customers (user_id, status);

create table if not exists public.visits (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  customer_id uuid not null references public.customers(id) on delete cascade,
  scheduled_at timestamptz not null,
  completed_at timestamptz,
  status text not null default 'planned',
  notes text,
  voice_note_path text,
  attachments text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists visits_user_scheduled_idx
  on public.visits (user_id, scheduled_at);

create index if not exists visits_customer_scheduled_idx
  on public.visits (customer_id, scheduled_at desc);

alter table public.customers enable row level security;
alter table public.visits enable row level security;

drop policy if exists "customers_select_own" on public.customers;
create policy "customers_select_own"
  on public.customers for select
  using (auth.uid() = user_id);

drop policy if exists "customers_insert_own" on public.customers;
create policy "customers_insert_own"
  on public.customers for insert
  with check (auth.uid() = user_id);

drop policy if exists "customers_update_own" on public.customers;
create policy "customers_update_own"
  on public.customers for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "customers_delete_own" on public.customers;
create policy "customers_delete_own"
  on public.customers for delete
  using (auth.uid() = user_id);

drop policy if exists "visits_select_own" on public.visits;
create policy "visits_select_own"
  on public.visits for select
  using (auth.uid() = user_id);

drop policy if exists "visits_insert_own" on public.visits;
create policy "visits_insert_own"
  on public.visits for insert
  with check (auth.uid() = user_id);

drop policy if exists "visits_update_own" on public.visits;
create policy "visits_update_own"
  on public.visits for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "visits_delete_own" on public.visits;
create policy "visits_delete_own"
  on public.visits for delete
  using (auth.uid() = user_id);

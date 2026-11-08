-- Pottuvil Blue Sky Jersey Request Portal — Supabase PostgreSQL setup
-- Run in Supabase SQL Editor. Admin setup instructions in README.md.
create extension if not exists pgcrypto;

create table if not exists public.jersey_requests (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  player_name text not null check (char_length(btrim(player_name)) between 1 and 100),
  jersey_number integer not null check (jersey_number between 0 and 999),
  printed_name text not null check (char_length(btrim(printed_name)) between 1 and 30),
  jersey_size text not null check (jersey_size in ('XS','S','M','L','XL','2XL','3XL','4XL','5XL')),
  fit text not null check (fit in ('Regular','Slim','Relaxed')),
  sleeve_style text not null check (sleeve_style in ('Short sleeve','Long sleeve')),
  contact_number text not null check (char_length(btrim(contact_number)) between 1 and 25),
  payment_status text not null check (payment_status in ('Paid','Not Paid')),
  paid_to text check (paid_to in ('AMJED','MAHIR')),
  expected_payment_date date,
  remarks text not null default '' check (char_length(remarks) <= 1000),
  confirmation_status text not null default 'Pending' check (confirmation_status in ('Pending','Confirmed','Rejected')),
  constraint payment_details_consistent check (
    (payment_status='Paid' and paid_to is not null and expected_payment_date is null)
    or (payment_status='Not Paid' and paid_to is null and expected_payment_date is not null)
  )
);

create table if not exists public.portal_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create index if not exists jersey_requests_created_idx on public.jersey_requests(created_at desc);
create index if not exists jersey_requests_payment_idx on public.jersey_requests(payment_status);

alter table public.jersey_requests enable row level security;
alter table public.portal_admins enable row level security;

-- Avoid allowing the public to read contact numbers or enumerate player requests.
-- Explicitly restrict table privileges and then grant only necessary operations.
revoke all on public.jersey_requests from anon, authenticated;
revoke all on public.portal_admins from anon, authenticated;
grant insert on public.jersey_requests to anon, authenticated;
grant select, update, delete on public.jersey_requests to authenticated;
grant select on public.portal_admins to authenticated;

-- Public can submit, but cannot set confirmation to Confirmed or Rejected.
-- The CHECK constraints enforce payment-field consistency.
drop policy if exists "Public submit pending requests" on public.jersey_requests;
create policy "Public submit pending requests" on public.jersey_requests
for insert to anon, authenticated with check (confirmation_status='Pending');

-- Admin status comes from an allowlist. Users cannot self-register as admins.
drop policy if exists "Admins read own membership" on public.portal_admins;
create policy "Admins read own membership" on public.portal_admins
for select to authenticated using (user_id=(select auth.uid()));

drop policy if exists "Admins read requests" on public.jersey_requests;
create policy "Admins read requests" on public.jersey_requests
for select to authenticated using (
  exists(select 1 from public.portal_admins a where a.user_id=(select auth.uid()))
);
drop policy if exists "Admins update requests" on public.jersey_requests;
create policy "Admins update requests" on public.jersey_requests
for update to authenticated using (
  exists(select 1 from public.portal_admins a where a.user_id=(select auth.uid()))
) with check (
  exists(select 1 from public.portal_admins a where a.user_id=(select auth.uid()))
);
drop policy if exists "Admins delete requests" on public.jersey_requests;
create policy "Admins delete requests" on public.jersey_requests
for delete to authenticated using (
  exists(select 1 from public.portal_admins a where a.user_id=(select auth.uid()))
);

-- Once an admin account is created in Supabase Authentication > Users,
-- replace the UUID below with its auth.users ID and run this separately:
-- insert into public.portal_admins(user_id)
-- values ('00000000-0000-0000-0000-000000000000')
-- on conflict (user_id) do nothing;

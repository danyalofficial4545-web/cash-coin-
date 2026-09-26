-- Cash Coin / Lovable Cloud Supabase schema
create extension if not exists "pgcrypto";

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text unique not null,
  username text unique not null check (username ~ '^[A-Za-z0-9]{4,15}$'),
  referral_code text unique not null,
  referred_by text,
  coins integer not null default 0 check (coins >= 0),
  total_tasks integer not null default 0,
  is_banned boolean not null default false,
  created_at timestamptz not null default now()
);
create table if not exists public.user_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'user' check (role in ('user','admin'))
);
create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(), title text not null, description text not null default '', coins_reward integer not null default 0,
  link text, category text not null default 'Featured', is_active boolean not null default true, created_by uuid references auth.users(id), created_at timestamptz not null default now()
);
create table if not exists public.user_tasks (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade, task_id uuid not null references public.tasks(id) on delete cascade,
  proof_image text, status text not null default 'pending' check (status in ('pending','approved','rejected')), rejection_reason text, submitted_at timestamptz not null default now(), unique(user_id, task_id)
);
create table if not exists public.withdrawals (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade, amount_coins integer not null, amount_pkr numeric(12,2) not null,
  method text not null check (method in ('JazzCash','Easypaisa','Bank')), account_number text not null, account_name text not null, status text not null default 'pending' check (status in ('pending','approved','rejected')), created_at timestamptz not null default now()
);
create table if not exists public.deposits (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade, amount_pkr numeric(12,2) not null, method text not null, transaction_id text not null, status text not null default 'pending', created_at timestamptz not null default now()
);
create table if not exists public.payment_accounts (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade, method text not null, account_number text not null, account_title text not null, unique(user_id, method, account_number)
);
create table if not exists public.referral_earnings (
  id uuid primary key default gen_random_uuid(), referrer_id uuid not null references auth.users(id) on delete cascade, referred_id uuid not null references auth.users(id) on delete cascade, coins integer not null default 50, created_at timestamptz not null default now()
);
create table if not exists public.site_settings (key text primary key, value text not null);
insert into public.site_settings(key,value) values ('coin_rate','100'),('referral_bonus','50'),('minimum_withdrawal','500'),('site_name','Cash Coin') on conflict (key) do nothing;

create or replace function public.is_admin() returns boolean language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.user_roles where user_id = auth.uid() and role = 'admin');
$$;
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path = public as $$
declare base_username text; final_username text; ref_code text;
begin
  base_username := coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1));
  final_username := regexp_replace(base_username, '[^A-Za-z0-9]', '', 'g');
  if length(final_username) < 4 then final_username := 'User' || floor(random()*900+100)::int; end if;
  final_username := left(final_username, 12);
  while exists(select 1 from public.profiles where lower(username)=lower(final_username)) loop final_username := left(final_username, 12) || floor(random()*900+100)::int; end loop;
  ref_code := final_username;
  insert into public.profiles(id,email,username,referral_code,referred_by) values(new.id,new.email,final_username,ref_code,nullif(new.raw_user_meta_data->>'referred_by','')) on conflict (id) do nothing;
  insert into public.user_roles(user_id,role) values(new.id, case when lower(new.email) in ('muhammaddanyal4949@gmail.com','muhammaddanyal4545@gmail.com') then 'admin' else 'user' end) on conflict (user_id) do nothing;
  return new;
end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.user_roles enable row level security;
alter table public.tasks enable row level security;
alter table public.user_tasks enable row level security;
alter table public.withdrawals enable row level security;
alter table public.deposits enable row level security;
alter table public.payment_accounts enable row level security;
alter table public.referral_earnings enable row level security;
alter table public.site_settings enable row level security;
create policy "profiles own read or admin" on public.profiles for select using (auth.uid()=id or public.is_admin());
create policy "profiles own insert" on public.profiles for insert with check (auth.uid()=id);
create policy "profiles own update" on public.profiles for update using (auth.uid()=id or public.is_admin());
create policy "roles own read" on public.user_roles for select using (auth.uid()=user_id or public.is_admin());
create policy "tasks public read" on public.tasks for select using (is_active or public.is_admin());
create policy "user tasks own" on public.user_tasks for all using (auth.uid()=user_id or public.is_admin()) with check (auth.uid()=user_id or public.is_admin());
create policy "withdrawals own" on public.withdrawals for all using (auth.uid()=user_id or public.is_admin()) with check (auth.uid()=user_id or public.is_admin());
create policy "deposits own" on public.deposits for all using (auth.uid()=user_id or public.is_admin()) with check (auth.uid()=user_id or public.is_admin());
create policy "payment accounts own" on public.payment_accounts for all using (auth.uid()=user_id or public.is_admin()) with check (auth.uid()=user_id or public.is_admin());
create policy "referrals participant" on public.referral_earnings for select using (auth.uid()=referrer_id or auth.uid()=referred_id or public.is_admin());
create policy "settings read" on public.site_settings for select using (true);

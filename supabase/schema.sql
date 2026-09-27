-- Cash Coin production schema for Lovable Cloud Supabase
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text unique not null,
  username text unique not null check (username ~ '^[A-Za-z0-9]{4,15}$'),
  referral_code text unique not null,
  referred_by text,
  coins integer not null default 0 check (coins >= 0),
  total_tasks integer not null default 0,
  is_banned boolean not null default false,
  package_name text not null default 'Free User' check (package_name in ('Free User','Basic Package','Pro Package','Premium Package')),
  package_activated_at timestamptz,
  created_at timestamptz not null default now()
);
alter table public.profiles add column if not exists package_name text not null default 'Free User';
alter table public.profiles add column if not exists package_activated_at timestamptz;
create table if not exists public.user_roles (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  role text not null default 'user' check (role in ('user','admin'))
);
create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(), title text not null, description text not null default '', coins_reward integer not null default 0,
  task_link text, category text not null default 'Featured', is_active boolean not null default true, created_by uuid references public.profiles(id), created_at timestamptz not null default now()
);
create table if not exists public.user_tasks (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade, task_id uuid not null references public.tasks(id) on delete cascade,
  proof_image_url text, status text not null default 'pending' check (status in ('pending','approved','rejected')), rejection_reason text, submitted_at timestamptz not null default now(), unique(user_id,task_id)
);
create table if not exists public.withdrawals (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade, amount_coins integer not null, amount_pkr numeric(12,2) not null,
  method text not null check (method in ('JazzCash','Easypaisa','Bank')), account_number text not null, account_title text not null, status text not null default 'pending' check (status in ('pending','approved','rejected')), created_at timestamptz not null default now()
);
create table if not exists public.deposits (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade, amount_pkr numeric(12,2) not null, method text not null, transaction_id text not null, status text not null default 'pending', created_at timestamptz not null default now()
);
create table if not exists public.payment_accounts (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade, method text not null, account_number text not null, account_title text not null, created_at timestamptz not null default now(), unique(user_id,method,account_number)
);
create table if not exists public.referral_earnings (
  id uuid primary key default gen_random_uuid(), referrer_id uuid not null references public.profiles(id) on delete cascade, referred_id uuid not null references public.profiles(id) on delete cascade, coins integer not null default 50, created_at timestamptz not null default now(), unique(referrer_id,referred_id)
);
create table if not exists public.site_settings (key text primary key, value text not null);
insert into public.site_settings(key,value) values ('coin_rate','100'),('referral_bonus','50'),('minimum_withdrawal','500'),('site_name','Cash Coin') on conflict(key) do nothing;

-- Public proofs bucket. The upsert is safe to run repeatedly.
insert into storage.buckets(id,name,public) values ('proofs','proofs',true) on conflict(id) do update set public=true;

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.user_roles where user_id=auth.uid() and role='admin');
$$;

create or replace function public.random_referral_code(p_username text) returns text
language plpgsql volatile security definer set search_path = public as $$
declare code text; alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; i integer;
begin
  loop
    code := upper(left(regexp_replace(p_username,'[^A-Za-z0-9]','','g'),4));
    for i in 1..4 loop code := code || substr(alphabet, floor(random()*length(alphabet)+1)::int, 1); end loop;
    exit when not exists(select 1 from public.profiles where referral_code=code);
  end loop;
  return code;
end; $$;

create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare base_username text; final_username text; code text; requested_ref text; valid_ref text; referrer uuid;
begin
  base_username := regexp_replace(coalesce(new.raw_user_meta_data->>'username',split_part(new.email,'@',1)),'[^A-Za-z0-9]','','g');
  if length(base_username)<4 then base_username := 'User' || floor(random()*900+100)::int; end if;
  final_username := left(base_username,15);
  while exists(select 1 from public.profiles where lower(username)=lower(final_username)) loop
    final_username := left(base_username,11) || floor(random()*9000+1000)::int;
  end loop;
  code := coalesce(nullif(new.raw_user_meta_data->>'referral_code',''),public.random_referral_code(final_username));
  while exists(select 1 from public.profiles where referral_code=code) loop code := public.random_referral_code(final_username); end loop;
  requested_ref := nullif(upper(trim(new.raw_user_meta_data->>'referred_by')),'');
  select p.referral_code,p.id into valid_ref,referrer from public.profiles p where upper(p.referral_code)=requested_ref and p.id<>new.id limit 1;
  insert into public.profiles(id,email,username,referral_code,referred_by) values(new.id,new.email,final_username,code,valid_ref) on conflict(id) do nothing;
  insert into public.user_roles(user_id,role) values(new.id,case when lower(new.email)='muhammaddanyal4949@gmail.com' then 'admin' else 'user' end) on conflict(user_id) do nothing;
  if referrer is not null then
    insert into public.referral_earnings(referrer_id,referred_id,coins) values(referrer,new.id,50) on conflict(referrer_id,referred_id) do nothing;
    update public.profiles set coins=coins+50 where id=referrer;
  end if;
  return new;
exception when others then
  raise log '[Cash Coin] handle_new_user failed for %: %',new.id,sqlerrm;
  raise;
end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

-- Enable RLS on every application table.
alter table public.profiles enable row level security;
alter table public.user_roles enable row level security;
alter table public.tasks enable row level security;
alter table public.user_tasks enable row level security;
alter table public.withdrawals enable row level security;
alter table public.deposits enable row level security;
alter table public.payment_accounts enable row level security;
alter table public.referral_earnings enable row level security;
alter table public.site_settings enable row level security;

do $$ declare t text; p text; begin
  for t in select unnest(array['profiles','user_roles','tasks','user_tasks','withdrawals','deposits','payment_accounts','referral_earnings','site_settings']) loop
    for p in select policyname from pg_policies where schemaname='public' and tablename=t loop execute format('drop policy if exists %I on public.%I',p,t); end loop;
  end loop;
end $$;

create policy allow_insert_own on public.profiles for insert with check(auth.uid()=id);
create policy allow_select_own_or_admin on public.profiles for select using(auth.uid()=id or public.is_admin());
create policy allow_update_own_or_admin on public.profiles for update using(auth.uid()=id or public.is_admin()) with check(auth.uid()=id or public.is_admin());
create policy service_role_full_profiles on public.profiles for all to service_role using(true) with check(true);
create policy allow_read_own_role on public.user_roles for select using(auth.uid()=user_id or public.is_admin());
create policy service_role_full_roles on public.user_roles for all to service_role using(true) with check(true);
create policy public_read_active_tasks on public.tasks for select using(is_active or public.is_admin());
create policy admin_manage_tasks on public.tasks for all using(public.is_admin()) with check(public.is_admin());
create policy service_role_full_tasks on public.tasks for all to service_role using(true) with check(true);
create policy own_user_tasks on public.user_tasks for all using(auth.uid()=user_id or public.is_admin()) with check(auth.uid()=user_id or public.is_admin());
create policy service_role_full_user_tasks on public.user_tasks for all to service_role using(true) with check(true);
create policy own_withdrawals on public.withdrawals for all using(auth.uid()=user_id or public.is_admin()) with check(auth.uid()=user_id or public.is_admin());
create policy service_role_full_withdrawals on public.withdrawals for all to service_role using(true) with check(true);
create policy own_deposits on public.deposits for all using(auth.uid()=user_id or public.is_admin()) with check(auth.uid()=user_id or public.is_admin());
create policy service_role_full_deposits on public.deposits for all to service_role using(true) with check(true);
create policy own_payment_accounts on public.payment_accounts for all using(auth.uid()=user_id or public.is_admin()) with check(auth.uid()=user_id or public.is_admin());
create policy service_role_full_payment_accounts on public.payment_accounts for all to service_role using(true) with check(true);
create policy participant_referrals on public.referral_earnings for select using(auth.uid()=referrer_id or auth.uid()=referred_id or public.is_admin());
create policy service_role_full_referrals on public.referral_earnings for all to service_role using(true) with check(true);
create policy public_read_settings on public.site_settings for select using(true);
create policy admin_write_settings on public.site_settings for all using(public.is_admin()) with check(public.is_admin());

-- In Supabase Dashboard > Authentication > Providers > Email, turn off Confirm email for direct signup/login.
-- Optional one-time cleanup, review before running in production:
-- delete from auth.users where id not in (select id from public.profiles);
-- Existing rows with a blank/NULL legacy code can be migrated with:
-- update public.profiles set referral_code=public.random_referral_code(username) where referral_code is null or btrim(referral_code)='';

-- Cash Coin production schema for Lovable Cloud Supabase
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text unique not null,
  username text unique not null check (username ~ '^[A-Za-z0-9]{4,15}$'),
  referral_code text unique not null,
  referred_by text,
  coins integer not null default 0 check (coins >= 0),
  deposit_wallet integer not null default 0,
  withdrawal_wallet integer not null default 0,
  total_tasks integer not null default 0,
  total_tasks_completed integer not null default 0,
  is_banned boolean not null default false,
  package_name text not null default 'Free' check (package_name in ('Free','Free User','Starter Package','Basic Package','Pro Package','Premium Package')),
  package_activated_at timestamptz,
  created_at timestamptz not null default now()
);
alter table public.profiles add column if not exists package_name text not null default 'Free';
alter table public.profiles add column if not exists package_activated_at timestamptz;
alter table public.profiles add column if not exists deposit_wallet integer not null default 0;
alter table public.profiles add column if not exists withdrawal_wallet integer not null default 0;
alter table public.profiles add column if not exists total_tasks_completed integer not null default 0;
update public.profiles set package_name='Free' where package_name='Free User';
alter table public.profiles drop constraint if exists profiles_package_name_check;
alter table public.profiles add constraint profiles_package_name_check check (package_name in ('Free','Free User','Starter Package','Basic Package','Pro Package','Premium Package'));
alter table public.profiles alter column package_name set default 'Free';
create table if not exists public.user_roles (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  role text not null default 'user' check (role in ('user','admin'))
);
create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(), title text not null, description text not null default '', coins_reward integer not null default 0,
  image_url text, task_link text, is_timewall boolean not null default false, reward_percent integer not null default 70, category text not null default 'Featured', is_active boolean not null default true, duration_minutes integer, start_at timestamptz, end_at timestamptz, created_by uuid references public.profiles(id), created_at timestamptz not null default now()
);
alter table public.tasks add column if not exists image_url text;
alter table public.tasks add column if not exists duration_minutes integer;
alter table public.tasks add column if not exists start_at timestamptz;
alter table public.tasks add column if not exists end_at timestamptz;
alter table public.tasks add column if not exists is_timewall boolean not null default false;
alter table public.tasks add column if not exists reward_percent integer not null default 70;
create table if not exists public.user_tasks (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade, task_id uuid not null references public.tasks(id) on delete cascade,
  proof_image_url text, proof_link text, status text not null default 'pending' check (status in ('running','pending','approved','rejected')), rejection_reason text, submitted_at timestamptz not null default now(), unique(user_id,task_id)
);
alter table public.user_tasks add column if not exists proof_link text;
alter table public.user_tasks drop constraint if exists user_tasks_status_check;
alter table public.user_tasks add constraint user_tasks_status_check check (status in ('running','pending','approved','rejected'));
create table if not exists public.withdrawals (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade, amount_coins integer not null, amount_pkr numeric(12,2) not null,
  method text not null check (method in ('JazzCash','Easypaisa','Bank')), account_number text not null, account_title text not null, status text not null default 'pending' check (status in ('pending','approved','rejected')), created_at timestamptz not null default now()
);
create table if not exists public.deposits (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade, amount_pkr numeric(12,2) not null, method text not null, payment_method text, transaction_id text not null, proof_image text, status text not null default 'pending', created_at timestamptz not null default now()
);
alter table public.deposits add column if not exists proof_image text;
alter table public.deposits add column if not exists payment_method text;
create table if not exists public.payment_accounts (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade, method text not null, title text, account_type text, account_number text not null, account_title text not null, is_active boolean not null default true, created_at timestamptz not null default now(), unique(user_id,method,account_number)
);
alter table public.payment_accounts add column if not exists title text;
alter table public.payment_accounts add column if not exists account_type text;
alter table public.payment_accounts add column if not exists is_active boolean not null default true;
create table if not exists public.referral_earnings (
  id uuid primary key default gen_random_uuid(), referrer_id uuid not null references public.profiles(id) on delete cascade, referred_id uuid not null references public.profiles(id) on delete cascade, task_id uuid references public.tasks(id) on delete set null, amount_coins integer not null default 50, coins integer not null default 50, total_earned_so_far integer not null default 0, type text not null default 'task', created_at timestamptz not null default now()
);
alter table public.referral_earnings add column if not exists amount_coins integer;
alter table public.referral_earnings add column if not exists type text not null default 'task';
alter table public.referral_earnings add column if not exists task_id uuid references public.tasks(id) on delete set null;
alter table public.referral_earnings add column if not exists total_earned_so_far integer not null default 0;
alter table public.referral_earnings drop constraint if exists referral_earnings_referrer_id_referred_id_key;
update public.referral_earnings set amount_coins=coins where amount_coins is null;
update public.referral_earnings set total_earned_so_far=amount_coins where total_earned_so_far=0;
create table if not exists public.site_settings (key text primary key, value text not null);
insert into public.site_settings(key,value) values ('coin_rate','100'),('referral_bonus','50'),('minimum_withdrawal','500'),('site_name','Cash Coin') on conflict(key) do nothing;
insert into public.tasks(title,description,coins_reward,task_link,category,is_active)
select 'Follow Instagram','Follow our official page',100,'https://instagram.com','Social',true
where not exists(select 1 from public.tasks where lower(title)=lower('Follow Instagram'));
insert into public.tasks(title,description,coins_reward,task_link,category,is_active)
select 'Subscribe YouTube','Subscribe to our channel',150,'https://youtube.com','Social',true
where not exists(select 1 from public.tasks where lower(title)=lower('Subscribe YouTube'));

-- Public proofs bucket. The upsert is safe to run repeatedly.
insert into storage.buckets(id,name,public) values ('proofs','proofs',true) on conflict(id) do update set public=true;
insert into storage.buckets(id,name,public) values ('task-images','task-images',true),('task-proofs','task-proofs',true) on conflict(id) do update set public=true;
insert into storage.buckets(id,name,public) values ('deposit-proofs','deposit-proofs',true) on conflict(id) do update set public=true;
drop policy if exists task_images_public_read on storage.objects;
drop policy if exists task_images_authenticated_upload on storage.objects;
drop policy if exists task_proofs_public_read on storage.objects;
drop policy if exists task_proofs_authenticated_upload on storage.objects;
create policy task_images_public_read on storage.objects for select using(bucket_id='task-images');
create policy task_images_authenticated_upload on storage.objects for insert to authenticated with check(bucket_id='task-images');
create policy task_proofs_public_read on storage.objects for select using(bucket_id='task-proofs');
create policy task_proofs_authenticated_upload on storage.objects for insert to authenticated with check(bucket_id='task-proofs');
drop policy if exists deposit_proofs_public_read on storage.objects;
drop policy if exists deposit_proofs_authenticated_upload on storage.objects;
create policy deposit_proofs_public_read on storage.objects for select using(bucket_id='deposit-proofs');
create policy deposit_proofs_authenticated_upload on storage.objects for insert to authenticated with check(bucket_id='deposit-proofs' and (storage.foldername(name))[1]=auth.uid()::text);

insert into public.payment_accounts(user_id,method,title,account_type,account_number,account_title,is_active)
select p.id,'JazzCash','Afaq Khan','JazzCash','03269337540','Afaq Khan',true
from public.profiles p
where lower(p.email)='muhammaddanyal4949@gmail.com'
and not exists(select 1 from public.payment_accounts a where a.account_number='03269337540');

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
  if tg_op = 'INSERT' then code := public.random_referral_code(final_username); end if;
  while exists(select 1 from public.profiles where referral_code=code) loop code := public.random_referral_code(final_username); end loop;
  requested_ref := nullif(upper(trim(new.raw_user_meta_data->>'referred_by')),'');
  select p.referral_code,p.id into valid_ref,referrer from public.profiles p where upper(p.referral_code)=requested_ref and p.id<>new.id limit 1;
  insert into public.profiles(id,email,username,referral_code,referred_by) values(new.id,new.email,final_username,code,valid_ref) on conflict(id) do nothing;
  insert into public.user_roles(user_id,role) values(new.id,case when lower(new.email)='muhammaddanyal4949@gmail.com' then 'admin' else 'user' end) on conflict(user_id) do nothing;
  return new;
exception when others then
  raise log '[Cash Coin] handle_new_user failed for %: %',new.id,sqlerrm;
  raise;
end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

create or replace function public.prevent_referral_code_update() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.referral_code is distinct from old.referral_code then raise exception 'Referral code is immutable'; end if;
  return new;
end; $$;
drop trigger if exists profiles_referral_code_immutable on public.profiles;
create trigger profiles_referral_code_immutable before update on public.profiles for each row execute function public.prevent_referral_code_update();

drop function if exists public.reward_referrer_on_task(uuid);
create or replace function public.reward_referrer_on_task(p_referred_id uuid, p_task_id uuid default null) returns void
language plpgsql security definer set search_path = public as $$
declare ref_code text; referrer uuid; earned integer; reward integer; running_total integer;
begin
  select referred_by into ref_code from public.profiles where id=p_referred_id;
  if ref_code is null then return; end if;
  select id into referrer from public.profiles where upper(referral_code)=upper(ref_code) and id<>p_referred_id limit 1;
  if referrer is null then return; end if;
  if p_task_id is not null and exists(select 1 from public.referral_earnings where referrer_id=referrer and referred_id=p_referred_id and task_id=p_task_id and type='task') then return; end if;
  select coalesce(sum(amount_coins),0) into earned from public.referral_earnings
    where referrer_id=referrer and referred_id=p_referred_id and type='task';
  if earned>=5000 then return; end if;
  reward := least(200, 5000-earned);
  running_total := earned + reward;
  insert into public.referral_earnings(referrer_id,referred_id,task_id,coins,amount_coins,total_earned_so_far,type) values(referrer,p_referred_id,p_task_id,reward,reward,running_total,'task');
  update public.profiles set coins=coins+reward,withdrawal_wallet=withdrawal_wallet+reward where id=referrer;
end; $$;
grant execute on function public.reward_referrer_on_task(uuid,uuid) to authenticated;

create or replace function public.approve_deposit_and_upgrade_package(p_deposit_id uuid, p_package_name text default 'Basic Package')
returns public.deposits language plpgsql security definer set search_path = public as $$
declare d public.deposits; ref_code text; referrer uuid; bonus integer; package_cost integer;
begin
  if not public.is_admin() then raise exception 'Admin access required'; end if;
  if p_package_name not in ('Starter Package','Basic Package','Pro Package','Premium Package') then raise exception 'Invalid package'; end if;
  select * into d from public.deposits where id=p_deposit_id;
  if d.id is null then raise exception 'Deposit not found'; end if;
  if d.status='approved' then return d; end if;
  update public.deposits set status='approved' where id=p_deposit_id returning * into d;
  if d.method='package_purchase' then
    p_package_name := case round(d.amount_pkr)::int when 200 then 'Starter Package' when 300 then 'Basic Package' when 400 then 'Pro Package' when 500 then 'Premium Package' else '' end;
    if p_package_name='' then raise exception 'Invalid package purchase amount'; end if;
    package_cost := round(d.amount_pkr*100)::int;
    update public.profiles set package_name=p_package_name,package_activated_at=now() where id=d.user_id;
  else
    update public.profiles set deposit_wallet=deposit_wallet+round(d.amount_pkr*100)::int where id=d.user_id;
  end if;
  select referred_by into ref_code from public.profiles where id=d.user_id;
  if d.method='package_purchase' and ref_code is not null then
    select id into referrer from public.profiles where upper(referral_code)=upper(ref_code) and id<>d.user_id limit 1;
    if referrer is not null then
      bonus := round(d.amount_pkr*0.10*100)::int;
      if bonus>0 then
        insert into public.referral_earnings(referrer_id,referred_id,coins,amount_coins,type) values(referrer,d.user_id,bonus,bonus,'package');
        update public.profiles set withdrawal_wallet=withdrawal_wallet+bonus where id=referrer;
      end if;
    end if;
  end if;
  return d;
end; $$;
grant execute on function public.approve_deposit_and_upgrade_package(uuid,text) to authenticated;

create or replace function public.approve_task_proof(p_user_task_id uuid) returns public.user_tasks
language plpgsql security definer set search_path = public as $$
declare ut public.user_tasks; reward integer;
begin
  if not public.is_admin() then raise exception 'Admin access required'; end if;
  select * into ut from public.user_tasks where id=p_user_task_id for update;
  if ut.id is null then raise exception 'Proof not found'; end if;
  if ut.status <> 'pending' then return ut; end if;
  select coins_reward into reward from public.tasks where id=ut.task_id;
  update public.user_tasks set status='approved' where id=p_user_task_id returning * into ut;
  update public.profiles set coins=coins+reward,withdrawal_wallet=withdrawal_wallet+reward,total_tasks=total_tasks+1,total_tasks_completed=total_tasks_completed+1 where id=ut.user_id;
  perform public.reward_referrer_on_task(ut.user_id,ut.task_id);
  return ut;
end; $$;
grant execute on function public.approve_task_proof(uuid) to authenticated;

create or replace function public.approve_withdrawal(p_withdrawal_id uuid) returns public.withdrawals
language plpgsql security definer set search_path = public as $$
declare w public.withdrawals; p public.profiles;
begin
  if not public.is_admin() then raise exception 'Admin access required'; end if;
  select * into w from public.withdrawals where id=p_withdrawal_id for update;
  if w.id is null then raise exception 'Withdrawal not found'; end if;
  if w.status='approved' then return w; end if;
  select * into p from public.profiles where id=w.user_id for update;
  if p.withdrawal_wallet < w.amount_coins then raise exception 'Insufficient withdrawal wallet'; end if;
  update public.profiles set withdrawal_wallet=withdrawal_wallet-w.amount_coins,coins=greatest(0,coins-w.amount_coins) where id=w.user_id;
  update public.withdrawals set status='approved' where id=p_withdrawal_id returning * into w;
  return w;
end; $$;
grant execute on function public.approve_withdrawal(uuid) to authenticated;

create or replace function public.request_withdrawal(p_amount_coins integer, p_method text, p_account_number text, p_account_title text) returns public.withdrawals
language plpgsql security definer set search_path = public as $$
declare p public.profiles; min_coins integer; w public.withdrawals;
begin
  select * into p from public.profiles where id=auth.uid();
  if p.id is null then raise exception 'Profile not found'; end if;
  min_coins := case p.package_name when 'Free' then 5000 when 'Free User' then 5000 when 'Starter Package' then 3000 when 'Basic Package' then 2000 when 'Pro Package' then 1000 when 'Premium Package' then 500 else 5000 end;
  if p_amount_coins < min_coins then raise exception 'Minimum withdrawal is % coins', min_coins; end if;
  if p_amount_coins > p.withdrawal_wallet then raise exception 'Insufficient withdrawal wallet'; end if;
  if p_method not in ('JazzCash','Easypaisa','Bank') then raise exception 'Invalid payment method'; end if;
  insert into public.withdrawals(user_id,amount_coins,amount_pkr,method,account_number,account_title) values(auth.uid(),p_amount_coins,round(p_amount_coins/100.0,2),p_method,p_account_number,p_account_title) returning * into w;
  return w;
end; $$;
grant execute on function public.request_withdrawal(integer,text,text,text) to authenticated;

create or replace function public.purchase_package(p_package_name text) returns public.profiles
language plpgsql security definer set search_path = public as $$
declare p public.profiles; price integer;
begin
  price := case p_package_name when 'Starter Package' then 200 when 'Basic Package' then 300 when 'Pro Package' then 400 when 'Premium Package' then 500 else 0 end;
  if price=0 then raise exception 'Invalid package'; end if;
  select * into p from public.profiles where id=auth.uid() for update;
  if p.id is null then raise exception 'Profile not found'; end if;
  if p.deposit_wallet < price*100 then raise exception 'Insufficient deposit wallet'; end if;
  update public.profiles set deposit_wallet=deposit_wallet-(price*100),package_name=p_package_name,package_activated_at=now() where id=auth.uid() returning * into p;
  return p;
end; $$;
grant execute on function public.purchase_package(text) to authenticated;

create or replace function public.start_task(p_task_id uuid) returns json
language plpgsql security definer set search_path = public as $$
declare p public.profiles; daily_limit integer; used_count integer;
begin
  select * into p from public.profiles where id=auth.uid();
  if p.id is null then raise exception 'Profile not found'; end if;
  daily_limit := case p.package_name when 'Free' then 1 when 'Free User' then 1 when 'Starter Package' then 5 when 'Basic Package' then 6 when 'Pro Package' then 8 when 'Premium Package' then 10 else 1 end;
  select count(*) into used_count from public.user_tasks where user_id=auth.uid() and submitted_at::date=current_date and status in ('running','pending','approved');
  if used_count >= daily_limit then raise exception 'Daily limit reached'; end if;
  if exists(select 1 from public.user_tasks where user_id=auth.uid() and task_id=p_task_id and status in ('running','pending','approved')) then raise exception 'Task already started'; end if;
  insert into public.user_tasks(user_id,task_id,status,submitted_at) values(auth.uid(),p_task_id,'running',now()) on conflict(user_id,task_id) do update set status='running',submitted_at=now();
  return json_build_object('started',true,'used',used_count+1,'limit',daily_limit);
end; $$;
grant execute on function public.start_task(uuid) to authenticated;

insert into public.user_roles(user_id,role)
select id,'admin' from public.profiles where lower(email)='muhammaddanyal4949@gmail.com'
on conflict(user_id) do update set role='admin';

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

-- ============================================================
-- LETEON 레테온 — C2C Bike Marketplace
-- Master Schema (safe to run multiple times)
--
-- 규칙:
--   DROP TABLE / TRUNCATE / DELETE FROM 절대 사용 금지
--   CREATE TABLE IF NOT EXISTS 사용
--   ALTER TABLE ADD COLUMN IF NOT EXISTS 사용
-- ============================================================

-- ============================================================
-- 1. PROFILES
-- ============================================================
create table if not exists public.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  username     text not null default '',
  avatar_url   text not null default '',
  bio          text not null default '',
  phone        text not null default '',
  heart_count  integer not null default 0,
  created_at   timestamptz not null default now()
);

-- ============================================================
-- 2. LISTINGS (판매 매물)
-- ============================================================
create table if not exists public.listings (
  id               uuid primary key default gen_random_uuid(),
  seller_id        uuid references public.profiles(id) on delete cascade not null,
  title            text not null,
  slug             text unique not null,
  category         text not null check (category in ('MTB', 'eMTB', 'eBike', 'Surron', 'Parts')),
  price            integer not null,
  description      text not null default '',
  specs            jsonb not null default '{}',
  image_urls       text[] not null default '{}',
  condition        text not null default 'good'
                     check (condition in ('new', 'like_new', 'good', 'fair')),
  location         text not null default '',
  status           text not null default 'draft'
                     check (status in ('draft', 'active', 'sold', 'deleted')),
  listing_fee      integer not null default 0,
  can_delete_after timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- 이후 추가된 컬럼 (기존 DB에 컬럼이 없는 경우만 추가)
alter table public.listings add column if not exists brand      text not null default '';
alter table public.listings add column if not exists model      text not null default '';
alter table public.listings add column if not exists year       smallint;
alter table public.listings add column if not exists thumbnail  text not null default '';
alter table public.listings add column if not exists updated_at timestamptz not null default now();

-- ============================================================
-- 3. HEARTS (신뢰 하트)
-- ============================================================
create table if not exists public.hearts (
  id           uuid primary key default gen_random_uuid(),
  from_user_id uuid references public.profiles(id) on delete cascade not null,
  to_user_id   uuid references public.profiles(id) on delete cascade not null,
  created_at   timestamptz not null default now(),
  unique(from_user_id, to_user_id),
  check (from_user_id != to_user_id)
);

-- ============================================================
-- 4. PAYMENTS (결제 내역 — 삭제하지 않는 불변 로그)
-- ============================================================
create table if not exists public.payments (
  id          uuid primary key default gen_random_uuid(),
  listing_id  uuid references public.listings(id) on delete set null,
  user_id     uuid references public.profiles(id) on delete set null,
  order_id    text unique not null,
  payment_key text,
  amount      integer not null,
  status      text not null default 'pending'
                check (status in ('pending', 'confirmed', 'failed')),
  created_at  timestamptz not null default now()
);

-- ============================================================
-- 5. REPORTS (신고 — 추가만, 삭제 없음)
-- ============================================================
create table if not exists public.reports (
  id            uuid primary key default gen_random_uuid(),
  reporter_id   uuid references public.profiles(id) on delete set null,
  target_type   text not null check (target_type in ('listing', 'user')),
  target_id     uuid not null,
  reason        text not null,
  detail        text not null default '',
  status        text not null default 'pending'
                  check (status in ('pending', 'reviewed', 'dismissed')),
  created_at    timestamptz not null default now()
);

-- ============================================================
-- 6. ADMIN_LOGS (관리자 행동 로그 — 삭제 없음)
-- ============================================================
create table if not exists public.admin_logs (
  id          uuid primary key default gen_random_uuid(),
  admin_id    uuid references public.profiles(id) on delete set null,
  action      text not null,
  target_type text not null,
  target_id   uuid,
  detail      jsonb not null default '{}',
  created_at  timestamptz not null default now()
);

-- ============================================================
-- 트리거: 신규 유저 → 프로필 자동 생성
-- ============================================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, username, avatar_url, phone)
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data->>'full_name',
      new.raw_user_meta_data->>'name',
      split_part(new.email, '@', 1)
    ),
    coalesce(
      new.raw_user_meta_data->>'avatar_url',
      new.raw_user_meta_data->>'picture',
      ''
    ),
    coalesce(new.raw_user_meta_data->>'phone', '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ============================================================
-- 트리거: 하트 추가 → heart_count 증가
-- ============================================================
create or replace function public.increment_heart_count()
returns trigger
language plpgsql security definer as $$
begin
  update public.profiles set heart_count = heart_count + 1 where id = new.to_user_id;
  return new;
end;
$$;

drop trigger if exists on_heart_created on public.hearts;
create trigger on_heart_created
  after insert on public.hearts
  for each row execute procedure public.increment_heart_count();

-- ============================================================
-- 트리거: 하트 삭제 → heart_count 감소
-- ============================================================
create or replace function public.decrement_heart_count()
returns trigger
language plpgsql security definer as $$
begin
  update public.profiles set heart_count = greatest(0, heart_count - 1) where id = old.to_user_id;
  return old;
end;
$$;

drop trigger if exists on_heart_deleted on public.hearts;
create trigger on_heart_deleted
  after delete on public.hearts
  for each row execute procedure public.decrement_heart_count();

-- ============================================================
-- 트리거: listings updated_at 자동 갱신
-- ============================================================
create or replace function public.set_updated_at()
returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists listings_set_updated_at on public.listings;
create trigger listings_set_updated_at
  before update on public.listings
  for each row execute procedure public.set_updated_at();

-- ============================================================
-- RLS (Row Level Security)
-- ============================================================

alter table public.profiles    enable row level security;
alter table public.listings    enable row level security;
alter table public.hearts      enable row level security;
alter table public.payments    enable row level security;
alter table public.reports     enable row level security;
alter table public.admin_logs  enable row level security;

-- 정책은 IF NOT EXISTS가 없으므로 DO 블록으로 중복 방지
do $$ begin
  -- profiles
  if not exists (select 1 from pg_policies where tablename='profiles' and policyname='profiles_select') then
    create policy "profiles_select"  on public.profiles for select using (true);
  end if;
  if not exists (select 1 from pg_policies where tablename='profiles' and policyname='profiles_update') then
    create policy "profiles_update"  on public.profiles for update using (auth.uid() = id);
  end if;
  if not exists (select 1 from pg_policies where tablename='profiles' and policyname='profiles_service') then
    create policy "profiles_service" on public.profiles for all using (true) with check (true);
  end if;

  -- listings
  if not exists (select 1 from pg_policies where tablename='listings' and policyname='listings_select_active') then
    create policy "listings_select_active" on public.listings for select using (status = 'active');
  end if;
  if not exists (select 1 from pg_policies where tablename='listings' and policyname='listings_insert_own') then
    create policy "listings_insert_own" on public.listings for insert with check (auth.uid() = seller_id);
  end if;
  if not exists (select 1 from pg_policies where tablename='listings' and policyname='listings_update_own') then
    create policy "listings_update_own" on public.listings for update using (auth.uid() = seller_id);
  end if;
  if not exists (select 1 from pg_policies where tablename='listings' and policyname='listings_delete_own') then
    create policy "listings_delete_own" on public.listings for delete using (auth.uid() = seller_id);
  end if;
  if not exists (select 1 from pg_policies where tablename='listings' and policyname='listings_service') then
    create policy "listings_service" on public.listings for all using (true) with check (true);
  end if;

  -- hearts
  if not exists (select 1 from pg_policies where tablename='hearts' and policyname='hearts_select') then
    create policy "hearts_select" on public.hearts for select using (true);
  end if;
  if not exists (select 1 from pg_policies where tablename='hearts' and policyname='hearts_insert') then
    create policy "hearts_insert" on public.hearts for insert with check (auth.uid() = from_user_id);
  end if;
  if not exists (select 1 from pg_policies where tablename='hearts' and policyname='hearts_delete') then
    create policy "hearts_delete" on public.hearts for delete using (auth.uid() = from_user_id);
  end if;

  -- payments (서비스 롤만 접근)
  if not exists (select 1 from pg_policies where tablename='payments' and policyname='payments_service') then
    create policy "payments_service" on public.payments for all using (true) with check (true);
  end if;

  -- reports
  if not exists (select 1 from pg_policies where tablename='reports' and policyname='reports_insert') then
    create policy "reports_insert" on public.reports for insert with check (auth.uid() = reporter_id);
  end if;
  if not exists (select 1 from pg_policies where tablename='reports' and policyname='reports_service') then
    create policy "reports_service" on public.reports for all using (true) with check (true);
  end if;

  -- admin_logs (서비스 롤만 쓰기)
  if not exists (select 1 from pg_policies where tablename='admin_logs' and policyname='admin_logs_service') then
    create policy "admin_logs_service" on public.admin_logs for all using (true) with check (true);
  end if;
end $$;

-- ============================================================
-- 인덱스
-- ============================================================
create index if not exists idx_listings_category   on public.listings (category);
create index if not exists idx_listings_slug        on public.listings (slug);
create index if not exists idx_listings_status      on public.listings (status);
create index if not exists idx_listings_seller_id   on public.listings (seller_id);
create index if not exists idx_listings_created_at  on public.listings (created_at desc);
create index if not exists idx_hearts_to_user       on public.hearts (to_user_id);
create index if not exists idx_hearts_from_user     on public.hearts (from_user_id);
create index if not exists idx_reports_target       on public.reports (target_type, target_id);
create index if not exists idx_admin_logs_created   on public.admin_logs (created_at desc);

-- ============================================================
-- Storage: listing-images 버킷
-- (Supabase 대시보드 Storage에서 직접 생성하거나 아래 실행)
-- ============================================================
insert into storage.buckets (id, name, public)
values ('listing-images', 'listing-images', true)
on conflict (id) do nothing;

-- Storage RLS
do $$ begin
  if not exists (select 1 from pg_policies where tablename='objects' and policyname='listing_images_select') then
    create policy "listing_images_select"
      on storage.objects for select using (bucket_id = 'listing-images');
  end if;
  if not exists (select 1 from pg_policies where tablename='objects' and policyname='listing_images_insert') then
    create policy "listing_images_insert"
      on storage.objects for insert with check (
        bucket_id = 'listing-images' and auth.role() = 'authenticated'
      );
  end if;
  if not exists (select 1 from pg_policies where tablename='objects' and policyname='listing_images_delete') then
    create policy "listing_images_delete"
      on storage.objects for delete using (
        bucket_id = 'listing-images' and auth.uid()::text = (storage.foldername(name))[1]
      );
  end if;
end $$;

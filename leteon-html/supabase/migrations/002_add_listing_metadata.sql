-- Migration 002: listings 테이블 컬럼 추가
-- Applied: 2026-06-29
-- Description: brand, model, year, thumbnail, updated_at 컬럼 추가
--              reports, admin_logs 테이블 신규 생성
--              Storage 버킷 listing-images 생성
--
-- 안전: ADD COLUMN IF NOT EXISTS 사용 → 기존 데이터 유지
-- Supabase SQL Editor에서 실행하세요.

-- listings 추가 컬럼
alter table public.listings add column if not exists brand      text not null default '';
alter table public.listings add column if not exists model      text not null default '';
alter table public.listings add column if not exists year       smallint;
alter table public.listings add column if not exists thumbnail  text not null default '';
alter table public.listings add column if not exists updated_at timestamptz not null default now();

-- updated_at 자동 갱신 트리거
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists listings_set_updated_at on public.listings;
create trigger listings_set_updated_at
  before update on public.listings
  for each row execute procedure public.set_updated_at();

-- 신고 테이블
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

-- 관리자 로그 테이블
create table if not exists public.admin_logs (
  id          uuid primary key default gen_random_uuid(),
  admin_id    uuid references public.profiles(id) on delete set null,
  action      text not null,
  target_type text not null,
  target_id   uuid,
  detail      jsonb not null default '{}',
  created_at  timestamptz not null default now()
);

-- RLS
alter table public.reports    enable row level security;
alter table public.admin_logs enable row level security;

do $$ begin
  if not exists (select 1 from pg_policies where tablename='reports' and policyname='reports_insert') then
    create policy "reports_insert" on public.reports for insert with check (auth.uid() = reporter_id);
  end if;
  if not exists (select 1 from pg_policies where tablename='reports' and policyname='reports_service') then
    create policy "reports_service" on public.reports for all using (true) with check (true);
  end if;
  if not exists (select 1 from pg_policies where tablename='admin_logs' and policyname='admin_logs_service') then
    create policy "admin_logs_service" on public.admin_logs for all using (true) with check (true);
  end if;
end $$;

-- 인덱스
create index if not exists idx_reports_target     on public.reports (target_type, target_id);
create index if not exists idx_admin_logs_created on public.admin_logs (created_at desc);

-- Storage 버킷
insert into storage.buckets (id, name, public)
values ('listing-images', 'listing-images', true)
on conflict (id) do nothing;

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
end $$;

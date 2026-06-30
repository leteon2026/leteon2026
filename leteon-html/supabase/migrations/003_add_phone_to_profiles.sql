-- Migration 003: profiles 테이블에 phone 컬럼 추가
-- Applied: 2026-06-29
-- Supabase SQL Editor에서 실행하세요.

alter table public.profiles add column if not exists phone text not null default '';

-- 신규 유저 가입 시 phone도 profiles에 저장하도록 트리거 업데이트
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

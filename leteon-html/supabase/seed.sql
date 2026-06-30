-- LETEON 레테온 — 예제 데이터 (Seed)
--
-- ⚠️  경고: 이 파일은 개발/테스트 환경에서만 수동으로 실행하세요.
-- ⚠️  운영(Production) DB에는 절대 자동 실행하지 마세요.
-- ⚠️  실행 전 반드시 개발 DB인지 확인하세요.
--
-- 실행 방법:
--   개발 DB의 Supabase SQL Editor에서 이 파일 내용을 복사해 실행
--
-- 이 파일은 INSERT ... ON CONFLICT DO NOTHING 을 사용하여
-- 중복 실행해도 기존 데이터를 덮어쓰지 않습니다.

-- 예제 매물 (실제 seller_id가 있어야 동작하므로 기본 주석 처리)
/*
insert into public.listings (
  id, seller_id, title, slug, category, price, description,
  condition, location, status, image_urls, specs
) values (
  gen_random_uuid(),
  '여기에_실제_유저_UUID',
  '[개발용] Trek Fuel EX 9.8 2023',
  'dev-trek-fuel-ex-9-8-2023',
  'MTB',
  3500000,
  '개발 테스트용 예제 매물입니다.',
  'good',
  '서울 강남구',
  'active',
  '{}',
  '{"프레임": "카본", "사이즈": "M"}'
) on conflict (slug) do nothing;
*/

-- 이 이하에 개발용 데이터를 추가하세요.
-- 운영 DB에는 실행하지 마세요.

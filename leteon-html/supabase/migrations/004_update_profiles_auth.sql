-- Migration 004: profiles 인증 필드 추가 및 강화
-- Applied: 2026-06-30
-- Supabase SQL Editor에서 실행하세요.
--
-- 안전: CREATE/ALTER ... IF NOT EXISTS, ON CONFLICT DO NOTHING 사용
-- DROP / TRUNCATE / DELETE 없음

-- ============================================================
-- 1. 새 컬럼 추가 (없으면 추가, 있으면 무시)
-- ============================================================
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email text NOT NULL DEFAULT '';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS verified_phone boolean NOT NULL DEFAULT false;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS role text NOT NULL DEFAULT 'user';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS deleted_at timestamptz;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

-- ============================================================
-- 2. 기존 빈 username 정리 (UNIQUE 제약 추가 전 중복 제거)
--    새 DB엔 데이터가 없으므로 기존 운영 DB용 안전 처리
-- ============================================================
UPDATE public.profiles
SET username = 'user_' || substring(id::text, 1, 8)
WHERE trim(username) = '' OR username IS NULL;

-- ============================================================
-- 3. username UNIQUE 제약 추가 (이미 있으면 무시)
-- ============================================================
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE table_schema = 'public'
      AND table_name   = 'profiles'
      AND constraint_type = 'UNIQUE'
      AND constraint_name = 'profiles_username_key'
  ) THEN
    ALTER TABLE public.profiles ADD CONSTRAINT profiles_username_key UNIQUE (username);
  END IF;
END $$;

-- ============================================================
-- 4. profiles updated_at 자동 갱신 트리거
-- ============================================================
CREATE OR REPLACE FUNCTION public.set_profiles_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS profiles_set_updated_at ON public.profiles;
CREATE TRIGGER profiles_set_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE PROCEDURE public.set_profiles_updated_at();

-- ============================================================
-- 5. 신규 유저 트리거 업데이트 (email 포함, upsert 방식)
--    API route에서 명시적 upsert가 오면 덮어쓰도록 ON CONFLICT DO UPDATE
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.profiles (id, email, username, phone, verified_phone, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.email, ''),
    COALESCE(
      NULLIF(trim(NEW.raw_user_meta_data->>'full_name'), ''),
      NULLIF(trim(NEW.raw_user_meta_data->>'name'), ''),
      'user_' || substring(NEW.id::text, 1, 8)
    ),
    COALESCE(NEW.raw_user_meta_data->>'phone', ''),
    false,
    'user'
  )
  ON CONFLICT (id) DO UPDATE SET
    email    = EXCLUDED.email,
    username = CASE WHEN public.profiles.username LIKE 'user_%' OR public.profiles.username = ''
                    THEN EXCLUDED.username
                    ELSE public.profiles.username END,
    phone    = CASE WHEN public.profiles.phone = ''
                    THEN EXCLUDED.phone
                    ELSE public.profiles.phone END;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- ============================================================
-- 6. RLS 정책 업데이트
--    - profiles_select: 삭제되지 않은 프로필만 공개 (deleted_at IS NULL)
--    - profiles_own: 자신의 프로필 수정 가능
--    - profiles_service: 서비스 롤은 전체 접근 (기존 유지)
-- ============================================================

-- 기존 정책 삭제 후 재생성 (IF NOT EXISTS가 없으므로 DO 블록 사용)
DO $$ BEGIN
  -- 기존 profiles_select 삭제하고 더 안전한 버전으로 교체
  DROP POLICY IF EXISTS "profiles_select" ON public.profiles;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'profiles' AND policyname = 'profiles_select_public'
  ) THEN
    -- 삭제된 계정은 숨김 처리
    CREATE POLICY "profiles_select_public" ON public.profiles
      FOR SELECT USING (deleted_at IS NULL);
  END IF;

  -- 자신의 프로필만 수정 (기존 profiles_update 유지)
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'profiles' AND policyname = 'profiles_update'
  ) THEN
    CREATE POLICY "profiles_update" ON public.profiles
      FOR UPDATE USING (auth.uid() = id);
  END IF;

  -- 서비스 롤 전체 접근 (기존 profiles_service 유지)
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'profiles' AND policyname = 'profiles_service'
  ) THEN
    CREATE POLICY "profiles_service" ON public.profiles
      FOR ALL USING (true) WITH CHECK (true);
  END IF;
END $$;

-- ============================================================
-- 7. 인덱스
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_profiles_username   ON public.profiles (username);
CREATE INDEX IF NOT EXISTS idx_profiles_email      ON public.profiles (email);
CREATE INDEX IF NOT EXISTS idx_profiles_deleted_at ON public.profiles (deleted_at) WHERE deleted_at IS NOT NULL;

# LETEON 환경변수 참조

## Supabase 설정

| 키 | 값 |
|---|---|
| SUPABASE_URL | https://ytxrbayjaebiiquprhlx.supabase.co |
| SUPABASE_ANON_KEY (클라이언트용) | `js/common.js` 에 포함됨 |
| SUPABASE_SERVICE_ROLE_KEY | **⚠ 절대 HTML/JS에 노출 금지** — Supabase 대시보드 Settings > API에서 확인 |
| ADMIN_EMAIL | leteon2026@gmail.com |

## 주의사항

- `SUPABASE_SERVICE_ROLE_KEY`는 어떤 HTML/JS 파일에도 포함되어 있지 않습니다.
- Anon Key는 RLS(Row Level Security)로 보호되므로 클라이언트 노출이 안전합니다.
- DB 스키마를 새 프로젝트에 적용할 경우 `schema.sql` 전체를 Supabase SQL Editor에서 실행하세요.
- 개별 마이그레이션은 `migrations/` 폴더의 번호 순서대로 적용하세요.

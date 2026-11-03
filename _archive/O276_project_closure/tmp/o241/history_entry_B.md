## O241-B 배포 실패(003001) 시정 + 05_지표GOLD매핑 미배선 129건 1건씩 대조·SV 동의어 배선 (2026-10-16 · trialadmin(mn11232) · ㉡ · 사용자 지시 = 동의어 꼼꼼히 순서대로 · 남은 작업 진행 · 확정위반 1)

- 착수 = 사용자 「32 실행 중 BIGQUERY_SESSION 003001」 + 「동의어·유사어 하나씩 대조」 + 「남은 작업 진행」.
- 원인 = 32 D1-a 가 SILVER.BIGQUERY_SESSION 열 선추가를 누락(소유자 GN_DW_ADMIN · GN_DW_DBT 는 append_new_columns ALTER 불가 · 쿼리 01c7c6d5-0304-f8f1-0005-878a0007fa52).
  ⇒ 에이전트가 `ALTER TABLE … ADD COLUMN IF NOT EXISTS SESSION_END_TS`(라이브 · 데이터 무변경) · 32 에 그 줄 추가 · 👤 D1-b 재실행 대기.
- 🔴 확정위반 1 = SV 동의어 삽입기 1차 판본이 `WITH SYNONYMS \(([^)]*)\)` 로 닫는 괄호를 찾아 「개발(건)」 같은 괄호 동의어 안에 토큰을 넣었다
  → 임시 이름 생성 검증에서 12파일 문법 FAIL 적발(라이브 전) → 19파일을 쓰기 전 해시로 복원(19/19 일치) → 따옴표 밖 괄호 판정으로 고쳐 재적용 → 19/19 PASS.
- 🟢 검증기 신뢰 = 복원 원본으로 먼저 돌려 19/19 PASS 확인 후 판정에 썼다(검증기 자체 결함 배제).
- 대조 = 미배선(OK/PARTIAL) 121 + WAIT 미배선 8 = 129건 · 근거 = 지표사전 정의·계산식 ↔ SV 필드 COMMENT·동의어 · O237 overlay(60건 · MSTR SV 필드 5개는 DDL 파일 없음).
  - ㉠ 115 · 보류 14 = 현업 확인 4(공11·공147·공153·공155) · SV 신설 6(공13·공48·공66·공93·공107·공112) · 범용 파생 2(공59·공60) · 판정표 `tmp/o241/wiring_decisions.tsv`.
  - 이름만 같은 다른 체계는 제외 = 공12 플랫폼(GA PLATFORM 아님) · 공14 기기(GA 기기 아님) · 공23·24(검색콘솔 아님) · 공96(광고 조회수 아님) · 공18(마케팅캠페인 아님).
- 반영 = SV DDL 19파일 동의어에 '공NN'·'신규NN' 토큰(바뀐 127줄 · 토큰 외 차이 0 · 줄 수 불변) · 백업 `tmp/o241/bak/`.
- 결과 = census 재측정(127표 · ERR 0) 후 재생성 · 상태 OK 110·PARTIAL 89·WAIT 16 불변 · 실측 85 · SV_배선 86 → 203/215 · Agent_배선 203 · SV有 Agent無 0.
  - 🔴 중간 재생성 1회는 `/tmp/census.json` 소실 상태여서 상태 61건이 추정으로 떨어졌다 → census 재측정 후 재생성으로 바로잡음(그 산출물은 남기지 않음).
- 부수 = 05_07 CTR COMMENT 실측치(「DIGITAL 3,190」·「100%」) 제거 → `sv_rule7_scan` 라이브 위반 1 → 0 · test_sv_rule7_scan PASS.
- 테스트 = `test_metric_sv_wiring.py` 15/15(R4 괄호 동의어 추가) · `scripts/test_*.py` 전건 rc=0 · 게이트 sv_identifier·sv_rule7·agent 3종·eval·campaign_axis·jinja·line_len rc=0.

### 독해 기록(`R1-3-7-b`)

- `tmp/o241/unwired_review.md` 1~484 · 도착 · `공4|CRM 개발(건)` · `신53` · `후원기간(년)`.
- `tmp/o241/unwired_overlay_join.tsv` 1~121 · 도착 · `MSTR_DVLP_CNT❌부재` · `SURVIVAL_RATE`.
- `05_SV-Agent_ai/05_18_SV_DDL_MEMBER_SERVICE_COHORT.sql` 추출본 1~138 · 도착 · `신규36` · `vqr_o205_sng_part`.
- `05_SV-Agent_ai/05_07_SV_DDL_AD.sql` 164~166 · 도착 · `DIGITAL 3,190` · `공10 CVR`.
- read 미반환 0 · 재호출 0.

_Co-authored with CoCo_

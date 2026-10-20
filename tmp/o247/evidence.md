# O247 독해 근거철 (R1-3-7-b · R1-3-7-c)

> 판정에 인용할 원문 구절 + 좌표. 요약 아님. 세션 = O247 (2026-10-20 · iw20760).

## 독해 기록

| 파일 | 범위 | 도착 | 고유 토큰 |
|---|---|---|---|
| `00_guides/00_작업지침_세션운영규칙.md` | 1~304 전량 | O | `R0-8-4` · `R4-4-4` |
| `20_issue/00_BRIEF.md` | 1~186 전량 | O | `O0246-D` · `3,294,120 자` |
| `85_실제 인수인계 문서/99_다음세션_프롬프트.md` | 1~66 전량 | O | `R1-7-2(같은 파일 병렬 edit)는 이번 세션에 **6회**` |
| `80_…/00_재현프롬프트.md` | 1~25 전량 | O | `build_handoff.py` · `세션 프롬프트` |
| `85_…/00_작업계획서.md` | 1~172 전량 | O | `BCR-2445` · `S8 | 00_INDEX.md` |
| `85_…/_드리프트/드리프트_통합.md` | 1~63 전량 | O | `DR-31` · `1,623,329` |
| `85_…/A8_미결이슈_인계목록.md` | 1~54 전량 | O | `P3 | 15` · `A8-12` |
| `85_…/N02_정책_적용_미실행.sql` | 1~85 전량 | O | `MP_PII_EMAIL` · `CP_GN_DW` |
| `85_…/N02_PII_정책정의서.md` | 1~87 전량 | O | `202,264` · `TM_PM_INSTT_ACNUT` |
| `08_mornitoring/00_README.md` | 1~69 전량 | O | `EXCLUDE_USERS` · `AI_USER_QUOTA` |
| `80_…/build_handoff.py` | 1~204 전량 | O | `extract_run_order_sql` · `READ_ORDER` |
| `95_정식산출물_생성_프롬프트.md` | 1~117 전량 | O | `70_후속 프로젝트 인계용` · `D10 | 운영 매뉴얼(Runbook)` |
| `02_GN_DW_building/06_RUNBOOK.md` | 1~784 전량(4회 · 1회 `Output too large` → 캐시 재호출 3) | O | `PASS=211 WARN=21` · `RM_ETL SET CREDIT_QUOTA = 300` · `11.2-C` |
| `60_repeat_어카운트시작/readme.md` | 1~41 전량 | O | `20260825_가오픈정리` · `151개` |
| `60_repeat_어카운트시작/13_운영계_반영_20261005이후.md` | 1~320 전량 | O | `JU93656` · `STOP_AMT_CNT NUMBER(18,4)` · `CK24285` |
| `60_repeat_어카운트시작/12_GN_DW_재구축_실행순서.md` | 1~109 전량 | O | `01:57:45~01:58:12` · `50_handoff/04_데이터마이그` |
| `85_…/A6_일배치_장애대응_런북.md` | 1~123 전량 | O | `HOURS_STALE 87` · `F9` |
| `85_…/N04_배치SLA_스케줄정의서.md` | 1~76 전량 | O | `610초` · `RUNKEY` |
| `50_handoff/예산 안.md` | 1~56 전량 | O | `rm_ai_chatbot` · `WH_PIPELINE_HEAVY` |
| `08_mornitoring/01_모니터링_대상 개요.md` | 1~58 전량 | O | `low latency 2시간` · `UTC 월/일 고정` |
| `08_mornitoring/03_비용제한_예산 쿼터.md` | 1~242 전량 | O | `INVALID_TARGET_TYPE` · `TIER_1H` · `1000%` |
| `08_mornitoring/04_알림_및 거버넌스.md` | 1~115 전량 | O | `cortex_cost_alert` · `AI_INFERENCE` |
| D10 캡처 `_ENV/IW20760/D10_Q01~Q07` | 전량 | O | `EMAIL_ALERT_INTEGRATION` · `GRANT_REVOKE_7D,2074` · `1,1,0,1` |

### 60_repeat 12·13 · 50_handoff 예산 안

- 12 :52 `| 2 | BRONZE DDL | `50_handoff/04_데이터마이그 GN_DW_BRONZE_DDL.sql` | 에이전트 | BRONZE 6 스키마 |` ⇒ 문서실행순서.md 「# 개발계」의 50_handoff 참조 출처
- 12 :66 `> 🔴 순 11 → 12 순서를 지켜라. JU93656 에서는 ML SV 가 Agent 보다 **늦게** 생성됐다(§1 순11·12).`
- 12 :82 `| 18 | 🟠 모니터링·비용 가드(미배포) | … | 🔴 CK24285 에 **0건**(O216-G 실측 · 이 런북 §2 에 단계가 없었다) — 배포 여부는 사용자 결정 |`
- 13 :108~109 `- 🔴🔴 **`03_top-down_gold/06_DDL.sql` 을 운영계에서 전체 실행하지 마라.**` · `GOLD 41테이블이 0행이 됐다(O202-B 실사고`
- 13 :137 `-- ① 배포본 갱신 (O202-C 교훈: EXECUTE 는 배포본을 돈다 · 워크스페이스 수정이 자동 반영되지 않는다)`
- 예산 안 :19 `## 설정 예시 (월 1000 크레딧 기준)` — 가정치 · 실측 아님 · WH 이름 `WH_PIPELINE_LIGHT` 등은 GN_DW 실재 WH 가 아님(확인 필요)

### 08_mornitoring 03·04

- 03 :212~221 `## 4. 본 계정 구축 현황 (2026-08-12)` … `AI_USER_QUOTA` … `⇒ **현재는 순수 관찰 상태이며 어떤 사용자도 차단되지 않는다.**` — 🔴 다른 계정 시점(DR-02 · IW20760 quota 0)
- 04 :98 `- [ ] `AI_INFERENCE`(REST API, 달러 과금)는 metering 뷰에 없으므로 청구서로 별도 확인`

| 파일 | 범위 | 도착 | 고유 토큰 |
|---|---|---|---|
| `08_mornitoring/02_Cortex_AI_사용량 모니터링.md` | 1~214 전량 | O | `34 | 4.4743` · `TOKEN_CREDITS` |
| `08_mornitoring/10_Cortex_Code_모델별_비용_비교.md` | 1~58 전량 | O | `Gemini Flash 3.8` · `(~20x)` — 🔴 출처 없음 · 미검증 |
| `08_mornitoring/05_AI비용가드_구축.sql` | 1~357 전량 | O | `QUOTA_ID=8` · `Operation not supported` · `ad50130` |
| `08_mornitoring/06_웨어하우스비용가드_구축.sql` | 1~422 전량 | O | `ML_WH_MONITOR` · `ARGUMENTS_SIZE_MISMATCH` · `0.251373cr` |

### 🔴 05 주석 ↔ 실행 구문 불일치 (신규 결함 후보 · DR-32)

- :132 `-- 5. 사용자별 지출 한도  ★현재 미적용 (= 무한대)`
- :151 `CALL GN_DW.OPS.AI_USER_QUOTA!SET_PER_USER_LIMIT(30);` ← 주석 아님(실행 구문)
- :162 `CALL GN_DW.OPS.AI_USER_QUOTA!SET_PER_USER_LIMIT(5,  'DAILY');   -- 실측 3.3/일 대비 약간 여유` ← 실행 구문
- :171 `-- 6. 내장 Block 활성화  ★현재 비활성 (FALSE)`
- :184 `CALL GN_DW.OPS.AI_USER_QUOTA!SET_BLOCK_ENFORCEMENT_ENABLED(TRUE);` ← 실행 구문
- :65 `ALTER USER choih SET TAG GN_DW.SECURITY.AI_COST_SCOPE = 'GOVERNED';` ← 실행 구문 · 계정 의존 사용자명
- :328~330 `PER_USER_LIMIT NULL` · `BLOCK_ENFORCEMENT_ENABLED FALSE` (현재 상태 요약)
- ⇒ 파일 전체 실행 시 = 월 30 · 일 5 한도 + 차단 활성. 요약의 「관찰 상태」와 다르다.
- 06 은 대조 결과 일치: :190·:193·:196 한도 3종 모두 `-- CALL` 주석 · :202 「의도적으로 사용하지 않는다」
- 06 계정 의존 값: :66 `NOTIFY_USERS = (TRIALADMIN)` · :24 `USE WAREHOUSE COMPUTE_WH`

## 인용 근거 (원문 그대로)

### RUNBOOK (`02_GN_DW_building/06_RUNBOOK.md`)

- :8 `last_updated: 2026-07-22`
- :37 `> ETL은 현재 온디맨드 dbt 실행(정기 cron Task 미도입). 실행 직후 아래 항목을 확인한다.`
- :47 `**정상:** SILVER 32 + GOLD 24 + WIDE 9 = 65 models green (dbt run/test 성공)`
- :61 `**정상:** BRONZE_CRM 43 · BRONZE_AGENCY 3 · BRONZE_ERP 1 · BRONZE_BIGQUERY 1 · SILVER 32 · GOLD 24 BASE + 9 VIEW · SERVING 2 VIEW(+SV 5·Agent 2)`
- :111 `→ relationships는 severity:warn(메달리온 BP)로 대개 경고`
- :119 `USE ROLE GN_DW_ENGINEER;` (§2.2 수동 재실행)
- :253 `USE ROLE GN_DW_ENGINEER;` + :255 `CREATE OR REPLACE TABLE GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO AS` (§4.2 = DR-26)
- :272 `> ⚠️ Resource Monitor는 현재 미배포(설계안, 04_운영 확인.md 8.1). 아래는 운영 승격 후 기준.`
- :284 `ALTER RESOURCE MONITOR RM_ETL SET CREDIT_QUOTA = 300;  -- 200 → 300`
- :323 `> 🔴 **[2026-08-18 실측] 롤별 권한을 점검할 때는 반드시 `USE SECONDARY ROLES NONE` 을 먼저 실행한다.**`
- :340 `SHOW GRANTS ON AGENT GN_DW.SERVING.AGENT_OVERALL;`
- :359 `-- 배포 SV 목록 확인 (5개)`
- :369 `> **라이브 실측: SERVING에 배포된 Streamlit 앱 없음(0개).**`
- :439~453 에스컬레이션 Level 1 ENGINEER 15분 · Level 2 ADMIN 30분 · Level 3 ACCOUNTADMIN+Support 1시간 · 외부 LOADER
- :481 `- `profiles.yml` role=`GN_DW_ENGINEER`, wh=`GN_DW_ETL_WH`.`
- :485 `Done. PASS=211 WARN=21 ERROR=0 SKIP=0 TOTAL=232   (87.5s)`
- :669 `| **0** | `02_GN_DW_building/07_ENVIRONMENT_RBAC_setup.sql` | … | WH 3 · 역할 6 · DATABASE · 스키마 11 |`
- :775 `--   🔴 SKIP 은 무해하지 않다 — 상류 1건 실패가 모델 9 + 테스트 59 를 건너뛰게 만든 이력이 있다.`

_Co-authored with CoCo_

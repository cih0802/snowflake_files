<!-- LLM-METADATA
doc_id: NEXT_SESSION_PROMPT_9D
doc_role: 다음 세션(순서9-D) 착수 프롬프트 — GN_DW dbt 파이프라인 이어가기
project: GN_DW (굿네이버스)
created: 2026-07-15 (순서9-C 종료 시점)
END-METADATA -->

# 다음 세션(순서 9-D) 착수 프롬프트 — GN_DW dbt 파이프라인

> 이 파일을 다음 세션 시작 시 그대로 붙여넣거나 참조하세요. 순서9-C 종료 상태의 핸드오프입니다.

## 0. 먼저 읽을 문서 (순서대로)
1. `20_issue/00_INDEX_이슈원장.md` — 이슈 원장 허브·상태 대시보드
2. `10_dbt_pipeline/DBT_배포운영_통합_20260715.md` — **배포/운영 정본 + §7 진행요건 총괄표**
3. `20_issue/50_dbt_파이프라인_미결조치.md` — BLOCKING·순서9-C DONE·warn복귀 추적표

## 1. 현재 상태 (순서9-D 종료, 2026-07-15)
- **배포 객체**: `GN_DW.OPS.DW_PIPELINE` (dbt project, 운영 전용 스키마). 최신 버전이 default.
- **워크스페이스 스테이지**: `snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline`
- **전체 파이프라인**: SILVER 32 + GOLD 22 + WIDE view 8 = 62 models, 164 tests. **full build green (PASS=205 WARN=21 ERROR=0)**.
- **적재 검증됨**: DIM_BUDGET_ITEM(2,041)·DIM_AD_CREATIVE(8,474)·FACT_BUDGET(24,480)·FACT_AD_PERFORMANCE(235,572)·FMM(37.8M, UNPAID_EOM=true 3.3M).
- **운영 계약**: 온디맨드 `EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build';` (run 금지, build 사용).
- **execute/dbt/DDL 은 사용자가 직접 실행** — 명령어만 제시할 것. 읽기전용 진단 SELECT 는 에이전트가 실행 가능.

## 2. 순서9-D 완료 작업 (내부 가능분 소진)
### ✅ WIDE VIEW 8/9 생성·배포 (BLOCKING-4 해소)
- dbt view 모델(`models/gold/wide/`, `materialized: view`, `ref()`) 8종 저작 → `ADD VERSION` → full `build` green(PASS=205 WARN=21 ERROR=0). COMMENT 는 **post-hook**(`ALTER VIEW ... ALTER COLUMN` + `COMMENT ON VIEW`, 정본 `10_WIDE VIEW 코멘트.sql` verbatim) → 뷰 8/8 + 컬럼 310/310 실측 확인.
- 8종: WIDE_MEMBER_MONTHLY·WIDE_MEMBER_EVENT·WIDE_TARGET_DEV·WIDE_SERVICE_EVENT·WIDE_GA_BEHAVIOR·WIDE_AD_PERFORMANCE·WIDE_EVENT_PARTICIPATION·WIDE_BUDGET.
- ⏳ **보류 1종 WIDE_TARGET_BIZ**: `FACT_TARGET_BIZ` 거버넌스 모델 부재(E-6 원천 0행). FACT_TARGET_BIZ 저작 시 동시 추가.
- ⚠️ WIDE_GA_BEHAVIOR: `DIM_MEMBER_IDENTITY`(enabled=false) 미조인, IDENTITY_* 타입드 NULL 플레이스홀더.
### ✅ #3 AD_DATE not_null warn→error 승격 (실측 널 0/235,572)

### 🔜 다음 세션 최우선 (외부/결정 도착 시)
- **설계결정**: FACT_BUDGET 추경/조정 예산 슬롯 신설 여부(문서30 §7) · WIDE_TARGET_BIZ+FACT_TARGET_BIZ(E-6 입고 시).
- **정의 원천 재사용**: `03_top-down_gold/09_빅테이블 VIEW.md` §3.4(WIDE_TARGET_BIZ DDL) + `10_WIDE VIEW 코멘트.sql`.

## 3. 순서9-C 산출물 요약 (참고)
- GOLD 미작성 4종 작성 + #80(FMM UNPAID_FLAG_EOM=BOOLOR_AGG(PAY_STAT_CD='F' OR NULL), BOM=LAG).
- 이슈 E 진단: 고아 99.98% `TD_MS_EVENT_PRTCPNT_DTL`·동일기간·동일형식 키 마스터 부재 = **마스터 누락(외부)**. warn 유지.
- 데이터기반 설계결정: A-2 `_SOURCE_SYSTEM='AGENCY'` 상수 / DEVICE_TYPE PC/M(APP 휴면).

## 4. 핵심 규칙·매크로·교훈 (재발방지)
- **매크로**: `gold_sk([cols])`=ABS(HASH), `gold_meta('SRC')`=감사4컬럼, `date_sk`/`month_key_clamp`(범위 클램프→무효는 0/NULL). Unknown 멤버 SK=0 union all 패턴.
- **R1 (필수)**: 상류 grain/로직 변경 시 **merge 차원(GOLD dim)은 pre-hook TRUNCATE 없어 stale 잔존** → 반드시 대상 `TRUNCATE` 후 재적재. (순서9-C DIM_GA_EVENT 2,842→2,846 사고)
- **R2**: `run` 금지 `build` 사용(0행 회귀를 test 로 게이트). 테스트는 **실행해야 검증됨**(저작만으로 아님).
- **severity 정책(메달리온 BP)**: Silver 참조무결성=알려진 원천 미완전이면 `severity:warn` 관측, error 는 구조 불변식만. warn→error 복귀 추적표: 문서50.
- **GOLD dim = incremental merge / GOLD fact = incremental append + pre-hook TRUNCATE**(dbt_project.yml). `+full_refresh:false`(DDL 구조 보호).
- **GA4_EVENT_DIM**: grain=(event_name×cat×label×action) 브리지 — `unique(EVENT_NAME)` 금지(다중행 정상). GOLD DIM_GA_EVENT 가 (cat,label,action) distinct 추출.

## 5. 외부 입력 대기 (착수 불가 — §7 정본)
- 원천 입고: FUNDRAISING_COST(E-1)·AD_COST(E-4)·FACT_TARGET_BIZ(E-6)·GA4 전기간(G-5)·회원 마스터 전량입고(BLOCKING-1→severity error 복귀).
- 현업 회신: FACT_AD_PERFORMANCE CAMPAIGN_SK(Q10)·AD_CREATIVE_SK(소재 부분키 설계)·DEVICE_SK(매핑)·GA_CONV 정의(O5)·이슈 A/C/D.
- 입고/회신 도착 시: `DBT_배포운영_통합_20260715.md` §7 표에서 해당 요건→산출물 찾아 착수.

## 6. 후속 개선 TODO (내부·저우선) — 순서9-D 처리결과
- 🟠 **[설계결정 대기] `FACT_BUDGET.PLAN_BUDGET_YEAR`**: 추경(CHN)/조정(ADJ) 은 원천 실재하나 GOLD 슬롯 부재. `PLAN_BUDGET_YEAR` 임의 주입 = 재무 오귀속 → 전용 슬롯 신설 또는 소비정의 확정 필요(문서30 §7). 임의매핑 금지.
- ⏳ **[Q10 게이트] `FACT_AD_PERFORMANCE` 캠페인 이름매칭**(AGENCY.CAMPAIGN_NM ↔ CRM_CAMPAIGN.CMPGN_NM) — 실구현 Q10 회신 대기(진단 PoC만 가능).
- ✅ **[DONE 순서9-D] `AGENCY_AD_PERFORMANCE.AD_DATE` not_null warn→error 승격**(실측 널 0/235,572 확인).

---
_Co-authored with CoCo_

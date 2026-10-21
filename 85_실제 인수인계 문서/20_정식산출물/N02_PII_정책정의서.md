---
doc_id: N02
title: PII 마스킹 · 행 접근 정책 정의서
version: 1.0
as_of: 2026-10-21 (운영계 ZL50263 · 정책·부착·권한·행 수 = 캡처 · 분류·형태 일치율 = 원천 표본 측정)
source_docs:
  - 10_실무자_인수인계/A2_롤별_접근권한_매트릭스.md §7 (ANALYST OPS 권한 회수 결정)
  - 02_GN_DW_building/06_RUNBOOK.md §6.2 (USE SECONDARY ROLES NONE 점검 규칙)
source_queries:
  - CALL SYSTEM$CLASSIFY(<표>, {'sample_count': 1000}) × 4 — BRONZE_CRM.TM_MM_FDRM_MBER_INFO · GOLD.DIM_MEMBER · GOLD.DIM_PAYMENT_ACCOUNT · OPS.ALERT_RECIPIENT_CONFIG (태그 미부착 · 읽기)
  - INFORMATION_SCHEMA.COLUMNS 컬럼명 패턴 스캔(EMAIL·TEL·ADDR·BIRTH·ACNUT 등) · SHOW GRANTS ON TABLE · INFORMATION_SCHEMA.PROCEDURES · GET_DDL(PROCEDURE)
  - 적용 SQL = 20_정식산출물/N02_정책_적용_미실행.sql (⬜ 운영계 미적용 · 정책 DDL compile 통과)
owner: TBD
status: review
---

# N02. PII 마스킹 · 행 접근 정책 정의서

본문 = `N02_PII_롤별노출.csv`(PII 컬럼 × 롤 노출) · 적용 = `N02_정책_적용_미실행.sql`(⬜ 운영계 미적용 — [2-B] 는 결정 A8-28 로 적용 예정 · [1][2] 는 사용자 결정 대기).

## 1. [ENV] 현황

| 항목 | 운영계(ZL50263 · 2026-10-21) |
|---|---|
| 마스킹 · 행 접근 정책 | 0 · 컬럼 부착 0 (A0 Q08-1·2·5 · D10 Q06) ⇒ §2-B 12 컬럼 미적용 |
| 분류 태그(`SNOWFLAKE.CORE.SEMANTIC_CATEGORY`) | GN_DW 객체 태그 부착 0 (A0 Q08-6·7) |
| 자동 분류 프로필 | TBD(캡처 대상 아님) |

## 2. 분류 결과 (2026-10-20)

| 대상 | 컬럼 | PII |
|---|---|---|
| `BRONZE_CRM.TM_MM_FDRM_MBER_INFO`(회원 마스터 원천) | 32 | **0** — 이름·전화·주소·생년월일 컬럼 자체가 없다(코드·ID·수신 동의 여부만) |
| `GOLD.DIM_MEMBER` | 58 | **0** — 성별·연령대·지역은 준식별자이지만 분류기가 표시하지 않았다 |
| `GOLD.DIM_PAYMENT_ACCOUNT` | 18 | **0** — `INSTT_ACNUT_SER_NO` 는 기관 계좌 **일련번호**(내부 키)다 |
| `OPS.ALERT_RECIPIENT_CONFIG` | 10 | **1** — `USER_EMAIL` = EMAIL · IDENTIFIER · HIGH · valid 100% |

- 컬럼명 패턴 스캔(SILVER·GOLD·OPS·SERVING·MSTR)으로 후보 21테이블을 먼저 골랐고, 그중 원천 PII 가능성이 있는 표를 분류기에 넣었다. 나머지 후보는 수신 동의 여부(`*_YN`)·기기 모델명·URL·발생일자라 PII 가 아니다.
- 🟠 분류기 표본 4테이블 + BRONZE 3테이블(§2-B)이다 — 전 스키마 전수 분류가 아니다. 상시 감시는 SQL [6] 자동 분류 프로필로 한다.

## 2-B. 🔴 BRONZE 원천 개인정보 (분류기가 놓친 것)

`SYSTEM$CLASSIFY` 는 `BRONZE_CRM.TM_PM_SETLE_INFO`·`TM_PM_INSTT_ACNUT` 에서 PII 0 을 냈다. 그러나 컬럼 COMMENT(휴대폰번호·결제자명·신청자명·기타연락처)로 찾아 **값의 형태를 집계**(값은 출력하지 않음)하니 실제 개인정보다 — 분류기가 한국어 이름·국내 휴대폰 번호를 인식하지 못한 것이다.

| 테이블(운영계 행 수 · B1 Q01) | 컬럼 | 형태 일치율(비어있지 않은 값 중) | 마스킹 흔적(`*`) |
|---|---|---|---|
| `TM_PM_SETLE_INFO`(결제정보 · 2,630,490행) | `MBTLNUM` 휴대폰번호 | 휴대폰 99.99% | 없음 |
| | `APPLCNT_MBTLNUM` 신청자휴대폰번호 | 휴대폰 99.8% | 없음 |
| | `PAYER_NM` 결제자명 · `APPLCNT_NM` 신청자명 | 한글 이름 97.8% · 97.8% | 극소수 |
| | `ETC_CTTPC` · `APPLCNT_ETC_CTTPC` 기타연락처 | 전화 74.3% · 96.8% | 극소수 · 없음 |
| `TH_PM_SETLE_INFO_HIST`(1,107,691행) | `PAYER_NM` · `APPLCNT_NM` · `ETC_CTTPC` · `APPLCNT_ETC_CTTPC` | 이름 98.3% · 98.4% · 전화 89.3% · 98.0% | 극소수 |
| `TM_PM_MBRFEE_ACMSLT`(회비 실적 · 50,020,690행) | `PAYER_NM` | 한글 이름 97.8% | 극소수 |
| `TM_PM_DNTN_DTLS`(기부 · 1,134,368행) | `PAYER_NM` | 한글 이름 17.8%(나머지는 법인·단체명으로 보임 · 미확인) | 극소수 |
| `SND_REQ_MST`(발송요청 · 2,316행) | `SENDER_EMAIL` | 이메일 100%(분류기도 EMAIL 로 표시) | 없음 |

- 일치율은 원천 표본 형태 집계(정규식)로 잰 비율이다. 🟠 컬럼별 절대 건수는 운영계 캡처에 없어 싣지 않는다(운영계 재집계 = TBD).

- 🟢 **2026-10-20 결정(A8-28) = 마스킹 적용 · 대상 12 컬럼 · `SND_REQ_MST.SENDER_EMAIL` 제외.** 스키마 권한은 줄이지 않는다.
  - `SENDER_EMAIL` 제외 근거 = 값이 **고유값 4종**이고 전부 조직 발신 주소(`@gni.kr` · 회원·직원 개인 주소 아님 · COUNT DISTINCT 실측).
  - 형태 재확인(같은 날 · 정규식 `01[016789]-?[0-9]{3,4}-?[0-9]{4}` · `[가-힣]{2,4}`) = 휴대폰 2컬럼 99.8~99.99% · 이름 4컬럼 97.6~98% · `TM_PM_DNTN_DTLS.PAYER_NM` 은 법인명 혼재(17%)지만 개인 이름이 있어 대상 유지.
  - 원천 값 중 「(임의생성)」 표기가 섞여 있다 — 데이터 일부 가공 가능성 · 실데이터 여부는 원천 담당 확인 전까지 **실데이터로 취급**한다.
  - 원본 정본 = `08_mornitoring/11_BRONZE_개인정보_마스킹정책_적용완료.sql`(이 산출물의 [2-B] 와 같은 내용).

- 형태 기준 = 휴대폰·전화: 숫자만 남겨 `0` 으로 시작하는 9~11자리 · 이름: 한글 2~5자 · 이메일: `x@y.z`. 근사 집계다(형태만 보고 실제 개인 여부는 확인하지 않았다).
- 읽을 수 있는 롤(운영계 `BRONZE_CRM` 테이블 SELECT 53/53 · A2 Q03 · 2026-10-21) = GN_DW_ADMIN(소유) · **GN_DW_ANALYST · GN_DW_ENGINEER · GN_DW_DBT · GN_DW_LOADER**. ANALYST 의 BRONZE 읽기는 2026-08-18 요건 변경으로 열린 것이다(RUNBOOK §6.2).
- SILVER·GOLD 로는 흘러가지 않는다 — dbt 모델이 이 컬럼을 명시적으로 제외한다(`10_dbt_pipeline/models/silver/crm/CRM_PAYMENT_METHOD_HIST.sql:4` 「민감 컬럼 제외」) · SILVER·GOLD·SERVING·MSTR·ML 에 해당 컬럼 0(COLUMNS 스캔). ⇒ **노출면은 BRONZE 직접 조회뿐**이다.
- 제외(사람 PII 아님): `TM_PM_INSTT_ACNUT.ACCTNO`(기관 계좌 239행 · 법인 계좌) · `SETLE_CMPNY_ACNT_NO`(결제사 계좌 · 형태 일치 0) · `SND_REQ_MST.CALL_NUMBER`(발신 대표번호 · 휴대폰 형태 0) · `RCPT_LIST`(전부 비어 있음).

## 3. 정책 설계

| 정책 | 대상 | 규칙 | 근거 |
|---|---|---|---|
| `SECURITY.MP_PII_EMAIL`(마스킹) | `OPS.ALERT_RECIPIENT_CONFIG.USER_EMAIL`(🟢 `BRONZE_CRM.SND_REQ_MST.SENDER_EMAIL` 은 A8-28 결정으로 제외 — 조직 주소 4종) | `IS_ROLE_IN_SESSION('GN_DW_ADMIN')` → 원문 · 그 외 → `***@도메인` · NULL 은 NULL | 범용 이메일 정책 1개를 재사용한다 · `CURRENT_ROLE` 비교는 상위 롤을 거부하므로 쓰지 않는다 |
| 🔴 `SECURITY.MP_PII_STRING`(마스킹) | BRONZE §2-B 12 컬럼(이름 6 · 휴대폰 2 · 기타연락처 4) | `IS_ROLE_IN_SESSION('GN_DW_ADMIN')` → 원문 · 그 외 → `***` | 분석 가치가 없어 dbt 도 제외하는 값이다 — 부분 노출(가운데 글자만 가림 등)도 두지 않는다 · dbt 영향 0(모델 미사용) · 부착 후 build 1회로 회귀 확인 |
| 행 접근 정책 | — | 만들지 않는다 | 행 단위 분리 요건(조직·지부별 열람 제한 등)이 문서·라이브 어디에도 없다 |
| 자동 분류 프로필(선택) | DB `GN_DW` | 30일마다 재분류 · `auto_tag` | 신규 PII 컬럼이 생기면 태그로 잡는다 |

- 정책 객체는 `GN_DW.SECURITY`(소유 GN_DW_ADMIN · 운영계 테이블·정책 0 · 태그 `AI_COST_SCOPE` 1)에 둔다.
- 알림 메일 프로시저 2종(`USP_SEND_PIPELINE_ERROR_ALERT`·`USP_SEND_DBT_WARN_SPNSR_CLS_DUP`)은 `EXECUTE AS OWNER` · 소유 GN_DW_ADMIN 이다. 소유자 권한 프로시저 안에서는 소유 롤만 평가되므로(Snowflake 문서) 메일은 원문 주소로 나가야 한다 — 🔴 부착 후 수동 발송 1회로 실측한다(SQL [5]③).
- A2 결정(ANALYST 의 OPS 권한 회수 · `A2_권한조정_적용완료.sql` [2])이 먼저 적용되면 ANALYST 행은 「접근 없음」이 된다. 두 조치는 독립이다.

## 4. 적용 순서 (🔴 미실행)

1. [0] ACCOUNTADMIN → `APPLY MASKING POLICY` 를 GN_DW_ADMIN 에.
2. [1] 정책 생성 → [2] 컬럼 부착 → [2-B] BRONZE 12 컬럼 부착(`SENDER_EMAIL` 제외 · A8-28) → dbt build 1회(ERROR 0 · SKIP 0 확인).
3. [5] 확인 — ① ADMIN 원문 ② `USE SECONDARY ROLES NONE` 후 ENGINEER 는 가려짐(RUNBOOK §6.2 · 안 하면 합집합 평가로 원문이 보여 오판한다) ③ 알림 메일 수동 발송 ④ `POLICY_REFERENCES`.
4. 롤백 = [9].

## 5. 드리프트

| # | 기대 | 실측 | 처리 |
|---|---|---|---|
| DR-30 | 「BRONZE 원천 PII 는 dbt 가 제외하므로 노출 없음」(모델 주석 취지) · 분류기가 PII 를 찾아 준다 | BRONZE 13 컬럼에 이름·휴대폰·연락처·이메일 원문(§2-B) · ANALYST·ENGINEER·DBT 가 SELECT 가능 · 분류기는 이 중 이메일 1개만 검출 | 마스킹 SQL [2-B](미실행) · 🟢 2026-10-20 결정(A8-28) = **12 컬럼 마스킹 · `SENDER_EMAIL` 제외 · 스키마 권한 유지** · 원본 = `08_mornitoring/11_BRONZE_개인정보_마스킹정책_적용완료.sql` · 자동 분류에만 의존하지 말고 COMMENT 기반 형태 점검을 A7 정기점검에 넣을 것을 제안한다(A7 미반영) |

- 정책 0 은 A0 와 일치한다.

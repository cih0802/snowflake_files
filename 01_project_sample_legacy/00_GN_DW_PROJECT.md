# GN_DW 프로젝트 구축 작업문서

## 목차

1. [환경 세팅](#1-환경-세팅)
   - 1.1 Timezone 설정
   - 1.2 Warehouse 생성 및 설정

2. [유저 & Role 세팅](#2-유저--role-세팅)
   - 2.1 Role 계층 구조 설계
   - 2.2 Role 생성
   - 2.3 유저 생성 및 Role 할당

3. [오브젝트 & 권한 세팅](#3-오브젝트--권한-세팅)
   - 3.1 Database 생성
   - 3.2 Schema 생성 (BRONZE / SILVER / GOLD / SERVING / OPS / SECURITY)
   - 3.3 BRONZE 테이블 생성
   - 3.4 SILVER 정제 레이어 생성
   - 3.5 GOLD 분석 View 생성
   - 3.6 Semantic View 생성
   - 3.7 Agent 생성
   - 3.8 권한 부여 (GRANT / Future Grants)
   - 3.9 Streamlit 대시보드

4. [프로시저 생성](#4-프로시저-생성)
   - 4.1 BRONZE → SILVER 정제 프로시저
   - 4.2 SILVER → GOLD 집계/변환 프로시저
   - 4.3 유틸리티 프로시저

5. [태스크 생성](#5-태스크-생성)
   - 5.1 태스크 스케줄 설계
   - 5.2 태스크 생성 DDL
   - 5.3 태스크 의존성 (DAG)

6. [테스트](#6-테스트)
   - 6.1 권한 테스트
   - 6.2 파이프라인 E2E 테스트
   - 6.3 데이터 정합성 검증

7. [보안 세팅](#7-보안-세팅)
   - 7.1 네트워크 룰 / IP 허용
   - 7.2 마스킹 정책
   - 7.3 MFA 설정

8. [모니터링 세팅](#8-모니터링-세팅)
   - 8.1 Resource Monitor
   - 8.2 Alert 설정
   - 8.3 비용 추적

---

## 1. 환경 세팅

> **SQL 파일:** [`01_환경세팅.sql`](./01_환경세팅.sql)

### 1.1 Timezone 설정

계정 레벨에서 Timezone을 `Asia/Seoul`로 설정한다. 이 값은 세션/유저 레벨의 기본값이 된다.

- **설정 레벨:** Account (전체 기본값)
- **대상 값:** `Asia/Seoul` (UTC+9)
- **참고:** 유저/세션 레벨에서 개별 오버라이드 가능

### 1.2 Warehouse 생성 및 설정

용도별로 Warehouse를 분리하여 비용 추적과 워크로드 격리를 달성한다.

| Warehouse 이름 | 용도 | Size | Auto Suspend | Auto Resume | 비고 |
|---|---|---|---|---|---|
| `GN_DW_ETL_WH` | ETL / 데이터 적재 | SMALL | 60초 | TRUE | 프로시저/태스크 전용 |
| `GN_DW_ANALYTICS_WH` | 분석가 쿼리 | MEDIUM | 300초 | TRUE | Analyst role 전용 |
| `GN_DW_DEV_WH` | 개발/테스트 | XSMALL | 60초 | TRUE | Engineer role 전용 |

**설계 원칙:**
- ETL과 분석 쿼리를 분리하여 상호 간섭 방지
- Auto Suspend를 짧게 설정하여 유휴 비용 최소화 (최소 60초, per-second billing)
- 필요 시 사이즈 업/다운 가능 (운영 중 ALTER WAREHOUSE로 즉시 변경 가능)

## 2. 유저 & Role 세팅

> **SQL 파일:** [`02_유저_Role_세팅.sql`](./02_유저_Role_세팅.sql)

### 2.1 Role 계층 구조 설계

Snowflake 권장 패턴(Functional Role + Access Role)에 따라 확장형 Role 계층을 구성한다.

```
ACCOUNTADMIN
  └── SYSADMIN
        └── GN_DW_ADMIN          ← DB/스키마 관리, DDL 실행
              ├── GN_DW_ENGINEER  ← ETL 개발, 프로시저/태스크 운영
              ├── GN_DW_ANALYST   ← 분석 쿼리 (SELECT only)
              │     └── GN_DW_VIEWER  ← 읽기 전용 (GOLD View 읽기 + SERVING 소비)
              ├── GN_DW_LOADER   ← 외부팀 BRONZE 적재
              └── GN_DW_SERVICE  ← 서비스 계정 (API, Streamlit 등)
  └── SECURITYADMIN
        └── (Role 관리)
```

| Role | 용도 | Warehouse | 접근 범위 |
|------|------|-----------|-----------|
| `GN_DW_ADMIN` | DB 관리, DDL | GN_DW_DEV_WH | 전체 |
| `GN_DW_ENGINEER` | ETL 개발, 프로시저 | GN_DW_ETL_WH, GN_DW_DEV_WH | BRONZE, SILVER, GOLD, SERVING(USAGE) |
| `GN_DW_ANALYST` | 분석 쿼리 | GN_DW_ANALYTICS_WH | SILVER(읽기), GOLD(읽기), SERVING(SV/Agent 소비) |
| `GN_DW_VIEWER` | 대시보드/리포트 | GN_DW_ANALYTICS_WH | GOLD View(읽기), SERVING(SV/Agent/Streamlit 소비) |
| `GN_DW_LOADER` | 외부팀 적재 | GN_DW_ETL_WH | BRONZE(쓰기) |
| `GN_DW_SERVICE` | 서비스 계정 | GN_DW_ANALYTICS_WH | GOLD(읽기), SERVING(소비) |

### 2.2 Role 생성

SQL 파일에서 6개 Role을 생성하고 계층 구조(GRANT ROLE TO ROLE)를 설정한다.

- 모든 Custom Role은 최종적으로 SYSADMIN에 귀속 (Snowflake Best Practice)
- ACCOUNTADMIN으로 직접 오브젝트 생성 금지

### 2.3 유저 생성 및 Role 할당

유저 생성 시 포함할 속성:
- `DEFAULT_ROLE` : 해당 유저의 주 업무 Role
- `DEFAULT_WAREHOUSE` : Role에 맞는 Warehouse
- `DEFAULT_NAMESPACE` : `GN_DW.GOLD` (분석가) 또는 `GN_DW.BRONZE` (엔지니어)
- `MUST_CHANGE_PASSWORD = TRUE` : 초기 비밀번호 변경 강제

> **참고:** 실제 유저 정보(이름, 이메일)는 조직 내부 정책에 따라 기입. SQL 파일에는 템플릿만 제공.

## 3. 오브젝트 & 권한 세팅

> **SQL 파일:**
> - [`03_01_DB_스키마_생성.sql`](./03_01_DB_스키마_생성.sql)
> - [`03_02_BRONZE_테이블_생성.sql`](./03_02_BRONZE_테이블_생성.sql)
> - [`03_03_GOLD_View_생성.sql`](./03_03_GOLD_View_생성.sql) *(SILVER는 4단계 프로시저에서 구현. 예측 물리 테이블 5개의 빈 구조 DDL도 본 파일에서 생성하며, 데이터 적재는 4.2 프로시저가 담당)*
> - [`03_04_Semantic_View_생성.sql`](./03_04_Semantic_View_생성.sql)
> - [`03_05_Agent_생성.sql`](./03_05_Agent_생성.sql)
> - [`03_06_권한_부여.sql`](./03_06_권한_부여.sql)
> - [`03_07_Streamlit_배포.sql`](./03_07_Streamlit_배포.sql) *(3.9 대시보드 6종, CREATE STREAMLIT)*

### 3.1 Database 생성

| 항목 | 값 |
|------|---|
| Database 이름 | `GN_DW` |
| 소유 Role | `GN_DW_ADMIN` (SYSADMIN에서 생성 후 이관) |
| Data Retention | 1일 (기본, 운영 후 조정) |

### 3.2 Schema 생성 (BRONZE / SILVER / GOLD / SERVING / OPS / SECURITY)

| Schema | 용도 | 소유 Role | 비고 |
|--------|------|-----------|------|
| `BRONZE` | 원천 데이터 적재 (다른 팀) | GN_DW_ADMIN | LOADER role에 쓰기 권한 |
| `SILVER` | 정제/변환 레이어 | GN_DW_ADMIN | 물리 테이블 (프로시저 갱신) |
| `GOLD` | 분석 View + 예측(Forecast) 물리 테이블 | GN_DW_ADMIN | **데이터 프로덕트 계층.** Analyst/Viewer 읽기 전용 (owner's rights View) |
| `SERVING` | Semantic View + Agent + Streamlit | GN_DW_ADMIN | **소비/서비스 계층.** GOLD View를 cross-schema 참조. Viewer 소비 지점 |
| `OPS` | 비용 리포트 View (+향후 모니터링 신규 객체) | GN_DW_ADMIN | 운영 메타데이터. **ETL_LOG·Alert는 SILVER 유지**, Resource Monitor는 계정 레벨 |
| `SECURITY` | 마스킹 정책 · 네트워크 룰/정책 객체 | GN_DW_ADMIN | 거버넌스 정책 격리 |

> **[스키마 분리 원칙]** BRONZE→SILVER→GOLD는 **데이터 정제 계층**, SERVING은 그 위의 **소비 계층**이다. Semantic View·Agent·Streamlit을 GOLD에서 분리하면 GOLD를 순수 데이터 프로덕트로 유지하고, `CREATE SEMANTIC VIEW`/`CREATE AGENT`/`CREATE STREAMLIT` 권한 표면을 SERVING으로 격리할 수 있다.
> - **GOLD**: 분석 View 35개 + 예측 물리 테이블 5개 (3.5)
> - **SERVING**: Semantic View 7개(3.6) + Agent(3.7) + Streamlit 6종(3.9)
> - SV는 `GN_DW.GOLD.V_*`(owner's rights View)를 cross-schema로 참조하므로, Viewer는 BRONZE/SILVER 직접 권한 없이 분석된 데이터만 본다.
> - **스키마명 주의**: PoC의 `ANALYTICS` 스키마(=현 GOLD View)와 혼동을 피하기 위해 소비 계층은 `analytics`가 아닌 `SERVING`으로 명명한다.

### 3.3 BRONZE 테이블 생성

PoC `RAW` 스키마의 테이블을 `GN_DW.BRONZE`로 매핑한다. (DIM 5개 + FACT 21개 = 총 26개)

**DIM 테이블 (5개):**
| # | 테이블명 | 설명 |
|---|----------|------|
| 1 | `DIM_CAMPAIGN_CODE` | 캠페인 코드 마스터 |
| 2 | `DIM_CAMPAIGN_CODE_BACKUP` | 캠페인 코드 백업 |
| 3 | `DIM_MEMBER_ATTRIBUTE` | 회원 속성 (성별, 연령대, 지역) |
| 4 | `DIM_ORG_CODE` | 조직 부서 코드 |
| 5 | `DIM_TEMP_TO_REGULAR_MATCH` | 일시→정기회원 매칭 |

**FACT 테이블 (21개):**
| # | 테이블명 | 설명 |
|---|----------|------|
| 1 | `FACT_AD_GA_AUDIENCE` | GA 잠재고객 세션 데이터 |
| 2 | `FACT_AD_GOOGLE_DEMANDGEN` | Google 디맨드젠 광고 |
| 3 | `FACT_AD_GOOGLE_PMAX` | Google P-MAX 광고 |
| 4 | `FACT_AD_META` | Meta 광고 성과 |
| 5 | `FACT_DIGITAL_AD_DETAIL` | 디지털 광고 상세 |
| 6 | `FACT_DIGITAL_MONTHLY_DEV` | 디지털 월별 개발 목표/실적 |
| 7 | `FACT_DISCONTINUED_MEMBER` | 중단회원 |
| 8 | `FACT_DRTV_BROADCAST_EFF` | DRTV 방송효과 |
| 9 | `FACT_DRTV_MONTHLY_DEV` | DRTV 월별 개발 목표/실적 |
| 10 | `FACT_GA_FEEDBACK_PAGE` | GA 피드백 페이지 |
| 11 | `FACT_GA_VISITS_APP` | GA 방문 (앱) |
| 12 | `FACT_GA_VISITS_MOBILE` | GA 방문 (모바일) |
| 13 | `FACT_GA_VISITS_PC` | GA 방문 (PC) |
| 14 | `FACT_GA_VISITS_TOTAL` | GA 방문 (전체) |
| 15 | `FACT_MARKETING_SEND_NEW` | 마케팅 발송 (신규) |
| 16 | `FACT_MEMBER_DEV_ALL` | 회원 개발 전체 |
| 17 | `FACT_PAYMENT_HISTORY` | 납입 이력 |
| 18 | `FACT_RETRANSMIT_BROADCAST_CONV` | 재송출 방송 전환 |
| 19 | `FACT_RETRANSMIT_MONTHLY_DEV` | 재송출 월별 개발 |
| 20 | `FACT_SMS_ALIMTALK_SEND` | SMS/알림톡 발송 |
| 21 | `FACT_TEMP_MEMBER_DONATION` | 일시후원 기부 |

**BRONZE 적재 방식 (PoC 현황 및 경계):**

PoC에서는 `Excel_to_Table.ipynb` 노트북으로 BRONZE를 적재했다. 흐름은 **Excel 파일 → Stage 업로드 → pandas 파싱 → Snowpark DataFrame → RAW 테이블 적재**이며, 초기 적재 후 3차례 재적재(교체·추가·신규 패턴)로 증분 관리했다.

| 항목 | PoC 현황 | GN_DW 적용 방침 |
|------|----------|-----------------|
| 적재 주체 | ACCOUNTADMIN, 노트북 수동 실행 | `GN_DW_LOADER` role (최소 권한) |
| 적재 방식 | Snowpark `create_dataframe` 단건 적재 | 대용량은 Excel→Parquet→`COPY INTO` 권장 |
| 멱등성 | APPEND 반복 시 중복 위험 | MERGE 또는 DELETE+INSERT로 멱등성 확보 |
| 검증 | row count만 확인 | `SP_VALIDATE_BRONZE_DATA`(4.3)로 품질 체크 |
| 스케줄 | 수동 | 태스크 05:30 `VALIDATE_BRONZE` 이전에 적재 완료 가정 |

> **경계:** 본 프로젝트에서 BRONZE 적재 파이프라인 구현은 외부팀(LOADER) 담당으로 범위 밖이며, 위는 `Excel_to_Table_해설.md`의 개선 권고를 반영한 가이드다. 개선판 노트북 `Excel_to_Table_개선.ipynb`을 적재 표준안으로 활용한다. 정제(SILVER)부터가 본 문서의 책임 범위다.

### 3.4 SILVER 정제 레이어 생성

> SILVER 레이어는 **4단계(프로시저 생성)**에서 BRONZE→SILVER 변환 로직과 함께 구현.
> 주요 정제 작업: 타입 캐스팅, NULL 처리, 날짜 포맷 통일, JOIN 정규화 등.

**SILVER 테이블 범위:** GOLD View는 SILVER만 참조하므로, **GOLD View가 소비하는 모든 BRONZE 테이블은 SILVER에 정제본이 존재해야 한다.** 26개 BRONZE 중 23개를 SILVER로 정제한다.

**정제 대상 (23개):**

| 분류 | SILVER 테이블 (BRONZE와 동일명) |
|------|------|
| DIM (4) | `DIM_CAMPAIGN_CODE`, `DIM_MEMBER_ATTRIBUTE`, `DIM_ORG_CODE`, `DIM_TEMP_TO_REGULAR_MATCH` |
| 회원/납입 (3) | `FACT_MEMBER_DEV_ALL`, `FACT_PAYMENT_HISTORY`, `FACT_DISCONTINUED_MEMBER` |
| 매체/광고 (6) | `FACT_DRTV_BROADCAST_EFF`, `FACT_DRTV_MONTHLY_DEV`, `FACT_DIGITAL_AD_DETAIL`, `FACT_DIGITAL_MONTHLY_DEV`, `FACT_RETRANSMIT_BROADCAST_CONV`, `FACT_RETRANSMIT_MONTHLY_DEV` |
| 디지털 광고/GA (6) | `FACT_AD_GA_AUDIENCE`, `FACT_AD_META`, `FACT_GA_VISITS_TOTAL`, `FACT_GA_VISITS_PC`, `FACT_GA_VISITS_MOBILE`, `FACT_GA_VISITS_APP` |
| 메시징/기타 (4) | `FACT_SMS_ALIMTALK_SEND`, `FACT_MARKETING_SEND_NEW`, `FACT_GA_FEEDBACK_PAGE`, `FACT_TEMP_MEMBER_DONATION` |

**정제 제외 (3개):** `DIM_CAMPAIGN_CODE_BACKUP`(백업), `FACT_AD_GOOGLE_DEMANDGEN`, `FACT_AD_GOOGLE_PMAX`(현재 어떤 GOLD View도 미참조). 향후 분석 추가 시 정제 대상에 포함.

### 3.5 GOLD 분석 View 생성

PoC의 `ANALYTICS` 스키마 객체를 `GN_DW.GOLD`로 매핑한다. **모든 GOLD View는 `GN_DW.SILVER.*` 또는 GOLD 내부 객체(하위 View·예측 테이블)만 참조**하며, `GN_DW_POC.RAW.*`(BRONZE) 직접 참조는 발생하지 않는다.

> **참고:** GOLD View는 `GN_DW_ADMIN` 소유(owner's rights)이므로, ANALYST/VIEWER는 GOLD View SELECT 권한만으로 SILVER 직접 권한 없이 조회 가능하다. (BRONZE 접근 불필요)

**(A) Agent(Semantic View)가 소비하는 분석 View (11개):**

| # | View 이름 | 설명 |
|---|-----------|------|
| 1 | `V_PAYMENT_ANALYSIS` | 납입이력+캠페인+회원특성 통합 |
| 2 | `V_MEMBER_DEV_DETAIL` | 회원 개발 상세 |
| 3 | `V_DISCONTINUATION_REPORT` | 중단회원 리포트 |
| 4 | `V_RETENTION_BY_PERIOD` | 캠페인별 유지율 (중단 교차반영) |
| 5 | `V_DISCONTINUED_DETAIL` | 중단회원 상세 (유지일수/주차) |
| 6 | `V_DISCONTINUED_PAYMENT_ANALYSIS` | 중단회원 미납이력 교차분석 |
| 7 | `V_TEMP_MEMBER_CONVERSION` | 일시→정기 전환 |
| 8 | `V_ALIMTALK_INCREASE_CROSS` | 알림톡수신 x 증액 크로스 |
| 9 | `V_SEND_CONVERSION_ANALYSIS` | 발송유형별 전환분석 |
| 10 | `V_APP_ENGAGEMENT` | 앱 방문/이벤트 분석 |
| 11 | `V_MEMBER_JOURNEY` | 회원 후원 전후 통합 여정 |

**(B) [재설계 추가] BRONZE 직접참조 제거용 정형화 GOLD View (9개):**

PoC에서 일부 Semantic View가 RAW를 직접 참조하던 것을, SILVER 기반 GOLD View로 래핑하여 대체한다.

| # | View 이름 | 대체 대상 (PoC RAW) | 사용 Semantic View |
|---|-----------|--------------------|-------------------|
| 1 | `V_SMS_ALIMTALK_SEND` | FACT_SMS_ALIMTALK_SEND | SV_MARKETING_MESSAGING |
| 2 | `V_DIGITAL_AD_DETAIL` | FACT_DIGITAL_AD_DETAIL | SV_AD_PLATFORM |
| 3 | `V_AD_GA_AUDIENCE` | FACT_AD_GA_AUDIENCE | SV_AD_PLATFORM |
| 4 | `V_AD_META` | FACT_AD_META | SV_AD_PLATFORM |
| 5 | `V_GA_VISITS_TOTAL` | FACT_GA_VISITS_TOTAL | SV_WEB_APP_ANALYTICS |
| 6 | `V_GA_VISITS_PC` | FACT_GA_VISITS_PC | SV_WEB_APP_ANALYTICS |
| 7 | `V_GA_VISITS_MOBILE` | FACT_GA_VISITS_MOBILE | SV_WEB_APP_ANALYTICS |
| 8 | `V_GA_VISITS_APP` | FACT_GA_VISITS_APP | SV_WEB_APP_ANALYTICS |
| 9 | `V_GA_FEEDBACK_PAGE` | FACT_GA_FEEDBACK_PAGE | SV_WEB_APP_ANALYTICS |

**(C) Streamlit 대시보드/리포트용 분석 View (15개):**

Agent는 사용하지 않으나 Streamlit 6종·예측이 소비하므로 GOLD에 유지한다.

| 분류 | View |
|------|------|
| 광고/매체 효율 | `V_MEDIA_EFFICIENCY_DETAIL`, `V_CHANNEL_ROI`, `V_BUDGET_EFFICIENCY`, `V_DRTV_SPOT_EFFICIENCY`, `V_TIME_SLOT_EFFICIENCY` |
| 캠페인 성과 | `V_CAMPAIGN_ROI`, `V_CAMPAIGN_LTV`, `V_MEMBER_DEV_STATUS`, `V_LOYAL_MEMBER_ANALYSIS`, `V_CONVERTED_MEMBER_PROFILE` |
| 메시징 | `V_ALIMTALK_EFFECTIVENESS` |
| 예측(ML) | `V_CAMPAIGN_DEV_FORECAST`, `V_CAMPAIGN_FEE_FORECAST`, `V_FORECAST_DEV_COUNT`, `V_FORECAST_AVG_PAYMENT` |

**(D) 예측(Forecast) 물리 테이블 (5개):** `FORECAST_TRAINING_DATA`, `TRAIN_AVG_PAYMENT`, `TRAIN_DEV_COUNT`, `FORECAST_AVG_PAYMENT_RESULT`, `FORECAST_DEV_COUNT_RESULT` — 4.2 `SP_REFRESH_FORECAST_DATA` 및 예측 태스크가 갱신.

> View 총계: PoC 26개(A 11 + C 15) + 재설계 래핑 9개(B) = **GOLD View 35개**. 모든 View는 SILVER 또는 GOLD 내부 객체만 참조 (BRONZE 직접참조 없음).

**GOLD View ↔ SILVER 소스 매핑:**

GOLD View가 참조하는 SILVER 테이블(또는 동일 GOLD 내 하위 View)을 정리한다. `[G]`는 GOLD 내부 View 참조(view-on-view, GOLD 내에서 해결되므로 BRONZE 미접근).

| GOLD View | 참조 SILVER 테이블 / `[G]`GOLD View |
|-----------|------------------------------------|
| `V_PAYMENT_ANALYSIS` | FACT_PAYMENT_HISTORY, FACT_MEMBER_DEV_ALL, FACT_DISCONTINUED_MEMBER, DIM_CAMPAIGN_CODE, DIM_MEMBER_ATTRIBUTE |
| `V_MEMBER_DEV_DETAIL` | FACT_MEMBER_DEV_ALL, DIM_MEMBER_ATTRIBUTE, DIM_CAMPAIGN_CODE, DIM_ORG_CODE |
| `V_DISCONTINUATION_REPORT` | FACT_DISCONTINUED_MEMBER, DIM_MEMBER_ATTRIBUTE, DIM_CAMPAIGN_CODE, DIM_ORG_CODE |
| `V_RETENTION_BY_PERIOD` | FACT_MEMBER_DEV_ALL, DIM_CAMPAIGN_CODE, FACT_DISCONTINUED_MEMBER |
| `V_DISCONTINUED_DETAIL` | FACT_DISCONTINUED_MEMBER, DIM_MEMBER_ATTRIBUTE |
| `V_DISCONTINUED_PAYMENT_ANALYSIS` | `[G]`V_DISCONTINUED_DETAIL, FACT_PAYMENT_HISTORY |
| `V_TEMP_MEMBER_CONVERSION` | DIM_TEMP_TO_REGULAR_MATCH, FACT_TEMP_MEMBER_DONATION, FACT_MEMBER_DEV_ALL, DIM_CAMPAIGN_CODE |
| `V_ALIMTALK_INCREASE_CROSS` | FACT_SMS_ALIMTALK_SEND, FACT_MEMBER_DEV_ALL, DIM_CAMPAIGN_CODE |
| `V_SEND_CONVERSION_ANALYSIS` | FACT_SMS_ALIMTALK_SEND, FACT_MEMBER_DEV_ALL |
| `V_APP_ENGAGEMENT` | FACT_GA_VISITS_APP |
| `V_MEMBER_JOURNEY` | `[G]`V_MEMBER_DEV_DETAIL, `[G]`V_ALIMTALK_INCREASE_CROSS, `[G]`V_DISCONTINUED_DETAIL, `[G]`V_APP_ENGAGEMENT, FACT_AD_GA_AUDIENCE, FACT_SMS_ALIMTALK_SEND |
| `V_MEDIA_EFFICIENCY_DETAIL` | FACT_DRTV_BROADCAST_EFF, FACT_DIGITAL_AD_DETAIL, FACT_RETRANSMIT_BROADCAST_CONV, DIM_CAMPAIGN_CODE |
| `V_CHANNEL_ROI` | `[G]`V_MEDIA_EFFICIENCY_DETAIL, FACT_MEMBER_DEV_ALL, DIM_CAMPAIGN_CODE |
| `V_CAMPAIGN_ROI` | `[G]`V_MEDIA_EFFICIENCY_DETAIL, FACT_MEMBER_DEV_ALL, DIM_CAMPAIGN_CODE |
| `V_BUDGET_EFFICIENCY` | FACT_DRTV_MONTHLY_DEV, FACT_DIGITAL_MONTHLY_DEV, FACT_RETRANSMIT_MONTHLY_DEV |
| `V_MEMBER_DEV_STATUS` | FACT_DRTV_MONTHLY_DEV, FACT_DIGITAL_MONTHLY_DEV, FACT_RETRANSMIT_MONTHLY_DEV |
| `V_DRTV_SPOT_EFFICIENCY` | FACT_DRTV_BROADCAST_EFF |
| `V_TIME_SLOT_EFFICIENCY` | FACT_DRTV_BROADCAST_EFF, FACT_RETRANSMIT_BROADCAST_CONV |
| `V_CAMPAIGN_LTV` | FACT_MEMBER_DEV_ALL, DIM_CAMPAIGN_CODE |
| `V_CAMPAIGN_DEV_FORECAST` | FACT_MEMBER_DEV_ALL, DIM_CAMPAIGN_CODE, DIM_ORG_CODE |
| `V_CAMPAIGN_FEE_FORECAST` | FACT_MEMBER_DEV_ALL, DIM_CAMPAIGN_CODE |
| `V_LOYAL_MEMBER_ANALYSIS` | FACT_MEMBER_DEV_ALL, DIM_CAMPAIGN_CODE, DIM_MEMBER_ATTRIBUTE |
| `V_CONVERTED_MEMBER_PROFILE` | FACT_MEMBER_DEV_ALL, DIM_MEMBER_ATTRIBUTE, DIM_CAMPAIGN_CODE, DIM_ORG_CODE |
| `V_ALIMTALK_EFFECTIVENESS` | FACT_SMS_ALIMTALK_SEND, FACT_MARKETING_SEND_NEW, FACT_MEMBER_DEV_ALL |
| `V_FORECAST_AVG_PAYMENT` | TRAIN_AVG_PAYMENT, FORECAST_AVG_PAYMENT_RESULT (예측 테이블, 4.2) |
| `V_FORECAST_DEV_COUNT` | TRAIN_DEV_COUNT, FORECAST_DEV_COUNT_RESULT (예측 테이블, 4.2) |
| (B) 9개 정형화 View | 각 1:1 대응 SILVER 테이블 (3.5 (B) 표 참조) |

> **GOLD 내부 View 의존성 주의:** `V_MEMBER_JOURNEY`·`V_CHANNEL_ROI`·`V_CAMPAIGN_ROI`·`V_DISCONTINUED_PAYMENT_ANALYSIS`는 다른 GOLD View를 참조하는 view-on-view 구조다. 생성 순서를 의존성에 맞춰 정렬하고(하위 View 먼저), GOLD 외부(BRONZE) 직접참조는 발생하지 않는다.

### 3.6 Semantic View 생성

PoC Semantic View를 `GN_DW.SERVING`에 재생성한다. **base 객체 참조는 모두 GOLD View(SILVER/GOLD 외 BRONZE 직접참조 금지).** SV는 SERVING에 위치하되 `GN_DW.GOLD.V_*`를 cross-schema로 참조한다.

| # | Semantic View | 참조 GOLD View | 설명 |
|---|---------------|----------------|------|
| 1 | `SV_PAYMENT_ANALYSIS` | V_PAYMENT_ANALYSIS | 납입 분석 |
| 2 | `SV_MEMBER_LIFECYCLE` | V_DISCONTINUED_DETAIL, V_DISCONTINUED_PAYMENT_ANALYSIS, V_TEMP_MEMBER_CONVERSION | 회원 생애주기 (중단/미납/일시→정기 전환) |
| 3 | `SV_MEMBER_DEVELOPMENT` | V_MEMBER_DEV_DETAIL, V_DISCONTINUATION_REPORT, V_RETENTION_BY_PERIOD | 회원 개발/유지율 |
| 4 | `SV_MARKETING_MESSAGING` | **V_SMS_ALIMTALK_SEND**(신규), V_ALIMTALK_INCREASE_CROSS, V_SEND_CONVERSION_ANALYSIS | 마케팅 발송/전환 |
| 5 | `SV_AD_PLATFORM` | **V_DIGITAL_AD_DETAIL, V_AD_GA_AUDIENCE, V_AD_META**(신규) | 광고 플랫폼 |
| 6 | `SV_WEB_APP_ANALYTICS` | V_APP_ENGAGEMENT, **V_GA_VISITS_TOTAL/PC/MOBILE/APP, V_GA_FEEDBACK_PAGE**(신규) | 웹/앱 분석 |
| 7 | `SV_MEMBER_JOURNEY` | V_MEMBER_JOURNEY | 회원 여정 |

> **참고(소스 중복):** `SV_WEB_APP_ANALYTICS`의 `V_APP_ENGAGEMENT`와 `V_GA_VISITS_APP`는 둘 다 `FACT_GA_VISITS_APP`를 기반으로 한다. SV 내 logical table 역할(이벤트 분석 vs 방문 집계)이 다르므로 유지하되, 구현 시 지표 중복 집계가 없도록 join key/granularity를 명확히 구분한다.

> **[재설계 핵심]** PoC에서 `SV_MARKETING_MESSAGING`·`SV_AD_PLATFORM`·`SV_WEB_APP_ANALYTICS`가 `GN_DW_POC.RAW.*`(BRONZE) 테이블을 logical table로 직접 참조했으나, 모두 **3.5 (B)의 SILVER 기반 GOLD 정형화 View 경유**로 변경한다.
>
> **VQR 경로 치환 필수:** Semantic View 내부 `ai_verified_queries`(VQR)에 하드코딩된 `GN_DW_POC.RAW.*` / `GN_DW_POC.ANALYTICS.*` 경로도 전부 `GN_DW.GOLD.*`로 치환한다. Cortex Analyst/Agent는 VQR SQL을 **실행 role 권한**으로 base 객체에 직접 실행하므로, BRONZE 경로가 남으면 ANALYST/VIEWER에서 권한 오류가 발생한다. (best practice: Cortex Analyst는 SV와 그 underlying 객체 모두에 SELECT 필요)

### 3.7 Agent 생성

| 항목 | 값 |
|------|---|
| Agent 이름 | `GN_DW.SERVING.GN_DW_AGENT` |
| Model (orchestration) | `auto` (자동 최적 모델 선택) |
| Budget | 60초 / 32,000 토큰 |
| Tools | Cortex Analyst text-to-SQL 7개 + `data_to_chart` (차트 생성) |
| Orchestration 라우팅 | 질문 유형별 분석툴 자동 라우팅 규칙 정의 |
| sample_questions | onboarding 예시 질문 6개 포함 |
| 접근 Role | GN_DW_ANALYST, GN_DW_VIEWER, GN_DW_SERVICE |

**Tool ↔ Semantic View 매핑 (`tool_resources`):**

| Tool (분석가) | Semantic View | 라우팅 대상 질문 |
|---|---|---|
| `payment_analyst` | SV_PAYMENT_ANALYSIS | 납입회비, 미납, 청구금액 |
| `lifecycle_analyst` | SV_MEMBER_LIFECYCLE | 중단회원, 유지기간, 일시→정기 전환 |
| `member_dev_analyst` | SV_MEMBER_DEVELOPMENT | 회원개발, 캠페인별 개발건수, ROI, 유지율 |
| `messaging_analyst` | SV_MARKETING_MESSAGING | 알림톡, 문자발송, 발송전환 |
| `ad_platform_analyst` | SV_AD_PLATFORM | 디지털광고, 매체, 구글/메타, CTR/CPC |
| `web_app_analyst` | SV_WEB_APP_ANALYTICS | 웹/앱 방문 |
| `journey_analyst` | SV_MEMBER_JOURNEY | 회원별 후원 전후 통합 여정 |

> **참고:** PoC에는 `GN_DW_AGENT`(7개 SV) 외에 구버전 `GN_DW_POC_AGENT`(4개 SV, 별도 테이블 기반)도 존재한다. 본 마이그레이션은 `GN_DW_AGENT`만 이관 대상으로 하며, 구버전은 폐기한다.

### 3.8 권한 부여 (GRANT / Future Grants)

Role별 스키마 접근 권한 요약:

| Role | BRONZE | SILVER | GOLD | SERVING |
|------|--------|--------|------|---------|
| `GN_DW_ADMIN` | ALL | ALL | ALL | ALL |
| `GN_DW_ENGINEER` | SELECT | ALL (CREATE TABLE, CREATE PROCEDURE, CREATE TASK 포함) | USAGE, SELECT, CREATE VIEW | USAGE |
| `GN_DW_LOADER` | INSERT, UPDATE | - | - | - |
| `GN_DW_ANALYST` | - | SELECT | USAGE, SELECT | USAGE + USAGE ON SV/AGENT/STREAMLIT |
| `GN_DW_VIEWER` | - | - | USAGE, SELECT(SV 참조 View) | USAGE + USAGE ON SV/AGENT/STREAMLIT |
| `GN_DW_SERVICE` | - | - | USAGE, SELECT | USAGE + USAGE ON SV/AGENT/STREAMLIT |

> **[SV/Agent/Streamlit 권한이 SERVING으로 이동]** Semantic View·Agent·Streamlit이 SERVING에 위치하므로 `USAGE ON SV/AGENT/STREAMLIT`는 SERVING에서 부여한다.
> **[Viewer의 GOLD SELECT가 필요한 이유]** Snowflake Intelligence(CoWork)에서 Agent가 만든 text-to-SQL은 **호출자(Viewer) 세션에서 실행**되며, SV가 참조하는 base 객체(`GN_DW.GOLD.V_*`)에 직접 실행된다. 따라서 Viewer는 SV가 참조하는 GOLD View에 `SELECT`가 필요하다. GOLD View는 owner's rights라 SILVER/BRONZE 직접 권한은 불필요 → Viewer는 분석된 데이터(GOLD View)만 본다.
> **[Streamlit 경로]** Streamlit 앱은 owner 권한(owner's rights)으로 실행되므로 Viewer는 `USAGE ON STREAMLIT`만으로 GOLD 직접 권한 없이 리포트를 본다.
> **[OPS / SECURITY 접근]** 위 표 외 운영/거버넌스 스키마:
> - `OPS`(비용 View): `GN_DW_ADMIN` ALL, `GN_DW_ENGINEER`·`GN_DW_ANALYST` SELECT(비용 가시성).
> - `SECURITY`(마스킹/네트워크 정책): `GN_DW_ADMIN`만 관리. *(07 SQL의 `GN_DW_MASKING_ADMIN` 역할은 02에 미정의 → SQL 편집 시 정리 대상)*

**Future Grants 적용:** 향후 생성되는 테이블/뷰에도 자동으로 권한이 부여되도록 설정.

### 3.9 Streamlit 대시보드

PoC의 Streamlit 앱 6종을 `GN_DW.SERVING` 스키마에 배포한다. 각 앱은 `GN_DW.GOLD.V_*` View만 참조하며, `GN_DW_SERVICE`(또는 `GN_DW_ANALYTICS_WH`) 권한으로 실행한다(owner's rights).

| # | 대시보드 | 주요 참조 GOLD View |
|---|----------|--------------------|
| 1 | 캠페인별 LTV/CAC 분석 | `V_CAMPAIGN_LTV`, `V_CAMPAIGN_ROI` |
| 2 | 주요캠페인별 미납현황 | `V_PAYMENT_ANALYSIS` |
| 3 | 개발회원 후원여정 현황 | `V_MEMBER_JOURNEY`, `V_MEMBER_DEV_DETAIL` |
| 4 | 주간중단회원 보고 | `V_DISCONTINUED_DETAIL` |
| 5 | 주요캠페인별 중단현황 | `V_DISCONTINUATION_REPORT`, `V_DISCONTINUED_DETAIL` |
| 6 | (테스트 앱) | - (운영 이관 시 정리) |

> Streamlit 앱은 `query_warehouse`를 PoC의 `COMPUTE_WH`/`POC_WH`에서 `GN_DW_ANALYTICS_WH`로 변경한다.

## 4. 프로시저 생성

> **SQL 파일:** [`04_프로시저_생성.sql`](./04_프로시저_생성.sql)

### 4.1 BRONZE → SILVER 정제 프로시저

BRONZE의 원천 데이터를 SILVER로 정제/변환한다. 주요 정제 작업:

| # | 프로시저 | 대상 테이블 | 정제 내용 |
|---|----------|------------|-----------|
| 1 | `SP_REFINE_DIM_CAMPAIGN` | DIM_CAMPAIGN_CODE | 중복 제거, 코드 TRIM, 사용여부 필터 |
| 2 | `SP_REFINE_DIM_MEMBER` | DIM_MEMBER_ATTRIBUTE | NULL 처리, 연령대/지역 표준화 |
| 3 | `SP_REFINE_FACT_PAYMENT` | FACT_PAYMENT_HISTORY | 회비청구월 DATE 캐스팅, 미납금액 계산 컬럼 추가 |
| 4 | `SP_REFINE_FACT_MEMBER_DEV` | FACT_MEMBER_DEV_ALL | 후원신청일 DATE 캐스팅, 신청월 파생 컬럼 |
| 5 | `SP_REFINE_FACT_DISCONTINUED` | FACT_DISCONTINUED_MEMBER | 가입일/중단일 DATE 캐스팅, 유지일수 계산 |
| 6 | `SP_REFINE_FACT_DIGITAL_AD` | FACT_DIGITAL_AD_DETAIL | 숫자형 FLOAT→NUMBER 캐스팅, NULL 0 대체 |
| 7 | `SP_REFINE_FACT_SMS` | FACT_SMS_ALIMTALK_SEND | 발송일시 TIMESTAMP 변환, 성공률 NUMBER 캐스팅 |
| 8 | `SP_REFINE_FACT_AD_GA` | FACT_AD_GA_AUDIENCE | 세션수/활성사용자 NUMBER 캐스팅, 날짜 DATE 변환 |
| 9 | `SP_REFINE_FACT_AD_META` | FACT_AD_META | 노출/클릭/지출(KRW) NUMBER 캐스팅, 보고기간 DATE 변환 |
| 10 | `SP_REFINE_FACT_GA_VISITS` | FACT_GA_VISITS_TOTAL/PC/MOBILE/APP | 세션/페이지뷰/방문수 등 TEXT→NUMBER 캐스팅 (4개 테이블) |
| 11 | `SP_REFINE_FACT_GA_FEEDBACK` | FACT_GA_FEEDBACK_PAGE | 이탈률/참여율/평균세션시간 NUMBER 캐스팅 |
| 12 | `SP_REFINE_DIM_ORG` | DIM_ORG_CODE | 부서코드 TRIM, 중복 제거 |
| 13 | `SP_REFINE_DIM_TEMP_MATCH` | DIM_TEMP_TO_REGULAR_MATCH | 전환일 DATE 캐스팅, 정기/일시 회원번호 정규화 |
| 14 | `SP_REFINE_FACT_DRTV` | FACT_DRTV_BROADCAST_EFF, FACT_DRTV_MONTHLY_DEV | 횟수/광고비/인입콜/시청률 NUMBER 캐스팅, 방송일자 DATE (2개 테이블) |
| 15 | `SP_REFINE_FACT_DIGITAL_DEV` | FACT_DIGITAL_MONTHLY_DEV | 예산/목표/실적 NUMBER 캐스팅, 날짜 DATE |
| 16 | `SP_REFINE_FACT_RETRANSMIT` | FACT_RETRANSMIT_BROADCAST_CONV, FACT_RETRANSMIT_MONTHLY_DEV | 횟수/편성비/인입콜 NUMBER, 날짜 DATE (2개 테이블) |
| 17 | `SP_REFINE_FACT_MARKETING_SEND` | FACT_MARKETING_SEND_NEW | 발송일시 TIMESTAMP 변환, 회원번호 정규화 |
| 18 | `SP_REFINE_FACT_TEMP_DONATION` | FACT_TEMP_MEMBER_DONATION | 후원일 DATE, 후원금액 NUMBER 캐스팅 |

> **[재설계 반영]** 8~11번은 PoC에서 Semantic View가 RAW를 직접 참조하던 GA/Meta 테이블, 12~18번은 (C) Streamlit/예측 GOLD View가 참조하는 매체·전환 테이블을 SILVER로 정제하기 위해 추가. 정제된 SILVER 테이블은 3.4의 23개와 일치하며, 모든 GOLD View가 SILVER만 참조하도록 보장한다.

**정제 원칙:**
- CREATE OR REPLACE TABLE 방식 (전체 재생성, 멱등성 보장)
- SILVER 테이블은 BRONZE와 동일 구조 + 파생 컬럼 + 올바른 데이터 타입
- NULL key 레코드는 WHERE 조건으로 제외 (회원번호 IS NOT NULL 등)

### 4.2 SILVER → GOLD 집계/변환 프로시저

> 현재 GOLD 레이어는 View로 구성되어 있어 별도 집계 프로시저가 불필요하다. 예측 데이터 갱신만 프로시저로 운영한다.
> (향후 성능 이슈로 GOLD를 물리 테이블화할 경우 CTAS 프로시저를 추가)

| # | 프로시저 | 용도 | 비고 |
|---|----------|------|------|
| 1 | `SP_REFRESH_FORECAST_DATA` | 시계열 예측 데이터 갱신 | 아래 예측 파이프라인 참조 |

**예측(Forecast) 파이프라인 (`SP_REFRESH_FORECAST_DATA`):**

PoC는 `SNOWFLAKE.ML.FORECAST`(Cortex 시계열 예측)로 브랜드별 월간 개발건수/평균납입액을 예측한다. 결과 테이블(`SERIES`, `TS`, `FORECAST`, `LOWER_BOUND`, `UPPER_BOUND`)은 ML.FORECAST 출력 스키마와 동일하다.

1. **학습 데이터 생성:** SILVER(`FACT_MEMBER_DEV_ALL`, `FACT_PAYMENT_HISTORY`) → `FORECAST_TRAINING_DATA` → 브랜드·월 단위 집계로 `TRAIN_DEV_COUNT`, `TRAIN_AVG_PAYMENT` 갱신
2. **모델 학습/예측:** `TRAIN_*`를 입력으로 `SNOWFLAKE.ML.FORECAST` 모델 생성 후 `FORECAST(...)` 호출
3. **결과 저장:** 예측 결과를 `FORECAST_DEV_COUNT_RESULT`, `FORECAST_AVG_PAYMENT_RESULT`에 저장
4. **노출:** `V_FORECAST_DEV_COUNT`, `V_FORECAST_AVG_PAYMENT`가 `TRAIN_*`(actual) + `FORECAST_*_RESULT`(forecast)를 UNION ALL로 제공

> 예측 객체(테이블 5개 + View 2개)는 `GN_DW.GOLD`에 위치하며, 5단계 `TASK_REFRESH_FORECAST`가 정제(SILVER) 완료 후 본 프로시저를 실행한다.

### 4.3 유틸리티 프로시저

> ※ SQL 파일에서는 의존성 상 `ETL_LOG` 테이블과 `SP_LOG_ETL_STATUS`가 4.1보다 먼저 정의됨 (4.1 프로시저들이 내부에서 호출하기 때문)

| # | 프로시저 | 용도 |
|---|----------|------|
| 1 | `SP_RUN_ALL_REFINEMENT` | 4.1의 모든 정제 프로시저를 순서대로 호출 (오케스트레이션) |
| 2 | `SP_LOG_ETL_STATUS` | ETL 실행 로그를 기록 (시작/종료/에러/row count) |
| 3 | `SP_VALIDATE_BRONZE_DATA` | BRONZE 데이터 품질 체크 (NULL 비율, row count 변동) |

## 5. 태스크 생성

> **SQL 파일:** [`05_태스크_생성.sql`](./05_태스크_생성.sql)

### 5.1 태스크 스케줄 설계

| 태스크 | 실행 주기 | 시간 | 비고 |
|--------|-----------|------|------|
| `TASK_VALIDATE_BRONZE` | 매일 1회 | 05:30 KST (Root) | BRONZE 품질 체크. **통과 시에만** 후속 정제 트리거 |
| `TASK_REFINEMENT_ROOT` | VALIDATE_BRONZE 이후 | (AFTER) | BRONZE→SILVER 전체 정제 |
| `TASK_REFRESH_FORECAST` | REFINEMENT_ROOT 이후 | (AFTER) | GOLD 예측 데이터 갱신 |
| `TASK_FINALIZER` | 전체 DAG 완료 후 | (Finalizer) | 상태 로그/알림 |

**스케줄 원칙:**
- `TASK_VALIDATE_BRONZE`를 DAG의 Root로 두어, 다른 팀의 BRONZE 적재 완료 후(새벽) 품질을 먼저 검증한다.
- `SP_VALIDATE_BRONZE_DATA`는 임계 위반(예: row count 급감, NULL key 발생) 시 **예외를 발생**시켜 태스크를 실패시키고, 후속 정제 태스크가 실행되지 않도록 차단한다(게이팅).
- Serverless 모드 사용 (비용 효율, 자동 스케일링)
- Serverless 사용 시 `EXECUTE MANAGED TASK ON ACCOUNT` 권한 필요 (02번 SQL에서 부여)
- 3회 연속 실패 시 자동 중단 (SUSPEND_TASK_AFTER_NUM_FAILURES = 3)

### 5.2 태스크 생성 DDL

| # | 태스크 이름 | 유형 | 트리거 |
|---|------------|------|--------|
| 1 | `TASK_VALIDATE_BRONZE` | Root (DAG) | CRON 05:30 KST |
| 2 | `TASK_REFINEMENT_ROOT` | Child | AFTER TASK_VALIDATE_BRONZE |
| 3 | `TASK_REFRESH_FORECAST` | Child | AFTER TASK_REFINEMENT_ROOT |
| 4 | `TASK_FINALIZER` | Finalizer | 전체 DAG 완료 후 로그/알림 |

### 5.3 태스크 의존성 (DAG)

```
[TASK_VALIDATE_BRONZE] (05:30, Root)
        │ (품질 통과 시에만 후속 실행, 실패 시 DAG 중단)
        ▼
[TASK_REFINEMENT_ROOT] (BRONZE→SILVER 정제)
        │
        ▼
[TASK_REFRESH_FORECAST] (Child, GOLD 예측 갱신)
        │
        ▼
[TASK_FINALIZER] (Finalizer - 상태 로그/알림)
```

**향후 확장:**
- BRONZE 적재 Stream 기반 트리거 (WHEN SYSTEM$STREAM_HAS_DATA) 전환 가능
- SILVER→GOLD 성능 이슈 시 CTAS 프로시저 전환 가능

## 6. 테스트

> **SQL 파일:** [`06_테스트.sql`](./06_테스트.sql)

### 6.1 권한 테스트

각 Role로 전환하여 의도한 접근만 가능한지 검증한다.

| 테스트 케이스 | Role | 기대 결과 |
|--------------|------|-----------|
| BRONZE SELECT | GN_DW_ENGINEER | ✅ 성공 |
| BRONZE SELECT | GN_DW_ANALYST | ❌ 실패 (접근 불가) |
| BRONZE INSERT | GN_DW_LOADER | ✅ 성공 |
| BRONZE INSERT | GN_DW_ANALYST | ❌ 실패 |
| SILVER SELECT | GN_DW_ANALYST | ✅ 성공 |
| GOLD SELECT | GN_DW_VIEWER | ✅ 성공 |
| GOLD CREATE VIEW | GN_DW_VIEWER | ❌ 실패 |
| Semantic View USAGE | GN_DW_ANALYST | ✅ 성공 |
| Agent USAGE | GN_DW_VIEWER | ✅ 성공 |
| Agent USAGE | GN_DW_LOADER | ❌ 실패 |

### 6.2 파이프라인 E2E 테스트

BRONZE 적재 → SILVER 정제 → GOLD View 조회 전체 흐름 검증.

| 단계 | 검증 항목 |
|------|-----------|
| 1 | BRONZE 테이블에 샘플 데이터 INSERT |
| 2 | SP_RUN_ALL_REFINEMENT 실행 → SILVER 테이블 생성 확인 |
| 3 | GOLD View 조회 → 결과 반환 확인 |
| 4 | ETL_LOG 기록 확인 (SUCCESS 상태) |
| 5 | TASK 수동 실행 (EXECUTE TASK) → 정상 완료 확인 |

### 6.3 데이터 정합성 검증

| 검증 항목 | 방법 |
|-----------|------|
| Row count 일치 | BRONZE vs SILVER 테이블 건수 비교 |
| NULL key 없음 | SILVER 테이블 PK 컬럼 NULL 체크 |
| 타입 캐스팅 정상 | SILVER 날짜 컬럼 NULL 비율 확인 (캐스팅 실패 시 NULL) |
| View 결과 정합 | GOLD View 집계 vs 수기 검산 비교 |
| Semantic View 동작 | Agent에 질문 → SQL 생성 → 결과 반환 확인 |

## 7. 보안 세팅

> **SQL 파일:** [`07_보안_세팅.sql`](./07_보안_세팅.sql)

### 7.1 네트워크 룰 / IP 허용

기능이 안정화된 후 네트워크 레벨에서 접근을 제한한다. 네트워크 룰/정책 객체는 `GN_DW.SECURITY` 스키마에 배치한다(3.2).

| 네트워크 룰 | 용도 | 타입 |
|------------|------|------|
| `NR_OFFICE_IP` | 사무실 IP 대역 허용 | IPV4 (INGRESS) |
| `NR_VPN_IP` | VPN 접속 IP 허용 | IPV4 (INGRESS) |
| `NR_SERVICE_IP` | 서비스/ETL 서버 IP | IPV4 (INGRESS) |

| 네트워크 정책 | 적용 대상 | 설명 |
|--------------|-----------|------|
| `NP_GN_DW_ACCOUNT` | Account | 사무실 + VPN + 서비스 IP만 허용 |
| `NP_GN_DW_SERVICE` | GN_DW_SERVICE 유저 | 서비스 IP만 허용 (더 엄격) |

**적용 순서:**
1. Network Rule 생성 → Network Policy 생성 → 테스트 (본인 IP 포함 확인)
2. Account에 활성화 (`ALTER ACCOUNT SET NETWORK_POLICY`)

> ⚠️ **주의:** 본인 IP를 ALLOWED에 포함하지 않으면 즉시 잠김. 반드시 테스트 후 적용.

### 7.2 마스킹 정책

BRONZE/SILVER에 민감 데이터(회원번호, 연락처 등)가 존재하므로, Role 기반 동적 마스킹을 적용한다. 마스킹 정책 객체는 `GN_DW.SECURITY` 스키마에 배치하고 SILVER 컬럼에 매핑한다(3.2).

| 정책 이름 | 대상 컬럼 | 마스킹 규칙 |
|-----------|-----------|------------|
| `MASK_MEMBER_ID` | "회원번호" | ENGINEER/ADMIN → 원본, 나머지 → 앞4자리 + **** |

> 현재 데이터에서 확인된 민감 컬럼은 회원번호다. 전화번호 등 추가 PII 컬럼이 도입되면 동일 패턴으로 마스킹 정책을 확장한다.

**마스킹 적용 레이어:**
- SILVER 물리 테이블 컬럼에 직접 적용 (CREATE OR REPLACE VIEW 시 정책 매핑 단절 방지)
- SILVER에 적용된 마스킹은 상단 GOLD View까지 자연스럽게 상속됨
- BRONZE는 ANALYST/VIEWER가 직접 접근 불가하므로 불필요

### 7.3 MFA 설정

| 대상 | MFA 정책 |
|------|----------|
| ACCOUNTADMIN 유저 | 필수 (Snowflake 권장) |
| GN_DW_ADMIN 유저 | 필수 |
| GN_DW_ENGINEER | 권장 |
| GN_DW_ANALYST | 선택 (조직 정책에 따라) |

> MFA는 Snowflake 웹 UI 또는 CLI에서 유저별 설정. DDL로 강제하려면 `AUTHENTICATION POLICY`를 사용.

## 8. 모니터링 세팅

> **SQL 파일:** [`08_모니터링_세팅.sql`](./08_모니터링_세팅.sql)

### 8.1 Resource Monitor

Warehouse별 크레딧 사용량을 관리하여 예상치 못한 비용 폭주를 방지한다. Resource Monitor는 **계정 레벨 객체**로 특정 스키마에 속하지 않는다.

| Resource Monitor | 대상 | 월 크레딧 한도 | 트리거 |
|-----------------|------|--------------|--------|
| `RM_ETL` | GN_DW_ETL_WH | 200 | 75% 알림, 90% SUSPEND, 100% SUSPEND_IMMEDIATE |
| `RM_ANALYTICS` | GN_DW_ANALYTICS_WH | 500 | 75% 알림, 90% 알림, 100% SUSPEND |
| `RM_DEV` | GN_DW_DEV_WH | 100 | 80% 알림, 100% SUSPEND |
| `RM_ACCOUNT` | 전체 계정 | 1000 | 80% 알림, 95% SUSPEND |

### 8.2 Alert 설정

ETL 파이프라인 실패, 비정상 쿼리 등을 감지하여 알림을 보낸다. Alert와 `ETL_LOG` 테이블은 운영 파이프라인과 함께 **`GN_DW.SILVER`에 유지**한다(OPS 이동 시 프로시저·태스크 광범위 수정 발생).

| Alert | 감지 조건 | 동작 |
|-------|----------|------|
| `ALERT_ETL_FAILURE` | ETL_LOG에 ERROR 상태 존재 (최근 1시간) | 이메일 알림 |
| `ALERT_LONG_QUERY` | 쿼리 실행 시간 > 30분 | 이메일 알림 |
| `ALERT_BRONZE_STALE` | BRONZE 테이블 최종 업데이트 > 24시간 | 이메일 알림 |

### 8.3 비용 추적

| 방법 | 설명 |
|------|------|
| `SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY` | Warehouse별 크레딧 사용 추이 |
| `SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY` | 쿼리별 비용 분석 |
| Resource Monitor 알림 | 임계값 도달 시 즉시 알림 |
| 비용 리포트 View | `V_MONTHLY_COST_REPORT`(Warehouse별 월간 집계), `V_COST_BY_ROLE`(Role별 일간 집계) |

> **참고:** `V_MONTHLY_COST_REPORT`·`V_COST_BY_ROLE`는 PoC에 없는 **신규 객체**다. `SNOWFLAKE.ACCOUNT_USAGE` 기반으로 GN_DW에서 신규 생성하며, 운영 스키마 `GN_DW.OPS`에 배치한다(3.2).

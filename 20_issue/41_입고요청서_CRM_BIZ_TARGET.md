<!-- LLM-METADATA
doc_id: INTAKE_REQUEST_CRM_BIZ_TARGET
doc_role: 데이터 입고 요청서 — CRM 사업목표(FTG-B) 원천
project: GN_DW (굿네이버스)
created: 2026-07-15
updated: 2026-07-20
blocker_ref: E-6 (40_입고대기_원천의존.md)
END-METADATA -->

# 데이터 입고 요청서 — CRM 사업목표 (FTG-B)

| 항목 | 내용 |
|------|------|
| **요청일** | 2026-07-15 |
| **수정일** | 2026-07-20 |
| **요청자** | DW 구축팀 |
| **수신자** | _(현업 담당부서 — 확인 후 기입)_ |
| **긴급도** | 🔴 하드 블로커 (E-6) — 입고 전까지 GOLD `FTG-B` 빌드 불가 |
| **관련 이슈** | `20_issue/40_입고대기_원천의존.md` §1 E-6 |

---

## 1. 요청 배경

GN_DW SILVER 레이어에 `ERP_BIZ_TARGET` 테이블을 설계하였으나,
현재 BRONZE에 대응하는 원천 데이터가 **존재하지 않습니다.**

- 기존 ERP 예산원장(`BDGT_ACMSLT_LEDGER`)은 **편성/집행** 데이터이며, **사업목표(연사업·추경 누계목표)** 와는 별개입니다.
- GOLD 팩트 테이블 `FTG-B`(TARGET_BIZ: 사업목표 달성률) 산출을 위해 반드시 필요합니다.
- 사업계획 관련 참조: #152~155

> **⚠️ 원천 변경 (2026-07-20)**
> 현업 확인 결과, 사업목표는 ERP가 아닌 **CRM에서 직접 관리**합니다.
> 매출(후원금) 실적을 확인한 뒤 목표를 사후 조정하는 프로세스이므로,
> ERP 예산 시스템이 아닌 CRM 수동 입력 방식으로 운영됩니다.
> 
> - BRONZE 적재 경로: `CRM → BRONZE_CRM.CRM_BIZ_TARGET → SILVER → GOLD`
> - 목표유형: 당초 → 추경1차 → 추경2차 (버전 누적, 덮어쓰기 아님)

---

## 2. 필요 데이터 스펙

### 2-1. 필수 컬럼

| # | 컬럼명(안) | 데이터 타입 | 설명 | 필수 |
|---|---|---|---|---|
| 1 | TARGET_YEAR | NUMBER(4) | 목표연도 (YYYY) | ✅ |
| 2 | MONTH_NO | NUMBER(2) | 월 (1~12). 연간 총량만 있으면 NULL 허용 | ✅ |
| 3 | ORG_CD | VARCHAR | 조직코드 (FK → DIM_ORG) | ✅ |
| 4 | ORG_NM | VARCHAR | 조직명 (부서/팀) | ✅ |
| 5 | SPONSOR_BIZ_NM | VARCHAR | 후원사업명 | ✅ |
| 6 | CAMPAIGN_NM | VARCHAR | 캠페인명 (연결키 부재 시 NULL 가능) | ◐ |
| 7 | TARGET_TYPE | VARCHAR | 목표유형: '당초' / '추경1차' / '추경2차' | ✅ |
| 8 | TARGET_CNT | NUMBER | 목표 건수(건) — 지표사전 #152~155 기준. ※금액(원)으로만 관리 시 별도 협의(SILVER /10000 파생) | ✅ |
| 9 | CONFIRMED_DATE | DATE | 등록일 (이 목표를 확정한 일자) | ✅ |
| 10 | CONFIRMED_BY | VARCHAR | 확정자 (입력 담당자) | ◐ |
| 11 | REMARK | VARCHAR | 비고 (사유 등 자유기술) | ◐ |

### 2-2. Grain (행 1건의 의미)

```
월 × 조직 × 후원사업 × 목표유형 [× 캠페인(선택)]
```

- **최소 grain**: 월 × 조직 × 후원사업 × 목표유형
- **이상적 grain**: 월 × 조직 × 후원사업 × 목표유형 × 캠페인 (캠페인 ROI 산출 가능)

> **중요**: 추경이 발생하면 기존 '당초' 행을 수정하지 않고 '추경1차' 행을 **새로 추가**합니다.
> 이를 통해 "당초 대비 추경 변동 분석"이 가능합니다.

### 2-3. 기간 범위

| 구분 | 요건 |
|------|------|
| 필수 | 2025년 ~ 현재 |
| 희망 | 과거 3개년 (비교 분석용) |

### 2-4. 목표 유형 및 변경 이력

- **당초** — 연초 사업계획 확정 시 설정
- **추경1차** — 1Q 실적 확인 후 조정
- **추경2차** — 2Q 실적 확인 후 조정 (필요 시)

> **이력 관리 원칙 (버전 누적)**:
> 추경 시 기존 행을 수정(UPDATE)하지 않고 새 행을 추가(INSERT)합니다.
> 즉, 동일 월×조직×후원사업에 '당초'와 '추경1차'가 공존합니다.

**입력 양식 예시:**

| 기준년월 | 조직코드 | 후원사업 | 목표유형 | 목표건수 | 등록일 | 비고 |
|---------|---------|---------|---------|---------|-------|------|
| 202601 | ORG001 | 아동후원 | 당초 | 30,000 | 2026-01-05 | |
| 202601 | ORG001 | 아동후원 | 추경1차 | 35,000 | 2026-04-10 | 1Q 실적 반영 |

---

## 3. 제공 가능 형태 (택1)

| 형태 | 비고 |
|------|------|
| **Excel/CSV 파일** | DW팀이 BRONZE로 적재 |
| **CRM 화면 직접 입력** | DW팀이 CRM DB에서 추출하여 적재 |
| **기존 시스템 화면 캡처 + 설명** | 구조 파악 후 추출 방안 협의 |

---

## 4. 입고 후 활용 계획

```
[CRM] 사업목표 수동 입력 (현업)
    ↓ 추출
[BRONZE] GN_DW.BRONZE_CRM.CRM_BIZ_TARGET (신규)
    ↓ 정제
[SILVER] GN_DW.SILVER.ERP_BIZ_TARGET (스키마 준비 완료)
    ↓ 변환
[GOLD]   FTG-B (사업목표 달성률 = 실적/목표)
    ↓
[SEMANTIC VIEW / 대시보드] 사업목표 vs 실적 비교
```

---

## 5. 요청 사항 정리

1. **CRM 내 사업목표 테이블/화면** 위치 확인 부탁드립니다
2. **제공 가능 형태와 주기** 확인 (일회성 vs 월/분기 갱신)
3. **컬럼 매핑 검토** — 위 §2 스펙과 실제 원천 간 차이 피드백
4. **조직코드**: 기존 DIM_ORG 코드와 동일한지 확인 (매핑 필요 여부)
5. **추경 입력 규칙**: 추경 시 새 행 추가로 운영하는 것이 맞는지 재확인

---

## 6. 참고 — 현재 SILVER DDL (스키마-only)

```sql
-- 04_silver_design/08_SILVER_테이블DDL_20260714.sql line 466
CREATE OR REPLACE TABLE GN_DW.SILVER.ERP_BIZ_TARGET (
    BIZ_TARGET_DK       VARCHAR         NOT NULL,  -- 사업목표 대체키 (PK)
    TARGET_YEAR         NUMBER(4,0),               -- 목표연도 YYYY
    MONTH_NO            NUMBER(2,0),               -- 월 1~12
    MONTH_KEY           VARCHAR(6),                -- 월키 YYYYMM
    ORG_NM              VARCHAR,                   -- 조직 (이름)
    SPONSOR_BIZ_NM      VARCHAR,                   -- 후원사업
    CAMPAIGN_NM         VARCHAR,                   -- 캠페인 (nullable)
    TARGET_AMT          NUMBER(38,0),              -- 목표 금액 원단위
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL,
    DW_SOURCE_TABLE     VARCHAR,
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL,
    DW_UPDATE_TS        TIMESTAMP_NTZ,
    DW_BATCH_ID         VARCHAR,
    PRIMARY KEY (BIZ_TARGET_DK)
);
```

---

_Co-authored with CoCo_

<!-- LLM-METADATA
doc_id: INTAKE_REQUEST_ERP_BIZ_TARGET
doc_role: 데이터 입고 요청서 — ERP 사업목표(FTG-B) 원천
project: GN_DW (굿네이버스)
created: 2026-07-15
blocker_ref: E-6 (40_입고대기_원천의존.md)
END-METADATA -->

# 데이터 입고 요청서 — ERP 사업목표 (FTG-B)

| 항목 | 내용 |
|------|------|
| **요청일** | 2026-07-15 |
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

---

## 2. 필요 데이터 스펙

### 2-1. 필수 컬럼

| # | 컬럼명(안) | 데이터 타입 | 설명 | 필수 |
|---|---|---|---|---|
| 1 | TARGET_YEAR | NUMBER(4) | 목표연도 (YYYY) | ✅ |
| 2 | MONTH_NO | NUMBER(2) | 월 (1~12). 연간 총량만 있으면 NULL 허용 | ✅ |
| 3 | ORG_NM | VARCHAR | 조직명 (부서/팀) | ✅ |
| 4 | SPONSOR_BIZ_NM | VARCHAR | 후원사업명 | ✅ |
| 5 | CAMPAIGN_NM | VARCHAR | 캠페인명 (연결키 부재 시 NULL 가능) | ◐ |
| 6 | TARGET_AMT | NUMBER | 목표 금액 (원 단위) | ✅ |

### 2-2. Grain (행 1건의 의미)

```
월 × 조직 × 후원사업 [× 캠페인(선택)]
```

- **최소 grain**: 월 × 조직 × 후원사업
- **이상적 grain**: 월 × 조직 × 후원사업 × 캠페인 (캠페인 ROI 산출 가능)

### 2-3. 기간 범위

| 구분 | 요건 |
|------|------|
| 필수 | 2025년 ~ 현재 |
| 희망 | 과거 3개년 (비교 분석용) |

### 2-4. 목표 유형

- 연사업 목표 (당초)
- 추경 목표 (수정)
- 누계 목표 (있다면)

> 위 유형이 **행 분리**(목표유형 컬럼)인지 **컬럼 분리**인지는 원천 형태에 따라 조정 가능.

---

## 3. 제공 가능 형태 (택1)

| 형태 | 비고 |
|------|------|
| **Excel/CSV 파일** | DW팀이 BRONZE로 적재 |
| **ERP 리포트/쿼리** | DW팀이 커넥터로 자동 적재 |
| **기존 시스템 화면 캡처 + 설명** | 구조 파악 후 추출 방안 협의 |

---

## 4. 입고 후 활용 계획

```
[BRONZE] 사업목표 원천 (신규)
    ↓ 정제
[SILVER] ERP_BIZ_TARGET (스키마 준비 완료)
    ↓ 변환
[GOLD]   FTG-B (사업목표 달성률 = 실적/목표)
    ↓
[SEMANTIC VIEW / 대시보드] 사업목표 vs 실적 비교
```

---

## 5. 요청 사항 정리

1. **사업목표 데이터의 원천이 무엇인지** 확인 부탁드립니다 (ERP 내 별도 모듈? 사업계획서 Excel?)
2. **제공 가능 형태와 주기** 확인 (일회성 vs 월/분기 갱신)
3. **컬럼 매핑 검토** — 위 §2 스펙과 실제 원천 간 차이 피드백
4. **제공 가능 일정** 회신

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

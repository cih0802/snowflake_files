# GN_DW dbt 프로젝트 이전 가이드

> 본 dbt 프로젝트를 다른 Snowflake 계정/환경으로 옮겨 작업을 이어가기 위한 가이드.

---

## 1. 이동 대상 파일 (필수)

| 폴더/파일 | 역할 |
|-----------|------|
| `dbt_project.yml` | 프로젝트 설정 (이름, 버전, 모델 경로 등) |
| `models/` | SQL 모델 + schema YAML (Silver CRM 21 + GA4 5) |
| `macros/` | 커스텀 매크로 (ga4_union_shards 등) |
| `seeds/` | 코드 마스터 CSV 등 정적 데이터 |
| `tests/` | 커스텀 테스트 |
| `packages.yml` | 외부 패키지 목록 (C-2 방식이라 비어 있을 수 있음) |

## 2. 이동 불필요 (환경별 재생성)

| 폴더/파일 | 이유 |
|-----------|------|
| `profiles.yml` | 계정·인증 정보가 환경마다 다름 → 대상에서 새로 작성 |
| `target/` | 빌드 산출물 (dbt run 시 자동 재생성) |
| `logs/` | 실행 로그 (재생성됨) |
| `dbt_packages/` | `dbt deps`로 재설치 |

## 3. 이동 방법

### 방법 A: Git (권장)
```bash
# 워크스페이스에서
cd 10_dbt_pipeline
git init && git add . && git commit -m "initial dbt project"
git remote add origin <your-repo-url>
git push -u origin main

# 대상 환경에서
git clone <your-repo-url>
```

### 방법 B: 파일 다운로드/업로드
1. 워크스페이스에서 `10_dbt_pipeline/` 폴더를 다운로드
2. 대상 Snowsight 워크스페이스에 업로드 또는 로컬 환경에 배치

### 방법 C: Snowflake Stage 경유
```sql
-- 원본 계정
PUT file:///workspace/10_dbt_pipeline/* @SANDBOX.TOOLS.BRONZE_RAW/dbt_backup/;

-- 대상 계정 (Stage 공유 또는 파일 전송 후)
GET @MY_STAGE/dbt_backup/ file:///tmp/dbt_project/;
```

## 4. 대상 환경 설정 체크리스트

### 4-1. profiles.yml 작성 (대상 계정용)

**Snowsight 워크스페이스 내**: 자동 생성됨 — 별도 작성 불필요.

**로컬 또는 외부 환경**:
```yaml
gn_dw:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: "<대상_계정_locator>"
      user: "<사용자>"
      role: GN_DW_ENGINEER
      database: GN_DW
      warehouse: GN_DW_ETL_WH
      schema: SILVER
      threads: 4
      # 인증: authenticator 또는 password (환경에 따라)
```

> ⚠️ Snowsight 워크스페이스에서는 `password`/`authenticator` 필드 불필요 (세션 인증 사용).

### 4-2. Snowflake 객체 존재 확인

대상 계정에 아래가 존재해야 `dbt run` 성공:

```sql
-- 필수 스키마
SHOW SCHEMAS IN DATABASE GN_DW;
-- 확인: BRONZE_CRM, BRONZE_GA4, SILVER, GOLD

-- Bronze 테이블 (source)
SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'BRONZE_CRM';
-- 기대: 41개 (정기+일시+공통)

-- Silver DDL (빈 테이블)
-- 미생성 시: 04_silver_design/SILVER_DDL_20260702.sql 실행
```

### 4-3. Role·권한

```sql
-- dbt_setting.sql 실행 (10_dbt_pipeline/dbt_setting.sql)
-- GN_DW_ENGINEER에 Bronze SELECT + Silver DDL + Gold DML 부여
```

### 4-4. dbt 실행 확인

```bash
dbt debug          # 접속 테스트
dbt deps           # 패키지 설치 (있을 경우)
dbt run --select silver.crm   # CRM Silver 모델 실행
```

## 5. 환경별 차이 주의사항

| 항목 | Snowsight 워크스페이스 | 로컬 (dbt-core) | dbt Cloud |
|------|------------------------|-----------------|-----------|
| profiles.yml | 자동 생성 | 수동 작성 (~/.dbt/) | UI 설정 |
| 인증 | 세션 토큰 (자동) | key-pair 또는 password | SSO/password |
| env_var() | ❌ 사용 불가 | ✅ 사용 가능 | ✅ 사용 가능 |
| 외부 패키지 | ❌ EAI 불가 (Trial) | ✅ 자유 | ✅ 자유 |
| dbt 버전 | 워크스페이스 내장 | 설치 버전 | Cloud 버전 |

## 6. 주의사항

- **DB/스키마 하드코딩**: 모델에 `GN_DW.SILVER.` 등 직접 참조가 있으면 대상 계정 DB명에 맞게 수정
- **매크로 내 계정 종속**: `ga4_union_shards` 매크로의 테이블 패턴이 계정별 다를 수 있음
- **SELECT * 금지**: GA4 모델은 반드시 명시적 30컬럼 나열 (GOLD 계약 오염 방지)
- **Trial 계정 제약**: External Access Integration 불가 → 외부 패키지(dbt-utils 등) 설치 안 됨, 커스텀 매크로로 대체

---

## 7. 폴더 구조 (현재)

```
10_dbt_pipeline/
├── dbt_setting.sql          # Snowflake 권한 세팅 SQL
├── MIGRATION_GUIDE.md       # ← 본 문서
├── models/
│   └── silver/
│       ├── crm/             # CRM 21 테이블 모델
│       └── ga4/             # GA4 5 테이블 모델
├── macros/                  # 커스텀 매크로
├── seeds/                   # 정적 데이터 (코드 마스터 등)
└── tests/                   # 커스텀 테스트
```

> dbt_project.yml, packages.yml 등은 프로젝트 초기화(dbt init) 시 생성 예정.

---

*작성: 2026-07-03*

# Excel_to_Table.ipynb 해설

이 노트북은 **GN_DW_POC** 데이터 웨어하우스에 Excel 파일을 적재하는 ETL 파이프라인입니다.

---

## 초기 적재 (최초 실행)

| 순서 | 셀 제목 | 역할 |
|------|---------|------|
| 1 | **Setup: DB, Schema, Stage** | `GN_DW_POC` DB, `RAW`/`ANALYTICS` 스키마, 스테이지 생성 |
| 2 | **pip install** | openpyxl (Excel 파서) 오프라인 설치 |
| 3 | **Python Setup & Utilities** | 세션 연결, 스테이지에서 파일 다운로드·타입변환·테이블 적재 유틸 함수 정의 |
| 4 | **Phase 1-A: DIM tables** | 캠페인코드(`DIM_CAMPAIGN_CODE`), 회원특성(`DIM_MEMBER_ATTRIBUTE`) 마스터 테이블 적재 |
| 5 | **Phase 1-B: FACT_MEMBER_DEV** | 회원개발이력 전체(`FACT_MEMBER_DEV_ALL`) + 신규/증액/재후원만(`FACT_MEMBER_DEV_NEW`) |
| 6 | **Phase 2-A: DRTV** | TV광고 월별실적(`FACT_DRTV_MONTHLY_DEV`) + 편성효율(`FACT_DRTV_BROADCAST_EFF`) |
| 7 | **Phase 2-B: Digital** | 디지털광고 월별실적(`FACT_DIGITAL_MONTHLY_DEV`) + 상세(`FACT_DIGITAL_AD_DETAIL`) |
| 8 | **Phase 2-C: Retransmit** | 재송출 월별실적 + 전환현황 |
| 9 | **Phase 3-A: Member** | 중단회원목록(`FACT_DISCONTINUED_MEMBER`) + 마케팅발송(`FACT_MARKETING_SEND_NEW`) |
| 10 | **Phase 3-B: SMS/Alimtalk** | 문자/알림톡 발송이력 13개 파일 → 하나의 테이블로 APPEND |
| 11 | **Phase 4: GA data** | Google Analytics 방문수 5개 시트 → 각각 테이블 |
| 12 | **Verify RAW tables** | RAW 스키마 테이블/건수 확인 |
| 13~24 | **ANALYTICS Views ①~⑩** | RAW 테이블을 조인/집계한 분석용 뷰 13개 생성 (회원개발현황, 예산효율, 매체효율, 전환회원, LTV, 중단보고 등) |

---

## 1차 재적재 (2026-04-08)

새 엑셀 파일로 `FACT_MEMBER_DEV_ALL`, `FACT_MEMBER_DEV_NEW`, `DIM_CAMPAIGN_CODE` 교체 + 신규 조직도 테이블(`DIM_ORG_CODE`) 추가

---

## 2차 재적재 (2026-04-15)

| 단계 | 내용 |
|------|------|
| Phase 1 (교체) | 캠페인코드·회원개발이력·회원특성을 새 파일로 DROP→재생성 |
| Phase 2 (추가) | 26년 DRTV/디지털/재송출/중단회원 데이터 APPEND |
| Phase 3 (신규) | 납입이력 15개월(`FACT_PAYMENT_HISTORY`), 일시→정기 매칭(`DIM_TEMP_TO_REGULAR_MATCH`), 일시회원 후원이력, 구글/메타 광고 4개 테이블 신규 생성 |
| Views 수정 | 컬럼명 변경에 맞춰 ANALYTICS 뷰 12개 재생성 (ROI, 전환분석, 유지율 등 추가) |

---

## 3차 재적재 (2026-04-21)

기존 26년 디지털 데이터(`연도='2026'`) DELETE 후 교체 파일로 재적재

---

## 요약

스테이지에 업로드된 Excel → pandas로 파싱 → Snowpark DataFrame으로 RAW 테이블 적재 → ANALYTICS 뷰로 분석 레이어 구성하는 전체 흐름이며, 이후 데이터 변경 시 교체/추가/신규 패턴으로 증분 관리합니다.

---

## 개선할 점 (비판적 리뷰)

### 1. 구조·유지보수성

| 문제 | 설명 |
|------|------|
| **단일 노트북에 모든 이력 누적** | 초기 적재 + 3차례 재적재가 하나의 파일에 순차적으로 쌓여 있어, 어느 셀까지 실행해야 현재 상태가 되는지 파악이 어려움. 재적재 단위로 별도 노트북 혹은 스크립트로 분리하는 것이 바람직함. |
| **유틸 함수 중복 정의** | `cs()`, `clean_dates()`, `download_from_stage()` 등이 재적재 섹션마다 다시 정의됨. 공통 모듈(`.py`)로 분리해 import하면 불일치 위험 제거 가능. |
| **하드코딩된 컬럼명** | 모든 컬럼명이 리터럴 리스트로 작성되어, Excel 헤더가 바뀌면 전체 노트북을 수작업 수정해야 함. 매핑 설정을 YAML/JSON으로 외부화하면 관리가 용이. |

### 2. 데이터 품질·안전성

| 문제 | 설명 |
|------|------|
| **DROP TABLE 후 재생성** | 교체 시 `DROP → CREATE → INSERT` 패턴을 사용해 적재 중 실패하면 기존 데이터가 소실됨. `CREATE OR REPLACE TABLE ... AS SELECT`나 SWAP 패턴, 또는 트랜잭션 제어를 사용해야 안전. |
| **데이터 검증 부재** | 적재 후 행 수(COUNT)만 확인하고, 컬럼별 NULL 비율·이상값·중복 키 검증이 없음. 적재 직후 assertion 체크가 필요. |
| **날짜 처리 일관성 없음** | 일부 테이블은 `NUMBER(YYYYMMDD)`, 일부는 `VARCHAR(YYYY-MM-DD HH:MI:SS)`, 일부는 pandas datetime으로 혼재. 날짜 컬럼 타입을 `DATE` 또는 `TIMESTAMP`로 통일해야 조인·필터 시 TRY_TO_DATE 변환 불필요. |
| **스키마 진화 관리 없음** | 2차 재적재에서 `FACT_MEMBER_DEV_ALL` 컬럼이 완전히 변경되었으나, 이전 뷰가 즉시 깨짐. 스키마 버전 관리나 마이그레이션 전략이 필요. |

### 3. 성능

| 문제 | 설명 |
|------|------|
| **pandas 단건 적재** | 수십만 행을 `session.create_dataframe(df)`로 적재하면 로컬 메모리 → Snowpark 직렬화 병목 발생. 대용량 시 Parquet로 스테이지 업로드 후 `COPY INTO`가 훨씬 빠름. |
| **SMS 13개 파일 순차 처리** | 반복문에서 파일별 `write.mode('append')`를 호출해 13번 커밋. concat 후 한 번에 적재하거나 Snowflake COPY를 사용하면 오버헤드 감소. |
| **임시 파일 미정리** | `tempfile.mkdtemp()`로 생성한 디렉토리를 정리하지 않아 노트북 반복 실행 시 디스크 누적. |

### 4. 운영·거버넌스

| 문제 | 설명 |
|------|------|
| **ACCOUNTADMIN 직접 사용** | 모든 작업이 ACCOUNTADMIN으로 실행됨. 최소 권한 원칙에 따라 전용 ETL 역할(Role)을 생성해 사용해야 함. |
| **멱등성 미보장** | 같은 셀을 두 번 실행하면 데이터가 중복 적재됨(APPEND 패턴). MERGE나 DELETE+INSERT 패턴으로 멱등성을 확보해야 함. |
| **로깅·감사 없음** | 적재 일시·건수·성공여부를 메타데이터 테이블에 기록하지 않아, 과거 적재 이력 추적 불가. |
| **테스트 환경 분리 없음** | POC라는 이름이지만, 개발/운영 환경 구분이 없어 실수로 운영 데이터를 덮어쓸 위험. |

### 5. 뷰 설계

| 문제 | 설명 |
|------|------|
| **TRY_TO_NUMBER/TRY_TO_DATE 남발** | RAW 테이블에 타입이 제대로 지정되지 않아 뷰에서 매번 형변환. 적재 시점에 올바른 타입으로 넣으면 뷰가 단순해지고 성능도 향상. |
| **뷰 간 의존성 미문서화** | `V_CHANNEL_ROI`가 `V_MEDIA_EFFICIENCY_DETAIL`을 참조하는 등 뷰 체인이 존재하나 의존관계 다이어그램이 없음. |
| **UNION ALL 패턴 반복** | 매체별(DRTV/디지털/재송출) 동일 구조를 UNION ALL로 합치는 패턴이 4개 뷰에서 반복. 공통 스테이징 테이블로 통합하면 유지보수 비용 절감. |

### 6. 권장 개선 방향

1. **dbt 프로젝트로 전환** — 모델 의존성 관리, 테스트, 문서화를 체계적으로 수행
2. **COPY INTO 기반 적재** — Excel → Parquet 변환 후 스테이지 적재로 성능·안정성 확보
3. **Snowflake Task/Stream 활용** — 수동 노트북 실행 대신 스케줄 기반 자동화
4. **데이터 계약(Data Contract)** — 소스 Excel 컬럼 스펙을 YAML로 정의하고, 적재 전 스키마 검증 수행

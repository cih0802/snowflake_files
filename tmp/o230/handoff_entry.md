### ▣ O230-A-0 🔴 먼저 알아라

- 개발계 = jw08094 · 2026-10-15 · 운영계 반영은 사용자가 이 세션 중 1차 완료(VERSION$5 · SV_AD · 코퍼스) — **VERSION$6 · #31 정정은 운영계 미확인**.
- 라이브(jw08094) = AGENT_MARKETING·AGENT_EXECUTIVE default **VERSION$6**(롤백 $5 · $4 = O228) · SV_AD 재배포 2회 · BIZ_DEFINITION_CORPUS 2,154행 · SEARCH_BIZ_DEFINITION REFRESH.
- 백로그 정본 = `12_agent개선과제/20_O21X_잔여작업_정리.md` #29·#30·#31.
- 🔴 `ALTER AGENT ... SET DEFAULT_VERSION = LAST` 는 001003 구문 오류 — `ADD VERSION` 만으로 새 버전이 default 가 된다(확인은 SHOW VERSIONS).

### ▣ O230-A-1 이번 단위 결과

| 순 | 결과 |
|---|---|
| ① 광고 0원 | 미매핑 248.9억(재방송 164.8억 100% · 영상 63.6억 · 디지털 20.5억) → SV_AD 규칙(3)·마케팅캠페인 COMMENT · MKT/EXEC 지침 「연결분 + 원천 방송명·소재명 분해 = 총액」 · 스모크 55,634,974,852.52 = FAP |
| ② ERP 캠페인축 | MKT·EXEC analyst_expense_resolution 설명에 세부캠페인코드·마케팅캠페인명 · RT-15 시정 (#30 닫힘) |
| ③ 사전 대조 | RT 28조항 참조 불일치 0 · 문구 오류 4 정정(RT-21 초수·캠페인유형·연 편성예산 · RT-24) (#31) |
| ④ 사전 밖 stale | MKT 초수 미노출 · BRONZE_BIGQUERY · analyst_budget 연 편성예산 · MKT/EXEC 「2026 연사업」 · SV_AD DURATION_SEC COMMENT(30·60·90·120 · VIDEO 전용) → VERSION$6 |
| ⑤ 시정안 판정 | 방송명 키워드 매핑 = 부적합(방송명 1 → 마케팅캠페인 6~23 · 재방송 원천 코드 0/2,190) · Pre-aggregation = 해당 없음 |
| ⑥ 운영계 SV 오류 | `invalid identifier MKTG.BIZ_CASE_TYPE` = 운영계 DIM_MARKETING_CAMPAIGN 에 O225-C 5컬럼 부재 → 소유자 롤 ADD COLUMN → dbt build → SV 재실행 안내 |
| ⑦ LTV 진단 | 현행 유지개월 = 중단자만 평균(24개월 코호트 4~8개월) · KM 24개월 상한 14~22개월 · 전체 이력 KM 36개월 상한 28.0 · 60개월 상한 41.2 |

### ▣ O230-A-2 ㉠ 이 작업의 잔여

| 순 | 작업 | 출처 | 판정 |
|---|---|---|---|
| ① | BRONZE_BIGQUERY 문구 환경 중립화 — 운영계에는 BRONZE_BIGQUERY 가 있고 프로시저로 SILVER.BIGQUERY_REFINED_DATA 에 정제 · dbt·SV 는 SILVER 부터 ⇒ RT-24 · MKT analyst_ad 설명의 「테이블이 없다」를 「광고 SV 의 직접 원천이 아니다(프로시저 정제 → SILVER)」로 → 코퍼스 재적재·REFRESH · Agent VERSION$7 | 사용자 O230 | 라이브 대조 |
| ② | LTV 생존분석 **기본값 구현**(사용자 결정 = 기본값 먼저 · 피드백 후 설정 수정) — 전체 이력 · 상한 36·60개월 두 지표 · 최초 중단 기준 · 셀 최소 500명 · 상한·학습기간 = dbt 변수 · 「잠정 정의」 표기 · 개발계만 | 사용자 O230 | 비교표 |
| ②-a | FACT_MEMBER_COHORT 에 관측 유지기간(일·개월)·중단 여부(0 = 관측 중) 추가 — 기준일 재계산 · ACQ_DATE 1900-01-01 센티널 제외 · 운영계는 소유자 롤 선반영 | ② | 👤 build |
| ②-b | GOLD 생존 집계 뷰(분류 축 × 경과월 × 위험 회원수 × 중단수 × 생존율) — 축 = 획득 후 경과월(달력월 아님) | ② | 실측 대조(전체 28.0 / 41.2) |
| ②-c | SV_MEMBER_COHORT 지표 = 기대 유지개월(36·60) · N개월 생존율 · 관측 회원수 · AVG_TENURE_DAYS 는 「중단자 평균」으로 명확화(LTV 미사용) | ② | 스모크 |
| ②-d | 현업 비교표(인입경로·캠페인카테고리별 현행 vs 36 vs 60 유지개월·LTV · 「1,000명 예산」 예시) | ② | 👤 현업 회신 |
| ②-e | 확정 후 RT-14·RT-27 · Agent LTV 지침 교체 · 운영계 반영 | ②-d | 회신 반영 |
| ③ | 런북 §7 에 「SV 배포 전 dbt build + 소유자 롤 컬럼 선반영」 순서 명시(O225-C 5컬럼 · IS_PARENT_CAMPAIGN_YN 사례) | O230 ⑥ | 문서 |
| ④ | 👤 운영계 반영 확인 = VERSION$6 · SV_AD 2차 · #31 · SV_EXPENSE_RESOLUTION 두 축 존재 | O230 | 운영계 |
| ⑤ | 👤 현업 = 방송명 ↔ 마케팅캠페인 매핑표·배분 규칙(#29) · 문서20 N-30 회신(O226-A ⑥ 승계) | #29 | 회신 반영 |

### ▣ O230-A-3 🟡 ㉡ 워크스페이스 백로그

- `20_O21X` 열림 = #12(eval 운영계) · #29(현업 매핑표·운영계) · #8 결정 · #15·#16 현업 · #9·#13 운영계보류.
- 이번 세션 변경은 Agent 실질문 스모크를 하지 않았다(eval = 운영계 결정).

### ▣ O230-A-4 ⚪ 결정 완료(재론 금지)

- 이중계상 방지를 이유로 원천 금액을 0 으로 만들지 않는다 — 미연결분은 원천 축으로 분해해 총액을 맞춘다(사용자 O230).
- 광고 마케팅캠페인 텍스트 키워드 매핑은 하지 않는다(현업 매핑표 전까지) · 사전 집계 안은 해당 없음.
- 현업 제공 정의(90_provided_definition)는 고치지 않는다(R2-8) · 사전 정정 대상 = 큐레이션 RT 조항.
- LTV = 기본값 먼저 구현 → 현업 피드백으로 설정 수정 · 생존분석 축 = 획득 후 경과월 · 회원별 값 = 관측 유지기간 + 중단 여부(회원 개인 기대 유지는 산출하지 않는다).
- eval = 운영계 · O229-B-4 결정 전건 유지.

_Co-authored with CoCo_

### ▣ O258-A-0 🔴 먼저 알아라

- `O258-A` = dbt 모델·yml 의 원천 라벨 하드코딩 제거 (2026-10-22 · TRIALADMIN(SR61467) · ㉡ · 사용자 지시·결정 · 확정위반 2 = R1-7-2 같은 파일 병렬 edit 2회 · 유실 0 실증).
- 직전 단위 = `99_NEXT_SESSION-O0256-B.md` (그 ②~⑤ 는 그대로 유효 · 아래 ㉡ 로 승계).
- O257 = 원장 정의 0 · 첨부된 미기록 세션(SV_MBRFEE DATA_TYPE_STD)으로 추정 · 이 단위가 그 다음 처방을 이어받았다.
- 근거 정본 = `tmp/o258/evidence.md`(E1~E8 · 판정 전 기록) · 추출기 = `tmp/o258/extract_*.py`.

### ▣ O258-A-1 결과

| 항목 | 결과 |
|---|---|
| 조사 | dbt 리터럴 131행 · SV 서술형 324종 798회 · SV 필터형 16 · Agent 22 · accepted_values 112 (BRONZE 대조 · 개발계 GOLD 83 중 1 만 데이터) |
| 처방 | seed 4(MAP_BUDGET_PROCEDURE · MAP_SPONSORSHIP_GROUP4 · MAP_EXT_DATA_TYPE · MAP_SERVICE_GROUP_RULE) · gn_code 키 6 · 매크로 gn_cpr_token_match · 모델 8 · yml 5곳 → seed relationships · warn 테스트 3 |
| 동작 변경 | ① 법인 판정 = CM019 토큰 정확일치(종전 LIKE 순서가 `통합…_사단` 2종을 통합으로 오분류 · 개발계 발송 0건) ② 표기 `추경` 순번 0→2(현재 0행) ③ CM003 `선물금`→기타(사용자 결정 · 사용 0) |
| seed 권한 | GN_DW_DBT 는 SILVER·GOLD CREATE TABLE 없음 = 설계 ⇒ 권한 추가 없이 ADMIN DDL 선생성(`38_DEPLOY_MAP_SEEDS.sql` [D1] 개발계 실행) · 07 [1-f] · 08 [2-a] · 문서실행순서 33 |
| 검증 | 👤 build PASS=721 WARN=23 ERROR=0 · seed 3/7/6/11 · F 746,103 = 종전 · 개발목표 576행 신구 차이 0 · 회비예측 528 동일 · 커버리지 미매핑 0 |

### ▣ O258-A-2 ㉠ 잔여(이 작업)

| 순 | 작업 | 판정 |
|---|---|---|
| ① | 운영계 = 문서실행순서 「기존 환경 갱신」 33(`38_DEPLOY_MAP_SEEDS.sql` [D1] ADMIN → 👤 dbt 재배포·seed·build → [D3]) · 🔴 [D1] 없이 seed 하면 003001 · SV 재배포 불요 | 👤 운영계 |
| ② | SV COMMENT 「실제값 N종」 열거(조직트리·지역·성별 등) 라이브 대조 — 개발계 build 완료 ⇒ 이제 측정 가능 · 미착수 | 다음 세션 |
| ③ | 문서50 등재(라벨 매핑 seed 운영 규칙 · 남은 리터럴 92 성격) — 증분형 `--rollover` 는 R4-4-3 승인 대상이라 이번에 하지 않음 | 승인 후 |

- 🔴 원천 라벨이 바뀌면 **모델을 고치지 말고** `10_dbt_pipeline/seeds/MAP_*.csv` 에 행을 더한 뒤 `dbt seed` · 경고 = `tests/warn_map_coverage_*.sql`.
- 🔴 새 seed 를 추가하면 **테이블 DDL 을 먼저**(SILVER = `04_silver_design/08` 끝 · GOLD = `03_top-down_gold/06_DDL`) — GN_DW_DBT 에 CREATE TABLE 을 주지 마라(07 §D.9 [1-f]).
- 🔴 코드 목록(MS054 · 행사구분 · CM019 A/I/S)은 `macros/gn_biz_codes.sql` `gn_code` 가 정본이다.

### ▣ O258-A-3 ㉡ 워크스페이스 백로그

- O256-B-2 ②~⑤ 그대로 승계(운영계 05_10 · 현업 안내문 v3 회신 · DEC-63-E/D · 운영계 29→30→31→32).
- 🟠 `jinja_config_gate` 축5 경고 1 = `FACT_MEMBER_COHORT_SURVIVAL.sql:28`(O258 무관 · 기존).

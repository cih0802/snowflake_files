# O261 evidence — 개발계 UM80684 실측 (판정 전 원문 기록 · R1-3-7-c)

## E1 요건3 (42_DEPLOY_AGENCY_AD_SRC_RENAME.sql) · UM80684 · 2026-10-23 19:26 PDT

원문 = `tmp/o261/req3.out` (생성 = `tmp/o261/measure_req3.py` · rc=0)

| 단계 | 결과 |
|---|---|
| D0 BRONZE 컬럼 | REBRDC_AD_CMPGN_DTLS.MKTG_CMPGN_NM(17) · VIDEO_AD_CMPGN_DTLS.UPPER_CMPGN_CD(19) · 구 이름 0행 |
| D1 SILVER 컬럼 | AGENCY_AD_ROW_REBRDC.MKTG_CMPGN_NM · AGENCY_AD_ROW_VIDEO.UPPER_CMPGN_CD — 08 DDL 이 이미 새 이름 ⇒ D1 건너뜀 |
| D0-b 채움 | VIDEO.UPPER_CMPGN_CD 47,838행 중 6,801 채움 · 고유 43 |
| D0-b 채움 | REBRDC.MKTG_CMPGN_NM 2,190행 중 286 채움 · 고유 26 |
| D0-c 이름 일치 | REBRDC 채움 286 중 DIM_MARKETING_CAMPAIGN 이름 일치 286 (100%) |
| D2-① 소스별 | DIGITAL 224,242행 · 32,305,953,021.9033 |
| D2-① 소스별 | REBROADCAST 2,190행 · 16,478,186,571.3314 |
| D2-① 소스별 | VIDEO 47,673행 · 6,590,884,384.0000 |
| D2-② 매핑 경로 | REBROADCAST NONE 381 · UPPER_CODE 1,809 |
| D2-② 매핑 경로 | VIDEO CREATIVE_MAP 34,303 · NAME 2,474 · NONE 10,510 · UPPER_CODE 386 |
| D2-③ 고아 | 0 |

- 대조: 문서실행순서 [O245] 기대값 = 재방송 `MKTG_MAP_METHOD='UPPER_CODE'` 1,809행 ⇒ 일치.
- 관측: VIDEO BRONZE 47,838 ↔ SILVER 47,673 (차 165).
  - 실측(UM80684): BRONZE 47,838 · AGENCY_AD_ROW_VIDEO 47,673 · AGENCY_AD_PERFORMANCE(VIDEO) 47,673.
  - 차이는 staging 단계 `AGENCY_AD_ROW_VIDEO.sql:77` `WHERE NOT IS_ALL_NULL_ROW` 에서 생긴다 · staging↔코어 1:1.
- 사용자 결정 ②㉠ 근거: REBRDC 마케팅캠페인명은 채움 13.1%(286/2,190)이고 채운 행은 100% DIM 이름과 일치.

## E2 O259 반영 확인 · UM80684 · 2026-10-23 PDT

- 39 [D3]: CLEAN 1,314 · CLEAN_ACTIVE 223 · SUCC 1,314 · PICKER 223 · PICKER_RETIRED 0 ⇒ 파일 기대값(1,314 · 1,314 · 223 · 0)과 일치.
- `scripts/sv_no_rollup_gate.py` rc=0 · 「🟢 PASS — 소계/합계 행 유도 0건 · 분모 35 파일」(`tmp/o261/rollup_gate.out`).
- 라이브 SV GET_DDL 스캔(`tmp/o261/live_rollup_scan.py`): SV 44종.
  - 1차(단순 토큰): 37종 적중 — 문맥(`tmp/o261/rollup_ctx.out`) = 「ROLLUP·CUBE·GROUPING SETS 금지 · 평면 GROUP BY 만」 O259 금지 문구.
  - 2차(금지 문구 제외 · J8): 적중 0 (`tmp/o261/live_rollup.out`).

## E3 SV COMMENT 「실제값 N종」 라이브 대조 · UM80684 · 2026-10-23 PDT

- 도구 = `tmp/o261/enum_check.py`(DESCRIBE SEMANTIC VIEW → base 컬럼 COUNT(DISTINCT)) · 결과 = `tmp/o261/enum_check.csv`.
- 결과(`tmp/o261/enum_check.out`): 대상 139 · OK 137 · MISMATCH 2.
- ① SV_GA_BEHAVIOR `src.DEFAULT_CHANNEL_GROUP` COMMENT 15종 ↔ 라이브 0.
  - `GOLD.DIM_BIGQUERY_SOURCE` 1행(센티넬) · DEFAULT_CHANNEL_GROUP 채움 0.
  - GA4 체인 행수: SILVER.BIGQUERY_REFINED_DATA 10,616,656 · BIGQUERY_BASIC 0 · BIGQUERY_SESSION 0 · FACT_BIGQUERY_BEHAVIOR 0 · FACT_BIGQUERY_SESSION 0.
  - 원천 EVENT_DATE = 20240122 ~ 20261005 · 34일 · `dbt_project.yml:94` `bigquery_lookback_days: 3`.
  - ⇒ COMMENT 문제가 아니라 **GA4 하류 미적재**다. 롤링 창(오늘-3일)에 원천이 없어 build 가 SUCCESS · 0행(02_dbt Step 3-3 O178 유형).
  - 처방 = 👤 범위 지정 build(`02_dbt_parse_compile_build.sql:39` · R2-9 개발계 예외 = 백필 필요).
- ② SV_MEMBER_SPONSOR_BIZ `org_succ.MAP_METHOD` COMMENT 8종 ↔ 라이브 6.
  - 라이브 = SELF 223 · AUTO_ORG_PARENT 222 · AUTO_ACMSLT_PARENT 135 · AUTO_NAME 109 · AUTO_MEMBER_FLOW 72 · UNMAPPED 553.
  - 없는 2종 = MANUAL · MANUAL_UNMAPPED — seed `GOLD.ORG_SUCCESSION_MANUAL` 0행(현업 회신 전)이라 생기지 않는다.
  - ⇒ 값 목록은 정의상 맞고 「실제값 8종」이라는 **표현**이 현재 데이터와 다르다(문안 변경 = 승인 대상).

## E4 후속 (2026-10-24 · UM80684)

- 👤 GA4 범위 build 후: REFINED 10,616,656/34일 · BASIC 10,616,656/34일 · FACT_BEHAVIOR 1,651,036/34일 · FACT_SESSION 1,233,789 ⇒ 일자 수 3자 일치.
- enum_check 재실행(`tmp/o261/enum_check2.out`): 139 · OK 137 · MISMATCH 2.
  - DEFAULT_CHANNEL_GROUP COMMENT 15종 ↔ 라이브 16종(NULL 제외) — 신규 'AI Assistant' 4행 등 · COMMENT 숫자가 낡았다(문안 변경 미승인).
  - MAP_METHOD 8 ↔ 6 (E3 ② 그대로).
- REBRDC CAMPAIGN_NM 승격 사전 실측(build 전 FACT 기준):
  - 현 NONE 381행 중 이름 보유 285 · 현 UPPER_CODE 1,809행 중 이름 보유 1(같은 캠페인) · 다른 캠페인으로 바뀌는 행 0.
  - 기대(build 후) = REBROADCAST NAME 경로 약 285~286행 · UPPER_CODE 1,808~1,809 · NONE 약 95.
- 사용자 결정 = 승격 · 코드 = `AGENCY_AD_PERFORMANCE.sql` REBROADCAST 분기 CAMPAIGN_NM = clean_str(MKTG_CMPGN_NM).
- 👤 build 후 FACT_AD_PERFORMANCE(UM80684): REBROADCAST NAME 286 · UPPER_CODE 1,808 · NONE 96(합 2,190 불변) · VIDEO 4경로 무변경(34,303 · 2,474 · 10,510 · 386) ⇒ 기대값 범위 안.

## E5 SV COMMENT 종 수 폐지 + 신규값 목록 반영 (사용자 승인 · UM80684)

- 스냅샷 = `_archive/<파일>.O261-preenum` 21건(snapshot_cli · 실패 0).
- 도구 = `tmp/o261/enum_rewrite.py`(치환·신규값 삽입) · `tmp/o261/enum_syntax_check.py`(문장 수·따옴표 짝 · BAD 0).
- 치환 = 「실제값 N종」 148건 → 「주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인)」 · 21파일(34_ 9건 포함) · 잔존 0.
- 교정 = SV_AD CM_POSITION 잘린 값 ''st''→''E-1st'' · ''th''→''E-4th''(라이브 실측 · 'st'·'th' 0행).
- 신규값 추가 = GA DEFAULT_CHANNEL_GROUP 6(AI Assistant 등) · FIRST_STOP_REASON 4(지라니 계열).
  - 1차 삽입 위치 오류 1건(경고문 뒤) → 수작업 교정 · 도구 삽입 위치 수정.
- 리터럴 형식 정리 = TARGET_BIZ NEW_OLD_DIV ''신규''·''기존'' · ML_MEMBER_PRED_AXIS INC_CLASS ''0''·''1''.
- 재배포 = 20파일 + 05_03 · 05_11 · 05_29 재실행 · 실패 0(34_ 는 신규 구축 미배포 · 원본만 동기화).
- 검증 = `tmp/o261/enum_newvalue_check.py`(종 수 대조를 대체) · SV 44 · 목록 대조 차원 155 · STALE_COUNT 0 · NEW 0.

## E6 후속 — 게이트 승격 · 열거 보강 · 34 정본 이식 (2026-10-24~25 · UM80684 · 사용자 승인 「검토거리 전부」)

- 게이트 승격 = `scripts/sv_enum_newvalue_gate.py`(JUDGE · rc 0/1/2) + 음성 `test_sv_enum_newvalue_gate.py`(10축 · 변이 구현 3 FAIL 실증) · `session_brief` GATES 편입.
- 🔴 결함 발견(내 O261 치환이 만든 회귀) = `sv_code_label_gate.COLON` 이 「실제…값:」 접두만 열거로 읽었다
  ⇒ 「주요 값(…):」로 바꾼 기존 열거 **109 차원**이 ①「없는 코드값」 검사 밖으로 빠지고 ④「열거 누락」으로 오분류(첫 판 413건 중 109).
  - 처방 = COLON 에 `주요\s*값` 추가 · ITEM 이 `'값'(라벨)` 괄호 주석을 1항으로 소비 · 픽스처 POS6·NEG10 · 구 COLON 변이에서 POS6 미검출 실증.
- 열거 보강 = `tmp/o261/enum_fill.py`(대상 = 첫 판 ④ 401 고유 차원 · 라이브 DISTINCT ≤ 20 · NULL·'' 제외)
  - FILL 253 · 기존 열거 보유(오분류) 146 · 제외 2(따옴표 1 · 범주 아님 `SV_MEMBER_SERVICE_COHORT.CHRG_DEPT_NAMES` 1)
  - 1차 정규식 결함 = COMMENT 없는 항목이 다음 항목 COMMENT 를 삼킴 ⇒ 항목 경계 lookahead 추가 · 소스 백업 = `tmp/o261/pre_fill/`
  - 무결성 = 36파일 문장 수 불변 · 따옴표 짝 0 · 재배포 34파일 0 failed(`tmp/o261/fill_deploy.out` · 35_·36_ 이력 미실행).
  - 개인정보 점검 = FILL 값 전수 패턴 대조(이메일·전화·2~3자 인명형) 0건 · 값은 전부 코드·라벨 범주.
- 🔴 결함 발견 = 신규 구축 순서(1~59)에 `34_`(O246-D 폴백 각주)가 없다 ⇒ 신규 계정은 SV_ML 3종이 22·25 판(각주 없음)으로 남는다(이 계정도 오늘 34 재실행 전까지 그 상태).
  - 처방 = 34 의 차원 COMMENT 12 · MA 테이블 COMMENT 3 · 지시문 4 를 정본 22·25 로 이식 ⇒ 정규화 대조 3 SV 전부 IDENTICAL(`tmp/o261/cmp_34_22c.py`).
- jinja 축5 경고 1 → 0(`FACT_MEMBER_COHORT_SURVIVAL.sql:28` `-#}`→`#}` · 다음 줄이 Jinja 주석 · 출력 무변경).
- 색인 = `handoff_write.py` 밀도 축소(최신 60 전체 열 · 이전 압축 · 여유 예산 20% 자동) · 35,195 → 21,507 B · 212 라벨 전건 · 음성 축10(변이 = 예산 초과 실증).
- `11_O누적작업_점검_재현_절차.md` 폴더 분할 2조각(SHA256 일치 · 유실 0) · census FAMILIES · 줄길이 glob · 골든 재발행.
- 2차 `sv_code_label_gate`(1차 배포 후 · 개정 게이트) = 🔴 1 · 🟠 19 (열거 누락 413 → 19).
  - 🔴 `SV_MEMBER_SPONSOR_BIZ.MAP_METHOD` 열거 ''MANUAL''·''MANUAL_UNMAPPED'' 라이브 0행 = E3 ② 와 같은 것(종전 게이트는 「주요 값」을 못 읽어 안 보였다).
    - 처방 = 목록은 라이브 6값만 · seed 의존 2값은 생성 조건과 「거르기 전에 조회로 확인」을 별 문장으로(Agent 지식 유지 · 0행 오답 경로 차단).
  - 🟠 19 = 기존 열거가 비표준 문안(「값 N종:」 3 · 접두 없음 · 범위 무따옴표 3 · 산문)이라 못 읽힌 것 ⇒ `tmp/o261/adv_normalize.py` 15 치환(13파일) 표준 문안화.
    - 범주 아님 2 = `CHRG_DEPT_NAMES`(부서명 조합) · `ASSUMPTIONS`(설명문 1행 · O261 보강에서 붙인 목록 원복) ⇒ 게이트 `ENUM_SKIP` 등재(사유 주석).
    - 잔여 1 = `SV_EVENT_PARTICIPATION.EVENT_CATEGORY_NAME` — 값을 산문 나열 · 값 1개에 따옴표(`I'm your pen`)가 있어 게이트 ITEM 이 못 읽는다 ⇒ advisory 유지(정보는 COMMENT 에 있음).
- 변형 종 수 표기(「원값 55종」·「실측 값 6종」 등) 18건 제거(`tmp/o261/strip_count2.py` · SQL 주석 줄 제외) · `sv_enum_newvalue_gate.N_PAT` 를 `값\s*N\s*종` 으로 확장 + 음성 2축(구 패턴 변이 FAIL 실증).
- 배포 = 1차 34파일 · 2차 15파일 · 3차 6파일 — 전부 0 failed(`tmp/o261/fill_deploy*.out`).
- 🟢 최종 라이브(UM80684 · 3차 배포 후) = `sv_code_label_gate` 🔴 0 · 🟠 1 · `sv_enum_newvalue_gate` SV 44 · 대조 차원 **422**(1판 155) · STALE 0 · NEW 0 · `sv_no_rollup_gate` PASS(35파일) · `sv_identifier_gate` blocking 0.
- 🟠 백그라운드 게이트 1회가 샌드박스 정지로 9시간 멈췄다(마지막 쿼리 20:30:41 → 재실행) — 판정은 재실행분(`g_*4.out`)이다.

# O262 evidence — O261-B ㉮ 상위캠페인 코드·이름 분리

## E0 [0] 착수 실측 (UM80684 · 2026-10-25 · TRIALADMIN / GN_DW_DBT)

- SQL = `99_NEXT_SESSION-O0261-B.md` [0] 재현 SQL(정렬만 code_shaped DESC 추가)
- 결과 43종(코드형 9 · 이름형 34)

| 형태 | 종 | 행 | 마스터 |
|---|---|---|---|
| 코드형 `^U[0-9]+$` | 9 | 2,715 (921+894+347+221+133+62+59+46+32) | CRM CMPGN_CD 9/9 |
| 이름형 | 34 | 4,086 (인수인계 기재값 · 아래 대사) | CRM 캠페인명 5 · DIM 마케팅캠페인명 7 · 없음 22 |

- 코드형 기간 = 2026-06-01 ~ 2026-10-20 · 이름형 최대 = 2026-05-31
- 오분류 = 0(이름형 34종 전부 code_shaped=FALSE · 코드형 9종 전부 is_cmpgn_cd=TRUE)
- 판정 = 🟢 분리 규칙 유지 · [1] 착수
- 이름형 합계 재측 = 4,086 · 코드형 2,715 · 채움 6,801(2,715+4,086) ✅

## E1 [1] DDL (UM80684 · 2026-10-25)

- 08 DDL 정본 = UPPER_CAMPAIGN_NM COMMENT 정정 + UPPER_CAMPAIGN_CD 맨 끝 열 추가
- `43_DEPLOY_AGENCY_UPPER_CMPGN_SPLIT.sql` 신설([D0]·[D0-b]·[D1]·[D2])
- [D1] 집행 = GN_DW_ADMIN · 사용자 승인(「전부 승인」) · INFORMATION_SCHEMA 확인 = UPPER_CAMPAIGN_CD ordinal 30(TOT_COST 29 다음)

## E2 [2] 사전 대사 (staging 직접 · build 전)

- 새 VIDEO 식을 AGENCY_AD_ROW_VIDEO(코어 VIDEO DK 범위)에 적용 = total 47,673 · CD 2,715 · NM 4,086 · 둘 다 NULL 40,872

## E3 [D0-b] build 전 FACT 매핑 경로 기준값

| AD_SOURCE_TYPE | MKTG_MAP_METHOD | n_rows |
|---|---|---|
| DIGITAL | NAME | 149,908 |
| DIGITAL | NONE | 21,800 |
| DIGITAL | UTM | 52,534 |
| REBROADCAST | NAME | 286 |
| REBROADCAST | NONE | 96 |
| REBROADCAST | UPPER_CODE | 1,808 |
| VIDEO | CREATIVE_MAP | 34,303 |
| VIDEO | NAME | 2,474 |
| VIDEO | NONE | 10,510 |
| VIDEO | UPPER_CODE | 386 |

## E4 [4] 하류 영향

- grep `UPPER_CAMPAIGN_NM` = models·tests·macros·05_SV-Agent_ai · rc=0
- 사용처 = 이 모델·yml·신규 테스트·42_/43_ 배포파일뿐 ⇒ GOLD·SV·Agent 사용 0 · 종단 컬럼 유지
- FACT_AD_PERFORMANCE 는 `select *` CTE 후 명시 열 선택 · AGENCY_AD_DIGITAL 은 AD_PERF_DK 만 ⇒ 영향 0
- 🟠 신규 테스트 `assert_aap_upper_cmpgn_split` 은 build 전 라이브에서는 NM_CODE_SHAPED 2,715 로 FAIL 이 정상(build 후 0 기대)

## E5 ㉰ 착수 실측 — 공통 블록 분포 (소스 · 05_SV-Agent_ai · 2026-10-25)

- 계측 = 시작 표식 `[O241-R 반올림 · 전 SV 공통]` ~ 끝 문장 `전체 값을 따로 COUNT DISTINCT 한다.` (rc=0)
- 정본 1,002자 = 30 건 동일(05_01~05_18 · 05_24 · 05_25 · 05_13×3 · 22_×6 · 34_×2)
- 블록 없음(인수인계 6종 일치) = 05_27 · 05_28 · 05_29 · 05_30 · 23_ · 24_ (+ 배포본 35_ · 36_)
- 🔴 인수인계에 없던 변형 = 시작 표식은 있으나 끝 문장 없음(-1) = 05_19 · 05_20 · 05_21 · 05_22 · 05_23 · 25_ · 22_ 1곳
  - 원문 예(05_19 @9277) = 「…(예: "청구액(원)" · "청구(건)")…답변에 쓸 합계·총계는 반드시 SQL 이 낸다…표 밖 본문 1줄로 적는다.」 — 예시가 SV 별로 다르고 COUNT DISTINCT 문장이 빠짐
- 🔴 길이 변형 = 05_26 553자 · 22_ 1곳 1,010자(인수인계 기재와 일치) · 34_ 1곳 11,751자(끝 문장이 블록 밖 멀리 있음 = 계측상 오탐 후보)
- ⇒ 인수인계 「현재 30개 SV 에 바이트 동일」은 **건수는 맞으나 나머지 SV 가 전부 정본이라는 뜻은 아님** · R-SV1 을 바이트 동일로 두면 변형 8곳 이상이 FAIL
- 판정 = 👤 결정 대기(아래 응답 질문) · ㉰ 집행 보류
  - ⇒ 👤 결정(2026-10-25) = 「변형 SV까지 모두 정본으로 교체하고 재배포」 · E8 집행

## E6 [D2] build 후 대사 (👤 build 1차 완료 · DW_LOAD_TS 2026-10-25 08:22:58)

- SILVER 분리 = VIDEO 47,673행 · CD 2,715 · NM 4,086 · 동시 0 · 형태 위반 0 · DIGITAL·REBROADCAST 채움 0
- FACT 매핑 경로 10행 = E3 기준값과 전부 동일

## E7 GOLD 승격(N-29 ⑥ 보류 해제 · 👤 지시)

- 보류 근거 원문 = `20_issue/20_현업확인_요청_조각/20_현업확인_요청-010.md:261` 「배선 보류(GOLD·SV 미노출)」 · `FACT_AD_PERFORMANCE.sql:128` 「상위캠페인명(코드·이름 혼재)은 보류(문서20 N-29 ⑥)」 · 상위 결정 = `30_설계_의사결정-001.md:61` O15
- 이름 경로 실측 = 이름형 중 DIM 마케팅캠페인명 일치 643행(6종 · 이름 유일) → 전부 이미 NAME 경로 · 다른 캠페인 0 ⇒ 신규 연결 0
- CRM 캠페인명 일치 5종 = CRM 마케팅캠페인명 NULL ⇒ 경로 없음
- 집행 = FACT `UPPER_NAME` 경로 + 맨 끝 2열 · GN_DW_ADMIN ADD COLUMN(ordinal 42·43) · WIDE_AD_COMBINED · yml · 06_DDL · 43_ [D1-b]
- 🟡 👤 2차 build 대기(FACT·WIDE 반영)

## E8 ㉰ SV 공통 블록 집행

- 스냅샷 18건 `_archive/*.O262-o262svblock`(SV 17 + MSTR 1)
- 변환 = 공통 4절 정본 교체 · 변형 문장은 `[공통 규칙 보충 · 이 SV]` 보존 · R-SV3 문장 4곳(05_27·05_30·35_·36_) · 재실행 변경 0
- 배포(UM80684) = deploy_sv.py 05_19~05_30·22_·23_ + MSTR · run_sql_file.py 24_·25_(24_ `$$` 프로시저는 deploy_sv 분할기 미지원)
- 게이트 = sv_common_block_gate 소스 51 · 라이브 44 · 위반 0 · 변환 전 스냅샷 대상 rc=1(위반 24) · 음성 8축 PASS · sv_no_rollup 35 PASS

## E9 카테고리 GOLD 미반영 점검 = `tmp/o262_audit/O262_카테고리_GOLD미반영_점검.md`(96건 · A21·B15·C13·D47)

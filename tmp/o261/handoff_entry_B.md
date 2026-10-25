### ▣ O261-B-0 🔴 먼저 알아라

- `O261-B` = **작업계획만** 남긴 단위다(2026-10-25 · 사용자 지시 「검토하고 실제 작업은 다른 세션에서」) — 이 세션은 코드·DDL·배포를 하지 않았다.
- 직전 단위 = `99_NEXT_SESSION-O0261-A.md` — 그 ⑤(운영계 반영)는 이 계획이 끝난 **뒤에** 한 번에 한다(사용자: 「남은 작업이 운영계 반영만 남으면 운영계에 반영」).
- 작업 3건 = ㉮ 상위캠페인 코드·이름 분리(이 문서 본체) · ㉯ 80 패키지 운영도구 `scripts/` 편입 · ㉰ SV 6종 공통 블록 규칙·적용.
  - ㉯㉰ 는 O261 마지막 계획(사용자 Proceed 전 · 아래 §B-3·§B-4)을 그대로 쓴다.

### ▣ O261-B-1 ㉮ 판정 — `SILVER.AGENCY_AD_PERFORMANCE` 는 dbt 모델이다(수기 적재 아님)

| 층 | 객체 | 근거 |
|---|---|---|
| 원천 | `BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS.UPPER_CMPGN_CD` | `models/silver/agency/AGENCY_AD_ROW_VIDEO.sql:66` `source('bronze_agency', …)` |
| staging | `SILVER.AGENCY_AD_ROW_VIDEO.UPPER_CMPGN_CD`(원천 무손실) | 같은 파일 `:44` |
| 코어 | `SILVER.AGENCY_AD_PERFORMANCE.UPPER_CAMPAIGN_NM` | `AGENCY_AD_PERFORMANCE.sql:175` `clean_str('UPPER_CMPGN_CD')` |
| GOLD | `FACT_AD_PERFORMANCE` — 🔴 코어 컬럼이 아니라 **staging `UPPER_CMPGN_CD` 를 직접** `video_code_mk`(CRM 상위캠페인코드 → 마케팅캠페인)에 조인 | `FACT_AD_PERFORMANCE.sql:79~84 · :203~205` |

- ⇒ 사용자 분기 규칙 「dbt 모델이면 dbt 모델 수정」 적용. 「GOLD 에서 join 해 NM·CD 를 올리는 방식」은 수기 적재일 때의 대안이라 채택하지 않는다.
- 라이브 실측(UM80684 · 2026-10-25 · VIDEO 6,801행 · 43종) — 값이 **혼재**다:

| 기간 | 값 형태 | 종 | 행 | 마스터 대조 |
|---|---|---|---|---|
| 2026-06 ~ | 코드 `U1479`·`U1485` … | 9 | 2,715 | `SILVER.CRM_CAMPAIGN.CMPGN_CD`·`UPPER_CMPGN_CD` 9/9 |
| ~ 2026-05 | 이름 `유어턴링(2기)`·`2025_국내_위기가정_정후`·`TV_위기가정(선아)` … | 34 | 4,086 | CRM 캠페인명 5 · 마케팅캠페인명 7 · 어디에도 없음 22(`TV_` 접두 다수) |

  - 원천 컬럼명은 `_CD` 인데 2026-05 이전 행은 이름이다(원천이 개명 전 값을 그대로 둠 · DIGITAL O171-D 와 같은 「방식 전환 중」 유형).
  - 재현 SQL = 아래 §B-2 [0].

### ▣ O261-B-2 ㉮ 작업계획 — 코어에서 코드·이름 2열로 나누고, GOLD 는 그 2열로 해석한다

🟢 설계 원칙: SILVER 코어는 **형태로만 나누고 CRM 마스터를 조인하지 않는다**. 도메인 간 해석(코드 ↔ 이름)은 이미 CRM 을 조인하는 GOLD `FACT_AD_PERFORMANCE` 에서만 한다(DEC-11 「DK·원천 해석 단일 지점」과 같은 이유 · 코어가 CRM 에 의존하면 build 순서·재적재 범위가 넓어진다).

| 순 | 작업 | 파일 | 정지점 |
|---|---|---|---|
| [0] | 착수 실측 — 위 표 재현. 분리 규칙 `REGEXP_LIKE(v, '^U[0-9]+$')` 이 코드 9종을 전부 잡고 이름 34종을 하나도 안 잡는지(오분류 0) 확인. 형태가 다른 코드가 새로 보이면 규칙을 바꾸기 전에 멈춘다 | evidence `tmp/o261b/evidence.md`(신설) | 오분류 0 |
| [1] | SILVER DDL — `AGENCY_AD_PERFORMANCE` 에 `UPPER_CAMPAIGN_CD VARCHAR` `ADD COLUMN IF NOT EXISTS`(소유자 GN_DW_ADMIN · 🔴 08 SILVER DDL 전체 재실행 금지) · 정본 `04_silver_design/08_SILVER_테이블DDL_20260714.sql` 에 열 추가 + 새 배포순서 파일 `05_SV-Agent_ai/43_DEPLOY_AGENCY_UPPER_CMPGN_SPLIT.sql` [D1] | DDL 2곳 | 🔴 [D1] 없이 build 하면 003001(GN_DW_DBT 는 ALTER 불가 · llm §4) |
| [2] | dbt 코어 — VIDEO 분기: `UPPER_CAMPAIGN_CD = IFF(형태=코드, v, NULL)` · `UPPER_CAMPAIGN_NM = IFF(형태=코드, NULL, v)` · DIGITAL·REBROADCAST 분기는 두 열 다 NULL · 머리 O260 주석(:62~64 「값은 코드다」)을 실측으로 정정 | `models/silver/agency/AGENCY_AD_PERFORMANCE.sql` | 출력 계약 변경(열 +1 · 기존 열 값 일부 NULL 화) ⇒ 하류 확인 [4] |
| [3] | dbt yml·테스트 — 두 열 description · 테스트 = `UPPER_CAMPAIGN_CD` 가 NOT NULL 이면 형태 규칙 만족(warn→error 승격 기준은 [0] 실측) · 두 열 동시 NOT NULL 0행 | `_schema.yml`(silver/agency) · `tests/` | — |
| [4] | 하류 영향 — `ref('AGENCY_AD_PERFORMANCE')` = `FACT_AD_PERFORMANCE` · `AGENCY_AD_DIGITAL` 두 곳에서 `UPPER_CAMPAIGN_NM` 사용 0 재확인(grep · O171 실측 「종단 컬럼」 유지 여부). 쓰는 곳이 있으면 그 모델을 같은 단위에서 고친다 | grep · `30_output_share/06_BRONZE노출감사.md` | 사용처 1건 이상이면 계획 재검토 |
| [5] | GOLD(선택 · 요건 확인 후) — 이름형 4,086행을 마케팅캠페인에 잇고 싶으면 `FACT_AD_PERFORMANCE` VIDEO 매핑에 「`UPPER_CAMPAIGN_NM` = `DIM_MARKETING_CAMPAIGN.MKTG_CAMPAIGN_NAME` 이름 일치(1:1 만)」 경로를 코드 경로 **뒤** 순위로 추가. 🔴 매핑 결과가 바뀐다 ⇒ 실측(이름 일치 7종 · 행수 · 다른 캠페인으로 바뀌는 행 0) 후 👤 결정 | `FACT_AD_PERFORMANCE.sql` · `MKTG_MAP_METHOD` 값 추가 시 SV 05_07 COMMENT 목록 | 👤 결정 |
| [6] | 👤 dbt 재배포 + `build --select AGENCY_AD_PERFORMANCE+` → [D2] 대사: VIDEO 행수 불변(6,801 채움 기준) · CD 채움 2,715 · NM 채움 4,086 · 합 = 종전 `UPPER_CAMPAIGN_NM` 채움 · FACT 재방송·영상 `MKTG_MAP_METHOD` 경로 행수 불변([5] 미적용 시) | `43_…` [D2] | 👤 build |
| [7] | 문서 — 문서실행순서 「기존 환경 갱신」 39 = `43_` [D1] → 👤 build → [D2](신규 구축은 08 DDL·dbt 에 이미 들어가므로 없음) · `_보조주석` 「O261-B만 덧입힐 때」 · `20_issue/32_컬럼개명표.md`(신규 열) · 원장 O261 행 | 문서 4곳 | — |

- 🔴 하지 말 것: 코어에서 CRM 조인 · `UPPER_CAMPAIGN_NM` 을 `_CD` 로 **개명**(이름 4,086행이 「코드」로 거짓 표기된다) · `CMPGN_CD` 전역 치환(CRM 동명 · O260 주의).
- 롤백 = 코어 모델 되돌림 + build(추가 열은 NULL 로 남아도 무해 · DROP 은 소유자 롤).

[0] 재현 SQL:

```sql
WITH v AS (SELECT UPPER_CAMPAIGN_NM v, COUNT(*) r, MIN(AD_DATE) d0, MAX(AD_DATE) d1
           FROM GN_DW.SILVER.AGENCY_AD_PERFORMANCE WHERE UPPER_CAMPAIGN_NM IS NOT NULL GROUP BY 1)
SELECT v, r, d0, d1,
       REGEXP_LIKE(v, '^U[0-9]+$')                                                   AS code_shaped,
       v IN (SELECT CMPGN_CD::VARCHAR FROM GN_DW.SILVER.CRM_CAMPAIGN)                AS is_cmpgn_cd,
       v IN (SELECT CMPGN_NM::VARCHAR FROM GN_DW.SILVER.CRM_CAMPAIGN)                AS is_cmpgn_nm,
       v IN (SELECT MKTG_CAMPAIGN_NAME::VARCHAR FROM GN_DW.GOLD.DIM_MARKETING_CAMPAIGN) AS is_dim_mktg
FROM v ORDER BY r DESC;
```

### ▣ O261-B-3 ㉯ 80 패키지 운영도구 편입(계획)

| 순 | 작업 |
|---|---|
| ① | 원본 이식성 수정(워크스페이스 동작 불변): `sys.path.insert('/workspace/scripts')` → 자기 폴더 기준 · `sv_enum_newvalue_gate --out` 기본값 = 실행 폴더 · `sv_no_rollup_gate --sv-dir`(+자동 탐지 `05_SV-Agent_ai/` · `01_실행순서_배포SQL/05_SV-Agent_ai/`) |
| ② | `sfconn.conn()` = 토큰 파일 있으면 현행 OAuth · 없으면 `SNOWFLAKE_CONNECTION_NAME`(connections.toml) · 역할·웨어하우스 환경변수 덮어쓰기(기본값 불변) |
| ③ | `build_handoff.py` MANIFEST `("10_운영도구_scripts", …)` = `sfconn.py` · `run_sql_file.py` · `sv_enum_newvalue_gate.py` · `sv_code_label_gate.py` · `sv_no_rollup_gate.py` · (㉰ 신설) `sv_common_block_gate.py` + `README.md`(접속·실행 순서·rc 0/1/2 의미) |
| ④ | 🔴 hook 이 `.py` 를 스크럽하는지 확인 — 안 하면 원본 `.py` 주석의 계정 ID 를 먼저 뺀다 · 재빌드 후 80 전체 `scrub_acct.ACC` 0 |
| ⑤ | 검증 = 워크스페이스 게이트 rc=0 · 음성 테스트 PASS · 80 사본 `--help`·`--self-check`(라이브 접속 없이) |

### ▣ O261-B-4 ㉰ SV 공통 블록 규칙·적용(계획)

- 대상 6종 = `05_27` · `05_28` · `05_29` · `05_30` · `23_` · `24_`(`O206-C` 토큰 부재 · 실측 2026-10-25).
- 정본 블록 = 현재 30개 SV 에 바이트 동일한 1,002자(`[O241-R 반올림 · 전 SV 공통]` ~ `… 전체 값을 따로 COUNT DISTINCT 한다.`) + 앞의 `[O216 SQL 작성 규칙]` · 변형 1건 = `22_ML_SV_DDL.sql` 안 1곳(1,010자 · 대조 후 정본화 또는 사유 기록).
- 규칙(신설 · 정본 `05_SV-Agent_ai/00_SV_공통지시문.md` · 원장 §0 유형 등재 필수 · `R1-6-18`):
  - **R-SV1** 모든 SV `AI_SQL_GENERATION` 은 정본 블록으로 시작한다.
  - **R-SV2** 고유 규칙은 블록 **뒤** 「핵심 규칙:」에만 · 충돌 시 공통 우선 · 예외는 「(공통 규칙 예외: …)」로 명시.
  - **R-SV3** 「미배분」·「배분 불가」 등 **구분 값 행**은 합계·소계 행이 아니다 — 고유 규칙에 그 문장을 쓴다(05_27 (2) · 05_30 (4)(6) 충돌 소지 차단).
- 게이트 = `sv_common_block_gate.py`(`new_tool.py` JUDGE · 소스+라이브 SV 44 · 음성 = 누락·변형·순서 FAIL / 정본 PASS · 변이 FAIL 실증 · `session_brief` GATES).
- 배포 = 6 SV → `34_`(최신본 원칙) · `36_` 은 이력이라 동기화만 · Agent 재버전 불요.

### ▣ O261-B-5 순서와 끝 조건

1. ㉮ [0]~[4] → ㉯ → ㉰(게이트·배포) → ㉮ [6] 👤 build 대사 → ㉮ [5] 👤 결정(선택) → ㉮ [7] + ㉯㉰ 문서 → 문서 게이트 전종 → 80 재빌드.
2. 끝 조건 = 남은 일이 「운영계 반영」만 — 그때 문서실행순서 「기존 환경 갱신」 33 → … → 38 → 39(이 계획) 를 운영계에 한 번에 집행한다(👤).
3. 승계 = O261-A ⑤ · O259-A-3 ③④ · O256-B-2(운영계·현업) 그대로.

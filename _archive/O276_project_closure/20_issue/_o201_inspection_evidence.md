<!-- LLM-METADATA
doc_id: O201_INSPECTION_EVIDENCE
doc_role: O201 세션 근거철 — R1-3-7-c 집행물(판정 전 원문·좌표·실측 보관 · 정본 아님)
project: GN_DW (굿네이버스)
created: 2026-10-03
created_by: O201
account: JU93656 (GRHVGDR-ZO79488 · 신규 개발계 · 사용자 확인 2026-10-03)
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

# O201 근거철 — O171~O200 비판적 검토 후속

> 🔴 정본이 아니다(원장 §0 `_o2….md` 행). 판정은 이 파일의 실측 뒤에만 한다.
> 🔴 계정 = **JU93656**. 프롬프트의 pw69582 수치는 인용하지 않는다(사용자 결정 2026-10-03).

## E0. 검토 결함 D1~D6 재수록 (원문 = `tmp/O201_검토후속_작업프롬프트.md` 부록)

| D | 결함 | 근거 좌표 |
|---|---|---|
| D1 | 브리핑 §1 이 착수표 열린 행 0건(정본이 라벨 파일 「남은 작업」 표로 이동) | `20_issue/00_BRIEF.md:27` |
| D2 | 라이브 Agent COMMENT stale(EXECUTIVE 「LTV스코어순위」 · MEMBER 「SV 8종」) | `SHOW AGENTS` · `O0200-D.md:45` |
| D3 | O189-C 가 예고한 O180~O189 검토 미실행 | `O0189-C.md:56` · `O0190-A.md` |
| D4 | 재구축 런북 실물 0 · 2026-08-25 판본(MSTR·ML 12·AGENT_MSTR 미반영) | `60_repeat_어카운트시작/readme.md:12,39` |
| D5 | 점검 절차서 §7 이 직전 점검을 O165 로 기재(O170 미등재) | `11_O누적작업_점검_재현_절차.md:342` |
| D6 | O200-B 기록 없는 라벨 변경 · ACCOUNTADMIN 소유 | `O0200-C.md:19-22` |

## E0-1. 독해 기록 (R1-3-7-b)

| 파일 | offset/limit | 도착 | 고유 토큰 |
|---|---|---|---|
| `tmp/O201_검토후속_작업프롬프트.md` | 전량(81줄) | O | `D6` · `#37` · `O189-C ▣1` |
| `00_guides/00_작업지침_세션운영규칙.md` | 전량(304줄) | O | `R0-8-4` · `R2-8-4-d` · `R4-4-4` |
| `20_issue/00_BRIEF.md` | 전량(149줄) | O | `O0200-D.md:37` · `3,134,895` · `조문 112개` |
| `scripts/session_brief.py` | 165~215 · 613~643 | O | `open_label_tasks` · `O201 D1` |
| `scripts/test_session_brief.py` | 390~423 | O | `축12` · `시정 전 경로(open_tasks)` |

- read 미반환 0 · 재호출 0.

## E1. 착수 실측

- `id_collision_gate.py --next O` rc=0 → 「정의 196 · 참조 200 ⇒ 다음 발급 = O201」.
- `SELECT CURRENT_ACCOUNT()` → `JU93656` · 역할 `ACCOUNTADMIN`.
- `session_brief.py --write` → `BRIEF_RC=0` · §1 = **14행**(O200-A 4 · O200-C 5 · O200-D 4 + 1).
- `20_issue/_o201_inspection_evidence.md` 착수 시 부재(`ls` rc≠0) · `_o1….md` 접두가 `_o201` 을 못 맞춤
  ⇒ 원장 §0 에 `_o2….md` 행 선행 등재(`doc_type_gate.declared` 의 `…` 매칭 = 접두+접미).

## E2. D1 실측 — 브리핑 추출부

- `scripts/session_brief.py:631-635` 원문:
  `#   🆕 🔴🔴 [2026-10-03 O201 D1] 착수표가 비면 **라벨 파일 「남은 작업」 표**로 내려간다.`
  `    if not tasks and lcur:` / `        tasks = open_label_tasks(llines)`
- `scripts/session_brief.py:193` `def open_label_tasks(lines):` — 3열(`순|작업|다음 행동`) 수용.
- 원인 원문(`:175`) = `if len(cells) < 4: continue` ⇒ 종전 `open_tasks` 는 3열 라벨 표를 0행으로 낸다.
- 음성 테스트 `scripts/test_session_brief.py:408`
  `check('시정 전 경로(open_tasks)는 3열 표를 못 본다', sb.open_tasks(L(LBL)), [])` · `:410` 열린 행 = 1·4.
- 실행 `python3 scripts/test_session_brief.py` rc=0 → 「✅ 전건 통과 — 12축 80개 단정」.
- 두 파일 mtime = `2026-10-03 08:23:38 UTC` — 이 세션 착수 전.
  사용자 확인(2026-10-03) = 「앞선 O201 시도」 ⇒ **D1 코드·테스트 = 기집행 · 원장·근거철 기록 누락**(D6 와 같은 형태).

## E3. D2 실측 — 라이브 Agent COMMENT ↔ 스펙 (JU93656 · `GN_DW.SERVING`)

`SHOW AGENTS` 4행 · 전건 owner `GN_DW_ADMIN` · created_on `2026-10-03 01:56~01:57 -0700` · 기본 VERSION$3.

| Agent | 라이브 COMMENT(원문 발췌) | 스펙 tool_resources SV 실측 |
|---|---|---|
| AGENT_EXECUTIVE | 「실적 SV 4종(예산편성/집행·광고실적·회원월실적·서비스발송) + … 미래예측 4종(개발금액전망·LTV월별예측·**LTV스코어순위**·기여요인분석)」 | 8 = TARGET_BIZ · BUDGET · AD · MEMBER_MONTHLY · SERVICE · ML_DVLP_FORECAST · ML_LTV_FORECAST · ML_FEATURE_IMPORTANCE |
| AGENT_MEMBER | 「실적 SV **8종**(…) + … 예측 **3종**(이탈위험·중단위험·회비납입예측)」 | 16 = 실적 9(MEMBER_MONTHLY · MEMBER_EVENT · SERVICE · EVENT_PARTICIPATION · RELATION_ACTIVITY · MEMBER_COHORT · DEV_ACHIEVEMENT · MEMBER_FEE · MEMBER_SPONSOR_BIZ) + ML 4(MEMBER_RISK · SPONSOR_RISK · FEE_FORECAST · ONCE_CONVERSION) + 부서 집계 3(MBRFEE_PRDT_ACTL · SPNSR_CLS_AGGR · DVLP_GOAL_ACMSLT) |
| AGENT_MARKETING | 「SV **7종**: 광고효율·개발목표달성·예산집행·사건시점전환회원·캠페인획득코호트·캠페인회비·후원약정활동회원」 | 10 = TARGET_BIZ · AD · DEV_ACHIEVEMENT · BUDGET · MEMBER_EVENT · MEMBER_COHORT · MEMBER_FEE · MEMBER_SPONSOR_BIZ · ML_DVLP_FORECAST · ML_MEMBER_RISK |
| AGENT_MSTR | 「SV 1종: MSTR 정기회원 후원개발(MSTR 기준 · GN_DW 지표와 합산 금지)」 | 스펙 미조회(COMMENT 수치 「1종」만 기록) |

- 결함 집합(판정 전 사실): EXEC = 폐기 SV 명시 + 사업목표 누락 · MEMBER = 실적 1·ML 1·부서집계 3 누락 ·
  MKT = 사업목표·ML 2 누락 · 4종 전부 **종수 수치**를 COMMENT 에 박음(규칙7 위반 형태).

### E3-1. D2 결정 재상정 · 집행

- 재상정 원문 = `99_NEXT_SESSION-O0200-D.md:45` 「`09_1` COMMENT = 초기 샘플(틀려도 됨 · 사용자 결정)」.
- 근거 = Agent COMMENT 는 `SHOW AGENTS`·CoWork 에 노출되는 라이브 AI 표면(§4-3).
- 🟢 사용자 결정(2026-10-03) = **해제하고 교정·집행**.
- 파일 = `09_1` [1-A][1-B][1-C] · [5] 6곳 + [1] 머리 주석 취소선 · `24_MSTR_AGENT_배포.sql:67`.
- 라이브 = `ALTER AGENT … SET COMMENT` 4건 성공 · 재조회 owner 전건 `GN_DW_ADMIN` · 「N종」 0 · 「LTV스코어」 0.
- 🟠 부수 발견(미처리 · 판정 보류) = EXEC·MKT 스펙 system 문안 「`BRONZE_GA4` 스키마는 실재하지 않는다」
  ↔ JU93656 라이브 `BRONZE_GA4` 스키마 실재 · 테이블 2(`INFORMATION_SCHEMA.TABLES`).

## E5. D4 실측 — 재구축 런북

- `60_repeat_어카운트시작/readme.md:12` 원문 = 「실물 파일 151개는 **용량 사유로 삭제**됐다 ⇒ 커밋 `20260825_가오픈정리` 에서 복원」.
- `git -C /workspace log` → `fatal: not a git repository` · `$HOME/*/.git` 부재 ⇒ **복원 경로 실행 불가**.
- `02_GN_DW_building/06_RUNBOOK.md` = `last_updated: 2026-07-22` 운영 매뉴얼(일상 점검) — 재구축 순서표 아님.
- 라이브 생성 순서(JU93656) = 스키마 01:26 → BRONZE·ML·SILVER 01:29~01:33 → GOLD dbt 01:32~01:56 →
  MSTR 01:46~01:48 → 실적 SV 01:55~01:56 → SERVING 뷰 01:56 → Agent 3 01:56:53~57 →
  **ML SV 7 01:57:45~01:58:12(Agent 뒤)** → AGENT_MSTR 01:57:56.
- 산출 = `60_repeat_어카운트시작/12_GN_DW_재구축_실행순서.md` · readme 행 12 내용 대체 + 행 추가.

## E6. D6 재발 방지 — 기록 없는 라이브 변경 탐지 (설계안 · 미집행)

- 실례 2건: O200-B(SV·Agent 무기록 변경) · O201 착수 전 `scripts/session_brief.py` 08:23 UTC 무기록 수정.
- 탐지 원천 = ㉠ `SHOW AGENTS`/`SHOW SEMANTIC VIEWS` 의 `created_on` · ㉡ `DESCRIBE AGENT` 의 `versions`
  ㉢ `ACCOUNT_USAGE.QUERY_HISTORY` 의 DDL(`CREATE|ALTER (AGENT|SEMANTIC VIEW)`) · ㉣ 워크스페이스 파일 mtime.
- 판정식 = 각 변경 시각 t 에 대해 원장 §1 에 「날짜 = t 의 날짜 · 대상 객체명 포함」 행이 존재하는가.
  부재면 🔴 경보(무기록) · 🟢 원장 행 시각보다 이른 변경만 허용.
- 게이트 신설 시 음성 테스트 = 원장 픽스처에서 해당 행 1개를 지우면 경보 1 · 복원하면 0(뒤집힘 ≥1).
- 🔴 한계 = ㉢ 은 ACCOUNT_USAGE 지연(최대 45분) · ㉣ 은 마운트 mtime 이 스테이지 커밋 시각과 다를 수 있다.

## E7. ⑤ GOLD 미주입 재측정 (JU93656 · `census_columns.py` 무인자 · `CENSUS_RC=0` · ERR 0)

- 착수 시 `/tmp/census.json` 부재 확인(캐시 오염 0) · 집합 도구 = `tmp/_o201_unfilled.py`(O167 사전 재사용 + §E4-3 해소 2 + §E7-3 신규 1 ⇒ `assert len == 95`).
- 원문 출력(`tmp/_o201_unfilled.out`): 「O170 집합 = 95 · JU93656 현재 = 61」 · 「해소 = 44」 · 「신규 = 10」.
- 🔴 총계 비교는 하지 않는다(§E4-3) — 아래는 집합 원소다.
- 해소 44 = `DIM_DATE.IS_HOLIDAY` · `FACT_EVENT_ATTENDANCE` 6 · `FME.NEW_EXISTING_FLAG` · `FMM` 22 · `FMD` 10 · `FACT_TARGET_PROJECT` 4(`ANNUAL_GOAL_CNT`·`MONTH_KEY`·`ORG_SK`·`SPONSORSHIP_SK`).
- 신규 10 = `DIM_EVENT.ENTRPS_CD`[전건0] · `DIM_MSG_TEMPLATE.ALTRTV_MSG_ATCHFL_ID`[전건NULL] ·
  `FACT_AD_BROADCAST_CASE` 6컬럼[0행] · `FACT_AD_DIGITAL.GROUP_DIV`[전건NULL] · `FACT_RELATION_CHANGE.CHG_RST_CD`[전건NULL].
- SV 노출 — 토큰 후보 18 중 **확정 3**(`GET_DDL('SEMANTIC_VIEW','GN_DW.SERVING.SV_AD')` 원문):
  `AD.TOTAL_CRM_DEV_CNT as SUM(ad.CRM_DEV_CNT)` · `AD.DEV_UNIT_PRICE as … / NULLIF(SUM(ad.CRM_DEV_CNT), 0)` ·
  `AD.TOTAL_MEDIA_POTENTIAL as SUM(ad.MEDIA_POTENTIAL_CUST_CNT)` — 원천 컬럼 전건 NULL ⇒ 항상 NULL.
- 오탐 판정 = `FACT_BUDGET.AD_COST`(SV_AD 의 AD_COST 는 `WIDE_AD_COMBINED` 소관) · `*_SK` 14건(각 SV 가 자기 팩트 키로 같은 이름을 씀) — 🟠 SK 14건은 SV 별 base 대조 미실행(미판정).

## E8. ③ NL 스모크 기준선 (JU93656 · 2026-10-03 · 사용자 승인 = 44문항 즉시 실행)

- 문항 실측 = 스펙 `sample_questions` MEMBER 18 · MARKETING 11 · EXECUTIVE 10 · MSTR 5 = 44(프롬프트 「36」과 다름).
- 도구 변경 = `scripts/nl_routing_smoke.py` `SPECS` 에 `AGENT_MSTR` 1행 + 헤더 「3종」→「4종」(diff 변경 5줄 · `py_compile` rc=0).
- 이전 계정 산출 보존 = `tmp/nlsmoke/` 45파일 → `tmp/nlsmoke_prev_pw69582/` 복사(삭제 0).
- 실행 = `python3 scripts/nl_routing_smoke.py --apply --strict --set-baseline` → `SMOKE_RC=1`.
- 원문 요약: 「총 44문항 · 호출성공 44 · SQL생성 40 · 실패 0」 ·
  「① 최종 응답 실패 0 ⇒ 🟢 · ② 중간 오류 1 (중간 오류 0(strict)) ⇒ 🔴 ⇒ 🔴 FAIL」 · 「기준선 갱신 = 1」.
- 중간 오류 1 = `AGENT_EXECUTIVE_05`(「전사 개발금액 예측을 예측월별로 보여줘 (만원, 예측)」) ·
  원문 `syntax error line 12 at position 13 unexpected '예측'` · 생성 SQL 에 `AS 예측월`(따옴표 없는 한글 별칭).
- 분류 = **추측 식별자 계열**(O189 식별자 규칙 「한글은 따옴표 별칭 안에서만」 위반) · metric-as-CTE 0 · 물리명 노출 = 미판정(답변 본문 미검사).
- ⇒ 🟢 JU93656 기준선 = `tmp/nlsmoke/_baseline.json` `{"mid_errors": 1}` · 「중간 오류 0」 판정은 🔴(1건).

## E9. 종료 게이트 실측

- 음성 테스트 전건 `for t in scripts/test_*.py` (rc 를 파이프 없이 파일로) = 47종 중 rc=0 **46** · rc=1 **1**(`test_verify_wide_doc.py`).
- rc=1 원문 = `AssertionError: View names mismatch!`(`verify_wide_doc.py:60` · 라이브 WIDE 뷰 ↔ dbt sql ↔ 문서 집합 불일치) — O201 은 이 경로를 수정하지 않았다 · 미해소 잔여. 🟢 [O201-B] 해소 = §E10 ⓐ.

## E10. O201-B — 사용자 결정 3건 집행 (2026-10-03 · JU93656)

- 결정 원문 = 「1. 항상 NULL 인 지표를 COMMENT 경고만 · 2. SQL 작성 규칙에 한글 별칭 따옴표 규칙을 보강. 스모크는 생략 · 3. O180~O189 검토를 착수」.
- ① `05_7_SV_DDL_AD.sql:83·85·91` COMMENT 에 `[O201-B]` 경고(수치·현재상태 단정 없음) → `tmp/_o201b_sv_ad_deploy.py`(CREATE OR ALTER + GRANT 3) rc=0 · 「owner = GN_DW_ADMIN」 · 「O201-B 표지 수 = 3」.
- ② 4종 스펙 orchestration 에 열 별칭 영문 한정 규칙(`tmp/_o201b_spec_patch.py` · 앵커 1회 · yaml 파싱 OK) → `[0-B]` COPY 4 · `[0-C]` 4건 OK · `[2]` no_live 4 · ADD VERSION 4.
  재조회 = EXEC·MKT·MEMBER `VERSION$4` · MSTR `VERSION$5` default · rule=True 4 · owner 불변. 🟠 스모크 생략(사용자) ⇒ 효과 미측정.
- 남은 문제 ⓐ `test_verify_wide_doc` = 라이브 17 · dbt 17 · 문서 14 · 차이 = `WIDE_DVLP_GOAL_ACMSLT`·`WIDE_MBRFEE_PRDT_ACTL`·`WIDE_SPNSR_CLS_AGGR`(O200-A 신설 · 생성기 `VIEW_META` 미등재).
  처방 = `scripts/build_wide_doc.py` 에 3종 + `_wide_dept_aggr_schema.yml` 병합 + 「14종」 하드코딩 → `len(VIEW_META)` · 재생성 rc=0 · 테스트 rc=0 「ALL PASS」.
- 남은 문제 ⓑ `BRONZE_GA4` = 라이브 `GA4_USER_DEMOGRAPHIC` 45,980행 · `SYNC_ERR_INFO` 0행 · dbt models 참조 0(정의 = `50_handoff/04` 만).
  EXEC 1곳 · MKT 2곳 문안 「실재하지 않는다」 → 「GA4 인구통계 원천만 담고 광고 SV 에 배선되지 않았다」 · EXEC·MKT `VERSION$5` · 구 문안 0.

## E11. MSTR — 「이미 반영됐나」 실측

- 기존 3종(MEMBER·EXEC·MKT) 스펙의 MSTR SV 도구 = **0**(「MSTR」 토큰은 CRM 테이블명 `TM_RM_RELATNSP_MSTR_INFO` 1건씩뿐).
- `ACCOUNT_USAGE.QUERY_HISTORY`(01:40~02:00 −07:00) = TRIALADMIN · GN_DW_ADMIN 이 01:46 스키마 → 테이블 10 → 01:47 뷰·함수·프로시저 → 01:56 `MSTR_SPNSR_DVLP_V`·`SV_MSTR_SPNSR_DVLP` → 01:57 ACCOUNTADMIN 소유권 이전 → `AGENT_MSTR` CREATE → 01:58 COMMIT·GRANT·CoWork ADD.
- 🔴 `GN_DW.MSTR` 테이블 10종 **전건 0행** · 오늘 INSERT/MERGE/CALL **0건** ⇒ 구조만 배포 · 이력 적재(`mstr_pipeline`) 미실행.
- 스모크 원문 `AGENT_MSTR_01` 「0행 반환. 테이블 자체가 비어있는 것으로 보인다」 ⇒ MSTR 값 검증 불가 상태.

## E12. ML 예측 질문 답변 가능성 (`90_provided_definition/데이터플랫폼 ML 예측관련_취합_20260730.xlsx`)

- 시트 4 · 셀 덤프 `tmp/_o201b_xlsx_dump.md`(94줄) · 통합본 「예측프롬프트」 = 회원실 9(D11~D19) · 기획실 3(D20·D22·D24) · 나마본 21(D26~D46).
- 판정표 = `05_SV-Agent_ai/40_ML예측질문_답변가능성_검토.md` · ⭕5 · △16 · ✕12(행 단위 재집계 · 초안 17/11 자기시정).

## E13. O180~O189 검토 (D3 · O189-C 예고분)

- 도구 = `tmp/_o201b_o18x_census.py` · 🔴 1판 = 이력 26/26 X · 남은 작업 0 ⇒ **J2 결함**(이력 제목 `> #### 🟢 [날짜 O183]` · 절 제목 「다음이 할 일」 · 순 셀 `**1**` 미인식) · 2판으로 재측정.
- 라벨 단위 26 · O 번호 결번 0 · 원장 §1 행 부재 **12**(O181-B · O183-B/C/D · O188-B/C/D/E/F/G · O189-B/C — 판정식 = 원장에 `` `라벨` `` 토큰 부재 · 접미 없는 상위 행이 포괄하는지는 미판정) · 이력 부재 **8**(O182-A · O183-B · O183-C · O188-C~G).
- 「후속 미등장」 후보 → `tmp/_o201b_o18x_j3.py` 로 후속 라벨·원장·문서50·문서20·라이브 대조(`tmp/_o201b_o18x_j3.out`).
- 🟢 해소 판정(라이브·정본 근거): CRM 신규 3종·A-7 = `SV_TARGET_BIZ` 라이브 1 + EXEC·MKT `analyst_target_biz` · GN_DW_DBT 롤 라이브 1 · A-11 `test_generators` rc=0(E9) · P66 = `09_2:315` 「O184 해소」 · A-8 = O189 규칙 + E10 ②.
- ⚪ 소멸 = `SILVER_2.CRM_MEMBER_DEV GRANT UPDATE` — JU93656 에 `SILVER_2` 스키마 0.
- 🔴 **미승계 3**(후속 문서 0 · 해소 근거 없음): `O183-A` 공45~47·54~57·77~78 비율 지표 · `O182-A` VIDEO 캠페인 축 도달률 급락(원천 `MKT_CMPGN_NM` 소멸) · `O180-B` `doc_coord_gate` 「줄 내용」 축.
- 🟠 승계 중(후속 문서 有 · 미종결): `--vars` 원인 · jinja_config_gate 축3·5 · DEC-33 D5 필터 · W3·B · DGT 재송부 · 2차-B · GOLD 9종 SV 노출.

## E14. O201-C — 사용자 승인(「재균형 등 모든 작업들 승인한다」) 집행

- MSTR 적재 방식 = dbt 아님 · `USP_RUN_MSTR_1ST(I_YM, I_OPER, I_HIST)` CALL(`04_sp_script.sql:978`) · 문서화 = `15_MSTR 이관 PoC/snowflake 적용 ddl/06_MSTR_적재_실행.sql`.
- 원천 월 = `TM_MM_FDRM_MBER_DVLP_AMT` 190001~999912 · 430개월 · `<= 202601` 3,438,776행(O200-D 의 이력 재적재 규모와 동일) ⇒ `CALL …('202601','POC',TRUE)` 집행(`tmp/_o201c_mstr_load.py`).
- 미승계 3 처리:
  · `O180-B` 줄 내용 축 = **이미 구현**(`doc_coord_gate.py:25` 「축8(경고 🟠) = 행 번호가 파일 안에 있지만 그 줄이 빈 줄인 좌표」 · O181/O181-B) ⇒ §E13 의 「미승계」 판정 철회(토큰 「줄 내용」 대조가 「빈 줄」 구현을 못 봤다 · J1).
  · `O183-A` 비율 = 단월 정의 확정 5종 SV_MEMBER_MONTHLY 신설(`STOP_RATE_2`·`STOP_RATE_NEW`·`STOP_RATE_EXISTING`·`UNPAID_RATE_NEW`·`UNPAID_RATE_EXISTING`) · 라이브 파일 대조 metric 25=25 후 배포 · 202512 = 72.33 · 1.90 · 0.69 · 13.74 · 8.42(전체 공76 9.11 사이).
    🔴 공45~47·54 = 분모 「DEV_CNT(YTD)」(`05_지표GOLD매핑.md:122~124·131`) — FMM 에 누계개발 컬럼 0 ⇒ 미구현 · 문서20 질의 대상.
  · `O182-A` VIDEO 도달률 재측정(SV_AD · 광고비 기준) = DIGITAL 66.90% · VIDEO 4.16% · REBROADCAST 0.00% ⇒ SV_AD `MARKETING_CAMPAIGN` COMMENT 에 출처유형별 경고(수치 미기재) · VQR 3 보존 확인.
- 소급 등재 = 이력 8(라벨 파일 ▣-0 원문 발췌 · rollover PASS) · 원장 §1 1행(12라벨 좌표) · 원장 재균형 `--rebalance --fill 0.7` PASS(바이트 동일 · 유실 0).
- 🟠 관찰 = FMM 최신 MONTH_KEY 가 202911(1행) — 미래월 행 1건(원인 미조사).

## E15. MSTR 적재 · 검증 결과 (JU93656)

- `tmp/_o201c_mstr_load.py` `LOAD_RC=0` · `sec=2367` · 원문 「F_MM_SPNSR_DVLP 이력 재적재 완료」.
- 행수 = BCHLOG 1,691 · D_BRND_CD 104 · D_CMMN_DTL_CD 6,374 · D_CMPGN_CD 37,164 · D_CM_DEPT_INFO 1,314 · D_MBER_DVLP_GOAL_CD 25,344 · D_SPNSR_BSNS_INFO 51 · D_STRD_CAL_CD 21,902 · **F_MM_SPNSR_DVLP 3,438,776** · **F_MM_SPNSR_DVLP_SUM 28,587**.
- `mstr_verify.py manifests/1차.json --ym 202601` rc=0 **PASS** · `report_summary` 「ROWS_OUT 10227 · CNT 29407.72 · AMT 294077200 · ROWS_WITH_UNMAPPED 0」.
- AGENT_MSTR 질의(기본 범위 신규·증액·재후원 · `tmp/_o201c_mstr_agent2.txt`) = 「개발(건) 약 29,407.72 건 · 후원금액 294,077,200원」 ⇒ baseline 과 **일치**.
  · 「개발구분 필터 없이 전체」 질의(`tmp/_o201c_mstr_agent.txt`)는 감액·중단 음수 포함 순합 1,854.23건 · 18,542,290원 — 질문 범위대로 답했다(오답 아님).
- 🟠 SV 의 적재 기준년월 = 집계 SUM 테이블이 202601 한 달뿐(Agent 원문 「적재된 기준년월은 현재 2026-01 한 달뿐」) — 다른 달은 `I_HIST=FALSE` 월 CALL 필요.

## E16. O201-D — 운영계 적재 범위(2026-01~) · 누계개발 확정 반영

- 40분 분해(BCHLOG) = `USP_F_MM_SPNSR_DVLP` 1,680문 · 2,341.1초(월당 ≈ 5.6초 · 420개월 루프) · 차원 7종 ≈ 13초 · SUM 10.5초 · ETL_WH = Small.
- 원본 DDL 전체(UTF-16) = 테이블 119(F 80 · D 35) · 뷰 184 · 함수 12 · SP 124(F 적재 76 · D 38) ↔ 1차 = 테이블 10 · SP 12.
- 2026 이전 제외의 장애물 = SUM 의 `SPNSR_AMT2_CD` 가 F 이력에서 「후원사업별 최초 개발금액」을 조회(`04_sp_script.sql` [9]) · 202601 의 46.0%(13,147/28,587)가 2026 이전 최초 개발.
  처방 = 조회 원천을 F → `BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT`(템플릿·04 동시 수정) · 조회 결과 대조 2,092,147건 · only_f 0 · only_b 0 · ser/amt/mt diff 0.
  재계산 후 202601 baseline PASS · Time Travel 대조 = SPNSR_AMT2_CD 변화 0 · 🟠 차이 38행 = FN_MM_SPNSR_DVLP B3(감액) `ORDER BY SPNSR_NO DESC` 동점 비결정(기존 결함 · 이번 변경 무관 · 미수정).
- 06 [2] 운영 블록 개발계 실행 = 202601~202610 10개월 전건 OK · 291초(≈ 29초/월) · SUM 월별 6,243~28,636행.
- 누계개발 = 사용자 확정 「당해년도 1월 ~ 조회월의 개발(건) 합계」.
  · 회원행 누계 방식 기각 = 2025-12 회원행 누계 합 154,721 / 연간 개발 190,534 = **81.20%**(sparse 스파인).
  · 사건 수 기준 공45 2025-12 = **100.94%**(>100) ⇒ 금액 ÷ 10,000(신규·증액·재후원) 기준 = 90.46% · 202601 97.94%.
  · 공46 사전 표기 그대로 = 138.18%(202512) · 103.09%(202601) — 100% 초과 ⇒ 현업 확인 ②.
  · 산출 = dbt 뷰 `WIDE_MEMBER_MONTHLY_KPI` + SV `05_14`(OPS 임시 객체로 DDL·값 사전 검증 후 삭제) · 🔴 dbt build 전 배포 불가.

_Co-authored with CoCo_

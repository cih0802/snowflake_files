<!-- LLM-METADATA
doc_id: HANDOFF_O0182_A
doc_role: 인수인계 — 세션 `O182-A` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-09-28
created_by: O182-A
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0182-A -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O182-A-0 🔴🔴 먼저 알아라 — 이 세션이 확정한 판정식

| # | 판정식 | 근거(실사고·실측) |
|---|---|---|
| ㉠ | **원천 재편은 개명이 아니라 구조 변경일 수 있다 — 컬럼 코멘트로 대응을 먼저 세워라** | AGENCY 3종이 DGT 36→41 · VIDEO 32→37 · REBRDC 34→21 로 바뀌었고, 하류 모델은 옛 이름을 그대로 참조해 **다음 build 가 invalid identifier 로 죽을 상태**였다 |
| ㉡ | **「채워짐」은 「유효함」이 아니다** — 날짜 컬럼은 에포크 기본값을 따로 걸러라 | DGT `DATE` 는 NULL 0 인데 **3,531행이 1970-01-01** 이었다(텍스트축은 2026-06~09 정상). NULL 만 폴백하면 1970년 광고비 9.47억이 생긴다 |
| ㉢ | **출력 계약을 고정하고 매핑만 바꾸면 GOLD 가 무변경으로 따라온다** | SILVER 하류 5종의 컬럼을 그대로 두고 원천 매핑만 바꿨다 ⇒ GOLD DDL·모델 **0파일 수정**으로 build PASS |
| ㉣ | **`ML_RST_*` 의 `STDR_MT` 는 테이블마다 의미가 다를 수 있다** | `ONCE_CONVERSION` 은 모델 실행월이 아니라 **가입월부터 6개월 관측월**(8,144명 전건 gap 0 · 회원당 6행)이다 ⇒ 다른 ML SV 의 「최신 기준월 하나로 한정」 규칙을 적용하면 대부분이 사라진다 |
| ㉤ | **병렬 `edit` 의 컨텍스트 미리보기는 서로 엇갈려 보고된다 — 병렬 편집 뒤에는 파일을 다시 읽거나 토큰을 세라** | 이 세션에서 **2회** 재현(`AGENCY_AD_ROW_DGT.sql` · 08 DDL). 실물은 전부 정상이었다(O180-B ㉥ 와 같은 class) |

---

### ▣ O182-A-1 🟢 이 세션이 끝낸 것

**① 인수인계 문서(50_handoff) — ML 17종 반영 잔여 정리**
- 07번 A.5-B.2 (5) `ONCE_CONVERSION` COPY = 컴파일 OK · 스테이지 48,864행 = 테이블 48,864행 · 파싱 100% OBJECT(xf98254 실측 · 주석 기록)
- 옛 기대값 정리: 02_1 A8(16→17 · 3곳) · 03 3.1-B · 01 §3.3·§4.2·§10(77→82) · VARIANT 4종→5종
- 사용자 확인 = A 계정 실측 일치 · SERVING/SV 컬럼 코멘트 현업 OK

**② ML `ONCE_CONVERSION` → SERVING·SV·Agent 배선(라이브 배포 완료)**
- 뷰 `GN_DW.SERVING.ML_ONCE_CONVERSION_V`(21번 [8]) · SV `SV_ML_ONCE_CONVERSION`(22번 [8]) · GRANT 3역할씩
- 설계 = `STDR_MT`→`OBSERVE_MT` 개명 노출 · 미래 관측월(상수 확률 11,666행) 제외 · `CONVERSION_YN` 미노출(전건 0)
- `AGENT_MEMBER` 에 도구 `analyst_ml_once_conversion` 추가(도구 12종) · 09_2 사전검증 27건

**③ Agent 3종 첫 활성화(라이브)** — 이 계정 기본 버전이 **빈 스펙**이었다
- MEMBER VERSION$3(도구 12) · EXECUTIVE VERSION$3(8) · MARKETING VERSION$3(7) · 이전 버전 보존(롤백 가능)
- 🟢 09_2 [3] 의 모순 해소 = **`ADD VERSION FROM` 은 자동으로 is_default=true 가 된다**(실측). `cortex-project.yaml` 24행 「발행만으로 default 가 되지 않는다(P66)」가 틀린 쪽이다 ⇒ **철회 미집행**(㉠ 잔여)

**④ AGENCY 원천 재편 재배선(SILVER 8모델 + 08 DDL · build 완료)**
- staging 3종 = 원천 이름 그대로 재정의 · 08 DDL 과 **컬럼 순서까지 일치**(50·46·30)
- 코어·위성 = 출력 계약 불변 · 날짜 보정(DGT 에포크 · VIDEO CTV 시트 NULL) · 광고비 **연속성 유지**(사용자 결정)
- VIDEO 개발건수·후원자수·노출·클릭·기기·CTV구분 **배선**(사용자 결정 「모두 배선」)
- `AGENCY_AD_BROADCAST_CASE` = 원천 사례 반복군 소멸 ⇒ **0행 스캐폴드**(스키마 유지)
- 사용자 실행 = 08 DDL 전체 + `dbt build` 전체 **PASS=542 WARN=22 ERROR=0 SKIP=0 TOTAL=564**
- 라이브 확인(2026-09-28 · xf98254) = SILVER/GOLD 광고 코어 **77,505**(=29,048+46,353+2,104) · FACT_AD_BROADCAST 48,457 · DIGITAL 29,048 · CASE 0

**⑤ 실측 판정 2건(결정은 미집행)**
- `GRANT UPDATE`(O181-B ▣2-7) = dbt SILVER 모델 전량 `append` · merge/UPDATE **0건** ⇒ SILVER 에는 UPDATE 불필요
  · 🔴 단 **GOLD dim 은 `unique_key` + 전략 미지정 = 기본 `merge`** ⇒ GOLD 에는 UPDATE 가 필요하다
- ML 17종 사용 현황 = **17/17 Agent 연결**(MEMBER 6 · EXECUTIVE 11 · MARKETING 0)

---

### ▣ O182-A-2 🟠 다음이 할 일 — ㉠ 이 세션 작업에서 생긴 것

| # | 항목 | 착수 정보 |
|---|---|---|
| **1** | 🔴 **dbt 전용 롤 `GN_DW_DBT` 신설**(사용자 지시 · 다음 세션 최우선) | 아래 ▣ O182-A-6 에 설계안·판정식이 있다 |
| **2** | 🔴 **SV_AD · Agent 문안 정정** — 원천 재편으로 **거짓이 된 서술** | 「VIDEO 는 개발 컬럼이 구조적으로 부재」·「전환콜」·「방송=기기 없음(DEC-10)」·사례 분석(CASE 0행)·REBRDC 시간대(구간 라벨→시각)·재방유형 값(재송출/특집→재송출/방송). 대상 = `05_SV-Agent_ai/05_7_SV_DDL_AD.sql` · `AGENT_EXECUTIVE`·`AGENT_MARKETING` spec · `models/gold/wide/_wide_schema.yml:1265·1275·1287` |
| **3** | 🟠 **VIDEO 캠페인 축 도달률 급락** | 원천 `MKT_CMPGN_NM` 소멸 → `CMPGN_NM` 은 CTV 시트 3,336/46,353 만 채움 ⇒ `DIM_MARKETING_CAMPAIGN` 이름매칭 도달이 크게 준다. 재측정 후 SV 문안에 반영 |
| **4** | 🟠 **원천 신규 컬럼 GOLD 승격 여부** | DGT `MARKUP_AMT`·`VAT_AMT`·`LAST_STMT_AMT`·`TOTAL_CPA`·`TOTAL_DVLP_UNIT_PRICE`·`BDGT_SOURCE_NM`·`CMPGN_TYPE*` · REBRDC `CONTENTS_PUR_COST`·`CALL_CTR_OPER_COST`·`TOT_COST` · VIDEO `BDGT_SOURCE_NM`·`MATR_TY_NM`. 🔴 **지금은 staging 에만 있다**(O171 선례: 요건이 명확해진 뒤 승격) |
| **5** | 🔴 **CRM 신규 3종 배선 설계** | `TM_CM_MBER_DVLP_GOAL_DIV`(290행) = **2026 사업목표**(연사업 = 법인×신규기존×조직구분×팀×후원사업 · 팀 = 채널상세). 입고 대기이던 `SILVER.CRM_BIZ_TARGET`(0행 스캐폴드) → `GOLD.FACT_TARGET_PROJECT` 자리. 🔴 **명칭만 있다** — 조직 명칭매칭 연사업 팀 7종 중 5종 · 후원사업 연사업 11종 중 8종(팀목표 4종은 0). `TM_CM_SCHDUL_MNG`(청구·출금 일정) · `TM_MS_AT_TMPLAT_MNG`(알림톡 템플릿 6,562) 는 **용도 결정부터** |
| **6** | 🟡 `cortex-project.yaml` 24행 P66 기재 철회 | ③ 실측이 반대로 나왔다(자동 default) |
| **7** | 🟡 ONCE_CONVERSION 잔여 | 일시회원 속성 축(가입경로·부서) 미배선 · 뷰가 `CURRENT_DATE()` 기준이라 월이 바뀌면 행이 는다(설계상 의도 · 문안 명시) |
| **8** | 🟠 **원장 §1 행·이력 항목 미기록** | 원장 `-002` 여유 240 B 라 이 세션 행을 넣을 공간이 없다(O181-B ▣2-5). 이력 롤오버는 `R4-4-3` 승인 대상 ⇒ 다음 세션이 승인받아 기록 |

---

### ▣ O182-A-3 ⚪ 미착수 — ㉡ 워크스페이스 백로그 (O181 계열 승계)

> 🔴 `-O0181-B` ▣2 · `-O0181-A` ▣3 이 **그대로 유효**하다. 아래는 요약 색인이며 정본은 그 파일이다.

| # | 항목 | 정본 |
|---|---|---|
| B-1 | 🔴 `--vars` 판별 실험 A·B(**사용자 실행** · `R4-1`) + 런북 2곳 문안 정정 | `-O0181-A` ▣6 |
| B-2 | 🟠 열린 문항 잔여 27건 `J3` 실측(판정식 = `**판정**` 줄의 `____`) | `-O0181-B` ▣2-2 |
| B-3 | 🟠 §E 질문 재발행 · §M-4 질문 분할 발행 | `-O0181-B` ▣2-3·4 |
| B-4 | 🔴 원장 `-002` 여유 240 B — `retire_rows.py` 또는 재균형(🔴 승인) | `-O0181-B` ▣2-5 |
| B-5 | 🟠 `sv_code_label_gate` 재측정 조건(문서40 3건 입고 시) | `-O0181-B` ▣2-6 |
| B-6 | 🟢 **`GRANT UPDATE` 처분 = ▣ O182-A-6 dbt 롤 신설로 흡수** — 🔴 별도로 REVOKE 하지 마라 | `-O0181-B` ▣2-7 |
| B-7 | ⚪ W3 결정·설계 대기 8건 · B2~B12(M-4·`-001:167`·회신 6·§N-13·W1 금지·문서02·`TASK_DW_*`·`_BATCH_ID`) | `-O0181-A` ▣3 |
| B-8 | ⚪ 착수표 ⑭(FME.SPONSORSHIP_SK 다중사업 현업 회신) · ⑩(이월 묶음 잔여 2축) | `00_BRIEF` §1 |
| B-9 | ⚪ 문서50 열린 절 6건(BLOCKING-2·5 · 누락/과잉 GOLD 6 · 순서9-C · O91-F · O59-P-1) | `00_BRIEF` §3 |

---

### ▣ O182-A-4 🔴 환경 함정 (이번에 실제로 밟은 것)

1. 🔴 **`python3 - <<'EOF' … </dev/null` 은 스크립트를 읽지 못한다** — heredoc 과 `</dev/null` 이 stdin 을 다툰다. rc=0 인데 **아무것도 안 했다**. 🟢 스크립트 파일(`_scratch_*.py`)로 만든다.
2. 🔴 **SQL 도구로 긴 렌더 SQL 을 보낼 수 없다** ⇒ 🟢 `snowflake.connector` + `SNOWFLAKE_TOKEN_FILE_PATH`(oauth) 로 스크립트에서 실행하면 된다(`host`·`account` 환경변수 · 이 세션 실증).
3. 🔴 **`table_ddl_column_gate` 는 `ref` 를 라이브 테이블로 푼다** ⇒ 모델만 바꾸고 DDL 재실행 전에 돌리면 **정상적으로 FAIL**(invalid identifier). DDL 실행 후 재측정하라.
4. 🟠 `grep -rln` 에 `20_issue` 전체 + `99_NEXT_SESSION_조각` 을 함께 넘기면 rc=143(분모 과대 · `J1`).

---

### ▣ O182-A-5 📏 종료 기준선 (2026-09-28 · xf98254 · 🔴 인용하지 말고 재라)

- dbt build 전체 = PASS 542 · WARN 22 · ERROR 0 · SKIP 0 · TOTAL 564(사용자 실행)
- SILVER AGENCY: ROW_DGT 29,048 · ROW_VIDEO 46,353 · ROW_REBRDC 2,104 · PERFORMANCE 77,505 · BROADCAST 48,457 · DIGITAL 29,048 · CREATIVE 3,366 · CASE 0
- GOLD: FACT_AD_PERFORMANCE 77,505 · FACT_AD_BROADCAST 48,457 · FACT_AD_DIGITAL 29,048 · FACT_AD_BROADCAST_CASE 0 · DIM_AD_CREATIVE 3,367
- ML: `ML_ONCE_CONVERSION_V` 관측 37,198행 · 회원 8,144 · 최신 관측 기준 모델 전환분류 8명
- Agent 기본 버전: MEMBER/EXECUTIVE/MARKETING = VERSION$3(도구 12/8/7)
- 게이트: handoff_ddl 7축 PASS · jinja PASS · sv_identifier PASS(27건) · line_len PASS · `table_ddl_column_gate` **rc=0**(build 후 재측정 · GOLD 37 + SILVER 42 · AGENCY 8종 전건 순서 일치)
- `_scratch_*` 잔존 0(3개 생성 → 개별 삭제 확인)

---

### ▣ O182-A-6 🔴 dbt 전용 롤 설계안 (다음 세션 착수 · 사용자 질문에 대한 답)

**질문** = 「GN_DW_ENGINEER 를 업데이트하는 방식으로 하면 되나?」
**답(권고)** = 🔴 **ENGINEER 를 고치지 말고 `GN_DW_DBT` 를 새로 만든다.** 이유 3가지:
- ㉠ ENGINEER 는 **사람(작업자)+dbt 혼용**이다 — 권한을 줄이면 작업자가, 늘리면 dbt 가 과잉이 된다. 분리해야 각자 최소권한이 된다
- ㉡ `profiles.yml` 3곳(`role: GN_DW_ENGINEER` · :12·:25·:34)을 바꾸는 것만으로 **전환·롤백이 1줄**이다
- ㉢ ENGINEER 는 그 뒤 **작업자 권한으로 축소**하면 된다(한 번에 하지 말고 dbt 롤 전환 build PASS 확인 후)

**최소권한 표(실측 근거)**

| 스키마 | GN_DW_DBT 권한 | 근거 |
|---|---|---|
| BRONZE_* | USAGE + SELECT(ALL/FUTURE) | source 읽기만 |
| SILVER | USAGE + INSERT·DELETE·TRUNCATE(ALL/FUTURE) · 🔴 **UPDATE 불요** | 전 모델 `append` + `silver_purge` 훅 · merge 0건(O182 실측) |
| GOLD | USAGE + INSERT·**UPDATE**·DELETE·TRUNCATE + CREATE VIEW | dim 은 `unique_key` 만 있고 전략 미지정 ⇒ **기본 merge**(O182 실측) · wide 는 view |
| SNAPSHOT | USAGE + CREATE TABLE + DML | dbt snapshot |
| OPS · dbt_test__audit | USAGE + CREATE TABLE | store_failures(`07_…RBAC` D.6) |
| 웨어하우스 | GN_DW_ETL_WH USAGE | 적재 전용 |

🔴 **먼저 확인할 것(착수 전 3줄 실측)**
1. **OWNERSHIP** — 테이블 소유자가 `GN_DW_ADMIN` 이다(SILVER 8종 실측). dbt 가 타입 변경 `ALTER` 를 스스로 발행하면 OWNERSHIP 이 필요하다(`dbt_project.yml:207-210` O121) ⇒ 현행과 같은 제약이 dbt 롤에도 걸린다(악화 아님).
2. **FUTURE GRANT 중복** — `07_…RBAC` 은 같은 스키마에 ALL/FUTURE 를 ENGINEER 에 이미 주고 있다(:216·:248·:344·:352). 스키마 FUTURE GRANT 는 역할별로 공존한다(충돌 아님).
3. **레포 밖 적재기** — `SILVER.BIGQUERY_REFINED_DATA` 외부 Python 적재가 어떤 롤로 쓰는지 확인(UPDATE 사용 여부 미확인).

**수정 대상 파일** = `02_GN_DW_building/07_ENVIRONMENT_RBAC_setup.sql`(D 절에 DBT 롤 블록 신설 · 계층도 :69) · `10_dbt_pipeline/profiles.yml` · `02_GN_DW_building/01_환경 Role.md` · 런북.
🔴 **`R4-4-3`** = 롤 생성·GRANT·ENGINEER 축소는 **라이브 권한 변경**이므로 SQL 은 에이전트가 쓰고 **실행은 승인 후**.

_Co-authored with CoCo_

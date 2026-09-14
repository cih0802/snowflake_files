<!-- LLM-METADATA
doc_id: O159_MSTR_IMPACT_MEASURE
doc_role: MSTR_DW 참조문서 ↔ 라이브 SILVER·GOLD 대조 실측 근거(판정 근거 원문 보관용)
project: GN_DW (굿네이버스)
created: 2026-09-14
created_by: O159
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

# O159 — MSTR_DW 참조문서 ↔ 라이브 SILVER·GOLD 대조 실측 근거

> 🔴 판정 근거 원문 보관용(`R1-3-7-c`). 계정 = 맥락 · 근거 = 조회 결과(`R3-9 ㉤`).
> 측정 = 2026-09-14 · 역할 `ACCOUNTADMIN` · WH `COMPUTE_WH` · DB `GN_DW`.
> 대상 문서 = `99_provided_definition/COCO_mstr_dw_reference.md`(2026-08-20 기준) ·
> `99_provided_definition/COCO_mstr_virtual_structure_reference.md`.
> 두 파일의 스테이지 타임스탬프 = **2026-09-14 05:45**(이번 세션 직전 입고).

---

## A. 🔴 문서 등재 상태 — 정본 어디에도 없다

`grep -rn "COCO_mstr" 20_issue/ 99_NEXT_SESSION_조각/ 00_guides/` = **rc=1 · 0건**.

- ⇒ MSTR 참조문서는 **이슈 원장·설계·인수인계에 미등재**다.
- ⚠️ `grep -rln "MSTR" 20_issue/` 적중 3건은 전부 **`MASTER` 약어 오탐**이다
  (`TM_RM_CHILD_MSTR_INFO` · `TM_RM_RELATNSP_MSTR_INFO`) ⇒ 선행 검토 이력이 아니다.
- 🔴 `rc` 주의(`R0-8-1`): 최초 `grep -rln "MSTR" scripts/ 20_issue/ 00_guides/` 는
  **rc=143(SIGTERM)** 으로 죽어 0건을 냈다 — 분모를 쪼개 재측정한 값이 위 결과다.

## B. 🔴🔴 원문 인용 — MSTR 정본이 요구하는 3개 규칙

> `COCO_mstr_dw_reference.md` §1 원칙 5 (`offset=1 limit=100` 도착 · 고유 토큰 `SPNSR_AMT_CNT`)
> *"`SPNSR_AMT_CNT` 는 일반적인 행 수가 아니다. 기본적으로 `SPNSR_AMT / 10000.0` 으로
> 계산되는 금액 환산 건수다."*

> 같은 문서 §3 (고유 토큰 `1→I`, `2→S`)
> *"법인 `CPR_DIV_CD` | DW에서는 주로 `I`=사단, `S`=사복. 일부 ODS에서는 `1`/`2` 이므로
> `1→I`, `2→S` 변환 적용"*

> 같은 문서 §3.1 (고유 토큰 `CM019`)
> *"법인 | `CM019` | `I` 사단, `S` 사복"*

> 같은 문서 §6.1 (고유 토큰 `ZV000000` · `ZC000029`)
> *"A(최상위) → B(DEPT4) → C(DEPT3) → D(DEPT2) → E(상세 DEPT)"* ·
> *"최상위: `A.UPPER_DEPT_ID = 'ZV000000'`"* · *"`C.DEPT_ID <> 'ZC000029'`"*

## C. 🟢 이미 구현되어 있어 「변경 없음」인 항목 — 개발구분 1·2·4 한정

`GN_DW.GOLD.FACT_MEMBER_EVENT` 그룹 집계 실측 =

| `DVLP_DIV_CD` | `DVLP_DIV_NM` | 행수 | `SUM(DEV_CNT)` | `SUM(DEV_MEMBERS)` | `SUM(SPNSR_AMT)` |
|---|---|---:|---:|---:|---:|
| `1` | 신규 | 1,788,612 | 1,788,612 | 1,788,612 | 33,033,020,890 |
| `2` | 증액 | 367,295 | 367,295 | 367,295 | 14,251,550,042 |
| `3` | 감액 | 292,285 | **0** | **0** | -12,443,707,772 |
| `4` | 재후원 | 135,971 | 135,971 | 135,971 | 2,392,565,214 |
| `5` | 후원중단 | 1,010,680 | **0** | **0** | -21,521,239,722 |
| `NULL` | `NULL` | 1,038,262 | **0** | **0** | `NULL` |

- ⇒ `DEV_CNT` 합 = **2,291,878** = 코드 `1+2+4` 정확히 일치.
- 🟢 MSTR 공#121 「개발구분 = 신규·증액·재후원」은 **이미 배선돼 있다**(O24 소관).
- ⇒ 🔴 **「개발 대상 코드를 엄격화하면 수치가 바뀐다」는 판정은 성립하지 않는다.**
- ⚠️ `NULL` 1,038,262행 = `EVENT_TYPE='STOP'` 원천 계통(중단 원천).
  MSTR 로직으로 `DVLP_DIV_NM='후원중단'`(1,010,680)과 합산하면 **이중계상**이다
  (설계문서 `03_top-down_gold/03_테이블 설계.md` FME 절의 🔴 합산 금지 경고와 동일 축).

## D. 🔴 진짜 갭 1 — 1만원 환산 건수(`SPNSR_AMT_CNT`)는 개발·증감 축에 없다

| 지점 | 실물 | 판정 |
|---|---|---|
| `FACT_MEMBER_MONTHLY.sql:313` | `aa.ACTIVE_BIZ_AMT / 10000 as ACTIVE_CNT` | 🟢 활동 축은 환산 적용 |
| 같은 파일 `:321`·`:322`·`:325`·`:326` | `YEAR_START/YEAR_END/MONTH_END/PREV` 계열 `/10000` | 🟢 적용 |
| 같은 파일 `:28` | `-- ⚠️ DEV_CNT = FME 사건수(금액/10000 아님 — 별도트랙)` | 🔴 **개발 축 미적용** |
| `05_SV-Agent_ai/05_2_SV_DDL_MEMBER_EVENT.sql:151` | `정본이 (건) = 금액÷10,000 으로 정의하므로(CONF-2) 행수로 세면 정의 파괴` | 🟠 인지됨 |
| 같은 파일 `:155` | 감액 measure = **금액(원, 음수)** · 주석에 `정본 공#38(감액(건)=금액÷10,000)과 단위·정의가 다르다(O24 미확정)` | 🔴 **미확정 상태로 열려 있다** |

- 🟢 **MSTR 문서의 기여** = 그 `O24 미확정`을 **확정할 정본 근거를 제공한다**
  (§1 원칙 5 = `SPNSR_AMT_CNT = SPNSR_AMT / 10000.0`).
- 🔴 그러나 **환산을 어느 축에 적용하는지**는 문서가 정하지 않는다
  (개발 축 `DEV_CNT` 를 환산으로 바꾸면 위 C 의 2,291,878 이 **정의부터 달라진다**)
  ⇒ **현업 확정 없이 배선하지 않는다.**

## E. 🔴🔴 진짜 갭 2 — `CPR_DIV_CD` 에 문서에 없는 `A` 코드가 21,167행 있다

`GN_DW.SILVER.CRM_MEMBER` 실측 =

| `CPR_DIV_CD` | 행수 |
|---|---:|
| `I` | 1,502,598 |
| `S` | 239,299 |
| **`A`** | **21,167** |
| `NULL` | 1 |

- 🟢 **`COCO_mstr_virtual_structure_reference.md` §17 질문 4 해소** —
  이 계정의 코드체계는 **`I`/`S`(DW 표기)** 이고 `1`/`2` 가 아니다
  ⇒ MSTR 문서가 지시한 `1→I`·`2→S` **변환은 불필요**하다.
- 🔴🔴 **그러나 문서 §3.1 `CM019` 는 `I`·`S` 2종만 정의한다** ⇒ `A` **21,167행은 문서 밖**이다.
  MSTR 규칙을 문자 그대로 적용하면 이 21,167행은 **조용히 탈락하거나 미분류로 뭉개진다.**
- 🔴 `A` 의 의미를 **창작하지 않는다**(`R2-7-1`) ⇒ **현업 확인 항목**이다.

## F. 🔴 진짜 갭 3 — 법인 축이 GOLD 차원에 존재하지 않는다

라이브 `INFORMATION_SCHEMA` 실측 = `CPR_DIV_CD` 보유 객체 =
`GOLD.DIM_CAMPAIGN` · `SILVER.CRM_CAMPAIGN` · `SILVER.CRM_MEMBER` · `SILVER.CRM_MEMBER_DEV` ·
`SILVER.CRM_PAYMENT_BILLING` · `SILVER.CRM_PAYMENT_METHOD` · `SILVER.CRM_SPONSORSHIP`.

- 🔴 **`GOLD.DIM_MEMBER` 에 `CPR_DIV_CD` 가 없다**(실물 24컬럼에 부재).
- 🔴 **`GOLD.DIM_SPONSORSHIP` 에도 없다**(실물 11컬럼에 부재).
- ⇒ MSTR `D_CPR_DIV_CD`(법인 차원 · `CM019`)와 `D_SPNSR_BSNS_INFO.CPR_DIV_CD` 를
  **현행 GOLD 로 재현할 수 없다** — SILVER 까지 내려가야 한다.
- ⚠️ 설계문서 `03_테이블 설계.md` D6 주석은 *"법인은 회원속성 `CPR_DIV_CD`"* 라고 적지만
  **그 회원속성이 `DIM_MEMBER` 에 노출돼 있지 않다** ⇒ 문서와 라이브의 축이 어긋난다.

## G. 🔴 진짜 갭 4 — 부서 계층이 4단이고 MSTR 은 5단을 요구한다

라이브 `GOLD.DIM_ORG` 실물 컬럼 =
`ORG_SK · ORG_DK · CORP · DIVISION · DEPARTMENT · TEAM · ACMSLT_UPPER_DEPT_ID ·
ACMSLT_DEPT_YN · USE_YN · DW_*`.

- MSTR `D_DEPT_CD` 요구 = `DEPT_ID`·`DEPT2_ID`·`DEPT3_ID`·`DEPT4_ID`·`DEPT5_ID` = **5단**.
- 🟢 재귀 전개 재료(`ACMSLT_UPPER_DEPT_ID`)는 `SILVER.CRM_ORG`·`GOLD.DIM_ORG` **양쪽에 있다**.
- 🔴 그러나 현행 4단(`CORP`/`DIVISION`/`DEPARTMENT`/`TEAM`)은 **레벨 정의가 이미 열린 이슈**다
  (`CONF-4` · 착수 대기 `ORG-H`/`F-1` = `STATS_DEPT_LVL` NULL 1,306 · 기획실 협의 중).
- ⇒ 🔴 **MSTR 5단을 지금 배선하면 열린 현업 결정을 에이전트가 선점하는 것**이다 ⇒ 금지.
- ⚠️ MSTR 상수 `ZV000000`(최상위) · `ZC000029`(제외 부서)는 **이 계정 데이터로 미검증**이다
  (이번 세션 미측정 · 배선 전 실측 필요).

## H. 🔴🔴 자기검토 — 이번 세션 답변의 확정 위반

이번 세션(대화 `85844620` · JSONL 15레코드)에서 **SQL 실행 0 · 코드 수정 0** 이었고,
실질 답변은 **2건**(레코드 2 · 4)이다. 그 2건에 아래 결함이 있다.

### H-1 🔴 컬럼명 창작 8건 (`R2-3`·`R2-7-1` 위반)

라이브 `INFORMATION_SCHEMA` 대조 결과 **부재**로 확인된 표기 =

| 답변에 쓴 이름 | 라이브 실물 | 판정 |
|---|---|---|
| `DEV_AMT` | 부재 (금액은 `FACT_MEMBER_EVENT.SPNSR_AMT`) | 🔴 창작 |
| `REDUCED_MEMBERS` | `FACT_MEMBER_MONTHLY.DECREASE_CNT` | 🔴 창작 |
| `CUMULATIVE_DEV_MEMBERS` | `ACTIVE_CUM_CNT`·`ACTIVE_CUM_MEMBERS`·`AMT_DECREASE_CUM_CNT` | 🔴 창작 |
| `UNPAID_MEMBERS` | `UNPAID_CNT`·`STATUS_UNPAID_CNT`·`UNPAID_FLAG_EOM` | 🔴 창작 |
| `NEW_OLD_DIV_CD` (DIM_MEMBER) | `FACT_MEMBER_MONTHLY.NEW_EXISTING_FLAG` | 🔴 창작 |
| `DEPT_LV1`~`DEPT_LV5` | `CORP`·`DIVISION`·`DEPARTMENT`·`TEAM` | 🔴 창작 |
| `DIM_MEMBER.CPR_DIV_CD` | 부재 (§F) | 🔴 창작 |
| `DIM_SPONSORSHIP.CPR_DIV_CD` | 부재 (§F) | 🔴 창작 |
| `CRM_PAYMENT_BILLING.SETLE_KEY` | `CRM_PAYMENT_METHOD.SETLE_KEY` | 🔴 소속 테이블 오기 |

⚠️ `UNPAID_MEMBERS` 는 설계문서 `03_테이블 설계.md` FMM 절에 문자열로 **존재한다**
⇒ 🟠 **설계문서 쪽이 라이브와 어긋난 것**이고, 내 오류는 그것을 **실측 없이 인용**한 것이다.

### H-2 🔴 이미 구현된 것을 「변경된다」로 판정 (§C)

`DEV_CNT` 코드 1·2·4 한정과 `ACTIVE_CNT` 계열 `/10000` 환산은 **이미 배선**돼 있는데
「MSTR 로직 적용 시 바뀐다」로 서술했다. ⇒ 실제 델타는 **§D·E·F·G 4건**뿐이다.

### H-3 🔴 열린 현업 결정을 침범할 처방 (§G)

`DIM_ORG` 5단 재정렬을 「설계 변경 사항」으로 제시했다. 그 축은 `CONF-4`·`ORG-H`/`F-1` 로
**현업 협의 중**이고 착수표 ⑭ 와 같은 등급의 정지점이다 ⇒ 제시 자체가 부적절했다.

### H-4 🔴 절차 위반 3건

| 축 | 위반 |
|---|---|
| `R4-4-1`·`A5` | 세션 착수 브리핑 미출력 — 사용자가 3턴째에 `init_ihcho` 를 직접 호출했다 |
| `R1-3-1`·`R1-3-5` | 두 MSTR 문서(729줄·945줄)를 **부분만** 읽고(`dw_reference` 1~202 · `virtual_structure` 본문 0줄) 부분 독해 사실을 **명시하지 않았다** |
| `R1-3-7-a` | `read` 미반환(`Output too large`) **4건**(두 MSTR 문서 · `03_테이블 설계.md` · `08_silver의존.md`) 좌표·건수를 기록하지 않았다 |
| `R4-3` | 단답형 위반 — 대형 표 2개로 답했다 |

🔴 `virtual_structure_reference.md` 는 **본문 0줄 확보 상태에서 인용**했다.
⇒ 그 문서 소관 판정은 **전부 근거 미확보**였다(`R1-3-7` 「대체 근거 금지」 정면 위반).
🟢 이번 세션에서 §17 질문 4·§18 안내문 구간은 재확보했다(미리보기 꼬리 + 재호출).

## I. 🟢 최종 정정 판정 — MSTR 문서가 실제로 바꾸는 것

| # | 대상 | 실제 델타 | 정지점 |
|---|---|---|---|
| 1 | `FACT_MEMBER_EVENT` 증액·감액 (건) / SV `05_2` | `O24 미확정` → MSTR §1 원칙 5 로 **확정 근거 확보**. 환산 적용 축은 미정 | 🔴 현업 확정 전 배선 금지 |
| 2 | `SILVER.CRM_MEMBER.CPR_DIV_CD` | `I`/`S` 확정(변환 불요) · **`A` 21,167행 문서 밖** | 🔴 현업 확인 |
| 3 | `GOLD.DIM_MEMBER` · `DIM_SPONSORSHIP` | 법인 축 **부재** ⇒ MSTR 법인 차원 재현 불가 | 🟠 설계 결정 |
| 4 | `GOLD.DIM_ORG` | MSTR 5단 ↔ 현행 4단 · 상수 `ZV000000`/`ZC000029` 미검증 | 🔴 `CONF-4`·`ORG-H` 협의 중 |

🟢 **변경 없음** = 개발구분 1·2·4 한정 · 활동 축 `/10000` 환산 · `ACMSLT_UPPER_DEPT_ID` 재료 보유.
🔴 **이 문서만으로 착수 가능한 항목은 0건**이다 — 4건 전부 현업 결정 또는 설계 결정에 걸린다.

_Co-authored with CoCo_

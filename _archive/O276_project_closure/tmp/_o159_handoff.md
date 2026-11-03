
---

## 0-GGGG. 🔴🔴 [2026-09-14 O159 필독 — **여기서 시작한다.** §0-FFFF 는 승계됐다]

### ▣ GGGG1 🟢 O159 이 한 일 — MSTR_DW 참조문서 최초 검토 + 직전 답변 자기검토 정정

1. 🔴 **MSTR 참조문서 2종이 신규 입고됐고 정본에 미등재였다**:
   - `99_provided_definition/COCO_mstr_dw_reference.md`(729줄) ·
     `COCO_mstr_virtual_structure_reference.md`(945줄) · 스테이지 타임스탬프 **2026-09-14 05:45**.
   - `grep -rn "COCO_mstr" 20_issue/ 99_NEXT_SESSION_조각/ 00_guides/` = **rc=1 · 0건**
     ⇒ 선행 검토 이력 없음. O159 가 최초 검토다.
   - 🟢 정본 근거철 = **`20_issue/_o159_mstr_impact_measure.md`**(실측 원문 · 인용 좌표 포함).
2. 🟢 **「이미 배선되어 변경 없음」 2건 실측 확정**:
   - `GOLD.FACT_MEMBER_EVENT` `SUM(DEV_CNT)` = **2,291,878** = 개발구분 `1·2·4` 정확 일치
     ⇒ MSTR 공#121 은 이미 구현됨(O24 소관).
   - 활동 축 1만원 환산 적용 = `FACT_MEMBER_MONTHLY.sql:313·321·322·325·326`.
3. 🔴 **직전 답변의 확정위반 4계열을 자체 적발·정정**: 컬럼명 창작 **9건** ·
   브리핑 미출력(`A5`) · MSTR 문서 부분 독해 인용(`virtual_structure` **본문 0줄**) · 단답형 위반.
   - 🟢 9건 전건은 라이브 `INFORMATION_SCHEMA` 대조로 실물명 확정(근거철 §H-1).
4. 🟢 **원장 조각 재균형(승인 처리 · `R4-4-3`)**: O159 행 추가로 조각-001 이 41,864 B 가 되어
   `--rebalance --fill 0.7` 실행 ⇒ max **28,299 B** · 최소 여유 **12,661 B** · 유실 0.

### ▣ GGGG2 🔴 MSTR 문서가 만든 신규 열린 항목 4건 — 착수 가능은 0건이다

🔴 **네 건 모두 현업 결정 또는 설계 결정에 걸린다. 임의 배선 금지.**

- 🔴 **[신규 · P1/현업확인] MSTR-1 `CPR_DIV_CD` 에 문서 밖 `A` 코드 21,167행**:
  `SILVER.CRM_MEMBER` 실측 = `I` 1,502,598 · `S` 239,299 · **`A` 21,167** · `NULL` 1.
  🟢 `virtual_structure` §17 질문 4 **해소**(이 계정은 `I/S` ⇒ `1→I`·`2→S` 변환 불요).
  🔴 그러나 문서 §3.1 `CM019` 는 `I`·`S` 2종만 정의 ⇒ `A` 의 의미를 **창작하지 말고 현업 확인**.
  ⚠️ 규칙을 문자 그대로 적용하면 21,167행이 **조용히 탈락**한다.
- 🔴 **[신규 · P1/현업확인] MSTR-2 증액·감액 (건) 금액÷10,000 환산 축 확정**:
  SV `05_2_SV_DDL_MEMBER_EVENT.sql:151·155` 가 `O24 미확정` 을 스스로 적는다.
  🟢 MSTR §1 원칙 5(`SPNSR_AMT_CNT = SPNSR_AMT / 10000.0`)가 확정 근거를 준다.
  🔴 **적용 축이 미정**이다 — 개발 축(`DEV_CNT`)에 걸면 위 2,291,878 이 정의부터 달라진다.
- 🟠 **[신규 · P2/설계] MSTR-3 법인 축이 GOLD 차원에 없다**:
  `GOLD.DIM_MEMBER`(24컬럼)·`DIM_SPONSORSHIP`(11컬럼) 에 `CPR_DIV_CD` **부재**
  ⇒ MSTR `D_CPR_DIV_CD`·`D_SPNSR_BSNS_INFO.CPR_DIV_CD` **현행 GOLD 로 재현 불가**.
  ⚠️ 설계문서 `03_테이블 설계.md` D6 의 *"법인은 회원속성 `CPR_DIV_CD`"* 서술과 라이브가 어긋난다.
- 🔴 **[신규 · P1/차단] MSTR-4 부서 5단 요구 ↔ 라이브 4단**:
  라이브 `DIM_ORG` = `CORP·DIVISION·DEPARTMENT·TEAM` ↔ MSTR `D_DEPT_CD` 는 `DEPT_ID`~`DEPT5_ID`.
  🔴 이 축은 **`CONF-4` · `ORG-H`/`F-1`(기획실 협의 중)과 동일 대상**이다
  ⇒ **MSTR 5단을 먼저 배선하면 열린 현업 결정을 선점한다. 금지.**
  ⚠️ MSTR 상수 `ZV000000`(최상위)·`ZC000029`(제외 부서)는 **이 계정 데이터로 미검증**이다.

### ▣ GGGG3 🟠 O159 가 적발했으나 고치지 않은 것 (판단 필요)

- 🟠 **설계문서 stale 1건**: `03_top-down_gold/03_테이블 설계.md` FMM 절의
  `UNPAID_MEMBERS` 가 라이브에 없다(실물 = `UNPAID_CNT`·`STATUS_UNPAID_CNT`·`UNPAID_FLAG_EOM`).
  🔴 컬럼 정의 소관 결정이 필요해 **문안을 바꾸지 않고 적발만 등재**했다(`R1-2`).
- 🟠 **MSTR 문서 전량 독해 미완**: O159 는 판정에 필요한 구간(`dw_reference` §1~§6.1 · §17·§18)만
  확보했다. 🔴 **실제 배선에 착수하는 세션은 두 문서를 전량 독해해야 한다**(729줄 · 945줄).

### ▣ GGGG4 🔴 기존 열린 작업 (승계 · §0-FFFF 에서 변동 없음)

- 🔴 **[P1/차단] 착수표 ⑭**: `FME.SPONSORSHIP_SK`(STOP) 동시중단 다중사업 귀속 규칙.
- 🔴 **[P1/현업회신] ORG-H / F-1**: `DIM_ORG` 4단 계층(`STATS_DEPT_LVL` NULL 1,306)
  — 🔴 **위 MSTR-4 와 같은 축이다. 함께 결정해야 한다.**
- 🔴 **[P1/현업회신] O145-5**: 권역본부 목표 행 의미(자체목표 vs 산하합산 · 3.27배).
- 🔴 **[P2/Silver] O59-P-1**: `FACT_MESSAGE_DISPATCH.SEND_STATUS2` 처분.
- 🔴 **[P3/원천입고] 19번 문서 12건**: `E-6`(`CRM_BIZ_TARGET` 0행) · `HOL-1` · `AD-5` · `PST-1` 등.
- 🟠 **[P3/Docs] 착수표 ㊳**: `_o125e_entry.md` 낡은 마운트 엔트리 모니터링(`rm` 금지).
- 🟠 **[P3/개명잔여] 축1 정비**: 잔여 421건 감시.

_Co-authored with CoCo_

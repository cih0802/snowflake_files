<!-- LLM-METADATA
doc_id: NEXT_SESSION_PROMPT
doc_role: 다음 세션 착수 프롬프트 — 이 파일만 읽고 바로 시작할 수 있게 구성
project: GN_DW (굿네이버스 데이터웨어하우스)
updated: 2026-08-07 (**O51-D — GOLD 뷰 컬럼 COMMENT 문안 355컬럼 완성 · 8모델 gn_view_commented 전환 · 빈 축 경고 43 · O45-B 해소 · ⛔dbt build 대기**. 착수는 §0-A 부터. 선행 O50/O51-C = 메커니즘 규명 + 6뷰 136컬럼 적용 + DEC-34 · 신규 P105~P113)
정본: 이슈=20_issue/00_INDEX_이슈원장.md · 진단·교훈=20_issue/10_진단_원인분석.md · 운영=02_GN_DW_building/06_RUNBOOK.md
편집 규칙: 이 문서는 **포인터 + 미결 항목 + 착수 프롬프트**만 담는다. 완료 작업의 경위는 정본에 두고 복사하지 않는다.
END-METADATA -->

# 99. 다음 세션 착수 프롬프트

## 0. 작업 규칙 (사용자 상시 지시)

1. 문서를 읽을 때 **중간에 끊기면 추론으로 채우지 말고 전부** 읽는다.
2. 작업 전에 `20_issue/` 를 읽고 **미해결·pending** 을 파악한다.
3. 데이터 작업은 COMMENT 를 근거로 단정하지 말고 **BRONZE 원본을 스캔해 실측**한다.
4. 큰 작업이 끝나면 `20_issue/` 를 갱신한다.
5. **`dbt build` 순서에 도달하면 멈추고 사용자 입력을 기다린다.**
6. 작업 완료 후 **단답형으로 짧게** 답한다.
7. **COMMENT 에 실측 수치를 넣지 않는다**(코드값만). 수치는 문서10·이슈원장에.
8. 🔴 **파일을 만들거나 고쳤으면 `cortex ws ls` 로 스테이지 실체를 확인한다** — §9 P102.
   `/workspace` 마운트의 `ls` 성공은 **스테이지 반영을 뜻하지 않는다.**
9. 🆕🔴 **로드맵 각 단계가 끝나면 그 자리에서 비판적 자기검토를 실행한다.** 형식:
   ① 이 단계에서 **내가 단정했지만 실측하지 않은 것**은 무엇인가 (→ 즉시 실측하거나 단정을 철회)
   ② **파일에 문장이 있는지**를 **효과가 있는지**로 착각한 곳은 없나 (→ `INFORMATION_SCHEMA` 스캔, P33)
   ③ 내가 **알아낸 수정을 미이행**한 채 넘어가지 않았나 (→ 마커만 남기고 넘어가는 것 금지, P105)
   ④ 이 단계에서 만든 **게이트를 대상이 존재하는 상태에서** 돌렸나 (P106)
   ⑤ 발견한 것을 `20_issue/` 에 등재했나
   ⛔ ①~⑤ 를 통과하지 못하면 **다음 단계로 넘어가지 않는다.**
10. 🆕 **완료 판정은 문서가 아니라 스캔이다**(P33). DDL 문장을 실행했다는 사실은 성공의 근거가 아니다.

---

## 0-A. 🔴 이번 세션(O51-D) 상태 — **`dbt build` 대기**. 여기서 시작한다

> ⛔ **첫 행동 = `dbt build`**(로컬 dbt). 그 다음 검증까지가 한 묶음이다.
> 사전검증은 전부 끝나 있다: `dbt parse` 통과 · 게이트 8/8 · 스테이지 전수 70/70 · 규칙 7 위반 0.

| 끝난 것 | 상태 |
|---|---|
| O51-D 문안 **355컬럼**(8객체) | ✅ yml 등재 완료 — `10_` 이관 206 · 기존 보존 17 · 신규 132 |
| 8모델 `materialized='gn_view_commented'` | ✅ 전환 + `post_hook` 전량 제거 |
| `DIM_MEMBER_CURRENT`·`DIM_MEMBER_ACQUISITION` | ✅ `_gold_ready_schema.yml` 신규 등재(O50 잔여 해소) |
| **O45-B** 결제수단 코드그룹 | 🟢 **해소** — PM040 확정. 처방은 `20_issue/50_…md` §O51-D-P1 |
| 빈 축 경고 43컬럼 | ✅ 부착 — 전건 NULL/전건 센티넬을 문안이 침묵하던 문제 |
| `(as-was)` 16건 | ✅ 교정 — DIM_ORG 는 SCD1(DEC-2)이라 거짓이었다 |

### ⛔ build 직후 반드시 할 검증 (이 순서로)

**0) build** — 파이프·리다이렉트 금지(클라이언트 파서가 거부한다). `--project-dir` 는 **워크스페이스 루트 기준 상대경로**다.
```
dbt build --project-dir /10_dbt_pipeline --select WIDE_MEMBER_MONTHLY WIDE_MEMBER_EVENT WIDE_SERVICE_EVENT WIDE_EVENT_PARTICIPATION WIDE_MEMBER_FEE WIDE_DEV_ACHIEVEMENT DIM_MEMBER_CURRENT DIM_MEMBER_ACQUISITION
```
⚠️ 8모델만 선택 실행이다. 전체 build 는 그 다음에 판단한다(WARN 추적표 §2 참조).

**1) 물리 COMMENT 355/355 확인** — 🔴 **완료 판정은 이것뿐이다**(P33). 분모를 함께 출력해 vacuous pass 를 배제한다(P106).
```sql
select table_name, count(*) cols, count(comment) commented, count(*) - count(comment) missing
from GN_DW.INFORMATION_SCHEMA.COLUMNS
where table_schema='GOLD' and table_name in
 ('WIDE_MEMBER_MONTHLY','WIDE_MEMBER_EVENT','WIDE_SERVICE_EVENT','WIDE_EVENT_PARTICIPATION',
  'WIDE_MEMBER_FEE','WIDE_DEV_ACHIEVEMENT','DIM_MEMBER_CURRENT','DIM_MEMBER_ACQUISITION')
group by 1 order by 1;
-- 기대: 80·62·57·53·39·19·20·25 = 355, missing 전부 0
```

**2) 빈 축이 다시 침묵하지 않는지**
```
python3 scripts/o51d_view_comments/nullscan.py
```
기대 = 전건 NULL 후보 전부 `✅문안 언급`.

**3) `(as-was)` 3뷰의 물리 COMMENT 가 교정됐는지** — O51-C 가 거짓을 물리에 배포했던 곳이다.
```sql
select table_name, column_name, comment
from GN_DW.INFORMATION_SCHEMA.COLUMNS
where table_schema='GOLD' and column_name in ('ORG_CORP','ORG_DIVISION','ORG_TEAM','ORG_DEPARTMENT')
  and comment ilike '%as-was%' and comment not ilike '%as-was 가 아니다%';
-- 기대: 0행 (3뷰가 이번 build 로 재생성되므로)
```

**4) 뷰 전체 커버리지** — 기대 **491/559**(제외 2뷰 68컬럼은 7단계 DROP 예정).

**5) 게이트 WARN 변화** — `warn_gold_view_comment_coverage` 가 통과로 바뀌는지. 8단계 error 승격의 선행조건이다.

### 🔴 build 실패 시

컬럼목록 불일치가 유일한 실패 모드다. `python3 scripts/o51d_view_comments/gate.py` 로 어느 모델인지 특정한 뒤
**yml 을 손으로 고치지 말고** `build_yml.py` → `reapply_cols.py` 로 재생성한다(순서 정본 = `ORDINAL_POSITION`).

### 생성기 (정본 — 손 편집 금지)

`scripts/o51d_view_comments/` : `desc_member`·`desc_own`·`desc_fee`·`desc_dim`·`desc_emptyaxis`(문안) ·
`build_yml`(생성) · `reapply_cols`(재반영) · `fix_as_was`·`switch_mat`(교정) · `gate`·`nullscan`(게이트) ·
`O51D_BRONZE_codescan.txt`(BRONZE 스캔 원자료).
⚠️ `desc_empty.py` 라는 이름은 **쓰지 말 것** — 그 경로가 스테이지에서 ENOENT 로 고착됐다(P99).

### 🔴 이번 세션에서 내가 저지른 것 (반복 금지)

| # | 무엇 | 교훈 |
|---|---|---|
| 1 | 규칙 7(COMMENT 에 수치 금지)을 **어긴 뒤, 재검토에서 "그 규칙은 없다"고 철회**했다. 대화의 6개 항목만 보고 이 문서의 10개를 확인하지 않았다 | **P111** 규칙의 정본은 문서다 |
| 2 | 경고 문안의 비율을 **행 가중**으로 적어 손실을 6배 축소해 보이게 했다(사라지는 것은 회원인데) | **P108** 경고의 비율은 보호 대상과 같은 분모로 |
| 3 | 멱등 가드가 **주석 문구에 오탐**해 8모델 전환을 조용히 스킵했다 | 가드는 대상 구조를 봐야 한다 |
| 4 | 스테이지 검증을 **손으로 고른 목록**으로 해서 파일 1개를 빠뜨렸고, 그 사이 stale 산출물이 반영됐다 | **P113** 디렉터리 전수 스캔으로 |
| 5 | 산문에 정규식 일괄 치환을 시도해 문장을 훼손했다 | **P112** 치환 결과를 읽어라 |

전량 경위·실측은 `20_issue/00_INDEX_이슈원장.md` §O51 → O51-D / O51-D-B / O51-D-C / O51-D-D.

---

## 1. 직전 세션(O50/O51-C)에서 끝난 것 — 다시 하지 말 것

> ⚠️ 이 절과 §2 는 **O51-D 이전** 세션의 기록이다. O51-D 결과는 **§0-A · §3** 에 있다.

| 끝난 것 | 결과 |
|---|---|
| **O51 원인 규명** | 🔴 **Snowflake 에 뷰 컬럼 COMMENT 를 사후 적용하는 문법이 없다.** 4변형 전부 실패 실측: `ALTER VIEW … ALTER COLUMN … COMMENT`(pos 61) · `… SET COMMENT`(pos 65) · `… MODIFY COLUMN … COMMENT`(pos 62) · `COMMENT ON COLUMN`(→ *"type 'VIEW', not 'TABLE'"*). 유일 경로 = **`CREATE VIEW` 인라인 컬럼목록** |
| `gn_view_commented` | ✅ `macros/gn_view_commented.sql` 신설. **로컬 dbt + 서버사이드 `EXECUTE DBT PROJECT` 양쪽에서 발화 확인**(뷰를 DROP 후 재생성시켜 구분). O42 의 「전역 매크로 미발화」는 **재발하지 않았다** — 내장 매크로를 덮지 않고 새 이름을 명시 호출하기 때문 |
| 컬럼 COMMENT 적용 | **6뷰 136컬럼 물리 반영**(`WIDE_TARGET_DEV` 10 · `_GA_BEHAVIOR` 38 · `_AD_PERFORMANCE` 32 · `_BUDGET` 21 · `_AD_BROADCAST_CASE` 18 · `_TARGET_BIZ` 17) |
| build 회복 | 깨진 post_hook 을 **16모델에서 제거** → `PASS=17 WARN=1 ERROR=0`. 게이트 WARN **15→10** |
| `WIDE_MEMBER_FEE` | ✅ 생성 — **GOLD 뷰 16개 완비**(종전 15/16, 이 뷰만 미생성이었다) |
| **DEC-34** | ✅ SV base 객체 선택 규칙 확정 — 정본 `05_SV-Agent_ai/04_SV_설계.md` **§0.8**. ①GOLD base FACT(기본) → ②SERVING helper 뷰(팩트 재구성 없음) → ③dbt 소유 GOLD 뷰(팩트 재구성). **②/③ 경계 = 「팩트를 재구성하는가」** |
| DEC-34-A 트리거 | ✅ 실측 통과 — `FACT_MEMBER_COHORT` **1,585,949 = distinct MEMBER_DK**(차원 자격) · `FMF ⋈ FMC` 팬아웃 0 · 결손 646,715(**1.606%**) → LEFT JOIN 필수 |
| 광고 위성 실측 | ✅ **완전분할** — 디지털 205,059 + 방송 38,486 = 코어 243,545 · 양쪽 0 · 미포함 0 · 조인 후 행수 불변. SILVER 도 동일 |
| 거짓 기재 정정 | `00_README`·`09`·`10`·`dbt_project.yml`·`_wide_schema.yml`·게이트테스트 **6파일** |

⚠️ **`06_DDL`·`08_SILVER` 재실행 금지** — 정본↔물리 불일치 0. 재실행하면 데이터만 날아간다(런북 §11).

---

## 2. 🔴 직전 세션(O50/O51-C) 비판적 검토 — 반복 금지

> 🔴 **공통 원인: 「있다」를 「작동한다」로 읽었다.** 파일·문장·문서의 존재를 효과의 증거로 취급했다.

| # | 무엇을 틀렸나 | 실측 |
|---|---|---|
| 1 | 🔴🔴 **`post_hook 16/16 = COMMENT 정본`** 이라고 5개 파일에 써넣었다 | GOLD 뷰 **520컬럼 중 COMMENT 0개(0.0%)**. 파일 존재만 세고 효과를 안 봤다 = **P33 위반**(그 규칙은 이미 문서에 있었다) |
| 2 | 🔴 게이트를 만들고 **0행 PASS 를 검증으로 취급** | 그 시점 GOLD 뷰가 **0개** = **공집합 통과**. 게이트를 무의미한 조건에서 돌려놓고 안심했다 → **P106** |
| 3 | 🔴 **경로 3연속 단정**(정의문 grep 없이) | `02_SERVING_setup.sql`(실제 스텁 0줄) · `§G`(2종뿐 · `FACT_AD_COMBINED` 는 `05_7_SV_DDL_AD.sql:57`) · GOLD 뷰 수 14(실제 **16** — `dim/` 2종 누락) |
| 4 | 🔴 **알아낸 수정을 미이행** | 「O50 전량 정정 필요」 마커까지 남기고 5파일의 거짓 기재를 방치했다. 세션 주제가 「거짓 성공 기록」인데 내가 만든 것을 남겼다 → **P105** |
| 5 | 🔴 **유일 사본을 지웠다** | `WIDE_MEMBER_FEE` 컬럼 문안은 `10_` 파일에 **없고** post_hook 에만 있었는데 지혈 중 삭제. 배포본 `snow://dbt/…/version$2/` 에서 `GET` 으로 복구 → **P107** |
| 6 | 🟠 도구 오류를 「결과 없음」으로 오독 | BusyBox `grep --include` 미지원 에러를 신호로 받아들였다. 결론은 우연히 맞았고 근거는 없었다 |

🟢 **기계 생성이 사람 눈보다 나았다** — 컬럼 문안 이관을 스크립트로 돌렸더니 `10_` 파일이 **존재하지 않는 컬럼 20건**을 지정하고 있음이 드러났다(O26 코드/라벨 리네임 미반영). 손으로 옮겼다면 순서 오류가 조용히 들어갔을 것이다.

---

## 3. 다음 세션 작업 — 병합 로드맵 (사용자 승인 2026-08-07)

> 🔴 **두 트랙이 있었고 중복이 있었다.** Track A = 기존 로드맵(`09` 보고서필드 조립가능성). Track B = 이번 세션 신규(GOLD 뷰/SV base 구조).
> 아래는 **중복을 제거해 병합한 순서**다. 종전 Track A 순서(#2→#3)를 그대로 하면 GOLD 스키마 변경 후 **재작업이 확정**이었다.
> ⛔ **각 단계 종료 시 §0-9 자기검토를 실행한다.**

| 순 | 작업 | 출처 | 완료 게이트 |
|---|---|---|---|
| ~~**1**~~ | ~~**O51-D — 87컬럼 문안 작성**~~ → ✅ **[2026-08-07 완료]** 실제로는 **8객체 355컬럼**으로 확대 실행됐다(87 은 신규 작성분의 일부 계산이었다). **§0-A 참조.** ⛔ **다시 하지 말 것.** 잔여는 `dbt build` 뿐이다 | B | ✅ TODO 0 · 8모델 전환 · 게이트 8/8 · `dbt parse` 통과 / ⛔ **물리 355/355 는 build 후 확인** |
| **2** | **Phase 1~2 — GOLD 최종형 (v5 확정 2026-08-10 · 원장 §O53)**. `06_DDL.sql` 신설 4종: `DIM_MONTH`(541행)·`DIM_MEMBER_CURRENT`(24컬럼)·`DIM_MEMBER_ACQUISITION`(라벨 내장)·`FACT_DEV_ACHIEVEMENT`(← `WIDE_DEV_ACHIEVEMENT` 개명) + dbt 뷰 신설 `WIDE_AD_COMBINED`(51컬럼). 🔴 **광고 3팩트 병합은 철회**(DEC-8 유지) | B | 31→**35테이블** · 뷰 16→**14** · 전 컬럼 COMMENT 100% |
| **3** | **Phase 3 검증 게이트** | B | `FACT_AD_PERFORMANCE`=**243,545 불변**(BRONZE replay 정합: DGT 205,059+REBRDC 2,070+VIDEO 36,416) · `DIM_MEMBER_CURRENT`=1,763,065 PK유일 · `DIM_MEMBER_ACQUISITION`=1,585,949 PK유일 · `DIM_MONTH`=541 · `FACT_DEV_ACHIEVEMENT` 목표행 보존 · **35테이블 COMMENT 100%** · 뷰 COMMENT **546** · DMC 4컬럼 채움 **FDRM 98.68/99.28/99.91/56.60% · ONCE 전건 0**(분모 확정 필수 · P128) |
| **4** | census/schema 재덤프 → **`09` 재생성 + 판정 오류 17건 교정 + 「집계필요」·「앵커_경합」 처방 쿼리 실행검증** | **A#2** (O49 중단분) | `09` md 에 SQL 블록 >0 · 집계필요 6건·경합 34행 쿼리 **실행 근거** 첨부 · 2-G 라벨 의심 2건 판정 |
| **5** | 골든 `scripts/golden/outputs.json` 갱신 | A#1 파생 | `test_generators.py` **17/17 PASS** |
| **6** | 🔴 **SV 9종 + Agent — 1회 편집·1회 배포**. base 재배선 **7종**(실측: `DIM_MONTH` 2 · `DIM_MEMBER_CURRENT` 4 · `FACT_AD_COMBINED` 1 · `WIDE_DEV_ACHIEVEMENT` 1 · 중복 제외) **＋** 판정 4종·경합·DEC-31 동일값 **동시**. ⚠️ `SV_DEV_ACHIEVEMENT` 1종만 **2단계에서 선행**(개명으로 base 소멸) | **A#3 ⊕ Phase 4** | SV **9/9 배포** · GATE-D(청구액 891,959,790,888 일치) · **`CREATE OR ALTER` + GRANT 9종 전수 + 소비 역할 세션 판정**(P125·P126) |
| **7** | **Phase 5 — 파괴적 정리**(⛔개별 승인). `SERVING.FACT_AD_COMBINED`·`DIM_MONTH`·`DIM_MEMBER_CURRENT` DROP. 🔴 **`GOLD.FACT_AD_DIGITAL`·`FACT_AD_BROADCAST` DROP 은 무효**(O53: 광고 병합 철회·DEC-8 유지) | B | `ACCOUNT_USAGE.OBJECT_DEPENDENCIES` 잔존 참조 **0** 확인 후 |
| **8** | **관문 dbt 승격** — `test_generators.py` 17종. 🔴 `warn_gold_view_comment_coverage` 는 **warn 유지**(사용자 결정) — 파일 헤더의 자동 승격 지시가 이 결정과 충돌하므로 **헤더를 고칠 것**(P130) | **A#4 ⊕ O51** | 승격 후 build ERROR=0 |
| **9** | **현업 질문서 마감** — §6 9건 + O51-D 미특정 코드그룹 합류 | A#5 | 회신 없이 진행 불가한 것 확정 |
| **10** | 문서·이슈 정리 — DEC-35(3계층 기준)·**DEC-8 유지 확정 기록**(반전 철회)·**DEC-34 §0.8-C 개정**(전량 테이블화 → 성격 기반·팩트 재구성형은 dbt GOLD 뷰)·O50/O51 종결 | Phase 6 | |

🔴 **6단계를 쪼개지 말 것** — `CREATE OR REPLACE SEMANTIC VIEW` 가 GRANT 를 파괴하므로 나누면 GRANT 재실행이 2배가 된다.
🟢 **[2026-08-10 O52-B 보강]** 더 나은 경로가 이미 원장에 있다 — **정의만 바꿀 때는 `CREATE OR ALTER SEMANTIC VIEW`**
  를 쓰면 **GRANT 가 보존**된다(`20_issue/10_진단_원인분석.md` §129 실측). `CREATE OR REPLACE` 는 GRANT 를 파괴한다.
  ⚠️ 본 세션에서 이 처방을 놓쳐 SV 2종의 GRANT 를 실제로 파괴했다(즉시 복구 · 원장 §O52-B · **P125**).
  ⇒ **권한 검사는 게이트로 고정됐다**: `scripts/sv_unit_gate.py`(비율 단위 + SV GRANT 6건/9종 전수).
🔴 **2단계가 `09` 판정의 입력을 바꾼다** — `gen_section_assembly.py:58-59` 가 `/tmp/census.json`·`/tmp/schema.json`(GOLD 실 스키마)을 읽는다. 그래서 4·5 가 2·3 뒤에 온다.

### 🔴 로드맵 진행 현황 — 2026-08-10 실측 (사용자 질의 「전부 완료됐나」에 대한 답)
**아니다. 10단계 중 완료 1 · 진행중 1(2단계) · 부분완료 2 · 미착수 6.** *(2026-08-10 O53 갱신)*

| 순 | 작업 | 상태 | 실측 근거 |
|---|---|---|---|
| 1 | O51-D 문안 | 🟢 **완료** | + **O51-F** 로 확장 종결 — 뷰 COMMENT **559/559 (100%)** |
| 2 | Phase 1~2 GOLD 최종형 | 🟢 **구조 완료 · ⛔ `dbt build` 대기 (2026-08-10 O53)** | 착수 시 실측: GOLD 테이블 **31**(DIM 17+FACT 14) · `06_DDL.sql` 내 GOLD `CREATE TABLE` **31** = 배포 실측과 완전 일치(**replay 전제 성립** · `dbt_project.yml:51` 「24테이블」은 stale) · `GOLD.DIM_MONTH` **없음** · `FACT_DEV_ACHIEVEMENT` **없음** · `DIM_MEMBER_CURRENT` **20컬럼 VIEW** · `DIM_MEMBER_ACQUISITION` **25컬럼 VIEW** · `WIDE_DEV_ACHIEVEMENT` **19컬럼 VIEW**(37,522행·`ORG_SK\|DEV_TYPE\|MONTH_KEY` 유일). 🔴 **광고 병합은 철회**(DEC-8 유지 · 사용자 결정 = BRONZE 증량 확장성) → 목표 **35테이블**. 계획 결함 7건·지침 위반 4건·문서 stale 6건을 **실행 전** 적발·교정(원장 §O53).<br>✅ **실행 결과(0~4단계)**: GOLD **테이블 35(619/619 COMMENT)** · **뷰 13**(build 후 `WIDE_AD_COMBINED` 생성 시 14) · 신규 84컬럼 · PK 4종 · 소비 4역할 SELECT 실측 · dbt 모델 5종(4종 append+TRUNCATE) · `dbt parse` 경고 0 · 컬럼순서 게이트 8/8 · 생성기 게이트 자기검사 9/9. ⛔ **5단계 = 사용자 `dbt build`** |
| 3 | Phase 3 검증 게이트 | 🟠 **build 후 실행 대기** | 구조 게이트는 이미 통과(테이블 35·619/619·PK·권한). 남은 것은 **행수·유일성·채움률** 판정이며 `dbt build` 이후에만 가능하다 — 기대치는 로드맵 3단계 열 참조 |
| 4 | `09` 재생성 + 판정오류 17건 | 🔴 **미착수** | 완료 게이트 = 「`09` md 에 SQL 블록 >0」 → 실측 **0** · 파일 mtime 2026-08-07 |
| 5 | 골든 `outputs.json` 갱신 | 🔴 **미착수** | mtime 2026-08-07(미갱신) |
| 6 | SV 9종 + Agent | 🟡 **부분완료** | ✅ SV **9/9 배포** · 스모크 9/9 · GATE-D 일치 · Agent 2종 도구 **9/9 배선** · GRANT 9종 전수 정상(복구 후) / 🔴 **미완**: ① base 재배선(SERVING→GOLD·뷰→테이블)은 **2단계 선행 필요** — SV 가 여전히 `SERVING.DIM_MONTH`·`DIM_MEMBER_CURRENT`·`FACT_AD_COMBINED` 를 참조 ② 판정 4종·경합·DEC-31 동일값 반영은 **4단계 선행 필요** |
| 7 | Phase 5 파괴적 정리 | 🔴 **미착수** | SERVING helper 3종 잔존. ⚠️ 2뷰 DROP 은 **철회**(O51-F) · ⚠️ `GOLD.FACT_AD_*` 2종 DROP 도 **무효화**(O53 · 광고 병합 철회) |
| 8 | 관문 dbt 승격 | 🔴 **미착수** | `warn_gold_view_comment_coverage` 는 **warn 유지**(사용자 결정 2026-08-10) — 🔴 실측 GOLD 뷰 **559/559 = WARN 0** 이라 파일 헤더의 자동 승격 트리거가 **이미 충족** 상태다. 헤더와 사용자 결정이 충돌하므로 **헤더 교정 필요**(P130) · `test_generators.py` 17종 미승격 |
| 9 | 현업 질문서 마감 | 🔴 **미착수** | §6 9건 + O51-D 미특정 코드그룹 |
| 10 | 문서·이슈 정리 | 🟡 **부분** | O51/O52/**O53** 원장 등재 완료 · `40_입고대기` **CMP-1**(캠페인 상위코드·공통코드 신설 예고) 등재 완료 / ⬜ DEC-35 · **DEC-8 유지 확정 기록** · **DEC-34 §0.8-C 개정** 미작성 |

⛔ **현재 착수점 = 2단계**(Phase 1~2 GOLD 최종형 · **v5 확정**). 3·4·5·6잔여·7 이 전부 여기에 물려 있다.
🔴 2단계는 **O51-D/O51-F 와 충돌 지점 3개**가 있다 — 바로 아래 §「2단계 착수 시 반드시 볼 것」을 먼저 읽을 것.
🟢 **[2026-08-10 O53] v5 실행 순서** — ⓿ 원장·문서 등재(완료) → ❶ 사전검증(문안 64 수집 + 신규 4 + `WIDE_AD_COMBINED` 51 이관 + `06_DDL` 4블록 기계 생성 + `scripts/table_ddl_column_gate.py` **신설** + 스테이지 전수 스캔) → ❷ `06_DDL` **전체 재실행 금지 · 신규 `CREATE TABLE` 4문장만** → ❸ dbt 5모델(전환·신설 4종은 **`append`+`pre-hook TRUNCATE`** · `WIDE_AD_COMBINED` 는 뷰) + yml 재배치 + `dbt parse` → ❹ 참조처(SV DDL `05_8` · dbt 테스트 **2건** · 커버리지 게이트 헤더 · GOLD 스키마 COMMENT **14** · 문서 12곳) → ❺ ⛔ **`dbt build` 정지선** → ❻ `SV_DEV_ACHIEVEMENT` **1종만** `CREATE OR ALTER` + GRANT 소비역할 판정.
  🔴 **merge 금지 근거**: `20_issue/50_…md` §300 R1 — `IS_CURRENT` 필터 차원에 merge 를 쓰면 구 현재행이 잔존해 **팬아웃 차단이 무너진다**(P131).

### ✅ O51-D 결과 (2026-08-07 완료 — 실행 상세는 §0-A)

| 객체 | 물리컬럼 | 문안 출처 |
|---|---:|---|
| `WIDE_MEMBER_MONTHLY` | 80 | 이관 66 + 신규 14 |
| `WIDE_MEMBER_EVENT` | 62 | 이관 38 + 신규 24 |
| `WIDE_SERVICE_EVENT` | 57 | 이관 42 + 신규 15 |
| `WIDE_EVENT_PARTICIPATION` | 53 | 이관 41 + 신규 12 |
| `WIDE_MEMBER_FEE` | 39 | 기존 보존 17 + 신규 22 |
| `WIDE_DEV_ACHIEVEMENT` | 19 | 이관 19 |
| `DIM_MEMBER_CURRENT` | 20 | 신규 20 |
| `DIM_MEMBER_ACQUISITION` | 25 | 신규 25 |
| **합** | **355** | 이관 206 · 보존 17 · **신규 132** |

🔄 **[2026-08-10 O51-F]** 종전 *"❌ 제외 2뷰 = `WIDE_AD_BROADCAST`·`WIDE_AD_DIGITAL`(7단계 DROP 예정)"* 은 **철회됐다.**
두 뷰는 **보존**하고 `10_` §7-A·§7-B 문안 **68컬럼을 이관 완료**했다(생성기 `build_ad_yml.py` → `patch_ad_yml.py`).
⇒ 이관 총계 = **423컬럼 / 10객체**(O51-D 355 + O51-F 68). 상세·근거 = 이슈원장 §O51-F.

⚠️ **`columns[]` 는 SELECT 와 개수·순서가 정확히 일치해야 한다**(부분 목록은 Snowflake 가 거부). 순서 정본 = `ORDINAL_POSITION`.
**손으로 옮기지 말고 `scripts/o51d_view_comments/build_yml.py` → `reapply_cols.py` 로 재생성**한다.

🔴🔴 **2단계 착수 시 반드시 볼 것 — O51-D 와 충돌하는 지점 3개**
1. **`DIM_MEMBER_CURRENT` 를 24컬럼 합집합으로 바꾸면** 현재 등재된 20컬럼 `columns[]` 와 어긋나 **build ERROR** 가 된다.
   ⇒ 모델 SELECT 변경과 `columns[]` 재생성을 **같은 커밋에서** 한다. 신규 4컬럼 문안도 그때 작성한다.
2. **`DIM_MEMBER_CURRENT`·`DIM_MEMBER_ACQUISITION`·`WIDE_DEV_ACHIEVEMENT` 를 테이블로 전환하면**
   `materialized='gn_view_commented'` 를 **`table` 로 되돌려야** 한다. 테이블은 `COMMENT ON COLUMN` 이 먹으므로
   인라인 컬럼목록이 불필요하고 **컬럼목록 일치 제약도 사라진다**(단 COMMENT 적용 경로를 별도로 심어야 한다).
3. `WIDE_DEV_ACHIEVEMENT` → `FACT_DEV_ACHIEVEMENT` **개명 시 `_wide_schema.yml` 의 `- name:` 도 옮긴다** — 안 옮기면 문안 19건이 유실된다.

🟢 **부산물**: `10_WIDE VIEW 코멘트.sql` 은 **정본 이관 완료·이력 전용**으로 강등됐다(헤더 명시).
그 파일의 컬럼명 **20건이 존재하지 않는 컬럼**(O26 리네임 미반영)이었고 **`(as-was)` 16건이 거짓**(DIM_ORG 는 SCD1·DEC-2)이었다 — 둘 다 교정 완료.

---

## 4. 현재 상태 (2026-08-07 실측)

| 계층 | 상태 |
|---|---|
| BRONZE | **51**테이블 (CRM 43 · AGENCY 4 · ERP 1 · GA4 3) |
| SILVER | **39**테이블 |
| GOLD | **31**테이블(DIM 17 + FACT 14) + 뷰 **16** · 총 **136,575,490행** · 정보성 FK 50 |
| GOLD 컬럼 COMMENT | 테이블 **535/535 (100%)** · 뷰 🟢🟢 **559/559 (100%)** — 2026-08-10 O51-F build ③차 후 실측. 규칙7 위반 0 · 빈축/센티넬 경고 침묵 0(설계상 면제 8 = `DW_SOURCE_SYSTEM`) |
| SERVING | 일반뷰 **3** · SV **7종** · Agent **2종**(`AGENT_MEMBER`·`AGENT_OVERALL`) |
| 🔴 SV 미배포 | **`SV_DEV_ACHIEVEMENT` · `SV_MEMBER_FEE`** — base 였던 dbt 뷰가 없어서 생성 못 했다. 이제 base 는 존재하므로 6단계에서 배포 |
| 최근 build | 🟢 **2026-08-10 O51-F build ③차 완료** — `PASS=376 WARN=27 ERROR=0 SKIP=0 TOTAL=403`. 물리 GOLD 뷰 **559/559** 확인. WARN 27 = 기존 27(커버리지 게이트는 **PASS 로 전환**). ⚠️ 게이트는 **warn 유지**(사용자 결정 — 원천 증량 시 파이프라인을 세우지 않는다) |
| DBT PROJECT | `GN_DW.OPS.DW_PIPELINE` · **VERSION$2(alias `O51C_PROBE`) = default·last**. ⚠️ O51-D 변경분은 **워크스페이스에만** 있다 — 서버사이드 실행이 필요하면 `deploy_dbt_project` 로 새 버전을 올려야 한다 |
| `30_output_share` | 17종 — 🔴 **2단계 이후 재생성 필요**(GOLD 스키마 변경) |

**GOLD 뷰 16개 처분 계획**(2단계 이후 → **13뷰**)
- 존속 13: `WIDE_MEMBER_MONTHLY`·`_MEMBER_EVENT`·`_MEMBER_FEE`·`_TARGET_DEV`·`_TARGET_BIZ`·`_SERVICE_EVENT`·`_GA_BEHAVIOR`·`_AD_PERFORMANCE`·`_AD_BROADCAST_CASE`·`_EVENT_PARTICIPATION`·`_BUDGET`·**`_AD_DIGITAL`·`_AD_BROADCAST`**
- 테이블 전환 3: `DIM_MEMBER_CURRENT` · `DIM_MEMBER_ACQUISITION` · `WIDE_DEV_ACHIEVEMENT`(→`FACT_DEV_ACHIEVEMENT`)
- ~~DROP 2~~ → 🔄 **철회(2026-08-10 O51-F · 사용자 결정)**: `WIDE_AD_DIGITAL`·`WIDE_AD_BROADCAST` **보존**.
  근거 = ① 두 뷰는 dbt 모델이라 물리 `DROP VIEW` 만으로는 다음 build 가 되살린다(진짜 DROP = 모델 삭제)
  ② 모델 헤더가 이미 `gn_view_commented` 이관을 처방하고 있었다 ③ DEC-8/DEC-10 이 **위성 단독 완결**을
  설계 의도로 명시한다(1:1 이라 fan-out 0) ④ `04_SV_설계.md` §542 가 SV 제외로 지목한 것은 1:N 인
  `_AD_BROADCAST_CASE` 뿐이다. ⇒ **68컬럼 COMMENT 이관 완료**(이슈원장 §O51-F).

**신규 계정 재현 순서**
`07_ENVIRONMENT_RBAC_setup` → `06_DDL` → `08_SILVER_테이블DDL` → `deploy_dbt_project` → **dbt build**
→ `08_After_Deploy_DBT`(§G helper 뷰 2종) → `05_1`~`05_9_SV_DDL_*` → `09_1_AGENT` → **`09_2_AGENT_버전업`**

🔴 자주 빠지는 3곳: ① `07` 누락 → `06_DDL.sql` 즉사 ② `dbt build` ③ **`09_2`**(`09_1` 은 껍데기).
⛔ 실행 금지(포인터 스텁): `13_SV_AD_배포_추가작업.sql` · `09_AGENT_spec_구현.sql` · `02_SERVING_setup.sql`.
⛔ **실행 금지(문법 자체가 무효)**: `03_top-down_gold/10_WIDE VIEW 코멘트.sql` — O51 참고본 강등.

---

## 5. Agent 스펙 — 정본 경로와 배포 절차

🔴 **정본은 `cortex_project/agents/<AGENT>/agent_spec.yaml` 하나다.** 파일명 반드시 `agent_spec.yaml`
(공식 문서의 `agent.yaml` 예시는 부정확 — 틀리면 `No spec file present` 로 실패).

⛔ 루트 `cortex_project/AGENT_*.agent.yaml` 은 `cortex_project/_archive/` 로 이관 — **복원 금지**.
🔴 **`cortex_agent_save`/`cortex_agent_deploy` 를 쓰지 말 것** — live 버전을 만들어 `ADD VERSION FROM` 을 거부시킨다.

**절차**: 스펙 수정 → `ALTER WORKSPACE USER$.PUBLIC."snowflake_files" COMMIT` → `09_2_AGENT_버전업.sql`
→ `SHOW VERSIONS IN AGENT` 로 `is_default` **실측** → 아니면 `SET DEFAULT_VERSION = 'VERSION$n'`(P66).

---

## 6. 현업 회신 대기 (사용자 소관)

| # | 항목 | 회신이 없으면 막히는 것 | 문서 |
|---|---|---|---|
| 1 | 🔴 **DEC-33 발송 유형 3건** — 코호트 모집단 정의 / 귀속 기간 / 채널 차등 | `FSE.D5_*` 8컬럼 | 20 §L-1 |
| 2 | 🔴 **중단보고 「후원사업」** = (가) 끊은 사업(코드5) vs (나) 데려온 사업(획득 차원) | 중단보고 후원사업 축 | 20 §L-2 |
| 3 | 🟠 **O28 오염 4행 정정** — 후보 `110`(`Success`) | `PART_STATUS` 정합 | 20 §I-2 #4 |
| 4 | 🟠 **O28 소정수 1~6 의미**(캠페인행사) | FEP 상태별 카운트 5종 | 20 §I-2 |
| 5 | 🟠 **O45-B** `SETLE_CD` 미라벨 5종(225,855행 · 0.48%) | `SV_MEMBER_FEE` 결제수단 라벨 | 00 §O45 |
| 6 | 🟠 **Q10** 광고비 배분 규칙 | 개발캠페인 grain ROAS | 20 |
| 7 | 🟠 **O19** `DIM_SPONSORSHIP` 6종 코드 라벨 · **O5** `GA_CONV_CNT` 어의 | SV 차원 라벨 | 20 |
| 8 | 🟠 **CONF-3** `ACTIVE_CNT` 분모 · **CONF-4** 상위 조직 산출규칙 | 활동회원 지표 · 본부/지부 분해 | 10 §25-C |
| 9 | 🟠 **O38-D** 개발목표가 「신규」에만 편성되는 것이 방침인가 · `GOAL_CNT=0` 의 의미 | `SV_DEV_ACHIEVEMENT` 달성율 비대칭 | 00 §O38-D |
| 10 | 🆕 **O51-D 미특정 코드그룹** — 1단계 BRONZE 스캔에서 도메인이 확정되지 않는 코드가 나오면 합류 | 뷰 컬럼 COMMENT 정확성 | 1단계 산출 |

---

## 7. 필독 문서 (순서대로)

| # | 문서 | 왜 |
|---|---|---|
| 1 | `20_issue/00_INDEX_이슈원장.md` | **이슈 정본**. 최상단이 시간 역순 |
| 2 | `05_SV-Agent_ai/04_SV_설계.md` **§0.8** | 🆕 **DEC-34 SV base 선택 규칙** — SV 를 만지기 전 필독 |
| 3 | `05_SV-Agent_ai/04_SV_설계.md` **§6.9** | 🔴 SV 구조적 제약 8건(반복 위반됨) |
| 4 | `10_dbt_pipeline/macros/gn_view_commented.sql` | 🆕 뷰 컬럼 COMMENT 메커니즘 + Snowflake 제약(전 컬럼·순서 일치) |
| 5 | `10_dbt_pipeline/dbt_project.yml` `models.gold.wide` 블록 | 🆕 객체 소유주 표 · FUTURE VIEWS grant 전제 |
| 6 | `30_output_share/09_보고서필드_조립가능성.md` §1·§3-B | 판정 11종 의미표 · 집계필요 · 앵커 경합 |
| 7 | `20_issue/30_설계_의사결정.md` §22 | DEC-31(종결)·32(철회)·33(성격변경)·**34(SV base)** |
| 8 | `02_GN_DW_building/06_RUNBOOK.md` §3.3·§11 | 평상시 컬럼 변경 / 전체 재구축 |
| 9 | `20_issue/50_dbt_파이프라인_미결조치.md` | WARN 27 정본·복귀조건 |

---

## 8. 교훈 색인 — 신규 (P105~P113)

> P105~P107 = O50/O51-C 분 · **P108~P113 = O51-D 분**(아래 표). 전문은 `20_issue/00_INDEX_이슈원장.md` §O51.

| 교훈 | 요지 |
|---|---|
| **P108** | **경고에 붙이는 비율은 그 경고가 보호하려는 단위와 같은 분모로** 제시한다. `1.61%`(행 가중)로 적었는데 사라지는 것은 회원이고 회원 기준은 `9.92%` 였다 — 분모 선택이 손실을 6배 축소해 보이게 했다 |
| **P109** | **「추측하지 않았다」가 탐색을 멈추는 근거가 되면** 해소 가능한 것을 미결로 방치한다. O45-B 는 코드그룹이 처음부터 PM040 으로 특정돼 있었고 SILVER 가 이미 그것으로 조인하고 있었다 — 3주 방치 |
| **P110** | **「값이 없다」는 컬럼 문안의 1급 정보다.** 전건 NULL 35 + 전건 센티넬 11 = 43컬럼이 그 사실을 침묵했다. 전건 센티넬(`'(미매핑)'`)은 문자열이라 **GROUP BY 가 성공한 것처럼 보인다** — NULL 보다 위험하다 |
| **P111** | **규칙의 정본은 문서다.** 대화에 요약된 6개 항목을 전체로 착각해, 어긴 규칙(§0 규칙 7)을 재검토에서 **"그 규칙은 없다"고 철회**했다 |
| **P112** | **산문에 정규식 일괄 치환은 품질 저하를 조용히 만든다.** 정제기가 `"( 채움 일부)"`·`"사전 복수"` 를 생성했다 — 치환 후 결과를 읽지 않으면 못 본다 |
| **P113** | **스테이지 검증은 디렉터리 전수 스캔으로** 한다. 손으로 고른 목록은 빠뜨린 파일을 구조적으로 못 본다(파일 1개 누락 → stale 산출물이 반영됐다) |

- **P105** 🔴 **경고문은 게이트가 아니다.** `10_WIDE VIEW 코멘트.sql` 헤더에 *"한쪽만 고치면 drift"* 가 3개월 있었고
  그 사이 drift 가 3건 발생했다. **규약을 사람의 성실성에 맡기면 조용히 깨진다.**
  → ① 규약은 **실행되는 검사**로 바꾼다 ② 🔴 **「고쳐야 한다」를 알아낸 그 자리에서 고친다** — 마커만 남기고
  넘어가면 그 마커가 다음 세션의 거짓 기록이 된다(내가 이 세션에 실제로 그랬다).
- **P106** 🔴 **게이트를 「대상이 없는 상태」에서 돌린 통과는 검증이 아니다(vacuous pass).**
  COMMENT 커버리지 게이트를 만들고 0행 PASS 를 받았는데 그때 GOLD 뷰가 **0개**였다.
  → ① 게이트는 **대상 건수를 함께 출력**하게 만든다(분모 0 이면 SKIP 이 아니라 실패로 본다)
  ② 🔴 **사본 개수 비교는 무의미할 수 있다** — 이번엔 세 사본(12/13/16)이 **전부 물리에 0** 을 반영했다.
  분자를 세기 전에 **메커니즘이 작동하는지**를 먼저 확인한다.
- **P107** 🔴 **유일 사본을 지우기 전에 어디에 또 있는지 확인한다.** `WIDE_MEMBER_FEE` 컬럼 문안은
  정본 문서에 **없고** 모델 post_hook 에만 있었는데 리팩터 중 삭제했다.
  → ① 삭제 전 `grep` 으로 **다른 소재지 존재를 확인** ② 🟢 **dbt 배포본이 백업이다** —
  `GET 'snow://dbt/<DB>.<SC>.<PROJ>/versions/version$N/<path>' 'file:///tmp/recover/'` 로 복구 가능
  (⚠️ 목적지 디렉터리를 **먼저 `mkdir`** 해야 한다) ③ 복구해 보니 그 post_hook 도 **17/39(44%)** 였다 —
  「post_hook 이 완전하다」는 전제 자체가 사실이 아니었다.
- **P108** 🟠 **이름이 실체를 숨긴다.** `WIDE_DEV_ACHIEVEMENT` 는 `WIDE_` 접두어이지만 평탄화가 아니라
  **팩트↔팩트 FULL OUTER + 사전집계 + 윈도우**다(Kimball 의 consolidated fact). `DIM_MEMBER_ACQUISITION` 도
  `DIM_` 이지만 실체는 팩트(`FACT_MEMBER_COHORT`) 기반이다.
  → 접두어로 성격을 추론하지 말고 **정의문을 열어본다.** 개명 대상은 2단계에서 처리.

**기존 핵심 색인**
- **P33** 🔴 **완료 판정은 문서가 아니라 `INFORMATION_SCHEMA` 스캔이다** ← 이 세션에 내가 위반한 규칙
- **P36** 숫자 코드의 **우연 일치**로 라벨을 붙이지 않는다(의미 무관 코드그룹이 실제로 6개 나왔다)
- **P57** 물리 `ALTER` 만 하고 정본 DDL 에 접지 않으면 다음 재구축에서 소실
- **P61** 부정형 서술(*"미적재/비활성/불가"*)은 **축 활성화 때마다 회수** — SV·Agent instruction·도구 description 까지
- **P62-B** **자기교정은 전파되지 않는다** — 인용처를 `grep` 으로 찾아 함께 고친다
- **P82** `ERROR=0` 은 성공 신호가 아니다 · **P85** 「자동 생성물」 표기가 신선함을 보장하지 않는다
- **P90** 검사기가 「가능」이라 하면 **그 조인을 실제로 실행해 행수·합계를 재라**
- **P94** 가용성 추정은 **낙관 편향** · **P97** 「가능하다」와 「해야 한다」는 다르다
- **P98** 수기 문서가 생성기 입력이면 **문서 편집은 코드 변경**이다
- **P99·P102** 스테이지 마운트에서 「복사했다」≠「존재한다」 — §9
- **P100** 경합·차단의 원인을 쓸 때는 **그 섹션 필드를 실제로 열어본다**
- **P101** 시간 근접성은 인과가 아니다 · **P67** 합계 일치는 grain 정확성의 근거가 아니다
- **P103**(O48) 생성기 회귀 테스트 · **P104**(O49) 필드가 요구하는 **시간 grain** 을 판정에 넣어야 한다
- **PROC-3** 기대값이 어긋나면 **원인 규명 전에 어느 쪽도 인용하지 말 것**

---

## 9. 운영 환경 지뢰

- 🟢 **계정 정지 해소** — O49 를 막았던 `000666 (57014) account is suspended` 는 풀렸다. 웨어하우스 실행 가능
  (`GN_DW_DEV_WH`). GOLD·SILVER **적재 완료**(136.5M / 112.1M).
- 🆕 **dbt 실행 2경로**
  - 워크스페이스 로컬: `dbt build --project-dir /10_dbt_pipeline --select <sel>` (⚠️ 경로는 `/10_dbt_pipeline`,
    `/workspace` 접두어 없이. 산출물 `/tmp/dbt/target/`)
  - 서버사이드: `ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE ADD VERSION <alias> FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline/'`
    → `EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS = 'build --select <sel>'` (산출물 `/tmp/dbt_output/target/`)
  - ⚠️ `EXECUTE DBT PROJECT` 에 **`VERSION =` 파라미터는 없다** — `default_version = LAST` 이므로 `ADD VERSION` 이 곧 기본이 된다
  - ⚠️ dbt 명령에 **쉘 연산자(파이프·리다이렉트·`&&`) 금지** — 클라이언트 파서가 거부한다. `dbt --version` 도 불가
  - ⚠️ jinja `config()` **안에 `#` 주석을 넣으면 컴파일 오류**다(`unexpected char '#'`). 설명은 `--` SQL 주석으로 블록 **밖**에
- 🔴🔴 **P102 — `/workspace` 마운트의 `ls` 는 반영 증거가 아니다.** 확인은 **반드시**
  `cortex ws ls 'USER$.PUBLIC."snowflake_files":/'`. **루트 파일 쓰기가 특히 자주 소실된다.**
  ⚠️ 스테이지 크기는 **16바이트 배수 패딩** → 대조는 `0 ≤ 스테이지−원본 < 16`.
- 🔴 **작업 사본은 `$HOME/work/` 에 둔다.** `/tmp` 는 세션 중에도 초기화되고 `/workspace` 루트는 쓴 파일이 사라진다.
  업로드: `cortex ws cp $HOME/work/<파일> 'USER$.PUBLIC."snowflake_files":/<폴더>/'`
  (⚠️ 목적지는 **폴더**이고 `/` 로 끝나야 하며 **리네임 불가** · 다운로드 `/versions/head`, 업로드 `/versions/live`)
- 🔴 **생성기를 수정하면 즉시 업로드하고 `cortex ws ls` 로 확인**한다 — 과거 이 장애로 생성기 소스 1종이 유실됐다.
- 🔴 샌드박스 python 은 `sys.path[0]` 이 runfiles 고정 → `sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))`.
- 산출물 재생성 순서: `dump_schema.py` → `census_columns.py`(수 분 · 백그라운드) → `gen_column_mapping.py`(04)
  → `gen_metric_gold_mapping.py`(05) → `gen_section_assembly.py`(09) → 그 외 독립(03·06·07·08).
  🔴 재생성 전 **입력 파일 존재 확인**(`05` 생성기가 `04` CSV 를 출력 디렉터리에서 찾는다).
- BusyBox `grep` 은 **`--include` 미지원** — 에러가 「결과 없음」처럼 보인다. 전역 검색은 Grep 도구를 쓴다.
- `find` 는 심링크 미추적 → `/usr/bin/find -L /workspace` 또는 `/workspace/`.
- SQL 도구 토큰 만료 시 python `snowflake.connector` + `/snowflake/session/token`(매번 새로 읽는다) = `scripts/sfconn.py`.
- `hashlib.md5` 는 FIPS 모드에서 실패 → `sha256` · CTE 명에 `asof` 금지(`ASOF JOIN` 예약어 충돌).
- 트라이얼 계정: `SNOWFLAKE.CORTEX.DATA_AGENT_RUN` **차단** → NL 검증은 사람이 Snowsight UI 에서.
- `EXPLAIN`(= SQL 도구의 `only_compile`)이 `INFORMATION_SCHEMA.VIEWS` 에서 권한 오류를 낸다 → 실행으로 검증한다.

---
_Co-authored with CoCo_

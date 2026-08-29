<!-- SPLIT-CHUNK 99_NEXT_SESSION.md | 006/019 | 허브 = 99_NEXT_SESSION.md | 원문 666~820행 -->
<!-- 🔴 이 파일은 원문 무변경 조각이다. 편집은 허브 계약을 따른다 (scripts/split_doc.py --verify 로 바이트 동일성이 검사된다). -->
<!-- BODY-BEGIN (아래는 원문 무변경 · 편집 금지) -->
## 0-JJJ. 🔴🔴 [2026-08-26 O102 필독 — ~~여기서 시작한다.~~ **⇒ [O105] 시작점은 위 §0-KKK 다.**]

> 착수 지시(O102) = 사용자 「`99_NEXT §0-III ▣HH` 미결 3건을 우선순위 순으로 처리」.
> ① `SV_MEMBER_COHORT.CAMPAIGN_NAME` 시점 혼합 건을 `20_현업확인_요청.md` **N-9** 로 등재했다.
> ② `20-007 §N-8`(`MKTG_UTM` 고아코드 `192`)은 **회신이 아직 없다** — 판정 셀 공백 확인, 대기 유지.
> ③ `decision_closure_gate` 21건 중 `DEC-43` 신규분 13건 = **게이트 오탐** 판정(▣KK) ·
> 회귀검증은 `O101 ▣II` 기준선과 결과 동일(▣LL · 단 1행은 축 동일성 미증명 = 동형 검증).
> 🔴🔴 **착수 시 계정이 또 바뀌어 있었다** — `CURRENT_ACCOUNT()` = **`ZL50263`** = **5차 이관**
> (계보 `ls82944→os09358→DV07626→UA93987→NX55103→ZL50263` · 정본 4차 = `NX55103`(O88 · `02-005:15·18`)).
> ⚠️ 초판 「6차」는 오기이며 정정했다(▣MM ㉠). 🟢 데이터는 이관 완료라 재측정이 가능했다 —
> SILVER **43테이블** · GOLD **37테이블+14뷰** · SERVING **뷰 10** · SV **17** · Agent **3** 실재 ·
> 빈 테이블은 `CRM_BIZ_TARGET`·`FACT_TARGET_BIZ` **2종뿐**(`E-6` 원천 대기 · 기지의 정상).

### ▣JJ 🟢 N-9 등재 (정본 = `20_현업확인_요청.md` N-9 · 판정 공백 = 회신 대기)

캠페인 12속성 중 8속성은 획득 시점 동결값(`ACQ_*`)인데 `CAMPAIGN_NAME` 만 `DIM_CAMPAIGN` 실시간
조인이다(`DEC-43` §29-B 목록에 캠페인명 자체는 없어 **의도적 범위 밖**) ⇒ 획득 시점 동결로 확장할지 문의.
⚠️ **실측** — `DIM_MEMBER_ACQUISITION.ACQ_CAMPAIGN_NAME` 은 **이미 존재**(ordinal 16) ⇒ 회신 시
신설이 아니라 **이 컬럼이 동결원인지 실시간 조인인지 배선 확인**이 선행이다.

### ▣KK 🟡 `decision_closure_gate` `DEC-43` 버킷(13건) = **게이트 오탐 · 닫을 인용처 없음**

게이트가 §29 종결선언으로 추출한 줄은 본문이 아니라 **자기시정 각주**(*"`DEC42` 는 `O96` 이 이미
사용…부분 종결…"*)이고 `CLOSE_WORDS`(종결)가 거기 매칭돼 첫 라벨 **`O96`** 을 「닫은 대상」으로
오추출했다 — `DEC-43`(캠페인 동결)은 `O96`(예산연도 라벨 충돌)을 닫지 않는다 ⇒ 미봉합 13건은
**전부 `O96`/`DEC-42`(예산) 인용처**다. 🟢 근거는 **내용 기반 비순환 재검색**으로 교체(`12속성` ∪
`스냅샷 동결` ∪ `N-7` 중 `DEC-43` 미포함 = `20-007:143` **1건**뿐이고 같은 절 `:160` 이 *"확정 —
`DEC-43`"* ⇒ 절 단위 봉합) · 초판의 `grep DEC-43` 근거는 순환이었다(▣MM ㉣).
⚠️ 잔여 `DEC-41`(6)·`DEC-42`(7)=13 은 **기존 미결**(`O8` 캠페인귀속·`FACT_BUDGET` 월 grain) — 존치.

### ▣LL 🟢 O101 §▣II 기준선 회귀검증 (2026-08-26 계정 `ZL50263` 재측정 · 축·분모 병기)

| 대조 | O101 기준선 | O102 재측정 (계정 `ZL50263`) | 판정 |
|---|---|---|---|
| 동결값 ↔ 라이브 `DIM_CAMPAIGN` 조인값 (기준선 6속성 ↔ **본 세션 동명 7속성**: `CMMN_BRND_NM`·`MKTG_UTM_NM`·`SPNSR_DIV_NM`·`CPR_DIV_NM`·`BRAND`·`PARENT_CAMPAIGN_NAME`·`PROMO_METHOD_NAME`) | 불일치 0/1,585,949 | **불일치 0/1,585,949** | 🟡 **동형 검증**(축 동일성 미증명) · 결과 동일 |
| SILVER↔GOLD 이중계산(`PARENT_CAMPAIGN_NAME`·`PROMO_METHOD_NAME` · `CMPGN_CD`=`CAMPAIGN_BK` 조인) | 불일치 0/36,163(채움 34,704) | **불일치 0/36,163 · 채움 34,704=34,704** | 🟢 동일 축 · 회귀 없음 |
| `MKTG_UTM` 코드/라벨 채움 · 고아 `192` (**분모 = SILVER `CRM_CAMPAIGN` 36,163**) | 93.96%/34.00%·21,682건 | **93.96%/34.00%·21,682건** | 🟢 동일 축 · 회귀 없음 |
| `MKTG_CMPGN_NM` 코드/라벨 채움 (동 분모) | 93.90%/74.40% | **93.90%/74.40%** | 🟢 동일 축 · 회귀 없음 |
| 회원 축 전파 `ACQ_MKTG_UTM_NM` / `ACQ_MKTG_CMPGN_NM` | 18.27% / 63.74% | **18.27% / 63.74%** | 🟢 동일 축 · 회귀 없음 |
| `CRM_CAMPAIGN`·`DIM_CAMPAIGN`·`FACT_MEMBER_COHORT`·`DIM_MEMBER_ACQUISITION` 행수 | 36,163·36,164·1,585,949·1,585,949 | **36,163·36,164·1,585,949·1,585,949** | 🟢 회귀 없음 |

🟢 **결론 = 계정이 바뀌어도 `DEC-43` 구현 결과는 전건 동일**(데이터 자체가 이관됨 · `R2-8-4` 충족).

### ▣MM 🔴 O102 자기검토 — 확정결함 5건 (전건 시정 · **경위·총평 정본 = 이력 §O102-B**)

| # | 결함 | 조문 | 시정 |
|---|---|---|---|
| ㉠ | 계정 차수 **오기**(미검증 문장 전재 「6차」 → 실제 **5차** · 3곳 전파) | `R2-8` | 3곳 정정 |
| ㉡ | 기준선 **축 불일치**(▣II 「6속성」 ↔ 동명 7속성을 「전건 일치」로 단정) | `R2-6` | ▣LL 축 명시 · **동형 검증으로 격하** |
| ㉢ | **측정 객체 상이**(UTM 분모 SILVER 36,163 ↔ GOLD 36,164) | `R2-6` | SILVER 재측정(값 동일) |
| ㉣ | **순환 논증**(`grep DEC-43` 으로 「전건 DEC-43 명시」 주장) | `R2-5` | 내용 기반 재검색으로 근거 교체 |
| ㉤ | **객체 수 혼동**(「GOLD 51」= 테이블 37+뷰 14) | `R2-6` | 유형별 분리 기재 |

🟢 **작업 적절성** = ① 현업 문항화가 옳다(임의 확장은 `DEC-43` 범위 무단 변경) ② 회신 없음 ⇒ 대기가 옳다(`R2-7-1`) ③ 오탐 판정도 결론은 옳았다.

### ▣NN 🔴 다음 세션 미결 2건 (O102 신규 적발 · 상세 = 이력 §O102-B ②)

1. 🔴🔴 **문서가 주장한 완화조치가 실재하지 않는다** — `▣HH ③`·`§O101 ④-3` 의 *"SV COMMENT 에
   명시하는 것으로 갈음"* 은 거짓이었다(라이브·정본 SV COMMENT 양쪽 언급 **0** · 동결 사실은 `--` SQL
   주석에만 있어 **라이브에 안 실린다** · 이웃 8속성만 「동결값」을 달아 **전부 동결로 오독**된다).
   🟢 정본 `05_3_SV_DDL_MEMBER_COHORT.sql:122` 컬럼 COMMENT 보강 완료. 🔴 **잔여 = 라이브 SV 재배포**
   (시맨틱 계약 문안 변경 = `R4-4-3` **승인 대상**이라 미실행) ⇒ ⚠️ **파일↔라이브가 이 한 컬럼에서
   의도적 불일치**다. 승인 후 `EXECUTE IMMEDIATE FROM` 재배포할 것.
2. 🟠 **`decision_closure_gate` 오매칭 구조** — `CLOSE_WORDS` 가 절 내 아무 줄에나 매칭돼 각주가
   종결선언으로 잡히고 그 줄 **첫 라벨**이 「닫은 대상」이 된다. 🔴 로직 변경은 21건 분류를 바꾸므로
   **미수정**(승인·회귀 대조 필요) · 후보 = 탐색범위 절 제목+첫 문단 한정 · 절 제목 동일 줄 라벨만 채택 ·
   결정 절에 `closes:` 명시 필드 신설.

---

## 0-III. 🔴🔴 [2026-08-25 O101 필독 — ~~여기서 시작한다.~~ **⇒ [O102] 시작점은 위 §0-JJJ 다.**]

> 착수 지시(O101) = 사용자 「어제 오늘 수정된 문서·이슈를 보고 파이프라인 수정 작업을 데이터
> 아키텍처 관점에서 비판적으로 검토하고 실데이터 기반으로 지침대로 수정」. `O100`(`DEC-43`,
> 구 `DEC-42`) 캠페인 12속성 스냅샷 동결 작업을 검토해 **확정위반 3 · 아키텍처 결함 3**을 시정하고
> `dbt build` + 회귀검증(불일치 0 유지)까지 완료했다. 정본 = `50_dbt_파이프라인_미결조치-018.md §O100·§O101`.
> `§0-HHH`(O98)의 ▣A(`DEC-41` 라이브 채움률)·▣C(승계 6건)는 **이 세션도 다루지 않았다** — 그대로 열려 있다.

### ▣GG 🟢 O101 이 닫은 것 (요약 — 상세는 `50_dbt-018 §O101`)

| # | 닫힌 것 | 정본 좌표 |
|---|---|---|
| ① | `DEC-42`→`DEC-43` 라벨 개번(O96 `DEC42` 와 충돌 해소) 42건/12파일 | `30_설계_의사결정-009.md §29` |
| ② | `P85` 이중계산 해소 — `DIM_CAMPAIGN` 이 `PARENT_CAMPAIGN_NAME`·`PROMO_METHOD_NAME` SILVER 승계 | `models/gold/dim/DIM_CAMPAIGN.sql` |
| ③ | 계층위반 시정 — `CRM_CAMPAIGN` 자기조인이 BRONZE 재스캔 대신 `base` CTE 재사용 | `models/silver/crm/CRM_CAMPAIGN.sql` |
| ④ | `dbt build --select CRM_CAMPAIGN DIM_CAMPAIGN+` PASS=41 WARN=6 ERROR=0 + 회귀검증(불일치 0 유지) | `50_dbt-018 §O101 ④-1` |
| ⑤ | 라이브 SV 2종(`SV_MEMBER_COHORT`·`SV_MEMBER_SPONSOR_BIZ`) `DEC-43` 재배포(owner 보존) | `50_dbt-018 §O101 ④-2` |
| ⑥ | `O100` 원장·이력 소급 등재(선점 등재·세션이력 양쪽 미이행 시정) | 원장 §1 `O101` 행 · 이력 §O100·O101 |

### ▣HH 🔴 다음 세션이 처리할 미결 3건 (우선순위 순)

1. 🟠 **[결정 필요] `SV_MEMBER_COHORT.CAMPAIGN_NAME` 시점 혼합** — 12속성 중 8속성은 획득 시점
   동결값인데 `CAMPAIGN_NAME`(캠페인 이름 자체)만 `DIM_CAMPAIGN` **실시간 조인**으로 남아 있다.
   캠페인이 나중에 개칭되면 이 SV 에서 「이름은 최신, 분류는 과거」인 상태가 될 수 있다.
   현재는 SV COMMENT 에 이 사실만 명시해뒀다(범위 밖 의도적 존치). **현업 확인 필요**:
   `CAMPAIGN_NAME` 도 획득 시점 동결로 확장할지, 지금처럼 실시간으로 둘지.
   ⇒ 확인되면 `20_현업확인_요청.md` 에 신규 N-항 등재 → 결정 시 `FACT_MEMBER_COHORT.ACQ_CAMPAIGN_NAME`
   신설(패턴은 이미 있는 `ACQ_BRAND` 등과 동일) → `DIM_MEMBER_ACQUISITION` 승계 → SV 재배선.
2. 🟠 **[현업 회신 대기] `20_현업확인_요청-007.md §N-8`** — `MKTG_UTM` 코드 채움 93.96% ↔ 라벨
   채움 34.00%(고아코드 1종 `192` 가 63.8% 를 차지). ㉠ 사전 등재 누락인지 ㉡ 센티넬인지 확인 대기.
   회신 전까지 `192` 정규화·라벨 창작 금지(`R2-7-1`). 회신 오면 `TM_CM_MKTNG_UTM` 신규 등재 또는
   센티넬 처리 결정 → `CRM_CAMPAIGN.sql` 조인 조건 조정.
3. ⚪ **[경고 전용 · blocking 아님] `decision_closure_gate` 미봉합 인용처 21건.** 대부분 `DEC-41`·
   O96 `DEC42` 계열의 기존 미결이며 이번 세션 범위로 처리하지 않았다. 착수 전 재실행해 `DEC-43`
   신규 인용처가 늘었는지 확인할 것: `python3 scripts/decision_closure_gate.py`.
   🔴 **부분 종결을 「종결」로 쓰지 말 것**(`R3-9 ㉥`) — 각 인용처는 병기해 닫거나 열린 이유를 적는다.

### ▣II 🟢 O101 실측 기준선 (재검증 시 대조용)

| 대조 | 값 |
|---|---|
| 동결값 ↔ 라이브 `DIM_CAMPAIGN` 조인값(6속성) | 불일치 0 / 1,585,949행 |
| SILVER↔GOLD 이중계산(2속성) | 불일치 0 / 36,163행(채움 34,704) |
| `DIM_MEMBER_ACQUISITION` 동결 승계(6속성) | 불일치 0 / 1,585,949행 |
| `MKTG_UTM` 코드/라벨 채움 | 93.96% / 34.00%(고아 `192`=21,682건) |

## 0-HHH. 🔴🔴 [2026-08-25 O98 필독 — ~~여기서 시작한다.~~ **⇒ [O101] 시작점은 위 §0-III 다.**]

> 착수 지시(O98) = 회원 개발이력 캠페인 7속성 비정규화 + 세부캠페인 후원/법인구분 SILVER·GOLD 적재
> 조건 검증. `§0-GGG` 의 ▣A(DEC-41 라이브 채움률 검증)·▣C(승계 6건)는 **이 세션이 다루지 않았다** —
> 그대로 열려 있다. 아래는 O98 이 새로 닫은 것과 새로 연 것만 적는다(중복 서술 금지 · `R1-3-6`).

### ▣AA 🟢 O98 이 닫은 것

| # | 닫힌 것 | 정본 좌표 |
|---|---|---|
| ① | SILVER 캠페인 7속성+후원/법인구분 **이미 완전 구현** 확인(9컬럼 실재·99%+ 비NULL) | `models/silver/crm/CRM_MEMBER_DEV.sql`·`CRM_CAMPAIGN.sql` |
| ② | GOLD 부분 미반영 적발·보강 — `DIM_CAMPAIGN` 5/7→7/7 · `WIDE_MEMBER_EVENT` 2/7→7/7 | `models/gold/dim/DIM_CAMPAIGN.sql`·`models/gold/wide/WIDE_MEMBER_EVENT.sql`·`_wide_schema.yml` |
| ③ | GOLD `dim:` 블록 `on_schema_change` 공백 신설 방어(GOLD dim 20종 공통) | `dbt_project.yml gold: dim:` |
| ④ | `06_DDL.sql` `DIM_CAMPAIGN` 4컬럼 추가 + 라이브 `ALTER TABLE ADD COLUMN`(ordinal 25~28 실측) | `03_top-down_gold/06_DDL.sql` |
| ⑤ | `dbt build --select DIM_CAMPAIGN WIDE_MEMBER_EVENT` **11/11 PASS**(사용자 실행 · `R4-1`) | `50_dbt_파이프라인_미결조치.md` §O98 |
| ⑥ | `SV_MEMBER_EVENT` 4차원(`CMMN_BRND_NM`·`MKTG_UTM_NM`·`SPNSR_DIV_NM`·`CPR_DIV_NM`) 추가·권한 보존 확인 | `GN_DW.SERVING.SV_MEMBER_EVENT`(라이브) |

### ▣BB 🔴🔴 O98 이 새로 연 것 — **다음 세션 최우선**

🔴🔴 **`AGENT_MEMBER` 의 LIVE(dev) 버전이 placeholder 스펙으로 대체돼 있다** — 진단 중
`ALTER AGENT ... MODIFY LIVE VERSION SET SPECIFICATION = '{"models":{"orchestration":"auto"}}'`
테스트가 실제로 적용됐고, 이후 원상복구(named version 재적용)를 시도했으나 경로를 찾지 못했다.
🟢 **프로덕션 영향 없음**(실측) — `DATA_AGENT_RUN('GN_DW.SERVING.AGENT_MEMBER', ...)`(버전 미지정 =
`DEFAULT`=`VERSION$7`)는 11개 tool 전건 정상. `!LIVE` 명시 호출만 placeholder 응답을 낸다.

- **1순위**: `AGENT_MEMBER!LIVE` 를 `VERSION$7`(또는 그 이후 최신 named version) 내용으로 복구.
  Snowsight UI 편집기 경유를 우선 시도할 것 — SQL 라운드트립(`DESCRIBE AGENT`→재구성→
  `EXECUTE IMMEDIATE MODIFY LIVE VERSION`)은 **재현 가능하게 `"agent spec is invalid"` 로 실패**했고
  원인을 특정하지 못했다(길이·홑따옴표 이스케이프·`TO_JSON` 라운드트립 개별 검증은 전부 정상이었는데
  실제 스펙 200자 절취본도 동일 실패 — 모순적 증상).
- **2순위**: `semantic_studio` 스킬의 `cortex_agent_read` 가 `"No data returned from DESCRIBE AGENT"`
  로 재현되게 실패하는 조건 규명(다른 agent·다른 세션에서도 재현되는지 확인).
- **3순위**: 원인 규명 후에만 `AGENT_MEMBER`·`AGENT_MARKETING` 툴 설명에 신규 4차원 안내 문장 반영
  (`AGENT_MARKETING` 은 이 세션에서 **손대지 않았다**).

정본 = 이력 §O98(경위 전문) · `20_issue/50_dbt_파이프라인_미결조치.md` §O98(GOLD dim 구조결함 정본).

---

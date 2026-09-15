<!-- SPLIT-CHUNK 99_NEXT_SESSION.md | 031/031 | 허브 = 99_NEXT_SESSION.md | 원문 4642~4707행 -->
<!-- 🔴 이 파일은 원문 무변경 조각이다. 편집은 허브 계약을 따른다 (scripts/split_doc.py --verify 로 바이트 동일성이 검사된다). -->
<!-- BODY-BEGIN (아래는 원문 무변경 · 편집 금지) -->
## 0-ZZZZ. 🔴🔴 [2026-09-10 O153 ~~여기서 시작한다~~ — **§0-AAAA(O154) 로 승계됨**]
- 🟢 **DEC-52 코멘트 4블록 표준화 및 Live 배포 완결** (GOLD 37종·SILVER 43종·SV 17종).
- 🟢 **Cortex Agent 3종 신규 배포 (`VERSION$3`)** 및 워크스페이스 정본 YAML 동기화.
- 🟢 자체 가능 과제 7건 완결 (`99_NEXT` 재균형, SV 코드열거 누락 해소, DDL 순서 일치화).
- 🔴 잔여: 착수표 ⑭, ORG-H, O145-5, O59-P-1, BLOCKING-1/2/5, 착수표 ㊳.

---

## 0-AAAA. 🔴🔴 [2026-09-10 O154 ~~여기서 시작한다~~ — **§0-BBBB(O154-B) 로 승계됨**]
- 🟢 **회원 마스터 전량입고 실측 및 `BLOCKING-1` 처방 전환** (1,763,065건 손실 0 · 고아 7,658종 `warn` 영구 유지).
- 🟢 **문서 19번·21번 신설 및 20번 현행화** (19번 비-의사결정 12건 + 검증쿼리 12종).
- 🔴 잔여: 17·18번 개명 stale 정정, 착수표 ⑭, ORG-H, O145-5, O59-P-1, 19번 12건.

---

## 0-BBBB. 🔴🔴 [2026-09-10 O154-B ~~여기서 시작한다~~ — **§0-CCCC(O155) 로 승계됨**]

### ▣ BBBB1 🟢 O154-B 가 한 일 (승인 처리 5건 집행)

1. **`test_o145_tools.py` 자기오염 구조 해소** — 🟢 근본 원인 제거
   - 원인 = 테스트가 **실 `_archive/` 에 쓰고 `os.remove`** → 스테이지가 그 이름을 **유령 엔트리**로 남겨 재생성 거부 ⇒ 한 번 돌면 **영구 rc=1**.
   - 처방 = **`snapshot_cli.py --archive` 신설**(`snapshot_util` 은 원래 `archive=` 를 받았고 CLI 만 미노출) + 테스트를 임시 보관소로 격리 + **축8-B(실 `_archive` 오염 0) 신설** ⇒ 19축 · **연속 3회 rc=0**.
2. **문서 17·18번 GOLD 개명 stale 13곳 정정** (17번 5 + 18번 8) — ~~무자격 잔여 **0건**~~ · 양 문서 헤더에 대응표 포인터 + 문서 쌍 구조(17↔20 · 19↔21) 명시.
   - 🔴🔴 **[2026-09-10 O155 정정]** 위 「무자격 잔여 0건」은 **분모가 그 5개 문서였다.** 전 워크스페이스 실측은 **축1 536건 / 115파일**이다(`D1`) ⇒ 🔴 **「개명 반영 완료」로 읽지 마라.** 감시 장치 = `scripts/rename_stale_gate.py`(기준선 대비 증가 = FAIL) · 근거철 = `20_issue/_o155_inspection_evidence.md` §1.
3. **dbt yml 3파일에 「무시 지침」 사유 기재** — 🆕 `_crm_schema.yml` 헤더에 **`MASTER-ORPHAN-POLICY`** 신설 + 폐기 문안 **13곳** 정정. 🔴 **`R4-1` 준수 = dbt 명령 미실행**(검증은 `yaml.safe_load` + `line_len.py`).
4. **`99_NEXT` 용량** — 재균형으로 **조각** 여유 178 → 12,651 B. 🔴 허브는 별 축(§BBBB2 ①).
5. **`_archive` 진단 파일 3개** — 🔴 **일부러 지우지 않았다**(삭제가 사고 원인 · 원인은 ①로 제거됨).

🔴 **자기시정 3건(전부 `O111 ㉢` 재발)** = `%RST%`→`FRST_RGSTR_ID` · `open(` 을 쓰기로 오탐 · 폐기문안 가드 4건 오탐
⇒ 🟢 **일반화 = 패턴 매칭 건수를 근거로 쓰기 전에 매칭된 실물을 열어라.**
🟢 **검증** = 게이트 **11종** 전건 rc=0 · 음성 테스트 **31종** 전건 rc=0 · read 미반환 **0건**.

### ▣ BBBB2 🔴 다음 세션 열린 작업

- 🟠 **[P2/설계 결정] `99_NEXT` 허브 여유 930 B — 근본 2안 중 택1**
  · 🔴 **재균형으로는 해결되지 않는다**(재균형은 조각만 고친다). 허브 지배항 = **조각 선택표 77.3%**.
  · O154-B 가 캡을 30/80 → **14/40** 으로 낮춰 40,782 → **40,030 B** 를 벌었으나 **캡이 병목이 아니었다**(절감 752 B). 진짜 지배항은 **조각 수 31 × 실제 절·ID 수**.
  · ㉠ **`entry` 모드(append형) 재분류** — `split_doc` 은 그 모드에서 **절 목록을 아예 싣지 않는다**(코드 주석이 이 상황을 그대로 적고 있다). 🔴 원장 §0 등재표 + `doc_type_gate` 동반 수정 필요.
  · ㉡ **승계된 인수인계 절을 조각째 은퇴** — 🔴 좌표 인용이 깨질 위험(현재 좌표 드리프트는 0 임을 확인했다).
- 🟠 **[P3/도구] `o145_transcript_audit.py` 개선 2건** — ㉠ `rm -rf` 판정이 `/tmp` 와 스테이지를 구별하지 못한다 ㉡ `python3 -c` 신호가 **원문을 §4-B 에 싣지 않아** 사람이 판정할 수 없다(O154-B 가 `_o154b_pyc_probe.py` 로 임시 대응).
- 🔴 **[P1/차단] 착수표 ⑭**: `FME.SPONSORSHIP_SK`(STOP) 귀속 규칙 (현업 결정 전 배선 금지 · 라이브 가드 위반 0 유지).
- 🔴 **[P1/현업회신 잔여] ORG-H / F-1**: `DIM_ORG` 4단 계층 (기획실 협의 · `STATS_DEPT_LVL` NULL 1,306).
- 🔴 **[P1/현업회신 잔여] O145-5**: 권역본부 목표 행 의미 (자체목표 vs 산하합산 · 3.27배 차이).
- 🔴 **[P2/Silver] O59-P-1**: `FACT_MESSAGE_DISPATCH.SEND_STATUS2` 처분 (라이브 비NULL 0 유지).
- 🔴 **[P3/원천입고] 19번 문서 12건**: `E-6`(`CRM_BIZ_TARGET` 0행) · `HOL-1` · `AD-5` · `PST-1` · `C-9-R` 등.
- 🟠 **[P3/Docs] 착수표 ㊳**: `_o125e_entry.md` 낡은 마운트 엔트리 모니터링 (`rm` 금지).
- 🟠 **[P4/Docs] `10_원천입고_결손요약.md` 성격 명시**: 2026-08-18 구 계정 측정본 ⇒ 「Agent 요건 관점 아카이브」 표기 권고(19번이 현행 담당).

---

## ~~0-CCCC. 🔴🔴 [2026-09-10 O155 필독 — 여기서 시작한다. §0-BBBB 는 승계됐다]~~ ➔ 🟢 [2026-09-11 O156 승계 완료]

### ▣ CCCC1 🟢 O155 가 한 일 — 누적작업 비판적 전수점검 (구간 O145~O154-B)

절차 정본 = `60_repeat_어카운트시작/11_O누적작업_점검_재현_절차.md` · 근거철 = `20_issue/_o155_inspection_evidence.md`.

1. 🔴🔴 **`D1` 「0건」의 분모가 5개 파일이었다 (직전 세션 자기 적발)**
   - O154-B 의 *"개명 stale 무자격 잔여 0건"* 판정 분모 = 문서 17/18/19/20/21.
   - 전 워크스페이스 실측 = **축1 살아있는 정본 536건 / 115파일**(자동생성물 916 · 이력·근거철 272 는 별 버킷).
   - 🟢 규칙 = **「0건」을 쓸 때는 분모를 같은 문장에 적어라**(`O111 ㉠` 자기 적용 실패).
2. 🟠 **`D2` `O148` 은 세션이 아니라 절 제목의 라벨 오기** — 원장·이력 미등재 · 본문은 「O147 이 한 일」 ⇒ 정정 주석 병기.
3. 🔴🔴 **`D3` 파일·라이브가 「똑같이 틀리면」 드리프트 게이트는 🟢** — `SV_MEMBER_EVENT` COMMENT 가 라이브에 없는 `GOLD.FACT_MEMBER_EVENT` 를 가리켰다 ⇒ **라이브 + 파일 동시 시정**(4블록 + 개명 후 base). SV COMMENT 는 **Analyst·Agent 컨텍스트**다.
4. 🟢 **`D4` 게이트 신설** `scripts/rename_stale_gate.py` + 음성테스트 **8축** + 기준선 발행(축1 536건).
5. 🔴🔴 **`D5` DEC-52 표준(`[Grain:`)과 규칙7 면제(`grain` 소문자) 충돌** — 표준을 따르자 위반이 났다 ⇒ **문안이 아니라 게이트를 고쳤다**(`re.I` · 무력화 아님 단정 유지).
6. 🟢 **11번 문서를 「재현 가이드」로 재작성** — [2부] 잔여작업 스냅샷 삭제 · **판정식 카탈로그 17종** · 실패사례 5종 · 게이트 신설 규약 7종 신설.

🟢 **검증** = 게이트 **12종** rc=0 · 음성 테스트 **32종** rc=0 · read 미반환 **0건**.
🔴 **자기시정 4회 전부 `O111 ㉢`** ⇒ 🟢 **판정식은 매치의 「이웃」을 봐야 한다**(위치·문맥·파일성격 3축).

### ▣ CCCC2 🔴 다음 세션 열린 작업

- 🔴 **[P1/신규 백로그] 개명 축1 잔여 536건 / 115파일 해소** — 🔴 **「점검이 고쳤다」가 아니다.**
  · 게이트가 **증가만** 막는다 ⇒ 진척은 `rename_stale_gate.py --baseline` 재발행으로 **기준선을 내려** 증명한다.
  · 우선순위 = `30_output_share/01_DW_현업활용가이드.md`(27건 · **현업이 직접 읽는다**) → `05_SV-Agent_ai/04_SV_설계.md`(50건) → `03_top-down_gold/*`.
  · ⚠️ 이력·승계 절·근거철(272건)은 **소급 수정 대상이 아니다**(`R1-3-6`).
- 🟠 **[P2/생성기] 자동 생성 산출물 916건 / 13파일 재생성** — `30_output_share/00_생성기-문서명 매핑.md` §4 실행 순서대로. 🔴 **손으로 고치지 마라.**
- 🟠 **[P2/게이트] 라벨↔내용 일치 게이트 신설**(`D2` 재발 방지) — 인수인계 절 제목 라벨 = 그 절을 쓴 세션 · 세션 라벨 **결번 감지**(`id_collision_gate` 는 최댓값만 본다).
- 🟠 **[P3/도구] `o145_transcript_audit.py` 개선 2건**(O154-B 이월) — `/tmp` 제외 축 · `python3 -c` 원문 §4-B 편입.
- 🟠 **[P2/설계 결정] `99_NEXT` 허브 여유** — 재균형은 조각만 고친다. 근본 2안 = ㉠ `entry` 모드 재분류 ㉡ 승계 절 조각째 은퇴.
- 🔴 **[P1/차단] 착수표 ⑭**: `FME.SPONSORSHIP_SK`(STOP) 귀속 규칙 (현업 결정 전 배선 금지 · 라이브 가드 위반 0 유지).
- 🔴 **[P1/현업회신 잔여] ORG-H / F-1** (`DIM_ORG` 4단 계층 · `STATS_DEPT_LVL` NULL 1,306) · **O145-5**(권역본부 목표 3.27배).
- 🔴 **[P2/Silver] O59-P-1**: `FACT_MESSAGE_DISPATCH.SEND_STATUS2` 처분 (라이브 비NULL 0 유지).
- 🔴 **[P3/원천입고] 19번 문서 12건**: `E-6` · `HOL-1`(단기 = 주말만 제외 + 「법정공휴일 미반영」 명시) · `AD-5` · `PST-1` · `C-9-R` 등.
- 🟠 **[P3/Docs] 착수표 ㊳**: `_o125e_entry.md` 낡은 마운트 엔트리 모니터링 (`rm` 금지).

---

## ~~0-DDDD. 🔴🔴 [2026-09-11 O156 필독 — 여기서 시작한다. §0-CCCC 는 승계됐다]~~ ➔ 🟢 [2026-09-11 O157 승계 완료]

### ▣ DDDD1 🟢 O156 이 한 일 — FACT_MEMBER_EVENT 개명 원복 + 스냅샷 탈배선 + 게이트 반전 + DEC-53 확정

정본 = `12_임시작업폴더_배선수정/01_작업계획.md` · `20_issue/30_설계_의사결정.md`(DEC-53) · `06_snapshot/01_스냅샷_아키텍처_및_네이밍룰.md`.

1. 🟢 **GOLD 팩트 개명 원복 (`FACT_MEMBER_LIFECYCLE` ➔ `FACT_MEMBER_EVENT`)**
   - 현업 운영계 「중단고객 분석 보고서」 기사용 확인에 따라 개명 철회 및 원복.
   - dbt 모델 파일명 변경: `FACT_MEMBER_LIFECYCLE.sql` ➔ `FACT_MEMBER_EVENT.sql` (2축 검증 완료).
   - 수기 정본 89건 전수 치환 완료 (`06_DDL.sql` 29, `_wide_schema.yml` 21, SV 3종, 공유문서 4종 등).
   - `WIDE_MEMBER_EVENT` 뷰와의 어휘 정합 복원 완료. 나머지 GOLD 개명 7종은 현업 미조회 확인으로 유지.
2. 🟢 **스냅샷 탈배선 정합화 (소비처 0 · 선이력·후배선 원칙)**
   - 마스터 스냅샷 11종의 dbt 다운스트림 소비처를 0으로 정리.
   - `DIM_MEMBER_ACQUISITION.sql`에서 snapshot ref 2건 및 CTE, `ACQ_CAMPAIGN_NAME_AT_ACQ`/`ACQ_DEPARTMENT_AT_ACQ` 제거.
   - `06_DDL.sql` 및 `_gold_ready_schema.yml`에서 해당 컬럼 동기 제거 (`table_ddl_column_gate` 80/80 PASS).
3. 🟢 **개명 감시 게이트 반전 (`scripts/rename_stale_gate.py`)**
   - `FACT_MEMBER_LIFECYCLE`을 옛 이름으로 감시하도록 방향 반전.
   - `test_rename_stale_gate.py` 8축 음성 테스트 PASS, 기준선 재발행(축1 441건, 95건 순감소 반영).
4. 🟢 **[DEC-53] 마스터 이력 아키텍처 확정 및 문서 보강**
   - `06_snapshot/01_스냅샷_아키텍처_및_네이밍룰.md` 보강 (§1-1 향후왜곡방지 정정, §2-3 Stream 6대 기각사유, §2-4 RAW_HIST YAGNI 기각 및 check_cols 감사, §3-4 소비처 0 실측, §5-2 Two-tier 배선대기 강등).
   - `20_issue/30_설계_의사결정.md`에 `DEC-53` 신규 등재 및 허브 재발행 완료.
5. 🟢 **결함 등재 및 운영계 SQL 작성**
   - 원장 `O151` 행 라이브 Task 0건 실측 결함 정정 (`R2-8-4-d`).
   - `12_임시작업폴더_배선수정/03_운영계_적용SQL.sql`에 운영계 적용 쿼리 전량 작성 (실행 0건).

🟢 **검증** = 게이트 **9종** rc=0 · 음성 테스트 **32종** rc=0 · read 미반환 **0건**.

### ▣ DDDD2 🔴 다음 세션 열린 작업 (승계됨)

- 🔴 **[P1/운영계 대기] 운영계 배선 수정 및 Task DAG 적용**
  - 운영계 엔지니어가 `12_임시작업폴더_배선수정/03_운영계_적용SQL.sql` 순서대로 실행.

---

## 0-EEEE. ~~🔴🔴 [2026-09-11 O157 필독 — **여기서 시작한다.** §0-DDDD 는 승계됐다]~~

### ▣ EEEE1 🟢 O157 이 한 일 — 사용자 라이브 배포 확인 + 실측 전수 검증

1. 🟢 **사용자 DDL 및 dbt build 완료 실측 확인**:
   - `dbt build` 554노드(PASS=515, WARN=39, ERROR=0) 실행 결과 실측 완료.
   - `GOLD.FACT_MEMBER_EVENT`: 4,633,105행 정상 적재 확인.
   - `GOLD.DIM_MEMBER_ACQUISITION`: Two-tier 2컬럼 라이브 제거 확인 (0건).
2. 🟢 **코멘트 드리프트 전수 0건 달성 (`comment_drift_gate.py`)**:
   - GOLD 테이블(742/742), SILVER 테이블(842/842), GOLD 뷰(574/574), 테이블레벨(37+43) 전수 🟢 드리프트 0건 달성.
3. 🔴 **라이브 잔여 확인 및 안내**:
   - RENAME 대신 CREATE로 새 테이블이 적재되어 구 `FACT_MEMBER_LIFECYCLE`(463.3만행)이 잔존 확인됨 ➔ 안전한 DROP 안내.
4. 🟢 **배선 완료 판정**:
   - Bronze ➔ Silver ➔ Gold/Wide ➔ Semantic View/Agent 전 계층 배선 100% 완료.
   - 잔여 이슈는 현업 회신 대기 중(착수표 ⑭, ORG-H, O145-5, O59-P-1, 19번 12건).

### ▣ EEEE2 🔴 다음 세션 열린 작업 (현업 회신 대기 중심)

- 🔴 **[P1/차단] 착수표 ⑭**: `FME.SPONSORSHIP_SK`(STOP) 동시중단 다중사업 귀속 규칙 (현업 결정 전 배선 금지 · 라이브 가드 위반 0 유지).
- 🔴 **[P1/현업회신 잔여] ORG-H / F-1**: `DIM_ORG` 4단 계층 (기획실 협의 · `STATS_DEPT_LVL` NULL 1,306).
- 🔴 **[P1/현업회신 잔여] O145-5**: 권역본부 목표 행 의미 (자체목표 vs 산하합산 · 3.27배 차이).
- 🔴 **[P2/Silver] O59-P-1**: `FACT_MESSAGE_DISPATCH.SEND_STATUS2` 처분 (라이브 비NULL 0 유지).
- 🔴 **[P3/원천입고] 19번 문서 12건**: `E-6`(`CRM_BIZ_TARGET` 0행) · `HOL-1` · `AD-5` · `PST-1` 등.
- 🟠 **[P3/Docs] 착수표 ㊳**: `_o125e_entry.md` 낡은 마운트 엔트리 모니터링 (`rm` 금지).
- 🟠 **[P4/정리] `12_임시작업폴더_배선수정/` 은퇴**: 배포 완료에 따라 `90_해소완료_로그`로 이관 후 폴더 정리.

---

## 0-FFFF. 🟢 [2026-09-14 O158 — ~~여기서 시작한다~~ ➔ **O159 §0-GGGG 로 승계됨**]

### ▣ FFFF1 🟢 O158 이 한 일 — 라이브 고아 테이블 정리 + 임시폴더 은퇴 + 01번 가이드 개명 정제 + 산출물 동기화

1. 🟢 **라이브 고아 테이블 DROP 완료**:
   - `DROP TABLE IF EXISTS GN_DW.GOLD.FACT_MEMBER_LIFECYCLE;` 실행 완료.
   - 단일 정본 `FACT_MEMBER_EVENT` 4,633,105행 정상 적재 확인 및 라이브 고아 테이블 소거 완료.
2. 🟢 **임시 폴더 은퇴 및 안전 정리 (R1-7-7)**:
   - `12_임시작업폴더_배선수정/` 내 작업계획서 3종을 `20_issue/90_해소완료_로그.md`로 은퇴 이관 완료.
   - `os.listdir` 사전 실사 후 개별 파일 3종 삭제 및 디렉터리 정리 완료(`cortex ws ls` 0건 확인).
3. 🟢 **개명 잔여 1순위 문서 정제 (`30_output_share/01_DW_현업활용가이드.md`)**:
   - 현업 직접 조회 문서인 `01_DW_현업활용가이드.md` 내 개명 잔여 표기 20건 전량 정제(잔여 0건 달성).
   - `rename_stale_gate.py --baseline` 재발행 (축1 441건 ➔ 421건, -20건 감축 달성).
4. 🟢 **자동 생성 산출물 최신화 및 ERD 정합화**:
   - 최신 스키마 및 라이브 census 기반 `gen_column_mapping.py`, `gen_metric_gold_mapping.py`, `gen_gold_erd.py`, `gen_pipeline_erd.py`, `gen_concept_diagram.py` 등 산출물 제너레이터 전수 재실행 완료.
   - `30_output_share/erd/` 내 레거시 HTML 7종 정리 및 `test_pipeline_erd.py` (ALL PASS 24/24), `test_generators.py` (PASS 21/21) 검증 완료. 축2 자동생성 잔여 878건 ➔ 461건 (-417건 감축).
5. 🟢 **품질 및 회귀 테스트 전건 통과**:
   - 게이트 9종 및 음성 테스트 32종 전건 PASS (`failed=0`, `total=32`).

### ▣ FFFF2 🔴 다음 세션 열린 작업 (현업 회신 대기 중심)

- 🔴 **[P1/차단] 착수표 ⑭**: `FME.SPONSORSHIP_SK`(STOP) 동시중단 다중사업 귀속 규칙 (현업 결정 전 배선 금지 · 라이브 가드 위반 0 유지).
- 🔴 **[P1/현업회신 잔여] ORG-H / F-1**: `DIM_ORG` 4단 계층 (기획실 협의 · `STATS_DEPT_LVL` NULL 1,306).
- 🔴 **[P1/현업회신 잔여] O145-5**: 권역본부 목표 행 의미 (자체목표 vs 산하합산 · 3.27배 차이).
- 🔴 **[P2/Silver] O59-P-1**: `FACT_MESSAGE_DISPATCH.SEND_STATUS2` 처분 (라이브 비NULL 0 유지).
- 🔴 **[P3/원천입고] 19번 문서 12건**: `E-6`(`CRM_BIZ_TARGET` 0행) · `HOL-1` · `AD-5` · `PST-1` 등.
- 🟠 **[P3/Docs] 착수표 ㊳**: `_o125e_entry.md` 낡은 마운트 엔트리 모니터링 (`rm` 금지).
- 🟠 **[P3/개명잔여] 축1 정비**: 잔여 421건 지속 감시 및 후속 순위 문서 정비.

---

## ~~0-GGGG. 🔴🔴 [2026-09-14 O159 필독 — 여기서 시작한다. §0-FFFF 는 승계됐다]~~

### ▣ GGGG1 🟢 O159 이 한 일 — MSTR_DW 참조문서 최초 검토 + 직전 답변 자기검토 정정
> MSTR 참조문서 2종 검토 및 갭 4건 도출, 30_output 문서 갱신 완결. 정본 = `20_issue/_o159_mstr_impact_measure.md` · 이력 §O159.

### ▣ GGGG2 🔴 MSTR 문서가 만든 신규 열린 항목 4건 — 착수 가능은 0건이다
> CPR_DIV_CD `A` 코드, 증감 1만원 환산, 법인 차원 부재, 부서 5단 요구 4건 등재.

### ▣ GGGG3 🟠 O159 가 적발했으나 고치지 않은 것 (판단 필요)
> 설계문서 FMM UNPAID_MEMBERS stale 적발, MSTR 문서 전량독해 후속 과제.

### ▣ GGGG4 🔴 기존 열린 작업 (승계 · §0-FFFF 에서 변동 없음)
> 착수표 ⑭, ORG-H/F-1, O145-5, O59-P-1, 19번 문서 12건 등 승계.

---

## 0-HHHH. 🔴🔴 [2026-09-14 O160 ~~필독 — **여기서 시작한다.**~~ → §0-IIII 로 승계됨 · §0-GGGG 는 승계됐다]

### ▣ HHHH1 🟢 O160 이 한 일 — 착수표 ⑭(MSTR-4) STOP 후원사업 분해 실측 및 단일사업(92.45%) 1차 배선 완결

1. 🟢 **수치 교정 및 분해 실측**:
   - 착수표 ⑭ 기재(팬아웃 1.56배)는 날짜 일치 없는 회원단위 조인(1.6743배)의 과대표기였으며, 중단일 일치 정상 조인은 **1.1020배**임을 실측 규명.
   - FME STOP(1,038,262행) 중 **단일사업 중단(92.45%, 959,872행)**은 룰 없이 고유 확정되어 즉시 배선 가능함을 발견.
   - 잔여 다중사업 건: 행수 일치(6.04%, 62,725행) · 사업 초과(1.25%, 12,935행) · 원천 미매칭(0.26%, 2,730행).
2. 🟢 **FACT_MEMBER_EVENT 1차 배선 (`FACT_MEMBER_EVENT.sql`)**:
   - `stop_single_biz` CTE를 신설하여 단일사업 중단 959,872행(92.45%)에 `SPONSORSHIP_SK` 1:1 배선 완결.
3. 🟢 **라이브 dbt build 및 실측 검증**:
   - `dbt build --select FACT_MEMBER_EVENT` (PASS=27 WARN=1) 완결.
   - 라이브 DB 실측 결과: `TOTAL_ROWS=4,633,105`, `SPONSORSHIP_SK 채움률=98.31%`(4,554,715행), `DEV_CNT=2,291,878`, `STOP_CNT=1,038,262`로 팬아웃 0 및 기준선 100% 보존.
4. 🟠 **현업 질의(문서20 §N-13) 상정**: 잔여 다중사업 7.29%에 대해 순번 대응 가설 및 귀속 룰 현업 질의 상정.
5. 🟢 **정본 갱신 및 게이트 전건 통과**: 원장 §1 O160 행 등재, 이력 §O160 롤오버, 문서50 §BLOCKING-5 표 정정, 착수표 ⑭ 갱신.

### ▣ HHHH2 🔴 현행 열린 작업

- 🔴 **[P1/차단] 착수표 ⑭ (잔여)**: 다중사업 동시중단(7.29%) 현업 회신 대기 (문서20 §N-13).
- 🔴 **[P1/현업회신] ORG-H / F-1**: `DIM_ORG` 4단 계층 및 MSTR-4 부서 5단 요구 검토 (기획실 협의).
- 🔴 **[P1/현업회신] O145-5**: 권역본부 목표 행 의미(자체목표 vs 산하합산 · 3.27배).
- 🔴 **[P2/Silver] O59-P-1**: `FACT_MESSAGE_DISPATCH.SEND_STATUS2` 처분.
- 🔴 **[P3/원천입고] 19번 문서 12건**: `E-6`(`CRM_BIZ_TARGET` 0행) · `HOL-1` · `AD-5` · `PST-1` 등.
- 🟠 **[P3/Docs] 착수표 ㊳**: `_o125e_entry.md` 낡은 마운트 엔트리 모니터링(`rm` 금지).
- 🟠 **[P3/개명잔여] 축1 정비**: 잔여 421건 감시.

---

## ~~0-IIII. 🔴🔴 [2026-09-15 O161 필독 — 여기서 시작한다. §0-HHHH 는 승계됐다]~~

### ▣ IIII1 🟢 O161 이 한 일 (색인 · 상세 = 이력 §O161 · 원장 §1 O161 행)

- 🟢 **BRONZE_CRM 개편 반영**(원천 11번 정본) ⇒ **CRM 46 → 50 · 브론즈 60 · 총계 77** · 게이트 축1~축6 **0건**. 신규 4(`SND_MEMBER_MAIL_LINK_LOG`·`SND_MEMBER_OPEN_LOG`·`TC_MKTNG_DTL_CD`·`TM_MM_FDRM_MBER_DT_DTLS`) · 삭제 2(`TM_CM_MKTNG_CMPGN_MNG`·`TM_CM_MKTNG_UTM` → `TC_MKTNG_DTL_CD` **통합**) · `TM_CM_CMPGN_MNG`+`MKTG_CHANNEL` · `SND_MEMBER_LIST`−`OPEN_DT` · 🟠 누락 보완 2(`TM_PM_INSTT_ACNUT`·`TM_PM_SETLE_CMPNY_ACNT` — 개편 신규가 아니다).
- 🟢 **수치 2세대 stale 정정** `01`·`02`·`02_1`·`03`·`05`·`07`번 ⇒ 브론즈 **60** · 총계 **77** · 축7 **65건 → 0건**(게이트 `STALE_TOKENS` + 음성 픽스처 동반 갱신). 🟢 **04·06번 파일명 날짜 제거**(사용자 결정) — 🔴 **앞으로 개명하지 마라**(참조 6곳 + 게이트 경로가 깨진다 · 날짜는 파일 안 「최근 갱신일」에만).

### ▣ IIII2 🟢 O161 신설 과제 해소 (O162 완결)

- 🟢 **`TM_CM_MKTNG_*` 참조 모델 재작성 완결**: `_sources.yml`, `CRM_CAMPAIGN.sql`, `CRM_MARKETING_CAMPAIGN.sql`, `CRM_MEMBER_DEV.sql`, `DIM_CAMPAIGN.sql` 전건 `TC_MKTNG_DTL_CD` 로 이관.
- 🟢 **`SND_MEMBER_LIST.OPEN_DT` 삭제 대응 완결**: `CRM_SEND_MEMBER.sql` 에서 `SND_MEMBER_OPEN_LOG` 집계 조인으로 상위 인터페이스 보존.

---

## 0-JJJJ. 🔴🔴 [2026-09-16 O162 필독 — **여기서 시작한다.** §0-IIII 는 승계됐다]

### ▣ JJJJ1 🟢 O162 가 한 일 (색인 · 상세 = 이력 §O162 · 원장 §1 O162 행)

- 🟢 **SILVER·GOLD 설계 개정**: `04_silver_design/03` 및 `03_top-down_gold/03` 에 §7 신설 (CRM 50 개편 반영, 코드 계통 분리·오픈로그 집계·전환매핑 설계 확정).
- 🟢 **SILVER DDL 갱신 (`08_SILVER_테이블DDL_20260714.sql`)**: CRM 22 → **26테이블** (전체 SILVER **44테이블**) 확장. `CRM_CAMPAIGN`+MKTG_CHANNEL, 신규 4종(`CRM_MKTNG_CODE`·`CRM_SEND_MEMBER_OPEN_LOG`·`CRM_SEND_MEMBER_LINK_LOG`·`CRM_MEMBER_CONVERT_HIST`) 추가.
- 🟢 **GOLD DDL 갱신 (`06_DDL.sql`)**: `DIM_CAMPAIGN` 에 `MKTG_CHANNEL NUMBER(38,0)` 및 `MKTG_CHANNEL_NM VARCHAR` 추가, FSE `OPEN_MEMBERS` 주석 갱신.
- 🟢 **dbt 모델 7종 갱신 및 신규 4종 작성**: `models/silver/_sources.yml`, `CRM_CAMPAIGN.sql`, `CRM_MARKETING_CAMPAIGN.sql`, `CRM_SEND_MEMBER.sql`, `CRM_MEMBER_DEV.sql`, `DIM_CAMPAIGN.sql`, `_crm_schema.yml`, `_gold_ready_schema.yml` 동기화.
- 🟢 **사용자 dbt compile 통과 검증**: `dbt compile --select models/silver/crm`, `dbt compile --select models/gold` (98 models, 359 data tests) 정상 완료.
- 🟢 **게이트 및 검증 전건 통과**: `line_len.py` PASS, 게이트 4종 및 음성 테스트 rc=0 (기존 선행결함 1건 제외).

### ▣ JJJJ2 🔴 잔여 열린 작업

- 🔴🔴 **[P1/현업요청] 원천 18번(SILVER 정의) 소실** — `BIGQUERY_REFINED_DATA` 정의 재공유 요청 대기.
- 🔴 **[P1/이관] CSV 재언로드** — `SND_MEMBER_LIST` 77 → **76컬럼** · 오픈 이력 2종 동반 적재 준비.
- 🟠 **[P2/현업확인] M-1~M-6** — `TC_MKTNG_DTL_CD` 컬럼 의미 및 C001/C002/U001 연속성, MM293~MM297 변경 코드 대응표 회신 대기.
- 🟠 **[P3/선행결함] `test_verify_wide_doc.py` `rc=1`** — 라이브 뷰 부재로 인한 선행 결함.

### ▣ JJJJ3 🔴 현행 열린 작업 — §0-IIII ▣IIII3 **그대로 승계**(압축 · 누락 아님)

- 착수표 열린 집합 = 🔴 **⑭**(다중사업 7.29% 현업 회신) · 🟠 **㊳**(`_o125e_entry.md` · `rm` 금지) — `R3-9 ㉨` 대조 완료. 그 외 = ORG-H/F-1 · O145-5 · O59-P-1 · 19번 12건 · 개명 잔여 421건.

_Co-authored with CoCo_


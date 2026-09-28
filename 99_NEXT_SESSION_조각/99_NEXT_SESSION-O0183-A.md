<!-- LLM-METADATA
doc_id: HANDOFF_O0183_A
doc_role: 인수인계 — 세션 `O183-A` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-09-28
created_by: O183-A
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0183-A -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O183-A-0 🔴🔴 먼저 알아라 — 이 세션이 확정한 판정식

| # | 판정식 | 근거(실측) |
|---|---|---|
| ㉠ | **「정본에 정의가 없다」는 주석을 믿지 말고 정본을 grep 하라** | FMM 주석이 활동누계 정의 부재를 주장했으나 `02_지표사전 공통.md` #158·#159 에 있었다 |
| ㉡ | **시간창 매칭은 D+0 을 따로 재라 — 당일 발송은 사건의 결과일 수 있다** | 2026-07 표본: 증액 D+0 매칭 3,174 중 통보성 제목 2,570 (DEC-33 재현) |
| ㉢ | **최초일 MIN 에는 센티넬이 먼저 걸린다** | FME DEV 최초일 1900-01-01 = 86명 → 후원기간 1,511개월 |
| ㉣ | **SILVER 원천이 0 이면 GOLD 공란은 결함이 아니다** | `ERP_BUDGET_YEARLY.CHN/ADJ_BDGT_TOT_AMT` 전건 0 |

---

### ▣ O183-A-1 🟢 이 세션이 끝낸 것 (코드·문서 · 🔴 라이브 반영 전)

- 착수 실측: GOLD 기본 테이블 전 컬럼 계측 — 전건 공란 컬럼 약 90개(xf98254 · 2026-09-28)
- dbt 모델 4종 배선(규칙 정본 = 문서30 **DEC-55**)
  - `FACT_MEMBER_MONTHLY` 22컬럼 · `FACT_MEMBER_EVENT.NEW_EXISTING_FLAG`
  - `FACT_MESSAGE_DISPATCH` D5 8종(창 D+1~D+5) + SERVICE 2종 · `FACT_EVENT_ATTENDANCE` 5종
- 사전검증(dbt 없이 라이브 재현): FME 신규/기존 NULL 1,458/4.7M · D5 매칭 발생 · FMM 202512 분포 타당
- SV 4종 DDL 갱신(05_1·05_2·05_4·05_5) — 임시 이름 생성·DESCRIBE·DROP 으로 **컴파일 PASS**(라이브 SV 미변경)
- `AGENT_MEMBER` 정본 yaml 갱신(stale 문구 2건 정정 + 활성 목록) — YAML 파싱 OK · **Agent 버전 미발행**
- GOLD DDL 정본 COMMENT 14건 정정(`03_top-down_gold/06_DDL.sql`) · 라이브 COMMENT 는 미적용
- 후속 배포 스크립트 신설 = `05_SV-Agent_ai/15_O183_GOLD공란채움_배포.sql`
- 문서50 BLOCKING-5 에 O183 현행 포인터 · 문서30 DEC-55 신설

---

### ▣ O183-A-2 🟠 다음이 할 일

| # | 항목 | 착수 정보 |
|---|---|---|
| **1** | 🔴 **사용자 `dbt build`** | 모델 4종 + 하류(WIDE 뷰). 정지점 `R4-1` |
| **2** | 🔴 **배포 스크립트 실행** | `15_O183_…배포.sql` [1] 재계측 → 0 이면 중단 · [2] COMMENT · [3] SV 4종 · [4] AGENT_MEMBER 버전업(09_2 절차) · [5] 스모크 |
| **3** | 🟠 D5 발송유형 필터 | DEC-33 ① 캠페인성/처리통보성 정의 현업 확정 → `send_pairs` 에 필터 1줄 |
| **4** | 🟡 공45~47·54~57·77~78 비율 지표 | 분모 「누계개발건」 조합 정의 후 SV metric 만 추가 |
| **5** | 🟠 원장 §1 행 · 이력 항목 | 원장 `-002` 여유 부족(O182 ▣2-8 과 같음) — 은퇴/롤오버 후 기록 |
| **6** | ⚪ 비워 둔 공란 | DEC-55 §55-C 표가 정본(원천 축 부재·미입고·설계 대기) |

---

### ▣ O183-A-3 ⚪ 승계 백로그

- `-O0182-A` ▣2(dbt 전용 롤 · SV_AD 문안 · VIDEO 캠페인 · CRM 신규 3종 등)·▣3 은 **그대로 유효**하다.
- 착수표 ⑭·⑩ · 문서50 열린 절 6건 — 변동 없음(BLOCKING-5 는 진행 포인터만 추가).

---

### ▣ O183-A-4 🔴 환경 함정

1. 🔴 `python3 - <<EOF` 대신 스크립트 파일 · `snowflake.connector`(scripts/sfconn.py) 경로가 긴 SQL 에 안정적이었다.
2. 🟢 SV DDL 사전 컴파일 = 대상명을 임시명으로 바꿔 `CREATE OR REPLACE` → `DESCRIBE` → `DROP`(라이브 무영향).
3. 🟠 병렬 `edit` 미리보기 엇갈림은 이번엔 없었다 — 그래도 편집 후 파일 재확인 유지.

---

### ▣ O183-A-5 📏 종료 기준선 (2026-09-28 · xf98254 · 🔴 인용하지 말고 재라)

- 라이브 GOLD 는 **이 세션에서 바뀌지 않았다** — 값 판정은 dbt build 이후 `15_…배포.sql` [1] 로 한다.
- 게이트: line_len PASS(편집 파일 전건) · SV 4종 컴파일 PASS · ALTER COMMENT 컴파일 PASS
- `_scratch_*` = 세션 종료 전 개별 삭제

_Co-authored with CoCo_

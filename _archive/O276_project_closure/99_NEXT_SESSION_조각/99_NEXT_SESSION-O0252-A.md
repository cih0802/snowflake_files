<!-- LLM-METADATA
doc_id: HANDOFF_O0252_A
doc_role: 인수인계 — 세션 `O252-A` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-21
created_by: O252-A
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0252-A -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O252-A-0 🔴 먼저 알아라

- `O252-A` = 폐지·개편 실적부서 → 현재 활성 부서-팀 귀속 차원 신설 · 주간중단보고 부서 드릴다운 지원 (2026-10-21 · TRIALADMIN(SR61467) · ㉡ · 사용자 지시·승인 · A안 확정).
- 결정 = **DEC-63**(DEC-56 결정 2 부분 대체 · `30_설계_의사결정-017.md`) — 원천 부서값은 그대로 두고 `GOLD.DIM_ORG_SUCCESSION.CUR_*` 로만 귀속한다.
- 🔴 `DIM_ORG.ORG_SK` 조인키 = `ABS(HASH(COALESCE(CAST(DEPT_ID AS VARCHAR),'∅')))`(매크로 `gold_sk`) — `HASH(DEPT_ID)` 로 조인하면 연 3만 건이 빠진다(이번 세션 1차 측정 오류).
- 근거 정본 = `tmp/o252/evidence.md`.

### ▣ O252-A-1 이번 단위 결과

| 항목 | 결과 |
|---|---|
| 모델 | `models/gold/dim/DIM_ORG_SUCCESSION.sql`(incremental · unique_key OLD_ORG_SK) · 규칙 = SELF → MANUAL → AUTO_NAME → AUTO_MEMBER_FLOW(lift≥3·근거≥30) → AUTO_ACMSLT_PARENT → AUTO_ORG_PARENT(L≥1) → UNMAPPED |
| seed | `seeds/ORG_SUCCESSION_MANUAL.csv`(헤더만) · `seeds/_seeds.yml`(schema GOLD) |
| 테스트 | schema yml(not_null·unique·relationships·accepted_values) · `tests/assert_org_succession_invariants.sql` |
| DDL | `03_top-down_gold/06_DDL.sql` 2블록(IF NOT EXISTS) · 개발계 생성 · OWNERSHIP GN_DW_ADMIN(COPY CURRENT GRANTS) |
| build | 👤 PASS=11 WARN=0 ERROR=0 · 라이브 1,314행 = 렌더 결과 1,314/1,314 일치 · seed 0행 |
| 연결률 | 중단 2024 99.3% · 2025 99.4% · 2026 99.5% · 미매핑 1,000 / 896 / 621 |
| 현업 문서 | `30_output_share/O252_폐지부서_현재부서연결_안내_20261021_v1.docx` · `O252_폐지부서_연결결과_검토요청_20261021.xlsx`(225행 · 현재부서 223) · CSV 원본 |

### ▣ O252-A-2 ㉠ 잔여(후속 작업)

| 순 | 작업 | 판정 |
|---|---|---|
| ① | 운영계 배포 — 06_DDL 2블록 + OWNERSHIP 이전 → dbt ADD VERSION → `build --select ORG_SUCCESSION_MANUAL DIM_ORG_SUCCESSION`(백필 없음 · R2-9) | 👤 운영계 |
| ② | 배포 후 현업에 「대시보드 반영 가능」 통보(안내서 §6 CoCo 문구 사용) | 👤 사용자 |
| ③ | 현업 검토 xlsx 회신 → seed CSV 반영(「연결안함」= CUR_DEPT_ID 빈칸) → build → 불변식 테스트 | DW |
| ④ | `GN_DW.PUBLIC.TMP_O252_MODEL`(검증용 영구 테이블) 삭제 | 👤 승인 대기 |

### ▣ O252-A-3 ㉡ 워크스페이스 백로그

- O251-A 착수표 ①(ANALYST_01 CoWork 확인) · ②(85 운영계 캡처 공유)는 **이 세션에서 손대지 않았다**(열림 유지).
- 매핑 갱신 주체(인사 담당) 지정 — 현업 회신 대기.
- 다른 부서별 보고서·SV 에 `DIM_ORG_SUCCESSION` 축 배선(SV_MEMBER_EVENT 등) — 요청 시.
- 스테이지 `30_output_share/O252_폐지부서_현재부서연결_안내_20261021.docx`(접미 없음) = zip 쓰기 실패 흔적(쓰기 불가 상태) · 삭제하지 않았다.

### ▣ O252-A-4 ⚪ 결정 완료(재론 금지)

- A안 = 폐지 지부·시도본부 24부서(2024 중단 3,146)의 회원서비스기획팀 귀속 유지 · 현업 리뷰 「권장(근거 약함)」 표시.
- 회원 흐름은 최빈값이 아니라 lift 로 판정한다(매체운영팀 43.8% 쏠림).
- GN_DW_DBT 는 GOLD 에 CREATE TABLE 권한이 없다 ⇒ seed 테이블도 DDL 선생성.

_Co-authored with CoCo_

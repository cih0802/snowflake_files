<!-- LLM-METADATA
doc_id: HANDOFF_O0246_A
doc_role: 인수인계 — 세션 `O246-A` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-18
created_by: O246-A
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0246-A -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O246-A-0 🔴 먼저 알아라

- `O246` = 운영계(ZL50263) 배포 세션 (2026-10-19 · CHOIH · ㉡).
- 지침 추가: `R2-9` 운영계 백필 및 기간 지정 실행 제외 (bigquery_dt_ranges 전구간 재적재 및 MSTR 과거 34개월 적재 제외).
- DDL/RBAC/SV/Agent 1~51번 전건 정상 배포 완료.

### ▣ O246-A-1 이번 단위 결과

| 항목 | 결과 |
|---|---|
| DDL/RBAC (1~14) | 01 RBAC(CHOIH) · 02~03 OPS · 04 SILVER DDL · 05 소재 매핑 CSV 258행 · 06 GOLD DDL · 07~12 MSTR 00~05 · 13 dbt project VERSION$26(PROD_20261019) · 14 After Deploy RBAC 전건 OK |
| dbt build (15) | 사용자 직접 실행 완료 (기간 지정 백필 제외) |
| OPS 알림 (16) | ALERT_DBT_WARN_SPNSR_CLS_DUP 생성 및 RESUME |
| MSTR 적재 (17) | R2-9 지침에 따라 제외(건너뜀) |
| SV/ML/Search (18~49) | SV 29종 DDL 전건 재배포 · ML 서빙 뷰 3종 및 SV 3종 · BIZ_DEFINITION_CORPUS 적재 및 Search 서비스 생성 |
| Agent (50~51) | Agent 3종 최신 스펙 버전 배포 및 기본값 활성화 (MEMBER VERSION$25 · EXECUTIVE VERSION$18 · MARKETING VERSION$21) |

### ▣ O246-A-2 ㉠ 잔여(이 작업)

- 운영계 1~51번 배포 작업 전건 완료(잔여 0).

### ▣ O246-A-3 ㉡ 워크스페이스 백로그(현업 회신만)

- H1 공11 「15개」 축 · H2 공147 공통캠페인 체계.
- H3~H6 A/B 채택(공#122 · 공#81 · 공91 · 공98) → 다른 안 회수.
- H7 W5 영상 이름형 매핑 · H8 미매칭 41행 · H9 정의 7종.
- W6 잔여 = 재방송 「캠페인코드」 열 마케팅캠페인명 CRM 일치 0 · 상위캠페인코드 1:N 78행.
- eval 하락 문항 분해(MEM D3·R14·R15 · EXEC Q13 · TE) — 사용자 제외 지시 유지.

### ▣ O246-A-4 ⚪ 결정 완료(재론 금지)

- 운영계 백필 및 기간 지정 실행 제외 (`R2-9`).
- 07 RBAC 47행 사용자명 `CHOIH`.
- 추경 = 데이터가 없다고만 쓴다 (원인 문구 금지).

_Co-authored with CoCo_

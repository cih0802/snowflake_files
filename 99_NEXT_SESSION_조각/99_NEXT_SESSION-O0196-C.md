<!-- LLM-METADATA
doc_id: HANDOFF_O0196_C
doc_role: 인수인계 — 세션 `O196-C` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-01
created_by: O196-C
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0196-C -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O196-C-0 🔴 먼저 알아라 (2026-10-01 · 개발계 pw69582)

- 🟢 AGENT_EXECUTIVE·AGENT_MARKETING = 원천 괄호·각주 규칙을 AGENT_MEMBER 형식(BRONZE_<스키마>.<테이블>)으로 맞춰 **VERSION$5 default** 배포 · 롤백 = `SET DEFAULT_VERSION = 'VERSION$4'`.
- 🟢 DEC-58 = 요청 grain 차원 · 결연활동 팩트 **신설 결정**(구현 미착수 · 범위 = 발송요청 16 · 발송결과 7 · 결연활동 12).
- 🟢 실측 종결 = `rename_stale_gate` 축1 0 · `comment_drift_gate` 드리프트 0 · 41~46 은 DEC-57 에서 이미 처분.
- 🟢 이 단위가 O196-B ▣2 를 대체한다(O196-B ▣1 순1·순2 는 그대로 유효).

### ▣ O196-C-1 🟠 남은 작업 — ㉠ 이 작업의 잔여

| 순 | 작업 | 다음 행동 |
|---|---|---|
| 1 | 산출물 골든(O196-B ▣1 순1) | 08 +104 행 분해(2차-B 99 + 5 규명) → `test_generators.py --update-golden --reason` |
| 2 | 원장 조각 002 용량(O196-B ▣1 순2) | `split_doc.py 20_issue/00_INDEX_이슈원장.md --rebalance`(사용자 승인 완료) |
| 3 | DEC-58 구현 | 58-C 순서 = 설계 → `06_DDL.sql` + dbt 모델 → 사용자 dbt build → 라이브 게이트 → SV·Agent |

### ▣ O196-C-2 🟠 남은 작업 — ㉡ 외부 회신 대기(실측 = 여전히 열림)

| 순 | 작업 | 대기 대상 |
|---|---|---|
| 1 | D-4 ML 다중 예측행 실행순번 컬럼 | ML 담당(원천에 실행 시각·순번 부재 · `45_` 요청 · DEC-57 #45) |
| 2 | D-5 「오픈 = 링크 클릭」 정의 ML 공유 | 사용자 전달 여부 미확인(DW 결정은 DEC-57 #44 완료) |
| 3 | ⑭ 다중사업 중단 7.29% | 현업 회신(문서20 §N-13) |
| 4 | ⑩ 잔여 2축 | §0-E 결정 1·2(`P102`·`P106` 복원 · 로드맵 10) |
| 5 | AGENT ③ 핵심원천 미기재(MEMBER·MKT 동일 6건) | advisory · 원천 괄호 확장 여부 결정 |

_Co-authored with CoCo_

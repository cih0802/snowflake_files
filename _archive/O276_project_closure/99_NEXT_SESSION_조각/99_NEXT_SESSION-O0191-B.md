<!-- LLM-METADATA
doc_id: HANDOFF_O0191_B
doc_role: 인수인계 — 세션 `O191-B` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-09-30
created_by: O191-B
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0191-B -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O191-B-0 🔴 먼저 알아라 (2026-09-30 · bt97381)

- 사용자 보고 = `dbt build --select DIM_ORG` PASS=11 WARN=0 ERROR=0 · 📏 GOLD 재조회 ZB 454 · ZC 450(O191-A 기대치 일치).
- 사용자 결정 = 조직 축 「DW 추천 + 기본값」 ⇒ **DEC-56**(`30_설계` -017) · 과거 실적부서 218 은 **현재 부서와 연결하지 않는다**.

### ▣ O191-B-1 🟢 이 단위가 끝낸 것

- `SV_MEMBER_EVENT` 4축(`ORG_DIV_GROUP`·`ORG_DIV`·`IS_ACTIVE_ORG`·`ORG_PATH`) · `SV_MEMBER_COHORT` 2축(`ACQ_ORG_DIV_GROUP`·`ACQ_ORG_DIV`) 배포 · ANALYST 조회 실증.
- 모델 추가 변경 0(결정 1~4 는 O191-A 4컬럼으로 충족) · 종전 「상위 조직 비노출」 주석 취소선(J5).
- COMMENT 주장 실측 = ZB 8종 · 협력시설은 **대부분** 협력시설·지부외(1곳은 지부(사복)) ⇒ 「전수」 단정 문안을 고쳤다.

### ▣ O191-B-2 🟠 남은 작업

㉠ 이 작업의 잔여 = 요청서 `41`~`46` 사용자 해결 중(이번 세션) · Agent 스펙 도구 설명에 본부/지부 축 반영(다음 스모크 전).

㉡ 워크스페이스 백로그 = 🟠 `sv_code_label_gate` blocking 1건(기존 · 이 단위 무관) = `SV_AD.CREATIVE_TYPE` COMMENT 「4종」 vs 실제 5종 ·
스모크 잔여 3 · `test_o125_layer_census` 하드코딩 · 2차-B 2단 · 문서02 · 산출물 재생성.

_Co-authored with CoCo_

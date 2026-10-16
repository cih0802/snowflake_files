### ▣ O239-A-0 🔴 먼저 알아라

- 작성 = ua91864 · 2026-10-16 · ㉡ · 사용자 지시 = 「추천안 2개를 확립·구현 → AGENT 로 현업 실사용 후 결정」.
- 🔴 라이브 미배포다 — 워크스페이스만 바뀌었다. 배포 정본 = `05_SV-Agent_ai/29_O239_G1잔여_배포순서.sql`(D1~D7 · 👤).
- 배포 전까지 `agent_object_ref_gate`·`sv_identifier_gate` 가 FAIL 1건씩 낸다(신규 SV·팩트 라이브 부재 · 배포로 해소).
- 매핑 정본 = `90_provided_definition/CRM-AGENCY 컬럼명 매핑.csv`(14행) — O238 이미지 판독본을 대체한다.

### ▣ O239-A-1 이번 단위 결과

| 순 | 결과 |
|---|---|
| ① 매핑 대조 | 구현 = 매체·채널 3시트 통과값 · utm(2순위 경로) · 영상 상위캠페인→UPPER_CMPGN_CD(코드형) · 제작비 컨텐츠구분자→CMPGN_CD · 미구현 = 특집·재송출 코드/명칭 4행(원천 공란·열 부재) · 정정 = 재송출 「캠페인코드」는 CRM 마케팅캠페인명과 결합 · 갭표 L2·L4·L5·L6 갱신 |
| ② G1 결연아동 | `FACT_GA_CHILD_VIEW` · 추천안A 형식 · B CRM_CHILD.CHILD_NO 대조 · probe = 이벤트 196,282 보존 · A 11,981 · B 11,978 |
| ③ G1 미납서비스 | `FACT_UNPAID_SERVICE_CONV` · A unpayed* · 미납분 납입 30일 · B + paymentchange_quick·check · 모든 납입 30일 · probe A 14.89% · B 38.90% |
| ④ SV·Agent | `SV_GA_CHILD_UNPAID`(05_26 · probe 컴파일·스모크 일치 후 DROP) · AGENT_MEMBER `analyst_ga_child_unpaid` · overlay MET_CMN-81 C5 · 122 C4 · 코퍼스 CSV 재생성 |
| ⑤ 백로그 | 순서표 05_24·05_25·05_26 + 보조주석 번호 · sv_unit_gate 예외 4 · test_generators 골든(측정일 1건 규명) · test_gold_erd LOGICAL_FK · test_verify_wide_doc(09 문서 재생성 +6열) · gold_erd_coverage_gate 미분류 3 해소 |
| ⑥ O238 W3 | 미매칭 목록 = `12_agent개선과제/output/O239_unmatched_link_values.csv`(인입경로 4 · 매체 4 · UTM 33) |

### ▣ O239-A-2 ㉠ 잔여

| 순 | 작업 | 판정 |
|---|---|---|
| ① | O239 배포 D1~D7(06_DDL 블록 IF NOT EXISTS · dbt build · 05_26 · 26 · 09_2 · 스모크) | 👤 dbt·DDL |
| ② | 현업 A/B 결정 후 다른 안 metric·플래그·overlay 문안 회수 · 「잠정」 확정 문안 교체 | 현업 → dbt |
| ③ | O238 W5 영상 이름형 · W6 특집·재송출 코드/마케팅캠페인명 입고 · 미매칭 41행 현업 회신 | 현업 |
| ④ | 현업 확인 = 최종캠페인 정의 · 클릭 전환 창 · 납입방식 잠정 축 · 수신 후 납입 창 · 공6·공166·신규6 · 발송 성공 코드 · 서비스 참여율 분모 | 현업 |

### ▣ O239-A-4 ⚪ 결정 완료(재론 금지)

- G1 2건 = 추천안 A/B 병기 → Agent 실사용으로 현업이 고른다(사용자 결정 2026-10-16).
- 재송출 「캠페인코드」 열 = CRM 마케팅캠페인명(매핑 CSV 정본) — CMPGN_CD 코드 결합이 아니다.

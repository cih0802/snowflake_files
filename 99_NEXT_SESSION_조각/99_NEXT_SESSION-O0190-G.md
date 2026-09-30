<!-- LLM-METADATA
doc_id: HANDOFF_O0190_G
doc_role: 인수인계 — 세션 `O190-G` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-09-30
created_by: O190-G
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0190-G -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
## O190-G 세션 마감 (E-1 빌드 검증)
- dbt build ERP_BUDGET+ : PASS=23 WARN=1 ERROR=0 (사용자 보고)
- E-1 검증: SILVER YN_1 non-null 1,092 / YN_2 1,500. GOLD FACT_BUDGET 1,332행
  - 합계 A(EXEC_DIRECT_MNYRS_1)=53,832,477,480 ≤ B(_2)=55,094,546,656 = 집행총액 EXEC_BUDGET_ERP
  - 행단위 A>B 3행 (YN_1=Y·YN_2≠Y 조합 존재 → 포함관계 아님), B>총액 0행
  - B=집행총액 → YN_2는 사실상 전건 Y(변별력 없음) 추정. 현업 회신(E-1 정의) 시 근거로 제시
- 스모크 재실행: 미실시 (다음 세션 순2)

## 다음 세션 프롬프트 추가용
# 순2. 실행해줘. (nl_routing_smoke.py --apply, 백그라운드, baseline mid_errors=10 대비)
# 순3. F-1 부서코드를 코드번호 A,B,C... 접두 기준으로 보면 어떤가? (455 성과부서→389 상위, 본부/지부 271 재집계)
# 순4. 현업회신 묶음(E-1 정의, F-2 11개, F-3 SND, ML grain, DGT) 왜 뭉쳐있냐 → 항목별로 하나씩 분해
# 순5. 19종 파생컬럼 하나씩 풀어보자 (모델 로직 기반 COMMENT 초안, 현업 불요 항목 선별)
# 순6~9. 위 작업 마무리 후 여유 있으면 진행, 없으면 다음 프롬프트:
#   6 2차-B 2단 32 tables / 7 문서02 재작성 / 8 test_agent_tool_claim_gate key-order negative fixture / 9 산출물 03~09+golden 재생성(잔여 0 시)

_Co-authored with CoCo_

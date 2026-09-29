
> #### 🟠 [2026-09-29 O188-B~G] 공8 확정·SV/Agent 배포 · 문서20 정리 · 조직표 규칙 · 공통브랜드 가입경로 · 미연결 BRONZE_CRM 11종 GOLD 설계

- ㉡ 적용(지시 동봉) · 계정 xf98254 · 사용자 포괄 승인 · 확정위반 1(병렬 `edit` 경합 의심 2회 — 재독해로 손상 0 확인)
- B: 문서20 공란 29건 × 10~22번 문서 대조 ⇒ 🟢3 · 🟡5 · 🔄5 · 🔴16 · `30_공8및미회신29건_질문요약.md`·`31_…_쿼리근거.sql`(실측 31줄)
- C: 공8 = agency 우선(사용자) · 15·17·20·22 → `_archive/` · 문서20 판정 8건 기재(공란 21)
- D: 문서20 `-001` 332→300줄(판정 블록 병합) · republish·verify PASS · SV_AD `GA_DEV_UNIT_PRICE` DIGITAL 97,905.60 · Agent EXEC·MKT V6 · `sv_unit_gate.NOT_RATIO` 등재
- D: 조직표 CSV 222 = `USE_YN`·`LAST_UPDT_DT` 활성 + 상위 전체 활성 규칙으로 재현(경로 222/222) · 해외파견 포함(사용자) ⇒ 223
- E: DIM_ORG `IS_ACTIVE_ORG`·`ORG_PATH`·`ORG_LEVEL` · 사업목표 조직 매칭 연사업 614/820·팀 338/440 · degen 5축 · `05_11` SV_TARGET_BIZ 작성(미배포)
- E: DGT 원천 연·월·일 = 29,048행 전건 커버 · 2026-06 이전 0행 · 스모크 중간 오류 = 7문항(종전 「2」 정정)
- F: 공통브랜드 가입경로 3경로(DIM_MEMBER·FACT_MEMBER_SPONSORSHIP_SPAN·FACT_MESSAGE_DISPATCH) · 미연결 11종 → SILVER 10·GOLD 9 · 민감 컬럼 11개 제외
- 🔴 F: O188-E 의 `DIM_ORG` 재귀 CTE `NOT IN` 서브쿼리가 Snowflake 컴파일 거부 — Jinja 전개 EXPLAIN 으로 build 전 적발 · anti-join 로 수정
- G: 사용자 결정 = 질문 21건 추천안 채택 · Agent 처방 D(B+C) · W3·B2~B12 실측 후 종결
- ⏸ dbt 정지점 = A~F 모델 일괄 재배포 + build(라벨 `-O0188-F.md` ▣3)
- read 미반환 0 · 재호출 0

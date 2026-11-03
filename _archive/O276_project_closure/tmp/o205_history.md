## O205 — 2차 Agent 개선 착수 (2026-10-07 · JU93656 · ㉡ 적용 · 확정위반 0)

- 지시 = 회원실 2차 문의 대응(SV_MEMBER_FEE 캠페인 8축 · 서비스 수신 코호트 WIDE/SV · 잔여작업).
- 실측: AGENT_MEMBER VERSION$10 orchestration 에 「SV 간 교차계산(cross-fact) 금지」 유지 ⇒ 질문1·3 ✕ 원인.
- 실측: DIM_MEMBER_ACQUISITION 이 8축 보유(1,617,660행 · UTM 383,572 채움) ⇒ WIDE_MEMBER_FEE 컬럼 노출만.
- 실측: FACT_MESSAGE_DISPATCH 43,440,831행 · 제목 34,549종 · 회원×제목 28,884,126 ⇒ 서비스그룹 grain 채택.
- 실측: 선넘는좋은일은 상위캠페인명에 있음 · 질문1 수신 3,508/미수신 666 · 일반행사 참여율 33.44%/39.79%.
- 신규 발견: CRMN FEA.DATE_SK 166,962행 1970-08 계열.
- 파일: WIDE_MEMBER_FEE.sql · WIDE_MEMBER_SERVICE_COHORT.sql(신설) · _wide_schema.yml · 05_9 · 05_18(신설) · 00_작업계획 §8.
- 정지점: dbt build 사람 대기(R4-1) · 라이브 변경 0.
- 독해 기록: 지침 304줄 전량(R0-8-4·R4-4-4) · 00_BRIEF 전량 · O203-A 48줄 · 00_작업계획 97줄 · 원장-002 97~108 · read 미반환 0.

> #### 🟢 [2026-09-02 O136] Cortex Analyst 30개 추천질문 전수 실측 + 착수표 ⑤·⑰·㉟ 완결
> · **착수 배경**: Trial API 제약 해제 관측에 따라 3개 Agent(MEMBER·OVERALL·MARKETING) 29개 추천 질문에 대해 Cortex Analyst 자연어 질의 ➔ SQL 생성 ➔ Live DB 실행 전수 실측 수행 및 착수표 ⑤, ⑰, ㉟ 후속 작업 집행.
> · **1. 30개 추천질문 실측**: 29문항 중 28건(96.6%) SQL 정상 생성 및 Live DB 실행 28/28(100.0%) PASS. 미생성 1건(`K9`)은 Cross-Fact 2팩트 복합 질의로 가드레일에 의해 정상 거부 확인.
> · **2. 착수표 ⑤ SERVING 표면 검증**: `sv_unit_gate.py`에 AGENT COMMENT/Description 및 소관 SV 종수 검증 축(MEMBER 11종, OVERALL 8종, MARKETING 7종) 흡수 배선, `o70_stale_scan.py` 상설 스캔 전수 PASS(17개 SV + 3개 Agent DDL).
> · **3. 착수표 ⑰ 마케팅 앵커 로직 정합화**: `scripts/gen_section_assembly.py`의 `SECTION_ANCHOR_OVERRIDE`에 마케팅 섹션 4(전환회원 ➔ `FACT_MEMBER_EVENT`), 섹션 5(캠페인별 LTV ➔ `FACT_MEMBER_COHORT`) 반영 후 `09_보고서필드_조립가능성.{md,csv}` 재생성 완료.
> · **4. 착수표 ㉟ ERD 추론 PK 명문화**: 물리 PK와 dbt 추론 PK 분리 표기 유지 및 52개 파이프라인 ERD & GOLD ERD 재생성 완료.
> · **5. 게이트 통과**: 게이트 6종 전수 통과 확인.

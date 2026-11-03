## O225 — dbt 1:N 매핑 안전장치(UTM) + ERP 세부캠페인 배선 + 캠페인 축 전수 배선 (2026-10-14 · xh20001)

- 진행 방식 = ㉡(지시 동봉 · 사용자 「승인 필요 작업 전부 승인」) · 확정위반 1(`R1-7-2` 같은 파일 병렬 edit 6건 — 해시 2회 안정 + 토큰 전건 실재로 무손상 실증 · 이후 순차) · 롤백 판단용 기록.
- 단위 = O225-A(광고 UTM) · O225-B(ERP · 인수인계 라벨은 C 에 통합) · O225-C(캠페인 축) · O225-D(build 후 배포·검증) · O225-E(다음 세션 통합 백로그).

### O225-A 광고비 → 마케팅캠페인 UTM 보조 경로
- 경로 = `FACT_AD_PERFORMANCE` 이름매칭(O45) 단일 → 이름매칭 우선 + UTM as-of 보조(`utm_pick`).
- 규칙 교정 = §15-9 초안 「시작일 최근 → 행수」는 turn24b 4,895,482,455원을 협업 캠페인(사진실의광선생님_* · 매핑 6행)에, meal24a 779,488,400원을 `사진실의광선생님_정용화` 에 보냈다 ⇒ 「매핑 행수 최다 → 시작일 최근」으로 뒤집음(시점 필터 유지).
- 결과 = DIGITAL 미매핑 11,379,933,112원(33.69%) → 2,693,839,977원(7.98%) · 이름↔UTM 1:1 일치 91.9%.
- 테스트 = `assert_fap_ad_cost_preserved`(첫 build FAIL = NUMBER(18,2) 행 반올림 누적 · 원천도 행 단위 ROUND 로 교정) · `warn_fap_mktg_unmapped_ratio` · build PASS 20/20.

### O225-B ERP 콘텐츠구분자(세부캠페인코드) → 마케팅캠페인
- 원천 `BRONZE_ERP.EXPENSE_RESOLUTION.CONTENTS_DELIMITER` 가 SILVER 에서 멈춰 Agent 가 「축 없음」으로 답했다.
- 값 150종 중 149종 CRM CMPGN_CD 일치 · 1:N 0 ⇒ 대표 선정 불필요 · 연결 2,893,355,860원(1.0%) · NULL·「-」 99% 는 향후 입고 가정(사용자 결정).

### O225-C 캠페인 축 전수 배선(사용자 결정 = 회원 월실적 = 그 달 후원 캠페인 · 광고비에 인입경로·채널·카테고리 미부착)
- 발송 = SND 캠페인 3종 SILVER→GOLD→`SV_SERVICE` · 회비청구 = `CAMPAIGN_SK` grain 편입(12,116 → 1,104,308) · 회원 월실적 = 단일 월만 SK + `IS_MULTI_CAMPAIGN`(DEC-41 패턴) · 광고 = `DIM_MARKETING_CAMPAIGN` UTM·국내해외·사업사례.
- 정의 지점 = 매크로 `billing_campaign_asof`(3키 유일 50,835,416 실측) · 재발 방지 = `campaign_axis_gate`(분모 45 · WIRED 22 · GAP 15 · EXEMPT 8) + 음성 테스트 7축 · `session_brief.GATES` 편입.

### O225-D build 후 배포·검증
- build PASS 118 · WARN 5(신규 테스트 3종은 조건 미충족 실측 · 원문 미확인) · SV 5종 배포 · SV 합계 = 팩트 원 단위 일치 5/5.
- 마케팅 Agent 원문 질문 = `analyst_expense_resolution` 선택 · 2026 제작비 493,537,156원(연결 674,000 · 미매핑 492,863,156) = 직접 집계 일치.

### 독해 기록(`R1-3-7-b`)
- 지침 1~304 도착(R0-8-4 · R4-4-4 · O173) · BRIEF 1~141(3,223,955 · 조문 112개) · 인수인계 O224-A·B 전건 도착 · read 미반환 0 · 재호출 0.

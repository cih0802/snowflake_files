# [다음 세션 프롬프트] GN_DW 순서 8 — GOLD dbt 파이프라인 착수

> 아래 블록을 **새 채팅 첫 메시지로 그대로 붙여넣으세요.** SILVER(순서 7)는 완료·검증 상태이며, 이 세션은 GOLD 저작/검증만 다룹니다.

---

```
GN_DW dbt 파이프라인 순서 8 = GOLD 세션을 시작한다. SILVER(순서 7)는 이미 완료됐다.

[먼저 읽을 것]
1. 10_dbt_pipeline/PIPELINE_STATE_20260714.md      — SILVER 현행 상태·배포버전·운영계약
2. 10_dbt_pipeline/GOLD_파이프라인_dbt_작업가이드 20260703.md — GOLD 모델 작성 규칙(정본)
3. 10_dbt_pipeline/models/gold/_gold_ready_schema.yml         — GOLD 계약(컬럼/테스트)

[현황]
- 배포객체 GN_DW.SILVER.GN_DW_SILVER_PIPELINE (VERSION$2, default). dbt 1.9.4.
- SILVER 32객체 적재·test(PASS=9) 완료. GOLD 는 dbt_project.yml 에서 gold: +enabled:false 로 비활성.
- GOLD 대상: models/gold/dim (13) + models/gold/fact (6) = 19객체.
    DIM: CAMPAIGN, DATE, DEVICE, EVENT, GA_EVENT, GA_SOURCE, MEMBER, MEMBER_IDENTITY,
         ORG, PAYMENT, REASON, SERVICE, SPONSORSHIP
    FACT: EVENT_PARTICIPATION, GA_BEHAVIOR, MEMBER_EVENT, MEMBER_MONTHLY, SERVICE_EVENT, TARGET_DEV

[환경 제약 — 반드시 준수]
- 프라이빗 망: 외부 패키지 설치 불가. packages.yml 없음, dbt_utils 금지 → 커스텀 매크로로 대체.
- ⚠️ 식별자 대소문자 교훈: BRONZE_GA4 는 소문자 인용식별자("events_...", "event_date")였다.
  GOLD 가 참조하는 SILVER 는 대문자(표준)지만, 신규 원천 참조 시 실제 저장 케이스를 INFORMATION_SCHEMA 로
  먼저 확인하고 필요 시 "col" AS COL 로 인용할 것. (조용한 0행 회귀 방지)
- profiles.yml 수정 금지(세션 인증). env_var 금지.

[작업 순서(제안)]
1. GOLD 모델 SQL·계약(_gold_ready_schema.yml) 리뷰 → SILVER 참조 정합성 확인.
2. dbt_project.yml 의 gold: +enabled:false → true 로 활성화(가드레일 해제).
3. compile 로 GOLD 컴파일 검증(테이블 불변).
4. build --select gold (run+test) 로 GOLD 19객체 생성·검증. DIM→FACT 의존순서는 ref DAG 자동보장.
5. 결과 스냅샷·이력을 04_silver_design 이력 문서 양식과 동일하게 GOLD용으로 기록.
6. 완료 후 배포객체에 ALTER DBT PROJECT ... ADD VERSION 으로 반영.

[가드레일]
- SILVER 32객체는 건드리지 않는다(재작성 금지). GOLD 만 생성.
- 실행형 EXECUTE/build 는 사용자 확인 후 진행. 대량 재작성은 신중히.

먼저 위 3개 문서를 읽고 GOLD 모델 현황을 요약한 뒤, 작업계획을 제시해줘.
```

---

## 왜 이렇게 넘기나 (핸드오프 근거)

- **스코프 격리:** GOLD는 별도 세션(순서 8). SILVER 컨텍스트와 섞으면 계약 변경 시 연쇄 재작업 위험.
- **교훈 전달:** 소문자 인용식별자 이슈를 명시해 GOLD에서 같은 조용한 회귀를 예방.
- **안전 게이트:** GOLD도 `build`(run+test)로 검증하도록 지시 — SILVER에서 검증된 패턴 재사용.

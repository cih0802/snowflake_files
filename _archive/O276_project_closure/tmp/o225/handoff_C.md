### ▣ O225-C-0 🔴 먼저 알아라

- O225-A(광고 UTM as-of · build PASS 20/20 완료) 위에 단위 2개를 쌓았다 — **ERP 세부캠페인 배선(B)** + **캠페인 축 전수 배선(C)**. 착수점 = 이 파일.
- 🔴 **dbt build 1회 대기**(`R4-1` · 사용자 실행) — 라이브 DDL(ALTER ADD COLUMN)은 끝났고 값은 build 후에 찬다.
  · `dbt build --select CRM_SEND_MEMBER+ FACT_PAYMENT_BILLING_STATUS+ FACT_MEMBER_MONTHLY+ DIM_MARKETING_CAMPAIGN+ FACT_EXPENSE_RESOLUTION+ --project-dir 10_dbt_pipeline`
- 🔴 SV 6종은 **정본 파일만 수정 · 라이브 미배포** — build 확인 후 배포: `05_04` · `05_19` · `05_01` · `05_07` · `05_23` (+ 하류 SV 영향 없음 확인).
- 사용자 결정(O225-B): ERP NULL·「-」 99% 는 향후 입고 가정 · 회원 월실적 캠페인 = **그 달 후원 캠페인** · 광고비에 인입경로·채널·카테고리 미부착.

### ▣ O225-C-1 이번 단위 결과 (xh20001 실측)

| 영역 | 변경 | 근거 수치 |
|---|---|---|
| ERP 지출결의(B) | `FACT_EXPENSE_RESOLUTION` + `CONTENTS_DELIMITER`·`MKTG_CAMPAIGN_SK` · `SV_EXPENSE_RESOLUTION` 마케팅캠페인 축 | 값 150종 중 149종 CMPGN_CD 일치 · 1:N 0 · 연결 2,893,355,860원(1.0%) |
| 발송 | SILVER `CRM_SEND_MEMBER` + SND 캠페인 3종 · `FACT_MESSAGE_DISPATCH.CAMPAIGN_SK` 실배선 · `SV_SERVICE` 캠페인 차원 | SND 원천 4,931,549행 · 마스터 일치 100% |
| 회비청구 | `FACT_PAYMENT_BILLING_STATUS.CAMPAIGN_SK`(grain 편입) · 매크로 `billing_campaign_asof`(정의 지점 1) · `SV_PAYMENT_BILLING_STATUS` | grain 12,116 → 1,104,308 · 캠페인 보유 금액 98.86% · 3키 유일 50,835,416 |
| 회원 월실적 | `FACT_MEMBER_MONTHLY.CAMPAIGN_SK`(단일 월만 · DEC-41 패턴) + `CAMPAIGN_CNT`·`IS_MULTI_CAMPAIGN` · `SV_MEMBER_MONTHLY` | 단일 38,553,741행 · 다중 1,861,948행(98,677,368,326원 · 10.5%) |
| 광고비 | `DIM_MARKETING_CAMPAIGN` + UTM·국내해외·사업사례(+ `*_IS_MULTI`) · `SV_AD` 3차원 + 회원 SV 안내 규칙 | 590개 중 UTM 다중 0 · 국내해외 41 · 사업사례 33 |
| 게이트 | `scripts/campaign_axis_gate.py`(JUDGE · `session_brief.GATES` 편입) + 음성 테스트 7축 | 분모 45 · WIRED 22 · GAP 15 · EXEMPT 8 · 위반 0 |
| 테스트 | `warn_fer_mktg_campaign_multi` · `assert_fpbs_billing_preserved` · `warn_campaign_axis_unmapped_ratio` · FPBS grain 유일 키 8컬럼 갱신 | — |

### ▣ O225-C-2 다음 세션 작업

- ① 👤 build 결과 → 테스트 3종 + grain unique · FPBS 행수 1,104,308 근처 · FMM `IS_MULTI_CAMPAIGN` 비중 4.6% 근처인지.
- ② SV 6종 배포 + 합계 스모크 + 마케팅 Agent 원문 질문(「세부캠페인 → 마케팅캠페인 제작비 재계산」) 재검증 · 도구 선택 실패 시 09_2 버전업.
- ③ `campaign_axis_gate` 🟠 GAP 15건 처리 순서 결정(우선 후보 = `DIM_MEMBER.FIRST_CAMPAIGN` SV 노출 · IRSD 증감액 캠페인 · DGT 캠페인유형1·2).
- ④ O225-A 승계 = 착수표 ⑤ 1:N 안전장치 전수(`tmp/o224/onen_inventory.txt`) · 작업계획 §15-9 규칙 순서 갱신.

### ▣ O225-C-3 🟠 위반·주의 기록

- `R1-7-2` 확정위반 1건 — `CRM_SEND_MEMBER.sql` 에 edit 6건을 병렬 전송 · 직후 해시 2회 안정 + 토큰 전건 실재로 결과 무손상 실증(이후 순차 편집).
- ㉡ 적용(지시 동봉 · 일괄 승인) · 라이브 변경 = ALTER ADD COLUMN 6테이블(비파괴)만.
- 발송 경고 임계(SND 매핑 < 35%)의 기준 43% 는 BRONZE 원행 기준이다 — SILVER dedup 후 값으로 build 뒤 재측정.

_Co-authored with CoCo_

## O236-A 캠페인별 누계중단율 계산 배선 — 후원건 캠페인 귀속 신규 팩트·SV·코퍼스·Agent (2026-10-15 · ua91864 작성 · 👤 운영계 반영 대기 · ㉡ 적용 · 사용자 승인 · 확정위반 1)

- 착수 = O235 이후 Agent 가 산식만 내고 계산은 근사 질문으로 돌림 · 사용자 지시 「SV·Agent 업데이트 필요 여부」 → 실측 → 결정 A(후원건 캠페인) → 계획 승인.
- 실측(jw08094 · 사용자 실행 · FMM 2026-01~09) = YS 1월만 1,535,149.1022 · 1~9월 SUM 13,298,119.8298(8.66배 · 월 수 9) · 중단 246,039.2325 · 개발 249,973.7993 · 「그 달 캠페인」 SK=0 중단 143,393.7432(58.3%) ⇒ 전사 누계중단율 = 13.78%(SV 그대로 SUM 시 1.82%).
- 원인 = FMM 회원×월 grain 이 `YEAR_START_ACTIVE_CNT` 를 매달 행에 반복(`FACT_MEMBER_MONTHLY.sql:347-350`) · `CAMPAIGN_SK` 는 그 달 캠페인 1개일 때만(`:202-217`).
- 신설 `FACT_CAMPAIGN_CUM_STOP`(dbt · gold/fact) = grain 기준연월×CAMPAIGN_SK · 스파인 = FMM (MONTH_KEY, MEMBER_DK) · 중단 = FMSS `DSCNTC_MONTH_KEY` 후원사업 SPNSR_AMT ÷ 10,000 · 연도초 = 1월 스파인 as-of(FMM 판정식) · 개발 = FME DEV_CNT · 캠페인 = 중단·연도초 FMSS 대표캠페인 / 개발 FME 사건 캠페인.
- 06_DDL = 테이블 블록(FACT_PAYMENT_METHOD_CHANGE 뒤) + FK_FCCS_DIM_CAMPAIGN(DROP 목록·ADD) · 모델↔DDL 컬럼 집합·순서 일치 · `_gold_ready_schema.yml` 말미 등재(not_null·relationships).
- SV = `05_24_SV_DDL_CAMPAIGN_CUM_STOP.sql`(DIM_CAMPAIGN 11축 · 지표 4 · VQR 1) · 대사 = `05_24b_대사_CAMPAIGN_CUM_STOP.sql`([0] IF NOT EXISTS 단독 생성 — 06_DDL 전체 재실행 금지 · [1] FMM 합 일치 · [2] SK=0 · [3] 캠페인 규칙 불일치율 · [4] 음성 · [5] SV 스모크).
- 코퍼스 = RT-30 TOOL_NAME `analyst_campaign_cum_stop` · SV_FIELD · 한계 문안 · 2,156행 재생성.
- Agent = 정본 yaml 3종 tool_spec·tool_resources +1 · [O235 산식 질문] 뒤 [O236] 1문장 · 의미 diff 3/3(그 외 불변) · spec 38.8K~58.9K자 · 도구 EXEC 16 · MKT 27 · MEMBER 26.
- 게이트 = campaign_axis · agent_tool_claim · jinja_config · gold_erd_coverage PASS · table_ddl_column rc=1 = 이 계정 BRONZE/GOLD 부재로 DIM_DATE ref 해석 실패(환경 · 신규 팩트는 오프라인 집합·순서 일치).
- 확정위반 1: `R1-7-1`·`R1-7-2` — `_gold_ready_schema.yml` 에 `edit` 툴로 블록 삽입 시 도구가 부분 독해본(약 730줄)을 기준으로 덮어써 **519줄(모델 6개 정의) 유실** · 쓰기 전 크기·사본 미기록이라 자력 복구 불가 → 사용자 복구(해시 `cab2bbab3bf3` = 편집 직전 측정값 일치) → 재추가는 백업 + 바이트 접두 동일 검증 python 덧붙이기. 🔴 교훈 = 대형 yml·DDL 은 `edit` 대신 백업 + 앵커 단일치 assert + 파싱 diff 스크립트로 고친다(이후 원장·코퍼스·Agent 전건 이 방식).
- 1차 보고 정정 = 「29개 모델 유실」은 과대(WIDE 19 = `_wide_schema.yml` 소관 · FACT_RELATION_* 등 원래 미등재) — 실제 유실 = 52−46 = 6개 모델 정의.
- 근거·백업 = `tmp/o236/`(yml·routing·Agent 3종·원장 직전본 · `patch_agents.py`).

### 독해 기록(`R1-3-7-b`)

- `FACT_MEMBER_MONTHLY.sql` 170~259 · 278~367 · 도착 · `cmpgn_rep` · `active_asof` · `YEAR_START_BIZ_AMT`.
- `FACT_MEMBER_SPONSORSHIP_SPAN.sql` 1~108 · `FACT_MEMBER_EVENT.sql` 1~41 · 160~200 · 도착 · `campaign_pick` · `DEV_EXCL_REASON` · `stop_single_biz`.
- `06_DDL.sql` 1360~1403 · 1550~1680 · 1810~1827 · 도착 · `FK_FMSB_DIM_CAMPAIGN` · `EXECUTE IMMEDIATE` · `SHOW IMPORTED KEYS`.
- `05_01_SV_DDL_MEMBER_MONTHLY.sql` 1~100 · `05_16_SV_DDL_BUDGET_YEARLY.sql` 1~64 · 도착 · `first_campaign` · `vqr_o203_yearly_plan_exec`.
- read 미반환 0 · 재호출 0.

_Co-authored with CoCo_

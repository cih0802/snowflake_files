## O237-B 캠페인 월 팩트 · 서비스 코호트 확장 · SV 2 · Agent 도구 +1 · O238 계획서 (2026-10-16 · ua91864 작성 · 👤 배포 대기 · ㉡ 적용 · 사용자 승인 · 확정위반 0)

- 착수 = 사용자 지시 「① 캠페인 귀속 월 팩트 ② 코호트 확장 ③ SILVER·GOLD·SV·AGENT 문서 작업 승인 · 링크 구분자 작업계획 + 다음 세션 프롬프트 · 넌 문서 수정만」 → 계획 제시 → 전체·가정 2건 승인.
- SILVER = 변경 없음(원천 CRM_MEMBER_SPONSOR_SPAN·CRM_MEMBER_AMT_CHANGE·FACT_MEMBER_FEE·FME·FMD 로 충분).
- `FACT_CAMPAIGN_MONTHLY`(gold/fact) = 스파인 FMM · span as-of(활동·전월말·중단·연도초) · FME 개발 · 금액변경 감액(원천 CMPGN_CD) · FACT_MEMBER_FEE 회비(회원×후원사업 → 그 달 유효 span 대표캠페인) · 누계 = 같은 해 1월~기준월(FCCS 식) · 납입방식 = 청구 결제수단(잠정).
- 사전 대사 = jinja2 렌더본(`tmp/o237b/render.py` · ref → GN_DW 정규명 · 매크로 동치 구현)을 GN_DW.OPS 세션 임시 테이블로 만들어 FMM 과 대조 → 202601·202609 8 measure DIFF 0 · 키 중복 0 · 2,166,493행 · 중단 SK=0 0% · 활동 결제수단 0 = 0.59%(202609).
- 정정 = O237-A 에서 FCCS 연도초를 1,535,149.1022 로 인용했으나 그 값은 jw08094 실측이었다 — 이 계정(ua91864) FMM 1월·FCCS = 1,535,186.1022 로 서로 같다(계정 간 적재 시점 차이 · 정의 차이 아님).
- `WIDE_MEMBER_SERVICE_COHORT` +6열 = D5_LETTER_FLAG · D5_GIFT_FLAG · RETAINED_3M/6M/12M_FLAG · PAID_AFTER_3M_FLAG(맨 끝 append) · 렌더본 = 기존 45열 라이브 뷰와 양방향 MINUS 0(6,602,895행) · 미수신 행 신규열 비NULL 0.
- 결함 시정 1 = 관측 최신월을 FMM MAX(MONTH_KEY) 로 잡았더니 미래 청구월(2029-11 등)이 있어 12개월 관측 = 수신 전원으로 나왔다 → 「마감된 직전 월 이하 최대월」로 교체 → 선넘는좋은일(2026 신규) 12개월 관측 0 확인.
- SV = 05_25 신규(캠페인 11축 + 납입방식 · metric 15 · VQR 1) · 05_18 차원 +6 · metric +6(RETAINED_3M/6M/12M_RATE · PAID_AFTER_3M_RATE · D5_LETTER/GIFT_PART_RATE).
- 매핑 = `o237_build_formula_map.py` 에 `upd()` 블록(행 키 보존 덮어쓰기) · G1 31 → 5 · `--check` 라이브 부재 0 · PENDING 28 토큰.
- Agent = `tmp/o237b/patch_agents.py` · 3종 도구 +1 · [O237 산식 대응] 문장 뒤 [O237-B] 1문장(MEMBER = 서비스 코호트 안내 · MKT·EXEC = 회원 Agent 소관 안내) · 의미 diff 3/3.
- O238 = `12_agent개선과제/O238_원천연결키_작업계획.md`(원천 7종 · 연결키 6묶음 판독표 · 실측 ①~⑥ · W1~W6 · 하지 마라) · 프롬프트 = `05_SV-Agent_ai/99_next_prompt.md` 머리 블록.
- 배포 순서 = 27_O237 「O237-B」 절(B1→B2→B3→[1]+B4→[2]→[3]) · 스모크 ③ 교체(캠페인별 납입율은 산출 가능해짐).

### 독해 기록(`R1-3-7-b`)

- `WIDE_MEMBER_SERVICE_COHORT.sql` 1~274 · 도착 · `SNG_INSTANT` · `d5_stop` · `ONLINE_EVENT_PART_ROWS_AFTER`.
- `FACT_CAMPAIGN_CUM_STOP.sql` 1~99 · `FACT_MEMBER_SPONSORSHIP_SPAN.sql` 1~108 · 도착 · `ys_by_month` · `campaign_pick` · `SPNSR_CMPGN_CD`.
- `FACT_MEMBER_MONTHLY.sql` 219~235 · 256~430 · 도착 · `amt_month` · `active_asof` · `STOP_AMT_CNT`.
- `macros/billing_campaign_asof.sql` · `gold_helpers.sql` 매크로부 · 도착 · `BILLING_CMPGN_CD` · `month_key_offset`.
- `05_18_SV_DDL_MEMBER_SERVICE_COHORT.sql` 28~53 · 91~103 · 도착 · `EVER_STOPPED_RATE` · `AVG_D5_STOP_SPONSOR_DAYS`.
- read 미반환 0 · 재호출 0.

_Co-authored with CoCo_

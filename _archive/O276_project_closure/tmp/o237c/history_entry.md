## O237-C 스모크 검증 · G1 3건 모델 · 이상치 규칙 · O238 W1·W2·W3-L4 (2026-10-16 · ua91864 작성 · 👤 배포 대기 · ㉡ 적용 · 사용자 지시·결정 · 확정위반 3)

- 착수 = 사용자 「문서실행순서 전부 실행 · dbt build 전체 · 결함 수정 + 잔여 전부」.
- 라이브 확인(ua91864) = 05_25b(실제 위치 `_archive/`) 465개월 BAD 0 · 누계 DIFF 0 · 신규 metric 12 실재 · 코퍼스 C1 64·C2 17·C3 8·C4 19·C5 30·G1 5·G2 3 · Agent 3종 도구·규칙 배선.
- 스모크 8문항 = `DATA_AGENT_RUN` 직접 실행 · 결함 후보 3 판정:
  - ⑥ `<answer>` 노출 = 재실행 2/2 비재현(O212 금지 규칙 이미 존재) ⇒ 1회성.
  - ⑤ 도구명 `system_execute_sql` = `analyst_campaign_monthly` VQR 경로(`verified_query_used: true`) ⇒ 정상.
  - ④ 0.14% vs 0.123% = 내 기대값이 전 기간 값(표기 오류) ⇒ 결함 아님 · spec·Agent 변경 0.
- 발견 = GA 계열 SILVER/GOLD 전부 0행 — 전체 빌드에서 새 테이블 + 롤링 창(오늘−3일) > 원천 최대일 20261003 ⇒ 백필 명령 = `02_dbt_parse_compile_build.sql:32`.
- G1 해소 3(사용자 결정):
  - 공#31 최종캠페인 = MSTR 로직 없음 · 90 정의서 = CRM 명 ⇒ 원천 LAST_CMPGN(546,221명) vs 파생(1,621,410명 · 활동금액 큼) ⇒ 파생 채택 · `DIM_MEMBER.LAST_CAMPAIGN`(잠정) · SV_MEMBER_MONTHLY `last_campaign`.
  - 결함 시정 = MAX_BY 키에 TRY_TO_NUMBER(비숫자 코드 1,098,925행 NULL 탈락 → 849,242명) → ROW_NUMBER 로 교체 → 1,621,462명.
  - 공#79 = 신규 `FACT_SPONSORSHIP_MONTHLY`(월×후원사업) · 202609 FMM DIFF 0 · 15.6991% · SV_MEMBER_SPONSOR_BIZ `fsm` + metric 4.
  - 신규#33 = FMD `CLICK_DEV_D5/D30_MEMBERS`(클릭일 기준 · 인정 개발) · 2025~ 클릭 126,799 · D5 377 · D30 1,839(발송일 기준 531/2,363 은 클릭 전 개발 혼입) · SV_SERVICE metric 5.
- 잔여 G1 2(결연아동코드 · 미납서비스 전환) = GA 백필 후 GA 기반 설계(사용자 결정) · 매핑 146 = C1 65·C2 17·C3 8·C4 20·C5 31·G1 2·G2 3.
- 이상치 규칙 = SV_CAMPAIGN_MONTHLY (5) 분모 100건 미만 순위 제외 + 제외 사유·개수 명시(사용자 결정).
- O238 W1 = SV_AD RT_TYPE 동의어 「특집」(= 값 '방송') · W2 = `output/O238_link_key_gap.csv`(L1 54.9% · L2 100% · L3 99.6/89.5% · L4 15.9% · L5/L6 원천 코드 0) · SV_AD 미매핑 = 재송출 100% · 영상 95.9%.
- O238 W3-L4(사용자 결정 = 코드형만) = FACT_AD_PERFORMANCE `video_code_mk`(U#### → 상위캠페인 → 마케팅캠페인 1:1 only) · 사전 측정 영상 미매핑 95.9% → 87.5%(3,406행).
- 확정위반 3: ① 매핑 생성기 `edit` 후 405행 절단(백업 없음 · 같은 세션 독해 원문으로 꼬리 복원 · py_compile·생성 OK) ② 05_10 백업을 첫 편집 뒤에 뜸 ③ 같은 파일 병렬 `edit` 2회(R1-7-2 · 행수·diff 로 무손상 확인).
- 배포 = `05_SV-Agent_ai/28_O237C_G1해소_배포순서.sql` · 백업 = `tmp/o237c/bak/`.

### 독해 기록(`R1-3-7-b`)

- `00_guides/00_작업지침_세션운영규칙.md` 1~304 · 도착 · `R0-8-4` · `R4-4-4` · `O143`.
- `20_issue/00_BRIEF.md` 23~142 · 도착 · `O0237-B` · `조문 112개`.
- `99_NEXT_SESSION-O0237-A.md` 1~50 · `-B.md` 1~54 · 도착 · `G1 31 → 5` · `B1 → B2 → B3`.
- `27_O237_산식대응_배포순서.sql` 1~86 · `_archive/05_25b` 1~65 · 도착 · `B7` · `SUM_1_9`.
- `FACT_CAMPAIGN_MONTHLY.sql` 1~219 · `DIM_MEMBER.sql` 1~95 · `FACT_MESSAGE_DISPATCH.sql` 1~174 · `FACT_AD_PERFORMANCE.sql` 1~181 · 도착 · `pay_biz` · `EMAIL_RECV_REFUSE_YN` · `d5 as (` · `utm_pick`.
- `05_10` 1~100 · `05_01` 2~101 · `05_04` 155~175 · `05_25` 88~91 · `O238_원천연결키_작업계획.md` 1~94 · `o237_build_formula_map.py` 305~440 · 도착 · `vqr_active_by_sponsorship` · `FIRST_MARKETING_CAMPAIGN` · `W6` · `def check`.
- read 미반환 0 · 재호출 0.

_Co-authored with CoCo_

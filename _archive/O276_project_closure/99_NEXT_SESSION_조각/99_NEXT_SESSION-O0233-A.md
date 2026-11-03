<!-- LLM-METADATA
doc_id: HANDOFF_O0233_A
doc_role: 인수인계 — 세션 `O233-A` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-15
created_by: O233-A
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0233-A -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O233-A-0 🔴 먼저 알아라

- 개발계 = jw08094 · 2026-10-15 · **운영계 반영 없음** · ㉡ 적용(지시 동봉 · 작업계획 전부 사용자 승인).
- 🔴 확정위반 4 = `R1-7-2` 같은 파일 병렬 edit 3건(백로그 `20_O21X` · `FACT_MEMBER_COHORT.sql` · /tmp 수정안 · 전건 유실 0 확인) · O232-B 이월 1건(SV·DDL 편집 전 해시 확인 일부 생략 · 게이트 지연 실행).
- 🔴 **마운트 단절 재발**(작업 중 `/workspace` I/O error) ⇒ 이후 쓰기는 `/tmp` 작성 → `cortex ws cp` 업로드. 편집분 13파일은 `cortex ws cp` 내려받기로 토큰 대조 13/13.
- ⚠️ 함정 = `EXECUTE IMMEDIATE` 안의 `USE ROLE GN_DW_ADMIN` 은 **세션 롤을 바꾼 채 남긴다**(그 롤은 기본 웨어하우스 없음 ⇒ 다음 쿼리 「No active warehouse」) · 끝나면 `USE ROLE ACCOUNTADMIN` → `USE WAREHOUSE COMPUTE_WH` 를 **따로** 실행한다.
- 원장 §1 에 O230~O232 행이 없다(창작 금지 · 손대지 않음 · 각 라벨 파일이 정본).

### ▣ O233-A-1 이번 단위 결과

| 순 | 결과 |
|---|---|
| ① #36 기록 복구 | 라이브 재측정 = DIM 591/591 · 불일치 0 · 192자 · FAP 271,489 중 246,371 · 불일치 0 · 백로그 #36 ✅ · `문서실행순서.md` 「O233 덧입힐 때」 3단계 |
| ② DEC-62 | 코호트 획득 = 신규 우선 → 최초 개발 FALLBACK(30-017 말미) · 실측 1,621,070 = NEW 1,618,360 + FALLBACK 2,710 · 규칙 변경 시 차이 NEW 19명 · FALLBACK 20건 = 유효 일자 없는 회원(규칙 차이 아님) · #33 잔여 닫힘 |
| ③ LTV 회신 | 비교표 §4 회신 열 · §6(최종중단 44,006명 · 상한80 50.1→52.7 · 무기한 120.9→130.3 · 「80 = 상한? 기대값?」 확인 문안 · 관측<80 셀 외삽 경고) · CSV 끝 8열(72/72) · FMC `LAST_STOP_DATE_SK`·`OBS_TENURE_MONTHS_LAST`·`IS_STOPPED_OBS_LAST`(ADMIN ALTER · 06_DDL · yml) · FMCS 입력 = `*_LAST` · vars `ltv_caps:[80]`·`ltv_min_cell:1`·`ltv_unlimited`·`ltv_horizon_max:480` · 무기한 = `LTV_CAP_MONTHS = 9999` · 테스트 ㉤ |
| ④ RAG | `tools/O233_synonym_overlay.csv`(9행 · 빈 SYNONYMS 만 · 90_ 원천 무수정) · 코퍼스 2,154 재적재(변경 9행 · SYNONYMS·SEARCH_TEXT 만) · REFRESH · 검색 = 「누적중단률」「누계중단비중」「…계산식」 1위 MET_NEW-17/TERM-0210 · Agent 3종 「유사 지표 되묻기」 = MEMBER $5 · EXEC $8 · MKT $9 |
| ⑤ 스트림릿 | 원본 SQL 컴파일 오류 3(BROADCAST_DATE · DEVELOPMENT_INFLOW_PATH · ACTIVITY/PAYMENT_RATE 부재) · 실측 = 디지털 367.3→205.0(1:N 107.0 폐기) · 영상 66.4→1.5(키 NULL 57.1 · 코드매칭 +4.4) · 재방송 174.9→0(키 전건 NULL) · GOLD 기준 수정안 검증 258,950행(325.2·66.4·164.8억 = GOLD · 미연결 200.3억 행 보존) · 현업 요청 문안 = `output/O233_스트림릿_광고비_진단.md` §5 |

### ▣ O233-A-2 ㉠ 잔여

| 순 | 작업 | 판정 |
|---|---|---|
| ① | 👤 `dbt build --select FACT_MEMBER_COHORT FACT_MEMBER_COHORT_SURVIVAL --project-dir 10_dbt_pipeline` → 기대 = 전체 9999 행 RMST 130.27 · 80 행 52.75 · 테스트 ㉤ PASS → SV_MEMBER_COHORT `SURV_LTV_CAP_MONTHS` COMMENT 에 9999 = 무기한 추가 후 05_03 재배포 | #32 |
| ② | 👤 현업 = 「80」이 상한인지 기대값인지 · 재후원 공백 기간 처리 · 관측<80 셀 처리 회신 → RT-14·27 · Agent LTV 지침 교체 | #32 |
| ③ | 👤 스트림릿 실제 소스(앱·계정) 확인 → 수정안 diff · 금액 정의(AD_COST vs 청구액·총비용) 결정 · 대행사 코드 보완 요청 발송 | 광고비 |
| ④ | 🟠 검색 「누계중단비중 산식」(「산식」 단독 표기)만 1위 미적중 — 되묻기 지침으로 방어 · CoWork UI 수동 스모크 필요(트라이얼 DATA_AGENT_RUN 차단) | RAG |
| ⑤ | 👤 운영계 = O231·O232·O233 덧입힘(문서실행순서) | #35 |
| ⑥ | 👤 현업 = 처리통보 키워드 | #34 |

### ▣ O233-A-4 ⚪ 결정 완료(재론 금지)

- 코호트 획득 = 신규 우선 → FALLBACK(DEC-62 · 사용자 승인).
- LTV = 최종 중단 기준 · 상한 80 + 무기한(9999 표지) · 전체 이력 · 셀 최소 1(현업 회신 · 「80」 의미만 확인 대기).
- 동의어는 90_ 원천이 아니라 오버레이로 넣는다(R2-8).
- O232-B-4 결정 전건 유지.

_Co-authored with CoCo_

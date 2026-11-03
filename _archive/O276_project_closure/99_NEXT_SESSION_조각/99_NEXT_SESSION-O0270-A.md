<!-- LLM-METADATA
doc_id: HANDOFF_O0270_A
doc_role: 인수인계 — 세션 `O270-A` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-29
created_by: O270-A
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0270-A -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O270-A-0 🔴 먼저 알아라

- `O270` = O269-C-4 집행 + 마케팅 피드백 3차(데분_5·6·7 · 출처명) 분석·반영 + R95 결과 반영(2026-10-29 · TRIALADMIN · ZS83821 개발계 · ㉡ · 사용자 전 작업 승인).
- 🔴 사용자가 준 `R96쿼리결과.md` 는 **R95(Q01~Q11 · 운영계 ZL50263) 결과**였다 — R96 은 이번에 새로 만들었고 아직 운영계 미실행.
- 🔴 라이브 변경(개발계) = `FACT_MKTG_CAMPAIGN_MONTHLY_COST` 컬럼 3 추가 + PROD_COST COMMENT(47 [D1] · ALTER 만) · 👤 dbt build · SV·Agent 재배포 미실행.

### ▣ O270-A-1 결과

| 순 | 작업 | 결과 |
|---|---|---|
| ① | 테스트 2종(C-1 ②③) | `run_sql_file.py` 기본 dry-run + `--apply` · `test_pipeline_erd` 기대 수 = 생성기 입력 유도 → ERD 4종 누락 발견 → `gen_pipeline_erd.py` 재생성 · 두 테스트 rc=0 · 호출 문서 3곳(`scripts/README_운영도구.md` · `문서실행순서_llm실행.md` · `문서실행순서_운영계_LLM실행카드.md`) `--apply` |
| ② | R95 반영 | Q01 → `05_07` 캠페인유형 3열 열거 = 운영계 공통값 · 개발계 전용값(하이픈·0·전체사업·통합 통합)은 열거 밖 문장 · Q07~Q10 ERP `YEAR` 비숫자 0건(원천 정정 추정 · C-5 처방 불요 판정) · Q04 운영계 `daily` 10-29 06:01 `FACT_AD_PERFORMANCE` FAILED(원문 200자 절단 → R96 Q01) |
| ③ | 데분_2 | 제작비 = 콘텐츠구분자 기재분(현업 확정) 문안 · 06_DDL · 모델 머리말 · 05_31 · Agent |
| ④ | 데분_1㉡·6 | 최종 광고비 = 디지털 LAST_STMT_AMT + 영상 LAST_AD_COST + 방송 TOT_COST · 팩트 3열(`AD_COST_REBROADCAST_TOT` · `FINAL_AD_COST` · `FINAL_AD_COST_NULL_ROWS`) · 05_31 지표 3 · VQR · Agent 「정산액 없음」 금지 · 신규 `05_SV-Agent_ai/47_DEPLOY_FINAL_AD_COST.sql` |
| ⑤ | 데분_4 | 80 = CEIL(관측 중 회원 평균 유지개월 79.13 · 736,453명 · 개발계) = 팩트 상한 80 일치 → Agent LTV 2단(현행 → 예측) 세로형 짧은 표 + 안내 1줄 |
| ⑥ | 데분_7 | 영상광고 원천 `DVLP_CNT` = 2026-06~08 전 행 0 · 01~05 일부 행(BRONZE 개발계 실측) ⇒ 원천 결함 · SV_AD·Agent 「0건 단정 금지 · MSTR 참고」 가드 |
| ⑦ | 출처명 | Agent 표기 = 디지털 / 영상광고 / 방송(REBROADCAST · 하위 재송출·방송) · 「재방송」 표기 금지 · 코드값·동의어 불변 · SV_AD AD_SOURCE_TYPE COMMENT |
| ⑧ | 데분_1㉠ | CRM 개발건 `FACT_MEMBER_EVENT.MKTG_CMPGN_CD_AT_EVENT` = `DIM_MARKETING_CAMPAIGN.MKTG_CAMPAIGN_BK` 연결 2026-01~09 100% · 10월 93.4% · 근거 표 = `12_agent개선과제/O238_원천연결키_작업계획.md` §0-2 · 값에 소수 있음 |
| ⑨ | R96 | `85_실제 인수인계 문서/30_현업요청대응/_근거쿼리/R96_O270_에이전트_피드백3차_질문답변.sql`(Q01~Q11 · Agent 질문답변·SQL · 제작비 기재 패턴 · 영상 개발건 · 원천별 최종 광고비 · 재송출/방송) |

### ▣ O270-A-2 ㉠ 이 작업의 잔여

| 순 | 작업 | 판정 |
|---|---|---|
| ① | 👤 dbt 재배포 + `build --select FACT_MKTG_CAMPAIGN_MONTHLY_COST` → 47 [D2] 대사(개발계) | 사용자 실행 · 기대 = 2026 최종 광고비 디지털 145.1억·영상 7.1억·방송 33.5억(개발계 사전 실측) |
| ② | 47 [D3] SV 4종 + [D4] Agent 재배포 → [D5] `sv_code_label_gate` 8조각 → Agent 재질문(데분_1·4·5·6·7·출처) | R4-4-3 · 개발계 → 운영계 |
| ③ | 👤 운영계 R96 실행 → 데분_5 원인 확정(제작비 기재 패턴·적재 시각 · 어제/오늘 SQL 차이) · daily FAILED 원문 | 운영계 회수 |
| ④ | 데분_1㉠ `DEV_CNT_CRM` 컬럼 추가 설계 | 🔴 현업 정의 1회 확인 = CRM 개발건수가 사건 수인지(소수 = 금액 환산) · MSTR 열 유지 여부 |
| ⑤ | 데분_7 처방 | 🔴 현업 확인 = 영상광고 「실제 마감값」 기준(MSTR DR광고 등) · 대행사 영상 리포트 개발건 칸 재보고 요청 여부 |
| ⑥ | 방송 TOT_COST 2026-09·10 전 행 NULL(콜센터운영비 미입력 · 개발계) | 운영계 R96 Q10 으로 확인 → 현업 입력 요청 |
| ⑦ | SV_AD 에 최종 광고비 지표(WIDE_AD_COMBINED 에 TOT_COST 없음) | 필요 시 후속 |
| ~~⑧~~ | ~~80 패키지 재빌드(`build_handoff.py`) — run_sql_file 사본·README 사본 갱신~~ ➔ 🟢 [O272-C] 재빌드 완료 573 · MISSING 0 | ~~다음 정리 시~~ 완료 |

### ▣ O270-A-3 ㉡ 워크스페이스 백로그

| 순 | 작업 | 판정 |
|---|---|---|
| ① | 현업 회신문(데분 2·3차) — 데분_4·6 반영 · 데분_5·7 원인 · 출처명 · ㉠④⑤ 질문 | ㉠①② 후 |
| ② | O269-A-3 현업 회신 대기 묶음 · A-4 공지 2건 | 그대로 유효 |
| ~~③~~ | ~~C-5 ERP YEAR 처방 비교 = 운영계 0건으로 보류(재발 시 ㉰ 격리 모델)~~ ➔ 🟢 [O272-D] **종결** — 사용자 결정(2026-10-30) = 원천이 YEAR 를 빠뜨리지 않고 넣는다 · 🔴 모델 격리(㉰)를 구현하지 마라 | ~~종결 후보~~ 종결 |

_Co-authored with CoCo_

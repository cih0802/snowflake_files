<!-- LLM-METADATA
doc_id: HANDOFF_O0190_B
doc_role: 인수인계 — 세션 `O190-B` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-09-30
created_by: O190-B
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0190-B -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O190-B-0 🔴 먼저 알아라 (2026-09-30 · bt97381)

- 🟢 사용자 build `CRM_BIZ_TARGET+` = PASS 14 · 재조회 = 5,244행 · DK 유일 · `BDGT_PRCD_NM` 채움 5,244.
- 🟢 사용자가 **과금·승인 대상 작업 일괄 사전 승인**(2026-09-30) — 스모크 2회 · Agent 재버전 · SV 재배포 집행.
- 🔴🔴 **ML `ML_RST_DATA_ONCE_CONVERSION` grain 붕괴** — `STDR_MT` 1종(202609) · 회원당 1~6행 · 서로 다른 예측값 공존
  (36,664행 · 고유행 16,503 · 회원 8,055). ⇒ 뷰 [8] `IS_LATEST_OBSERVED` **전건 TRUE** = 회원수 과대계상.
  🔴 어느 행이 현행 예측인지 판정할 키가 원천에 없다 ⇒ **값 창작 금지로 뷰 미수정** · 원천(ML 담당) 확인 대상.
- ⚠️ 세션 중 샌드박스 `/tmp` 가 비워졌다 — 임시 스크립트·1회차 스모크 요약은 소실 · 이 절이 정본.

### ▣ O190-B-1 🟢 이 단위가 끝낸 것

- **Agent EXEC·MKT VERSION$4**(롤백 = VERSION$3) — `analyst_target_biz` 설명·지시문을 9종·단위별 지표로 교정
  (치환 7종 · 잔여 옛 어휘 0 · 도구 집합 불변 9·8 · 스테이지 size 대조 OK · 기본 버전 텍스트 재조회 확인).
- **COMMENT 규칙 검토**(SILVER·GOLD·SV·AGENT) — 게이트 6종 rc=0 + 게이트 밖 라이브 직접 스캔:
  - 🔴 규칙7 수치 혼입 2건 교정(`CRM_MEMBER_SPONSOR_SPAN.CMPGN_CD` 「채움 100%」 · `WIDE_MEMBER_EVENT.SPONSORSHIP_DIV_NAME` 개발건수) — 파일+라이브.
  - 🔴 사업목표 3객체(SILVER·FACT·WIDE) COMMENT 가 구 구조(「연사업/팀」·단위 「건」·「입고 대기」) — 파일 4개 + 라이브 18문 교정 · 잔여 0.
  - 🟢 금지어(미상·알 수 없음) 38건 = 전부 「창작하지 않는다」 부정 규칙문(오탐 · J8).
  - 🟢 SV 요소 COMMENT 숫자 = 정의 상수(÷10,000 · 95% CI · 100% 경계) — 규칙7 위반 아님.
  - 재게이트 = 컬럼 GOLD 948/948 · SILVER 1,100/1,100 · 테이블레벨 46·57 일치 · rule7 0 · DDL 집합 103/103 · SV rule7·객체 PASS.
  - 🟠 **범위 밖 보고** = SERVING ML 뷰 8종 컬럼 COMMENT **106/106 부재**(뷰 DDL 에 컬럼 COMMENT 절 없음).
- **NL 스모크 36문항 1회차 = 🔴 FAIL**(호출 성공 36 · 실패 0 · SQL 생성 33 · 중간 오류 14).
  - 최다 원인 7건 = `DATE.FULL_DATE` — 동의어로만 있던 이름을 Analyst 가 식별자로 추측.
  - 처방 = SV 4종(MEMBER_EVENT·SERVICE·EVENT_PARTICIPATION·AD)에 `date.FULL_DATE` **실차원 추가** + 동의어 제거 · 배포 · 조회 실증.
  - 🔴 판정 = O189 식별자 규칙은 3종 **모두 이미 탑재**돼 있었다 ⇒ 지시문 가드는 효과가 없다(구조 처방만 효과).
- **NL 스모크 2회차 = 🔴 FAIL · 중간 오류 14 → 10**(호출 성공 36 · 실패 0) · `DATE.FULL_DATE` 7 → 1.
  - 잔여 최다 = **metric 이름을 CTE 컬럼으로 참조** 7건(`FMSB.CURRENTLY_ACTIVE_MEMBERS` · `TOTAL_GOAL_CNT` · `F.TOTAL_EXEC_BUDGET` ·
    `AD.TOTAL_AD_COST` · `FSE.TOTAL_SEND_MEMBERS` · `DF.FORECAST_AMT` · `LS.AVG_LTV`) — Analyst 생성 단계 거동 · SV 선언으로 막을 수 없다.
  - 기타 = `DATE.YEAR` 1 · `FME.EVENT_DATE` 1 · `DATE.FULL_DATE` 1(AGENT_MEMBER_05 · 대상 SV 미확인).
  - ⚠️ LLM 생성은 비결정적 ⇒ 14→10 은 **처방 효과의 시사**이지 증명이 아니다. 원문 = `tmp/nlsmoke/`(2회차).

### ▣ O190-B-2 🟠 남은 작업

| 순 | 구분 | 중요도 | 작업 | 상태 | 선행 |
|---|---|---|---|---|---|
| 1 | ㉠ | 🟠 | 스모크 잔여 10건 — metric-as-CTE 7건은 SV 로 못 막는다 ⇒ 수용(최종 응답 36/36) 또는 판정 기준 조정을 사용자 결정 · `DATE.YEAR`·`FME.EVENT_DATE` 는 실차원 추가로 처방 가능 | 👤 결정 | — |
| 2 | ㉠ | 🔴 | ML ONCE_CONVERSION 원천 grain 확인(ML 담당) → 뷰 [8] 현행 예측 판정 규칙 | 👤 | — |
| 3 | ㉡ | 🟠 | SERVING ML 뷰 8종 컬럼 COMMENT 106 부여(`21_ML_SERVING_뷰_DDL.sql`) | 신규 | — |
| 4 | ㉡ | 🟡 | 사업목표 주석 잔여 — `CRM_BIZ_TARGET.sql` 헤더 :3~:8 · FTP `.sql` :36 코드 주석(라이브 미도달) | 신규 | — |
| 5 | ㉠ | 🔴 | O189-C ▣2 4~9행 승계(배선 7건 · 2차-B 2단 32테이블 · 문서02 재서술 · W3 잔여 · 신규 19종 COMMENT · 현업 회신) | 승계 · 미착수 | — |

_Co-authored with CoCo_

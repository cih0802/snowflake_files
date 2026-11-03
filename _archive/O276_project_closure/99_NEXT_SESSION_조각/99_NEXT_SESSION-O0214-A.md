<!-- LLM-METADATA
doc_id: HANDOFF_O0214_A
doc_role: 인수인계 — 세션 `O214-A` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-08
created_by: O214-A
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0214-A -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
## O214-A 인수인계 (7차 COMMENT 규약 검토·시정 + 내부 잔여 집행 · 다음 = 8차 eval 퇴행 분석)

### ▣ O214-A-0 🔴 먼저 알아라 (2026-10-08 · nj58180 · ㉡ 적용 · 승인 일괄(R4-4-3 4건 별도 승인) · 확정위반 2)

- 🟢 COMMENT 검토 기준 = `05_0_SV_DDL.sql` COMMENT 규약 1~4 + 지침 R2-6·R2-7 · 대상 = 7차 변경 객체(SILVER·GOLD·SERVING · 2026-10-08 변경 69객체 + SV 22종).
- 🟢 시정(파일 정본 → 라이브):
  · 규약4 세션 태그 = 7차 신설 `O213` 태그 전량 제거(파일 156줄 · 라이브 = 컬럼 34 · 테이블레벨 4 · SV 항목 111 → 0).
  · 규약1·3 = 7차 `N종` 개수 표기 → 실측 원값 열거(예산 장·관·항·재원 · 지출결의 출처구분) 또는 삭제.
  · 빈 COMMENT = `SILVER.BIGQUERY_SESSION` 41 · `GOLD.FACT_BIGQUERY_SESSION` 35 · 지출결의 2테이블 40(라이브 유실) → 0.
  · range 모델 2종은 06·08 에 **비실행 `/* */` 선언 블록**으로 정본화(선생성 금지 유지 · drift 게이트가 블록을 읽는다).
  · SV_MEMBER_FEE 규칙7 라이브 위반 2(「202,601」) → 숫자 없는 서술 · `test_sv_rule7_scan` FAIL 해소.
  · SV 19종 재배포(CREATE OR ALTER · 차원 수 불변) · MSTR_SPNSR_DVLP_V 컬럼 4 = `ALTER VIEW … ALTER COLUMN … COMMENT`(뷰 재생성 없이 된다 · 실측).
- 🟢 게이트 = comment_drift 0 · audit_ddl_rule7 0 · sv_rule7 라이브 0 · sv_comment_object PASS · 음성 테스트 전건 PASS.
- 🟢 OPS 임시 객체 DROP = O213_* 7표 + 프로시저 5 · 보존 = `tmp/o214_ops_backup/`(CSV 행수 7/7 일치 · DDL 5) · 잔존 0.
- 🟢 NL 회귀 = 49/49 응답 · 중간 오류 1(기준선 1 이하) ⇒ PASS(`tmp/nlsmoke/_summary.json` · 재개 러너 `tmp/o214_nl_resume.py`).
- 🔴 eval v3_0(VERSION$7) = AC EXEC 0.761 · MEMBER 0.769 · MKT 0.786(기준선 O211-B VERSION$3 = 0.905 · 0.846 · 0.929) · TSA 3종 하락 · 분해 = `tmp/o214_eval_regress.tsv`.
  · 🔴 기준선이 VERSION$3 이다 — VERSION$6 은 eval 미실행이라 **7차 단독 원인으로 단정하지 마라**.
- 🔴 `_archive` UNLABELED 정리 = 229 삭제 · 26 보존(인용 6 · 원본별 최신 20) · 🔴 **마운트 `os.remove` 도 경로 접두 삭제였다**
  (`…prehub.5` 삭제가 `…prehub.54` 를 지움 · 보존 대상 4건 소실) → `COPY FILES … versions/version$8/` 로 4건 복원 · 두 축 26/26 확인.
- 🔴 확정위반 2 = R1-7-9(quoted heredoc 로 배포 스크립트 복제 1 · 영향 0) · R1-7-7(접두 삭제 부수 소실 4 · 복원 완료).

### ▣ O214-A-1 🟠 ㉠ 이 작업(7차 → 8차)의 잔여

| # | 할 일 | 비고 |
|---|---|---|
| 1 | eval 퇴행 원인 분석 — ① EXEC 회비 예측(Q03·Q04)이 도구 미호출 ② 신규 개발 건수 by 인입경로·캠페인카테고리(X1·X2)가 MSTR SV 로 라우팅 ③ MKT 무도구 정답(Q19·Q21)이 analyst_ad 직행 | `tmp/o214_eval_regress.tsv` |
| 2 | VERSION$6 eval 1회(과금) — 6차·7차 기여 분리 | 롤백 판단 근거 |
| 3 | Analyst 1차 SQL 오류 패턴(지표명을 컬럼처럼 · CTE 미선택 차원 · `CAL_YEAR` invalid identifier) — AI_SQL_GENERATION 규칙 보강 | NL MARKETING_14 |
| 4 | 문서20 N-29 ①~⑧ 회신 반영 · 라벨 해소 잔여(행사 그룹 3 · 이전상태 · 약칭 코드 = dbt 정지점) | 현업 회신 대기 |

### ▣ O214-A-1b 🟡 ㉡ 워크스페이스 백로그(7차와 무관)

- 기존 COMMENT 부채(7차 이전) = 세션 태그(O51-D 등) 컬럼·뷰 다수 · SV 항목 157 · `N종` 개수 표기 · 빈 컬럼 COMMENT `WIDE_MEMBER_MONTHLY_KPI` 12 — 이번 범위 밖.
- `05_18_SV_DDL_MEMBER_SERVICE_COHORT.sql:105` 2,007자(R1-5 상한 초과 · 기존분 · 문자열 리터럴이라 분할 시 값이 바뀐다 → 문안 축약 필요).
- 스크립트 개선 후보 = `apply_*_comment_drift.py` 는 테이블레벨 COMMENT 를 반영하지 않는다(이번엔 수동 ALTER 4) · OPS·eval 스테이지 소유 = ACCOUNTADMIN(GN_DW_ADMIN 접근 불가).

### ▣ O214-A-2 ⚪ 결정 완료(재론 금지)

- O213-A~J 결정 전건 유지 + 아래 추가:
- COMMENT 규약4 는 컬럼·테이블레벨·SV 항목 전부에 적용한다(VQR VERIFIED_BY 만 예외).
- range 모델 테이블의 COMMENT 정본 = DDL 파일의 비실행 선언 블록(실행 가능한 CREATE 를 두지 않는다).
- 스테이지 마운트 파일 삭제는 **접두가 다른 형제가 없는지 확인한 뒤** 개별 삭제한다(`os.remove` 포함).

_Co-authored with CoCo_

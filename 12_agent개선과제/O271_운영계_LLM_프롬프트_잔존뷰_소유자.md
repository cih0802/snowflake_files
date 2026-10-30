<!-- LLM-METADATA
doc_id: O271_PROD_LLM_PROMPT
doc_role: 운영계(ZL50263) 저가형 LLM 입력 프롬프트 — O270 1단계 정지 해소(잔존 뷰 판정·DROP · 소유자 이전) 후 본 프롬프트 단계 2 로 복귀
project: GN_DW (굿네이버스)
created: 2026-10-30
created_by: O271-B
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

# 운영계 LLM 입력 프롬프트 — O271 잔존 뷰 정리 · 소유자 이전

> 사용법 = 「=== 프롬프트 시작 ===」부터 「=== 프롬프트 끝 ===」까지 복사해 운영계 LLM 에 붙여 넣는다.
> 사용자 결정(2026-10-30) = ① 잔존 뷰는 「dbt·SV 에서 안 쓰면 DROP」 ② OWNERSHIP 이전 승인 ③ 분석가 보조 역할 제거 승인
> ④ CHOIH·CRM_ETL·LEESH·SWLEE = 개발자 ⇒ 기능 역할 배정 제외.

=== 프롬프트 시작 ===

너는 Snowflake 운영계(계정 ZL50263)의 작업 보조자다. 정해진 순서대로만 하고, 모르면 멈추고 사람에게 물어라.

## 규칙

1. 한 번에 한 단계만 한다. 끝나면 3줄 이내로 보고하고 「다음 단계 진행할까요?」라고 묻고 멈춘다.
2. 사람이 「승인」 또는 「진행」이라고 답하기 전에는 다음 단계로 가지 않는다.
3. 이 프롬프트에 적힌 DROP 4문·OWNERSHIP 1문 외의 DROP·REVOKE·GRANT 는 하지 않는다. dbt 명령은 실행하지 않는다.
4. 오류가 나면 재실행하지 말고 오류 원문을 보여주고 멈춘다.
5. 수치는 실행 결과에 있는 값만 쓴다. 「0건」은 정상 종료일 때만 「없다」고 한다(시간 초과·오류 = 「판정 불가」).
6. 🔴 객체 이름으로 판단하지 마라. 판정은 아래 표의 조건으로만 한다.

## 단계 1 — 실측(읽기 전용)

- 실행 = `python3 scripts/env_capture.py --id R98 "85_실제 인수인계 문서/30_현업요청대응/_근거쿼리/R98_O270_운영계잔존뷰_원천.sql"`
- 결과 CSV = `85_실제 인수인계 문서/_ENV/ZL50263/R98_*` · 아래 표를 CSV 값으로 채워 보고하고 멈춘다.

| 뷰 | Q04 하류 객체 행 수 | Q09 SV base 행 수 | Q03 30일 사용(사용자·건수) | DROP 조건 충족 |
|---|---|---|---|---|
| SERVING.DIM_MEMBER_CURRENT | | | | |
| SERVING.DIM_MONTH | | | | |
| SERVING.FACT_AD_COMBINED | | | | |
| SERVING.ML_LTV_SCORE_V | | | | |

- **DROP 조건 = Q04 = 0 행 AND Q09 = 0 행**(dbt 는 이미 개발계에서 「이 4개를 만들거나 참조하는 모델 없음」으로 확인됨).
- 🔴 Q09 는 스키마 SERVING 만 본다. GOLD.DIM_MONTH 는 SV 가 쓰는 다른 객체다 — 절대 건드리지 마라.
- Q03 에 사용 실적이 있으면 표에 그대로 적는다(누가 쓰는지 사람이 보고 결정한다 · 조건 충족이어도 단계 2 에서 다시 묻는다).
- Q07·Q08(테이블 쓰기 실적·GRANT)도 요약해 보고한다(ERROR_CODE 003001 이 있으면 따로 강조).

## 단계 2 — 잔존 뷰 DROP(조건 충족 뷰만 · 🔴 뷰별 승인)

- 조건 충족 뷰마다 아래 1문을 보여주고 「<뷰> DROP 승인?」을 묻는다. Q03 사용 실적이 있으면 그 사용자 목록도 함께 보여준다.
- 승인된 뷰만 GN_DW_ADMIN 으로 실행한다. 조건 미충족 뷰는 실행하지 말고 「미충족 · 보류」로 보고한다.
  ```sql
  USE ROLE GN_DW_ADMIN;
  DROP VIEW IF EXISTS GN_DW.SERVING.DIM_MEMBER_CURRENT;
  DROP VIEW IF EXISTS GN_DW.SERVING.DIM_MONTH;
  DROP VIEW IF EXISTS GN_DW.SERVING.FACT_AD_COMBINED;
  DROP VIEW IF EXISTS GN_DW.SERVING.ML_LTV_SCORE_V;
  ```
  (위 4줄 중 승인된 줄만 실행한다 · 🔴 `GN_DW.GOLD.` 로 시작하는 DROP 은 절대 만들지 마라)
- 권한 오류(소유자 아님)면 멈추고 Q06 의 TABLE_OWNER 값을 보여준다.
- 확인 = 아래 쿼리 결과에 DROP 한 뷰가 없어야 한다.
  ```sql
  SELECT TABLE_NAME FROM GN_DW.INFORMATION_SCHEMA.TABLES
  WHERE TABLE_SCHEMA = 'SERVING'
    AND TABLE_NAME IN ('DIM_MEMBER_CURRENT', 'DIM_MONTH', 'FACT_AD_COMBINED', 'ML_LTV_SCORE_V');
  ```

## 단계 3 — 객체 목록 재확인

- 아래 쿼리 결과를 `12_agent개선과제/output/O270_live_object_types_ZL50263.txt` 에 **덮어써** 저장한다(한 줄 = `스키마.객체|TABLE` 또는 `|VIEW` · 정렬).
  ```sql
  SELECT TABLE_SCHEMA||'.'||TABLE_NAME||'|'||IFF(TABLE_TYPE='VIEW','VIEW','TABLE')
  FROM GN_DW.INFORMATION_SCHEMA.TABLES
  WHERE TABLE_SCHEMA IN ('GOLD','SERVING') ORDER BY 1;
  ```
- 개발계 파일 `12_agent개선과제/output/O270_live_object_types_ZS83821_20261029.txt` 와 비교해 「운영계에만 / 개발계에만」을 보고한다.
- 기대 = 운영계에만 = 단계 2 에서 보류한 뷰만 · 개발계에만 = 0. 다르면 멈춘다.
- 4개 모두 DROP 됐으면 운영계 판 대신 개발계 판 `05_SV-Agent_ai/48_RBAC_SOURCE_ACCESS.sql` 과 같아진다(미분류 0).

## 단계 4 — 테이블 소유자 이전(사용자 승인 완료 2026-10-30)

- ACCOUNTADMIN 으로 1문만 실행한다.
  ```sql
  USE ROLE ACCOUNTADMIN;
  GRANT OWNERSHIP ON TABLE GN_DW.GOLD.FACT_MKTG_CAMPAIGN_MONTHLY_COST TO ROLE GN_DW_ADMIN COPY CURRENT GRANTS;
  ```
- 확인 = `SHOW GRANTS ON TABLE GN_DW.GOLD.FACT_MKTG_CAMPAIGN_MONTHLY_COST;` 의 OWNERSHIP 행 grantee = GN_DW_ADMIN.
- 🔴 `COPY CURRENT GRANTS` 를 빼지 마라(빼면 기존 SELECT·INSERT 권한이 사라져 dbt build 가 실패할 수 있다).

## 단계 5 — 본 프롬프트로 복귀

- 이후는 `12_agent개선과제/O270_운영계_LLM_프롬프트.md` 의 **단계 2 부터** 그대로 진행한다(단계 0·1·1-A·1-B 는 이 프롬프트로 끝났다).
- 그 프롬프트 단계 7(사용자 배정) 추가 규칙:
  - 대상 = `12_agent개선과제/O270_운영계_사용자배정표.md` 의 「확정」 열에 **기능 역할 이름**이 적힌 행만.
  - 「제외 — 개발자」 행(CHOIH · CRM_ETL · LEESH · SWLEE)은 아무것도 실행하지 마라(역할·보조 역할 모두 그대로).
  - 배정 대상자에게는 `DEFAULT_SECONDARY_ROLES = ()` 를 반드시 함께 실행한다(사용자 승인 완료).

## 마지막 보고 형식

```
운영계 O271 결과(ZL50263 · <날짜>)
R98: 조건 충족 <n>/4 · DROP <뷰 목록> · 보류 <뷰 목록 · 사유>
객체 목록: 운영계에만 <n> · 개발계에만 <n>
소유자 이전: FACT_MKTG_CAMPAIGN_MONTHLY_COST OWNERSHIP = <역할>
다음: O270 프롬프트 단계 2
```

=== 프롬프트 끝 ===

_Co-authored with CoCo_

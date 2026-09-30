<!-- LLM-METADATA
doc_id: OUTPUT_DERIVED_COL_COMMENT_DRAFT_O191
doc_role: 신규 19종 테이블 파생 컬럼 COMMENT 초안 — 모델 로직 + 원천 COMMENT 기반 · 40_현업회신요청_O190 §2 대체
project: GN_DW (굿네이버스)
created: 2026-09-30
created_by: O191
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

# 신규 19종 — 파생 컬럼 COMMENT 초안

> 근거 = 모델 SQL(`10_dbt_pipeline/models/…`) + `BRONZE_CRM` 원천 COMMENT(2026-09-30 bt97381 조회).
> 🟢 결론 = **요청서 §2 의 15칸은 전부 현업 회신이 필요 없습니다**. 원천 이름만 바꾼 컬럼이거나, DW 가 로직으로 만든 컬럼입니다.
> 분류: **상속**(원천 COMMENT 그대로) · **DW**(모델 로직으로 문안 확정) · **확인**(문안 확정 · 회신은 선택).

## DIM_MSG_TEMPLATE · CRM_MSG_TEMPLATE

| 컬럼 | 분류 | 근거 | COMMENT 초안 |
|---|---|---|---|
| `SEND_CHANNEL` | DW | UNION 분기 상수 | 발송채널 — `MSG_AT`=알림톡 템플릿(TM_MS_AT_TMPLAT_MNG) · `EMAIL`=이메일 템플릿(TM_MS_EMAIL_TMPLAT_MNG) |
| `TEMPLATE_KEY` | 상속 | `TMPLAT_ID`「템플릿ID」 · `TMPLAT_KEY`「템플릿KEY」 | 템플릿 키 — 알림톡=템플릿ID · 이메일=템플릿KEY(문자열 변환). SEND_CHANNEL 과 함께 유일 |
| `TEMPLATE_CTNT` | 상속 | `TMPLAT_CTNT`「템플릿내용」 · `EMAIL_CTNT`「이메일내용」 | 템플릿 본문 — 알림톡=템플릿내용 · 이메일=이메일내용 |
| `TEMPLATE_RM` | 상속 | `TMPLAT_RM`「템플릿비고」 | 템플릿비고 — 알림톡 전용 · 이메일 행은 원천 개념 부재로 NULL |
| `BUTTON_CNT` | DW | `DIM_MSG_TEMPLATE.sql:22` | 버튼 수 — 알림톡 템플릿의 버튼 행 수(CRM_MSG_TEMPLATE_BUTTON) · 버튼 없으면 0 · 이메일은 개념 부재로 NULL |

## DIM_PAYMENT_ACCOUNT

| 컬럼 | 분류 | 근거 | COMMENT 초안 |
|---|---|---|---|
| `ACCOUNT_KIND` | DW | UNION 분기 상수 | 계정 종류 — `INSTT`=기관 계좌(TM_PM_INSTT_ACNUT) · `SETLE_CMPNY`=결제사 계정(TM_PM_SETLE_CMPNY_ACNT) |
| `ACCOUNT_KEY` | DW | `DIM_PAYMENT_ACCOUNT.sql:14·26` | 계정 키 — INSTT=계좌일련번호 · SETLE_CMPNY=결제사계좌번호(문자열). ACCOUNT_KIND 와 함께 유일 |
| `ACCOUNT_ABBR` | 상속 | `ACNUT_ABRV`「계좌약칭」 | 계좌약칭 — 기관 계좌 전용 · 결제사 행 NULL |
| `ACCOUNT_PURPOSE` | 상속 | `ACNUT_PRP`·`ACNT_PRP`「계좌용도」 | 계좌용도 |
| `ACCOUNT_DIV_CD` | 상속 | `ACNUT_DIV_CD`「계좌구분코드」 · `SETLE_CMPNY_ACNT_DIV_CD`「결제사계좌구분코드」 | 계좌구분코드 — INSTT=계좌구분코드 · SETLE_CMPNY=결제사계좌구분코드(🟠 코드체계가 같은지는 코드군 미확인) |
| `INSTT_ACNUT_SER_NO` | 상속 | `ACNUT_SER_NO`「계좌일련번호 (참조: TM_PM_INSTT_ACNUT)」 | 기관계좌 일련번호 — 결제사 계정이 연결된 기관 계좌 · INSTT 행은 자기 자신 |

## DIM_CODE_GROUP

| 컬럼 | 분류 | 근거 | COMMENT 초안 |
|---|---|---|---|
| `DTL_CODE_CNT` | DW | `DIM_CODE_GROUP.sql:11·15` | 세부코드 수 — 이 코드그룹(CD_ID)에 속한 상세코드 행 수(CRM_CODE) · 없으면 0 |

## FACT_PAYMENT_METHOD_CHANGE · FACT_RELATION_CHANGE · FACT_RELATION_DEV

| 테이블 | 분류 | 근거 | COMMENT 초안 |
|---|---|---|---|
| `FACT_PAYMENT_METHOD_CHANGE.MEMBER_DK` | 상속 | `:11` `MBER_NO as MEMBER_DK` | 회원번호(원천 MBER_NO · degenerate) |
| `FACT_RELATION_DEV.MEMBER_DK` | 상속 | `:11` · 원천「회원번호」 | 회원번호(원천 MBER_NO · degenerate) |
| `FACT_RELATION_CHANGE.MEMBER_DK` | 확인 | `:4·16` 결연키 → CRM_SPONSOR_RELATION | 회원번호 — 결연키로 결연 마스터를 조회해 얻은 MBER_NO · 매칭 실패(고아 결연)는 NULL |

## 남는 것

- 🟢 **[O191 반영 완료]** 라이브 COMMENT 19/19 갱신(`ALTER … MODIFY COLUMN … COMMENT`) · DDL 정본 2파일 동일 문안 · 자리표시자 잔존 0.
- 🟢 `ACCOUNT_DIV_CD` 실측 = 두 원천 코드 도메인이 다르다(INSTT 1·2 / SETLE_CMPNY 1·2·3·4 + NULL) ⇒ COMMENT 에 「ACCOUNT_KIND 동반 필수」를 명시했다(라벨은 창작하지 않았다).
- 현업 회신 필요 = **0칸**.

-- CRM_SEND_MEMBER: 발송×회원 상세 = 채널별 상세 ∪ SND 회원리스트 (채널별 dedup), 정본 09 STEP3.
-- Co-authored with CoCo
-- [2026-08-11 O59-N · DEC-35 1단계] 코드→라벨 계층화. 정본 = 문서30 §23-G·§23-J · 매핑 = 문서31 §1·§2.
--   구조를 바꾼 이유: 종전에는 4원천을 곧바로 UNION ALL 했는데, 라벨 조인을 각 브랜치에 붙이면
--   같은 조인이 4벌로 복제된다. ⇒ raw 브랜치를 `base` CTE 로 모으고 **조인은 1벌만** 둔다.
--   ⚠️ dedup QUALIFY 는 브랜치 안에 그대로 남긴다(원천별 PK 가 다르므로 밖으로 뺄 수 없다).
--
--   축 A(채널 상태) = SNDNG_RST_CD(raw 유지) + SEND_STATUS_GROUP(조인키) + SEND_STATUS_NAME(라벨)
--     · MSG_AT → `MS282` (등급 C = 정황) 🔴 **조건부 적용**: 문서20 §M-3 회신이 다르면 되돌린다(§23-J 결정 2).
--     · EMAIL `{0,1}` · SND `{Y,N}` → 🔴 **라벨 만들지 않는다**(§23-J 결정 3) — 코드군이 특정되지 않아
--       `CRM_CODE` 에서 가져올 문자열이 없다. 「성공/실패」는 우리 해석이므로 넣으면 라벨 창작이다(DEC-17-B).
--     · PSTMTR → 원천 컬럼 자체가 없다(구조적 부재 · P21).
--   축 B(통신사 결과 · 신설) = SEND_RESULT_CD + SEND_RESULT_GROUP + SEND_RESULT_NAME
--     · MSG_AT `TRNSMS_FAILR_CD_ID` · SND `CALL_STATUS` — 🟠 **[2026-08-29 O116-B 부분 부정] 종전 판단은
--       「🟢 conformed(두 채널이 같은 코드공간)」였으나 실측이 이를 부분 부정한다** — 정본 = 문서50 §O116-3 ㉠.
--       · 라벨 미부착 1,401,419행(코드 보유 26,252,471 의 **5.34%** · 커버리지 94.66%)의 정체:
--         ㉠ `SND` 단자리 코드(`0,3,4,5,6,8,9`)가 `MS056` 에 미등재 **824,030**
--            — `MS056` 의 단자리 등재는 **`1`·`2` 뿐**이다 ⇒ SND 코드체계가 이 코드공간과 완전히 겹치지 않는다.
--         ㉡ 4자리(`7319`·`7320`·`7321`·`7205`·`9034`)가 사전에 **아예 없음** **577,389**
--            — `MS057` 은 `7318`·`7322` 를 갖고 있어 **대역 안의 결번**이다(사전이 원천을 못 따라갔다).
--       🔴 **그래도 코드군 지정(MS056~MS059)은 유지한다** — 결번은 「다른 코드군을 골라야 한다」가 아니다.
--       🟠 남은 질문(현업) = SND 단자리 체계가 이 코드공간과 같은 것인가 ⇒ 문서20 질의 후보.
--     · 🟢 코드군을 **리터럴로 지정하지 않는다**: `MS056`~`MS059` 4그룹에 걸쳐 코드값 중복이 0(실측)이므로
--       매칭된 `CD_ID` 자체가 코드군이다 ⇒ P31(하드코딩 금지) 준수 · 채널이 늘어도 불변.
--       ⚠️ 이 배타성은 현재 사전 상태의 실측이다 — 사전에 값이 추가되면 깨진다 ⇒ 게이트로 재검한다.
--       🟢 **[O116-B] 그 예고가 실현됐다** — 위 ㉠㉡ 가 「사전이 원천 코드 증가를 못 따라간」 실물이다.
--   ⚠️ fan-out 안전: (CD_ID, DTL_CD_ID) 가 대상 그룹 전건 유일 + 축B 4그룹 교차중복 0 (실측 2026-08-11).
--   ⚠️ 사전 초과값은 라벨 NULL 로 남긴다(DEC-17-B · 센티넬 창작 금지) — `_crm_schema.yml` 이 warn 으로 관측한다.
WITH base AS (
  SELECT SNDNG_KEY AS SNDNG_KEY, SNDNG_DTL_KEY AS SNDNG_DTL_KEY, NULLIF(TRIM(MBER_NO),'') AS MBER_NO,
    SNDNG_DE AS SNDNG_DE, NULLIF(TRIM(SNDNG_RST_CD),'') AS SNDNG_RST_CD, 'EMAIL' AS SEND_CHANNEL,
    CAST(NULL AS VARCHAR) AS SEND_RESULT_CD,
    CAST(NULL AS TIMESTAMP_NTZ) AS OPEN_DT,
    'CRM' AS DW_SOURCE_SYSTEM, 'BRONZE_CRM.TD_MS_EMAIL_SNDNG_DTLS' AS DW_SOURCE_TABLE
  FROM GN_DW.BRONZE_CRM.TD_MS_EMAIL_SNDNG_DTLS WHERE SNDNG_KEY IS NOT NULL AND SNDNG_DTL_KEY IS NOT NULL
  QUALIFY ROW_NUMBER() OVER (PARTITION BY SNDNG_KEY, SNDNG_DTL_KEY ORDER BY SNDNG_DE DESC NULLS LAST)=1
  UNION ALL
  SELECT SNDNG_KEY, SNDNG_DTL_KEY, NULLIF(TRIM(MBER_NO),''), SNDNG_DT, NULLIF(TRIM(TRNSMS_STAT_CD),''), 'MSG_AT',
    NULLIF(TRIM(TRNSMS_FAILR_CD_ID),''),
    CAST(NULL AS TIMESTAMP_NTZ),
    'CRM','BRONZE_CRM.TD_MS_MSG_AT_SNDNG_DTLS'
  FROM GN_DW.BRONZE_CRM.TD_MS_MSG_AT_SNDNG_DTLS WHERE SNDNG_KEY IS NOT NULL AND SNDNG_DTL_KEY IS NOT NULL
  QUALIFY ROW_NUMBER() OVER (PARTITION BY SNDNG_KEY, SNDNG_DTL_KEY ORDER BY SNDNG_DT DESC NULLS LAST)=1
  UNION ALL
  SELECT SNDNG_KEY, SNDNG_DTL_KEY, NULLIF(TRIM(MBER_NO),''), SNDNG_DE, NULL, 'PSTMTR',
    NULL,
    CAST(NULL AS TIMESTAMP_NTZ),
    'CRM','BRONZE_CRM.TD_MS_PSTMTR_SNDNG_DTL'
  FROM GN_DW.BRONZE_CRM.TD_MS_PSTMTR_SNDNG_DTL WHERE SNDNG_KEY IS NOT NULL AND SNDNG_DTL_KEY IS NOT NULL
  QUALIFY ROW_NUMBER() OVER (PARTITION BY SNDNG_KEY, SNDNG_DTL_KEY ORDER BY SNDNG_DE DESC NULLS LAST)=1
  UNION ALL
  SELECT REQ_SEQ_NO, R_NUM, NULLIF(TRIM(MBER_NO),''), SND_DT, NULLIF(TRIM(SND_YN),''), 'SND',
    NULLIF(TRIM(CALL_STATUS),''),
    -- 🆕 [2026-08-20 O93] 오픈시각 — **SND 채널에만 존재**하는 신규 원천 컬럼이다.
    --    원천에서 물리 ordinal 이 맨 끝이다(ALTER ADD COLUMN 으로 나중에 붙었다는 뜻).
    --    ⚠️ 채움이 부분이고 관측 개시 시점 이후만 값이 있다 — 그 이전 구간의 NULL 은
    --       「열지 않았다」가 아니라 **「측정하지 않았다」**다. 소비 판정은 GOLD 쪽 주석 참조.
    OPEN_DT,
    'CRM','BRONZE_CRM.SND_MEMBER_LIST'
  FROM GN_DW.BRONZE_CRM.SND_MEMBER_LIST WHERE REQ_SEQ_NO IS NOT NULL AND R_NUM IS NOT NULL
  QUALIFY ROW_NUMBER() OVER (PARTITION BY REQ_SEQ_NO, R_NUM ORDER BY SND_DT DESC NULLS LAST)=1
)
SELECT
  b.SNDNG_KEY                     AS SNDNG_KEY,
  b.SNDNG_DTL_KEY                 AS SNDNG_DTL_KEY,
  b.MBER_NO                       AS MBER_NO,
  b.SNDNG_DE                      AS SNDNG_DE,
  b.SNDNG_RST_CD                  AS SNDNG_RST_CD,
  b.SEND_CHANNEL                  AS SEND_CHANNEL,
  b.DW_SOURCE_SYSTEM              AS DW_SOURCE_SYSTEM,
  b.DW_SOURCE_TABLE               AS DW_SOURCE_TABLE,
  CURRENT_TIMESTAMP()             AS DW_LOAD_TS,
  CURRENT_TIMESTAMP()             AS DW_UPDATE_TS,
  NULL                            AS DW_BATCH_ID,
  -- 🔴 신설 컬럼은 **감사컬럼 뒤**다 — 정본 DDL 규약(08_SILVER…sql · 06_DDL.sql:298): 라이브에는
  --    ALTER ADD COLUMN 으로 붙어 물리 ordinal 이 맨 끝이므로 모델 SELECT 순서도 그에 맞춘다.
  -- 축A: 코드군은 채널이 판별한다. MSG_AT 만 사전 조인이 성립한다(EMAIL·SND 는 §23-J 결정 3 으로 NULL).
  CASE WHEN b.SEND_CHANNEL='MSG_AT' AND b.SNDNG_RST_CD IS NOT NULL THEN 'MS282' END AS SEND_STATUS_GROUP,
  sa.DTL_CD_NM                    AS SEND_STATUS_NAME,
  -- 축B: 코드군을 조인 결과에서 얻는다(리터럴 아님).
  b.SEND_RESULT_CD                AS SEND_RESULT_CD,
  sb.CD_ID                        AS SEND_RESULT_GROUP,
  sb.DTL_CD_NM                    AS SEND_RESULT_NAME,
  -- 🆕 [2026-08-20 O93] 오픈시각(SND 전용). 신설 컬럼이라 감사컬럼 뒤에 붙인다(DDL ordinal 규약).
  --   🔴 이 컬럼이 「오픈」 지표의 **유일한 원천**이다 — 이메일·알림톡 집계의 오픈/클릭 컬럼은
  --      전건 NULL 이라(기지 `C-9-R`·이슈 D) 채널 통합 오픈율은 아직 만들 수 없다.
  b.OPEN_DT                       AS OPEN_DT
FROM base b
LEFT JOIN GN_DW.SILVER.CRM_CODE sa
  ON sa.CD_ID = 'MS282' AND b.SEND_CHANNEL = 'MSG_AT' AND sa.DTL_CD_ID = b.SNDNG_RST_CD
LEFT JOIN GN_DW.SILVER.CRM_CODE sb
  ON sb.CD_ID IN ('MS056','MS057','MS058','MS059') AND sb.DTL_CD_ID = b.SEND_RESULT_CD
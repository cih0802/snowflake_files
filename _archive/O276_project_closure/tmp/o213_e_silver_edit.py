"""O213-E — CRM_SEND_REQUEST · CRM_SEND_MEMBER 4브랜치 말미 컬럼 추가(앵커 정확히 1회 검증 후 치환)."""
import io, sys

APPLY = "--apply" in sys.argv
D = "/workspace/10_dbt_pipeline/models/silver/crm/"
EDITS = {
    "CRM_SEND_REQUEST.sql": [
        ("  ,CAST(NULL AS VARCHAR(255)) AS USE_YN\nFROM {{ source('bronze_crm','TM_MS_EMAIL_SNDNG') }}",
         "  ,CAST(NULL AS VARCHAR(255)) AS USE_YN\n"
         "  -- 🆕 [2026-10-08 O213-E] SND 요청 전용 2종(법인구분 CM019 · 분할방식 once/divide) — 비해당 채널 NULL · 감사·누락 컬럼 뒤\n"
         "  ,CAST(NULL AS VARCHAR(10)) AS CORP_TYPE\n  ,CAST(NULL AS VARCHAR(20)) AS SEND_SPLIT_TYPE\n"
         "FROM {{ source('bronze_crm','TM_MS_EMAIL_SNDNG') }}"),
        ("  ,CAST(NULL AS VARCHAR(255))\nFROM {{ source('bronze_crm','TM_MS_MSG_AT_SNDNG') }}",
         "  ,CAST(NULL AS VARCHAR(255))\n  ,CAST(NULL AS VARCHAR(10))\n  ,CAST(NULL AS VARCHAR(20))\n"
         "FROM {{ source('bronze_crm','TM_MS_MSG_AT_SNDNG') }}"),
        ("  ,CAST(NULL AS VARCHAR(255))\nFROM {{ source('bronze_crm','TM_MS_PSTMTR_SNDNG') }}",
         "  ,CAST(NULL AS VARCHAR(255))\n  ,CAST(NULL AS VARCHAR(10))\n  ,CAST(NULL AS VARCHAR(20))\n"
         "FROM {{ source('bronze_crm','TM_MS_PSTMTR_SNDNG') }}"),
        ("  ,NULLIF(TRIM(USE_YN),'')\nFROM {{ source('bronze_crm','SND_REQ_MST') }}",
         "  ,NULLIF(TRIM(USE_YN),'')\n  ,NULLIF(TRIM(CORP_TYPE),'')\n  ,NULLIF(TRIM(SEND_SPLIT_TYPE),'')\n"
         "FROM {{ source('bronze_crm','SND_REQ_MST') }}"),
    ],
    "CRM_SEND_MEMBER.sql": [
        ("  ,REAL_SEND_DT AS REAL_SEND_DT\n  FROM {{ source('bronze_crm','SND_MEMBER_LIST') }} s",
         "  ,REAL_SEND_DT AS REAL_SEND_DT\n"
         "  -- 🆕 [2026-10-08 O213-E] SND 발송 시점 회원 스냅샷 4종(라벨 원문 · 타 채널 NULL) — 혼합 코드 3종(후원구분·중단채널·결연중단유무)은 제외(문서20 N-29)\n"
         "  ,NULLIF(TRIM(s.SPNSR_NM),'') AS SND_SPNSR_NM\n  ,NULLIF(TRIM(s.DSCNTC_RSN_NM),'') AS SND_DSCNTC_RSN_NM\n"
         "  ,NULLIF(TRIM(s.NEW_CHILD_PROJECT_COUNTRY),'') AS SND_CHILD_PROJECT_COUNTRY\n"
         "  ,NULLIF(TRIM(s.NEW_CHILD_WORKPLACE_NM),'') AS SND_CHILD_WORKPLACE_NM\n"
         "  FROM {{ source('bronze_crm','SND_MEMBER_LIST') }} s"),
        ("  ,CAST(NULL AS TIMESTAMP_NTZ) AS REAL_SEND_DT\n  FROM {{ source('bronze_crm','TD_MS_EMAIL_SNDNG_DTLS') }}",
         "  ,CAST(NULL AS TIMESTAMP_NTZ) AS REAL_SEND_DT\n"
         "  ,CAST(NULL AS VARCHAR) AS SND_SPNSR_NM, CAST(NULL AS VARCHAR) AS SND_DSCNTC_RSN_NM\n"
         "  ,CAST(NULL AS VARCHAR) AS SND_CHILD_PROJECT_COUNTRY, CAST(NULL AS VARCHAR) AS SND_CHILD_WORKPLACE_NM\n"
         "  FROM {{ source('bronze_crm','TD_MS_EMAIL_SNDNG_DTLS') }}"),
        ("  ,CAST(NULL AS TIMESTAMP_NTZ) AS REAL_SEND_DT\n  FROM {{ source('bronze_crm','TD_MS_MSG_AT_SNDNG_DTLS') }}",
         "  ,CAST(NULL AS TIMESTAMP_NTZ) AS REAL_SEND_DT\n"
         "  ,CAST(NULL AS VARCHAR), CAST(NULL AS VARCHAR), CAST(NULL AS VARCHAR), CAST(NULL AS VARCHAR)\n"
         "  FROM {{ source('bronze_crm','TD_MS_MSG_AT_SNDNG_DTLS') }}"),
        ("  ,CAST(NULL AS TIMESTAMP_NTZ) AS REAL_SEND_DT\n  FROM {{ source('bronze_crm','TD_MS_PSTMTR_SNDNG_DTL') }}",
         "  ,CAST(NULL AS TIMESTAMP_NTZ) AS REAL_SEND_DT\n"
         "  ,CAST(NULL AS VARCHAR), CAST(NULL AS VARCHAR), CAST(NULL AS VARCHAR), CAST(NULL AS VARCHAR)\n"
         "  FROM {{ source('bronze_crm','TD_MS_PSTMTR_SNDNG_DTL') }}"),
        ("    ,ALTRTV_MSG_SNDNG_YN, RELATNSP_KEY, MNG_NO, MSG_KEY, CINFO, RESPONSED_YN, RESPONSED_DT, REAL_SEND_DT\n  FROM snd_base",
         "    ,ALTRTV_MSG_SNDNG_YN, RELATNSP_KEY, MNG_NO, MSG_KEY, CINFO, RESPONSED_YN, RESPONSED_DT, REAL_SEND_DT\n"
         "    ,SND_SPNSR_NM, SND_DSCNTC_RSN_NM, SND_CHILD_PROJECT_COUNTRY, SND_CHILD_WORKPLACE_NM\n  FROM snd_base"),
        ("  ,b.REAL_SEND_DT                   AS REAL_SEND_DT\nFROM base b",
         "  ,b.REAL_SEND_DT                   AS REAL_SEND_DT\n"
         "  -- 🆕 [2026-10-08 O213-E] SND 발송 시점 회원 스냅샷 4종(감사·누락 컬럼 뒤 · DDL 08 선행)\n"
         "  ,b.SND_SPNSR_NM                   AS SND_SPNSR_NM\n  ,b.SND_DSCNTC_RSN_NM              AS SND_DSCNTC_RSN_NM\n"
         "  ,b.SND_CHILD_PROJECT_COUNTRY      AS SND_CHILD_PROJECT_COUNTRY\n  ,b.SND_CHILD_WORKPLACE_NM         AS SND_CHILD_WORKPLACE_NM\n"
         "FROM base b"),
    ],
}
bad = 0
for f, eds in EDITS.items():
    t = io.open(D + f, encoding="utf-8").read()
    for old, new in eds:
        n = t.count(old)
        if n != 1:
            print(f"🔴 {f} anchor ×{n}: {old[:60]!r}")
            bad += 1
        else:
            t = t.replace(old, new)
    if APPLY and not bad:
        io.open(D + f, "w", encoding="utf-8").write(t)
    print(f, "OK" if not bad else "FAIL")
print("bad", bad, "APPLY" if APPLY and not bad else "DRY-RUN")
sys.exit(1 if bad else 0)

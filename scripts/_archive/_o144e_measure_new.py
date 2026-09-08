#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# 문서17 보강 쿼리에 실을 수치를 라이브에서 먼저 실측한다 — 추측 기재를 막기 위한 사전 측정이다.
# Co-authored with CoCo
import sys
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn

Q = [
    ("M5-a · 통신사 실패코드 미등재 종수 (NOT EXISTS 로 정확히)", """
        SELECT COUNT(DISTINCT d.trnsms_failr_cd_id) AS UNREG_KINDS,
               COUNT(*) AS UNREG_ROWS
        FROM GN_DW.BRONZE_CRM.TD_MS_MSG_AT_SNDNG_DTLS d
        WHERE d.trnsms_failr_cd_id IS NOT NULL
          AND NOT EXISTS (
                SELECT 1 FROM GN_DW.BRONZE_CRM.TC_CMMN_DTL_CD c
                WHERE c.cd_id IN ('MS056','MS057','MS058','MS059')
                  AND c.dtl_cd_id = d.trnsms_failr_cd_id)
    """),
    ("M5-b · 실패코드 전체 종수와 등재 여부 분해", """
        SELECT COUNT(DISTINCT trnsms_failr_cd_id) AS ALL_KINDS
        FROM GN_DW.BRONZE_CRM.TD_MS_MSG_AT_SNDNG_DTLS
        WHERE trnsms_failr_cd_id IS NOT NULL
    """),
    ("M5-c · MS056~MS059 사전 등재 코드 종수", """
        SELECT cd_id, COUNT(*) AS N
        FROM GN_DW.BRONZE_CRM.TC_CMMN_DTL_CD
        WHERE cd_id IN ('MS056','MS057','MS058','MS059')
        GROUP BY 1 ORDER BY 1
    """),
    ("L2-a · 획득사업 ↔ 중단사업 불일치율 직접 계산", """
        WITH acq AS (
            SELECT mber_no, MIN_BY(spnsr_bsns_id, occrrnc_de) AS acq_id
            FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT
            WHERE spnsr_bsns_id IS NOT NULL GROUP BY mber_no)
        SELECT COUNT(*) AS STOP_BSNS_ROWS,
               COUNT(CASE WHEN b.spnsr_bsns_id <> a.acq_id THEN 1 END) AS MISMATCH_ROWS,
               ROUND(COUNT(CASE WHEN b.spnsr_bsns_id <> a.acq_id THEN 1 END)*100.0/COUNT(*),2) AS MISMATCH_PCT
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_BSNS b
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR s ON s.spnsr_no = b.spnsr_no
        JOIN acq a ON a.mber_no = s.mber_no
        WHERE b.spnsr_dscntc_yn = 'Y'
    """),
    ("L2-b · 동시중단 다중사업 팬아웃 규모 (⑭ 결정 직결)", """
        WITH x AS (
            SELECT s.mber_no, b.spnsr_dscntc_de AS de,
                   COUNT(DISTINCT b.spnsr_bsns_id) AS bsns_n
            FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_BSNS b
            JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR s ON s.spnsr_no = b.spnsr_no
            WHERE b.spnsr_dscntc_yn = 'Y' AND b.spnsr_dscntc_de IS NOT NULL
            GROUP BY 1, 2)
        SELECT bsns_n AS SAME_DAY_BSNS_CNT, COUNT(*) AS STOP_EVENTS,
               ROUND(COUNT(*)*100.0/SUM(COUNT(*)) OVER (),2) AS PCT
        FROM x GROUP BY 1 ORDER BY 1
    """),
    ("I2-a · S+8자리 비표준 회원번호 건수·종수", """
        SELECT COUNT(*) AS ROWS_N, COUNT(DISTINCT mber_no) AS KINDS
        FROM GN_DW.BRONZE_CRM.TD_MS_EVENT_PRTCPNT_DTL
        WHERE REGEXP_LIKE(mber_no, '^S[0-9]{8}$')
    """),
    ("I2-b · S형식 중 일시회원 마스터 매칭 여부", """
        SELECT COUNT(DISTINCT p.mber_no) AS S_KINDS,
               COUNT(DISTINCT CASE WHEN o.once_mber_no IS NOT NULL THEN p.mber_no END) AS MATCHED
        FROM GN_DW.BRONZE_CRM.TD_MS_EVENT_PRTCPNT_DTL p
        LEFT JOIN GN_DW.BRONZE_CRM.TM_MM_ONCE_MBER_INFO o ON o.once_mber_no = p.mber_no
        WHERE REGEXP_LIKE(p.mber_no, '^S[0-9]{8}$')
    """),
    ("A-a · LPAD 보정 시 기존 6자리와 충돌하는지", """
        WITH five AS (
            SELECT DISTINCT mbrfee_mt AS raw5, LPAD(mbrfee_mt, 6, '0') AS fixed6
            FROM GN_DW.BRONZE_CRM.TM_PM_MBRFEE_ACMSLT
            WHERE LENGTH(mbrfee_mt) = 5)
        SELECT f.raw5, f.fixed6,
               (SELECT COUNT(*) FROM GN_DW.BRONZE_CRM.TM_PM_MBRFEE_ACMSLT a
                 WHERE a.mbrfee_mt = f.fixed6) AS EXISTING_6DIGIT_ROWS
        FROM five f ORDER BY 1
    """),
    ("BE-a · 고아 EVENT_CD 의 참여연도 분포 (추출 기간 누락 판별)", """
        SELECT LEFT(TO_CHAR(p.partcpt_dt, 'YYYYMMDD'), 4) AS YR,
               COUNT(*) AS ROWS_N,
               COUNT(CASE WHEN e.event_cd IS NULL THEN 1 END) AS ORPHAN_ROWS
        FROM GN_DW.BRONZE_CRM.TD_MS_EVENT_PRTCPNT_DTL p
        LEFT JOIN GN_DW.BRONZE_CRM.TM_MS_EVENT e ON e.event_cd = p.event_cd
        GROUP BY 1 ORDER BY 1
    """),
    ("BE-b · 행사 마스터의 보유 연도 범위 (참여는 있는데 마스터가 없는 구간)", """
        SELECT COUNT(*) AS MASTER_ROWS,
               MIN(event_bgng_de) AS MIN_DE, MAX(event_bgng_de) AS MAX_DE
        FROM GN_DW.BRONZE_CRM.TM_MS_EVENT
    """),
    ("F2-a · 후원사업 약어코드 종수 (4그룹 전제 검증)", """
        SELECT COUNT(DISTINCT spnsr_bsns_abrv_cd) AS ABRV_KINDS,
               COUNT(*) AS BSNS_ROWS
        FROM GN_DW.BRONZE_CRM.TM_CM_SPNSR_BSNS_INFO
    """),
    ("F1-a · STATS_DEPT_LVL 판별력 실측", """
        SELECT stats_dept_lvl AS LVL_VALUE, COUNT(*) AS DEPT_N
        FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO GROUP BY 1 ORDER BY 1
    """),
    ("N1-a · 개발구분코드 라벨과 목표 실적 유무", """
        SELECT g.mber_dvlp_div_cd AS DIV_CD,
               MAX(d.dtl_cd_nm) AS LABEL_GUESS,
               COUNT(*) AS ROWS_N,
               SUM(g.goal_cnt) AS GOAL_SUM,
               COUNT(CASE WHEN g.goal_cnt > 0 THEN 1 END) AS ROWS_WITH_GOAL
        FROM GN_DW.BRONZE_CRM.TM_CM_MBER_DVLP_GOAL g
        LEFT JOIN GN_DW.BRONZE_CRM.TC_CMMN_DTL_CD d
               ON d.dtl_cd_id = g.mber_dvlp_div_cd AND d.cd_id = 'MM003'
        GROUP BY 1 ORDER BY 1
    """),
    ("J2-a · 8자리 정수 ↔ 시분초 환산 대조 (µs 가설 검증)", """
        SELECT ad_sec AS RAW_VALUE, COUNT(*) AS N,
               CASE WHEN ad_sec LIKE '%:%' THEN 'HH:MM:SS'
                    ELSE 'NUMERIC' END AS NOTATION,
               CASE WHEN ad_sec LIKE '%:%'
                    THEN TO_NUMBER(SPLIT_PART(ad_sec,':',2))*60
                         + TO_NUMBER(SPLIT_PART(ad_sec,':',3))
                    ELSE TRY_TO_NUMBER(ad_sec)/1000000 END AS SEC_IF_MICRO
        FROM GN_DW.BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS
        WHERE ad_sec IS NOT NULL
        GROUP BY 1 ORDER BY 2 DESC
    """),
    ("F5-a · 캘린더 부재 대조군 (BRONZE 전체 테이블 수)", """
        SELECT COUNT(*) AS BRONZE_TABLES,
               COUNT(CASE WHEN table_name LIKE '%DT%' OR table_name LIKE '%DE%' THEN 1 END) AS DATE_ISH
        FROM GN_DW.INFORMATION_SCHEMA.TABLES
        WHERE table_schema LIKE 'BRONZE%'
    """),
]


def main():
    c = conn()
    cur = c.cursor()
    cur.execute("USE WAREHOUSE GN_DW_DEV_WH")
    cur.execute("USE ROLE GN_DW_ADMIN")
    for title, sql in Q:
        print("\n=== %s ===" % title)
        try:
            rows = cur.execute(sql).fetchall()
        except Exception as exc:
            print("  🔴 실패 — %s: %s" % (type(exc).__name__, str(exc).split('\n')[0]))
            continue
        cols = [d[0] for d in cur.description]
        print("  " + " | ".join(cols))
        for r in rows[:25]:
            print("  " + " | ".join("" if v is None else str(v) for v in r))
        if len(rows) > 25:
            print("  ... 총 %d행" % len(rows))
    print("\nrc_ok")


if __name__ == '__main__':
    main()

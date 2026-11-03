# O237-B — 06_DDL.sql · _gold_ready_schema.yml 에 FACT_CAMPAIGN_MONTHLY 등재(전체 재작성 없음)
# 방식 = O236 교훈: 백업 → 앵커 1회 assert → 삽입 → 바이트 보존 검증(삽입 전후 나머지 동일) → yml 파싱 diff
# Co-authored with CoCo
import os
import shutil
import sys

import yaml

BAK = "/workspace/tmp/o237b/bak"
DDL = "/workspace/03_top-down_gold/06_DDL.sql"
YML = "/workspace/10_dbt_pipeline/models/gold/_gold_ready_schema.yml"

TABLE = """
-- FACT_CAMPAIGN_MONTHLY — 기준연월 × 캠페인 × 납입방식 월 팩트 (🆕 O237-B · 신규지표 #12~#16 · #19~#25 · #27~#28)
CREATE OR REPLACE TABLE GN_DW.GOLD.FACT_CAMPAIGN_MONTHLY (
    BASE_MONTH_KEY            NUMBER(6,0)     NOT NULL COMMENT '기준연월 YYYYMM. 당월 measure = 이 월 · 누계 measure = 같은 해 1월 ~ 이 월. 🔴 기준월 하나를 골라 조회한다',
    BASE_YEAR                 NUMBER(4,0)     NOT NULL COMMENT '기준연도 YYYY(= BASE_MONTH_KEY 의 연도)',
    CAMPAIGN_SK               NUMBER(38,0)    NOT NULL COMMENT '대리키 ※비강제 FK→DIM_CAMPAIGN. 활동·중단·연도초·회비 = 후원사업 대표캠페인(FMSS) · 개발 = 개발 사건 캠페인(FME) · 감액 = 금액변경 원천 캠페인 · 0 = 미매핑',
    PAYMENT_SK                NUMBER(38,0)    NOT NULL COMMENT '대리키 ※비강제 FK→DIM_PAYMENT. 잠정 = 그 달 회원×후원사업 청구 행 결제수단(청구액 최대) → 회원×월 대표 결제수단 → 0(청구 없음)',
    ACTIVE_CNT                NUMBER(18,4)    COMMENT '월말 활동(건) = 기준월 as-of 활동 후원사업 약정금액 ÷ 10,000 (FMM ACTIVE_CNT 와 같은 판정)',
    PREV_MONTH_END_ACTIVE_CNT NUMBER(18,4)    COMMENT '전월말 활동(건) = 전월 as-of 활동 약정금액 ÷ 10,000 (FMM 과 같은 판정)',
    YEAR_START_ACTIVE_CNT     NUMBER(18,4)    COMMENT '연도초활동(건) = 기준연도 1월 as-of 활동 약정금액 ÷ 10,000 · 같은 해 기준월마다 같은 값이 실린다(기준월 1개 고정 · 여러 달 SUM 금지)',
    STOP_CNT                  NUMBER(18,4)    COMMENT '당월 중단(건) = 기준월 중단 후원사업 약정금액 ÷ 10,000 (FMM STOP_AMT_CNT 와 같은 식)',
    DEV_CNT                   NUMBER(18,4)    COMMENT '당월 개발(건) = MSTR 개발(건)(인정금액 ÷ 10,000) (FMM DEV_CNT 와 같은 원천)',
    DECREASE_CNT              NUMBER(18,4)    COMMENT '당월 감액(건) = 감액금액 ÷ 10,000 (FMM DECREASE_CNT 와 같은 식)',
    CHURN_CNT                 NUMBER(18,4)    COMMENT '당월 이탈(건) = 중단(건) + 감액(건) (FMM CHURN_CNT 와 같은 식 · 신규 #20)',
    PAID_FEE_BILLABLE         NUMBER(18,2)    COMMENT '당월 납입회비(원 · 회비만) (FMM PAID_FEE_BILLABLE 과 같은 값)',
    UNPAID_BILLED_AMT         NUMBER(18,2)    COMMENT '당월 미납회비(원) = 결제 실패·미기록 청구액 (FMM UNPAID_BILLED_AMT 와 같은 값)',
    CUM_STOP_CNT              NUMBER(18,4)    COMMENT '누계중단(건) = 1월~기준월 STOP_CNT 합',
    CUM_DEV_CNT               NUMBER(18,4)    COMMENT '누계개발(건) = 1월~기준월 DEV_CNT 합',
    CUM_ACTIVE_CNT            NUMBER(18,4)    COMMENT '누계 활동(건) = 1월~기준월 ACTIVE_CNT 합(누계납입율 분모)',
    CUM_PAID_FEE_BILLABLE     NUMBER(18,2)    COMMENT '누계 납입회비(원) = 1월~기준월 PAID_FEE_BILLABLE 합',
    DW_SOURCE_SYSTEM          VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS                TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS              TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID               VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '캠페인별 월 지표(활동율·중단율·이탈율·납입율·미납율) 분자·분모 팩트. [Grain: BASE_MONTH_KEY × CAMPAIGN_SK × PAYMENT_SK]. [대상 집합 = FACT_MEMBER_MONTHLY 회원×월 스파인 — 전 캠페인·납입방식 합 = FMM 같은 월 합]. [원천: GOLD.FACT_MEMBER_SPONSORSHIP_SPAN · FACT_MEMBER_EVENT · FACT_MEMBER_FEE · SILVER.CRM_MEMBER_AMT_CHANGE]. [적재: dbt]';
"""
ANCHOR_TABLE_END = "[원천: GOLD.FACT_MEMBER_SPONSORSHIP_SPAN · FACT_MEMBER_EVENT]. [적재: dbt]';\n"
ANCHOR_DROP = "  BEGIN ALTER TABLE GN_DW.GOLD.FACT_CAMPAIGN_CUM_STOP DROP CONSTRAINT FK_FCCS_DIM_CAMPAIGN; EXCEPTION WHEN OTHER THEN NULL; END;\n"
DROP_ADD = ("  BEGIN ALTER TABLE GN_DW.GOLD.FACT_CAMPAIGN_MONTHLY DROP CONSTRAINT FK_FCM_DIM_CAMPAIGN; EXCEPTION WHEN OTHER THEN NULL; END;\n"
            "  BEGIN ALTER TABLE GN_DW.GOLD.FACT_CAMPAIGN_MONTHLY DROP CONSTRAINT FK_FCM_DIM_PAYMENT; EXCEPTION WHEN OTHER THEN NULL; END;\n")
ANCHOR_FK = ("ALTER TABLE GN_DW.GOLD.FACT_CAMPAIGN_CUM_STOP ADD CONSTRAINT FK_FCCS_DIM_CAMPAIGN\n"
             "    FOREIGN KEY (CAMPAIGN_SK) REFERENCES GN_DW.GOLD.DIM_CAMPAIGN (CAMPAIGN_SK) NOT ENFORCED NORELY;\n")
FK_ADD = ("ALTER TABLE GN_DW.GOLD.FACT_CAMPAIGN_MONTHLY ADD CONSTRAINT FK_FCM_DIM_CAMPAIGN\n"
          "    FOREIGN KEY (CAMPAIGN_SK) REFERENCES GN_DW.GOLD.DIM_CAMPAIGN (CAMPAIGN_SK) NOT ENFORCED NORELY;\n"
          "ALTER TABLE GN_DW.GOLD.FACT_CAMPAIGN_MONTHLY ADD CONSTRAINT FK_FCM_DIM_PAYMENT\n"
          "    FOREIGN KEY (PAYMENT_SK) REFERENCES GN_DW.GOLD.DIM_PAYMENT (PAYMENT_SK) NOT ENFORCED NORELY;\n")

YML_ADD = """  - name: FACT_CAMPAIGN_MONTHLY
    description: >
      기준연월 × 캠페인 × 납입방식 월 팩트 — grain = BASE_MONTH_KEY × CAMPAIGN_SK × PAYMENT_SK.
      대상 집합 = FACT_MEMBER_MONTHLY 회원×월 스파인이라 같은 월 전 캠페인·납입방식 합이 FMM 합과 같아야 한다(대사 = 05_25b).
      🔴 누계·연도초는 기준월마다 as-of 값이다 — 기준월 하나를 골라 조회한다(여러 기준월 SUM 금지).
      🔴 캠페인 = 후원건 대표캠페인(활동·중단·연도초·회비) · 개발 사건 캠페인(개발) · 금액변경 캠페인(감액) — 규칙이 다르다.
      ⚠️ 납입방식 축은 잠정(그 달 청구 결제수단) · 컬럼 문안 정본 = `03_top-down_gold/06_DDL.sql`.
    columns:
      - name: BASE_MONTH_KEY
        tests:
          - not_null
      - name: CAMPAIGN_SK
        tests:
          - not_null
          - relationships: { to: ref('DIM_CAMPAIGN'), field: CAMPAIGN_SK }
      - name: PAYMENT_SK
        tests:
          - not_null
"""


def patch_once(src, anchor, add, after=True):
    assert src.count(anchor) == 1, (anchor[:60], src.count(anchor))
    i = src.index(anchor) + (len(anchor) if after else 0)
    return src[:i] + add + src[i:], i


def main():
    os.makedirs(BAK, exist_ok=True)
    for p in (DDL, YML):
        b = os.path.join(BAK, os.path.basename(p) + ".O237B-before")
        if not os.path.exists(b):
            shutil.copyfile(p, b)
        if open(b, encoding="utf-8").read() != open(p, encoding="utf-8").read():
            sys.exit("백업 ≠ 현재 — 중단: " + p)
    d = open(DDL, encoding="utf-8").read()
    if "FACT_CAMPAIGN_MONTHLY" in d:
        sys.exit("06_DDL 이미 등재")
    n = d
    n, _ = patch_once(n, ANCHOR_TABLE_END, TABLE)
    n, _ = patch_once(n, ANCHOR_DROP, DROP_ADD)
    n, _ = patch_once(n, ANCHOR_FK, FK_ADD)
    # 바이트 보존 = 삽입분을 빼면 원본과 같다
    assert n.replace(TABLE, "", 1).replace(DROP_ADD, "", 1).replace(FK_ADD, "", 1) == d
    open(DDL, "w", encoding="utf-8").write(n)
    assert open(DDL, encoding="utf-8").read() == n
    print("06_DDL OK", len(d.splitlines()), "→", len(n.splitlines()), "줄")

    y = open(YML, encoding="utf-8").read()
    if "FACT_CAMPAIGN_MONTHLY" in y:
        sys.exit("yml 이미 등재")
    assert y.endswith("field: CAMPAIGN_SK }\n"), repr(y[-60:])
    ny = y + YML_ADD
    o, nn = yaml.safe_load(y), yaml.safe_load(ny)
    assert nn["models"][:-1] == o["models"] and nn["models"][-1]["name"] == "FACT_CAMPAIGN_MONTHLY"
    assert {k: v for k, v in nn.items() if k != "models"} == {k: v for k, v in o.items() if k != "models"}
    open(YML, "w", encoding="utf-8").write(ny)
    assert open(YML, encoding="utf-8").read() == ny and ny.startswith(y)
    print("yml OK · 모델", len(o["models"]), "→", len(nn["models"]))


if __name__ == "__main__":
    main()

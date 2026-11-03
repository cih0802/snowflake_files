import io
p = '/workspace/문서실행순서.md'
s = io.open(p, encoding='utf-8').read()
head, sep, ops = s.partition('# 운영계\n')
assert sep
rep = [
    ("4. /04_silver_design/08_SILVER_테이블DDL_20260714.sql\n",
     "4. /04_silver_design/08_SILVER_테이블DDL_20260714.sql -- [🆕 O225] CRM_SEND_MEMBER SND 캠페인 3종 포함\n"),
    ("5. /03_top-down_gold/06_DDL.sql\n",
     "5. /03_top-down_gold/06_DDL.sql -- [🆕 O225] 캠페인 축 컬럼 포함(팩트 5종 + DIM_MARKETING_CAMPAIGN)\n"),
    ("14. /10_dbt_pipeline/02_dbt_parse_compile_build.sql\n",
     "14. /10_dbt_pipeline/02_dbt_parse_compile_build.sql -- [🆕 O225] 매크로 billing_campaign_asof · 테스트 6종 포함\n"),
    ("16. /05_SV-Agent_ai/05_01_SV_DDL_MEMBER_MONTHLY.sql\n",
     "16. /05_SV-Agent_ai/05_01_SV_DDL_MEMBER_MONTHLY.sql -- [🆕 O225] 그 달 후원 캠페인 차원\n"),
    ("19. /05_SV-Agent_ai/05_04_SV_DDL_SERVICE.sql\n",
     "19. /05_SV-Agent_ai/05_04_SV_DDL_SERVICE.sql -- [🆕 O225] 발송(SND) 캠페인 차원\n"),
    ("22. /05_SV-Agent_ai/05_07_SV_DDL_AD.sql\n",
     "22. /05_SV-Agent_ai/05_07_SV_DDL_AD.sql -- [🆕 O225] 마케팅캠페인 UTM·국내해외·사업사례 차원\n"),
    ("34. /05_SV-Agent_ai/05_19_SV_DDL_PAYMENT_BILLING_STATUS.sql\n",
     "34. /05_SV-Agent_ai/05_19_SV_DDL_PAYMENT_BILLING_STATUS.sql -- [🆕 O225] 그 달 후원 캠페인 차원\n"),
    ("38. /05_SV-Agent_ai/05_23_SV_DDL_EXPENSE_RESOLUTION.sql\n",
     "38. /05_SV-Agent_ai/05_23_SV_DDL_EXPENSE_RESOLUTION.sql -- [🆕 O225] 세부캠페인코드 → 마케팅캠페인 차원\n"),
]
for a, b in rep:
    assert ops.count(a) == 1, a
    ops = ops.replace(a, b)
note = (
    "> 🆕 [O225] **기존 계정에 O225 만 덧입힐 때** = 처음부터 다시 돌리지 않는다 — 아래 순서로 3단계만 한다.\n"
    "> ① `ALTER TABLE … ADD COLUMN IF NOT EXISTS`(비파괴) 6테이블 — 컬럼·COMMENT 정본 = `04_silver_design/08_…sql`(CRM_SEND_MEMBER)\n"
    ">    · `03_top-down_gold/06_DDL.sql`(FACT_AD_PERFORMANCE · FACT_EXPENSE_RESOLUTION · FACT_MESSAGE_DISPATCH · FACT_PAYMENT_BILLING_STATUS · FACT_MEMBER_MONTHLY · DIM_MARKETING_CAMPAIGN)\n"
    "> ② dbt build(👤) = `CRM_SEND_MEMBER+ FACT_PAYMENT_BILLING_STATUS+ FACT_MEMBER_MONTHLY+ DIM_MARKETING_CAMPAIGN+ FACT_EXPENSE_RESOLUTION+ FACT_AD_PERFORMANCE+`\n"
    "> ③ SV 재배포 = `05_23` · `05_07` · `05_19` · `05_04` · `05_01`(Agent 버전업 불필요 · 도구 대상 SV 이름 불변) · 경위 = 인수인계 `99_NEXT_SESSION-O0225-C.md`\n"
)
ops = ops.rstrip('\n') + '\n' + note
io.open(p, 'w', encoding='utf-8').write(head + sep + ops)
print('ok')

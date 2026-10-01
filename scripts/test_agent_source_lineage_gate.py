# -*- coding: utf-8 -*-
"""[2026-10-01 O193] `agent_source_lineage_gate` 음성 테스트 — **잡아야 할 것을 잡는가**.

🔴 왜 필요한가: 이 게이트는 처음 돌린 순간 PASS(blocking 0) 였다. 「0건」이 「없다」인지
   「판정식이 못 본다」인지는 PASS 만으로 구별되지 않는다(`agent_object_ref_gate` 테스트와 같은 이유).
   ⇒ 가짜 dbt 프로젝트·SV DDL·스펙을 임시 폴더에 만들어 축마다 양방향으로 단정한다.

🟢 라이브 접속 없이 돈다.
"""
import sys
import os
import io
import tempfile

sys.path.insert(0, '/workspace/scripts')
import agent_source_lineage_gate as G

# 가짜 리니지: FACT_E ← CRM_DEV(TM_DEV) + CRM_CODE(TC_CODE) + DIM_C ← CRM_CMP(TM_CMP)
#             FACT_K(파생) ← FACT_E
FILES = {
    '10_dbt_pipeline/models/silver/crm/CRM_DEV.sql': "select * from {{ source('bronze_crm','TM_DEV') }}",
    '10_dbt_pipeline/models/silver/crm/CRM_CODE.sql': "select * from {{ source('bronze_crm','TC_CODE') }}",
    '10_dbt_pipeline/models/silver/crm/CRM_CMP.sql': "select * from {{ source('bronze_crm_ref','TM_CMP') }}",
    '10_dbt_pipeline/models/silver/crm/CRM_OTHER.sql': "select * from {{ source('bronze_crm','TM_OTHER') }}",
    '10_dbt_pipeline/models/silver/crm/CRM_MEM.sql': "select * from {{ source('bronze_crm','TM_MEM') }}",
    '10_dbt_pipeline/models/gold/dim/DIM_M.sql': "select * from {{ ref('CRM_MEM') }}",
    '10_dbt_pipeline/models/gold/dim/DIM_C.sql': "select * from {{ ref('CRM_CMP') }}",
    '10_dbt_pipeline/models/gold/fact/FACT_E.sql':
        "select * from {{ ref('CRM_DEV') }} join {{ ref('CRM_CODE') }} join {{ ref('DIM_C') }} join {{ ref('CRM_MEM') }}"
        "\n-- {{ ref('CRM_OTHER') }} 주석 안의 ref 는 리니지가 아니다",
    '10_dbt_pipeline/models/gold/fact/FACT_K.sql': "select * from {{ ref('FACT_E') }}",
    '05_SV-Agent_ai/05_x.sql':
        "CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_E\n tables ( e AS GN_DW.GOLD.FACT_E, c AS GN_DW.GOLD.DIM_C );\n"
        "CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_K\n tables ( k AS GN_DW.GOLD.FACT_K );\n"
        "CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_ML\n tables ( m AS GN_DW.SERVING.ML_X_V );\n",
}


def spec(desc, sv='SV_E'):
    return ("models:\n  orchestration: auto\ninstructions:\n  system: 'x'\n"
            "tools:\n- tool_spec:\n    type: cortex_analyst_text_to_sql\n    name: analyst_t\n"
            "    description: '%s'\ntool_resources:\n  analyst_t:\n    semantic_view: GN_DW.SERVING.%s\n" % (desc, sv))


def run(desc, sv='SV_E', strict=False):
    with tempfile.TemporaryDirectory() as d:
        for rel, body in FILES.items():
            p = os.path.join(d, rel)
            os.makedirs(os.path.dirname(p), exist_ok=True)
            open(p, 'w', encoding='utf-8').write(body)
        p = os.path.join(d, 'cortex_project/agents/A_TEST/agent_spec.yaml')
        os.makedirs(os.path.dirname(p), exist_ok=True)
        open(p, 'w', encoding='utf-8').write(spec(desc, sv))
        buf = io.StringIO()
        rc = G.judge(root=d, strict=strict, out=buf)
        return rc, buf.getvalue()


def check(name, cond, detail=''):
    print(('PASS ' if cond else 'FAIL ') + name + ('' if cond else '\n' + detail))
    return cond


def main():
    ok = True
    # 축0 · 양성: 리니지 안 테이블 + 맞는 GOLD ⇒ PASS, advisory 없음
    rc, o = run('원천=BRONZE_CRM(TM_DEV) → GOLD.FACT_E.')
    ok &= check('축0 정상 문안 PASS', rc == 0 and '③' not in o and '④' not in o, o)
    # 축1 · 리니지 밖 BRONZE 테이블(모집단에는 있음) ⇒ blocking
    rc, o = run('원천=BRONZE_CRM(TM_DEV·TM_OTHER) → GOLD.FACT_E.')
    ok &= check('축1 리니지 밖 테이블 FAIL', rc == 1 and '`TM_OTHER`' in o, o)
    # 축1-B · 주석 안 ref 는 리니지로 세지 않는다(세면 TM_OTHER 가 ALLOWED 로 새어 축1 이 침묵한다)
    ok &= check('축1-B 주석 ref 비리니지', 'TM_OTHER' not in {t for _, t in G.closure(G.load_models(_tmp_root()), 'FACT_E')})
    # 축1-C · DIM 경유 원천(TM_CMP)은 ALLOWED ⇒ blocking 아님
    rc, o = run('원천=BRONZE_CRM(TM_DEV · 캠페인 TM_CMP) → GOLD.FACT_E.')
    ok &= check('축1-C DIM 경유 원천 허용', rc == 0, o)
    # 축2 · 리니지 밖 GOLD ⇒ blocking
    rc, o = run('원천=BRONZE_CRM(TM_DEV) → GOLD.FACT_NOPE.')
    ok &= check('축2 GOLD 리니지 밖 FAIL', rc == 1 and 'GOLD.FACT_NOPE' in o, o)
    # 축2-B · 파생 팩트 SV 가 조상 팩트를 적는 것은 정상
    rc, o = run('원천=BRONZE_CRM(TM_DEV) → GOLD.FACT_E 에서 파생 → GOLD.FACT_K.', sv='SV_K')
    ok &= check('축2-B 조상 팩트 허용 + 파생 팩트 CORE 하강', rc == 0 and '③' not in o, o)
    # 축3 · 핵심 원천 누락 ⇒ advisory(rc 0) · TC_* 는 누락으로 세지 않는다
    rc, o = run('원천=BRONZE_CRM(TM_CMP) → GOLD.FACT_E.')
    ok &= check('축3 CORE 누락 advisory', rc == 0 and '③' in o and 'TM_DEV' in o and 'TC_CODE' not in o, o)
    # 축4 · 원천 괄호 미기재 ⇒ 기본 advisory · strict blocking
    rc, o = run('원천=CRM → GN_DW.BRONZE_CRM.')
    ok &= check('축4 미기재 advisory', rc == 0 and '④' in o, o)
    rc, o = run('원천=CRM → GN_DW.BRONZE_CRM.', strict=True)
    ok &= check('축4-B 미기재 strict FAIL', rc == 1 and '④' in o, o)
    # 축5 · dbt 밖 SV 는 관측(판정 생략) — 아무 테이블을 적어도 blocking 안 됨
    rc, o = run('원천=GN_DW.ML → SERVING.ML_X_V.', sv='SV_ML')
    ok &= check('축5 dbt 밖 SV 관측', rc == 0 and 'dbt 밖' in o, o)
    # 🆕 축6 · [O196-D · DEC-59 #7] 차원 원천 제외 — 팩트가 직접 읽어도 DIM_* 가 읽는 SILVER 원천(TM_MEM)은
    #   누락으로 세지 않는다 · 차원이 아닌 핵심(TM_DEV)은 여전히 잡는다 · 메시지에 DEC 번호가 나온다
    ok &= check('축6-A 차원 원천 집합', 'TM_MEM' in G.dim_sources(G.load_models(_tmp_root()))
                and 'TM_DEV' not in G.dim_sources(G.load_models(_tmp_root())))
    rc, o = run('원천=BRONZE_CRM(TM_DEV) → GOLD.FACT_E.')
    ok &= check('축6-B 차원 원천 미기재는 ③ 아님', rc == 0 and 'TM_MEM' not in o and '③' not in o, o)
    rc, o = run('원천=BRONZE_CRM(TM_CMP) → GOLD.FACT_E.')
    ok &= check('축6-C 핵심 누락은 여전히 ③ + DEC 안내', '③' in o and 'TM_DEV' in o and 'TM_MEM' not in o
                and 'DEC-59' in o, o)
    print('=' * 40)
    print('ALL PASS' if ok else 'SOME FAIL')
    return 0 if ok else 1


_TMP = None


def _tmp_root():
    global _TMP
    if _TMP is None:
        _TMP = tempfile.mkdtemp()
        for rel, body in FILES.items():
            p = os.path.join(_TMP, rel)
            os.makedirs(os.path.dirname(p), exist_ok=True)
            open(p, 'w', encoding='utf-8').write(body)
    return _TMP


if __name__ == '__main__':
    sys.exit(main())

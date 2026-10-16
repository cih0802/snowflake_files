# test_metric_sv_wiring.py — gen_metric_gold_mapping SV 배선 축 음성 테스트(R3-2 · O241)
# Co-authored with CoCo
"""토큰이 있으면 배선이 잡히고, 토큰을 지우면 미배선으로 잡혀야 한다(실패 케이스로 검증).

실행: python3 scripts/test_metric_sv_wiring.py  → 전건 PASS 면 exit 0.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_metric_gold_mapping as G  # noqa: E402

SV_WITH = """CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_TEST
  TABLES (
    t AS GN_DW.GOLD.FACT_T
      WITH SYNONYMS ('공99 아님')
      COMMENT = '테이블 행은 배선 대상이 아니다.'
  )
  DIMENSIONS (
    t.DIM_A AS t.DIM_A WITH SYNONYMS ('차원') COMMENT = '정본 공#130 차원.'
  )
  METRICS (
    -- 공777 주석은 무시한다
    t.M_ONE AS SUM(t.X)
      WITH SYNONYMS ('하나', '공91B')
      COMMENT = '공#139~141 매칭. 현업 회신 44 는 지표가 아니다.',
    t.M_TWO AS SUM(t.Y)
      WITH SYNONYMS ('둘', '신규44')
      COMMENT = '신규 #33 · 공88·90.'
  )
  AI_SQL_GENERATION '핵심 규칙: 공500 은 규칙 문장이라 배선이 아니다.'
  );
"""

FAIL = []


def check(name, cond):
    print(("PASS " if cond else "FAIL ") + name)
    if not cond:
        FAIL.append(name)


def main():
    sv, w = G.parse_sv_wiring_text(SV_WITH)
    check("T1 SV명 파싱", sv == "SV_TEST")
    check("T2 동의어 토큰(공91B)", w.get("공91") == {"SV_TEST.M_ONE"})
    check("T3 범위 전개(공#139~141)", all(w.get(f"공{n}") == {"SV_TEST.M_ONE"} for n in (139, 140, 141)))
    check("T4 신규 #NN → 신NN", w.get("신33") == {"SV_TEST.M_TWO"} and w.get("신44") == {"SV_TEST.M_TWO"})
    check("T5 가운뎃점 나열(공88·90)", w.get("공88") == {"SV_TEST.M_TWO"} and w.get("공90") == {"SV_TEST.M_TWO"})
    check("T6 차원도 배선(공#130)", w.get("공130") == {"SV_TEST.DIM_A"})
    check("T7 테이블 행 제외(공99)", "공99" not in w)
    check("T8 SQL 주석 제외(공777)", "공777" not in w)
    check("T9 AI_SQL_GENERATION 규칙 문장 제외(공500)", "공500" not in w)
    # 🔴 음성 = 토큰을 지우면 미배선으로 잡혀야 한다
    _, w2 = G.parse_sv_wiring_text(SV_WITH.replace("'공91B'", "'선물금'"))
    check("N1 토큰 제거 → 공91 미배선", "공91" not in w2)
    _, w3 = G.parse_sv_wiring_text(SV_WITH.replace("공#139~141", "발송 후"))
    check("N2 범위 토큰 제거 → 공139 미배선", "공139" not in w3)
    # 실 정본 스모크 — O241 이 배선한 공91·공98 이 실제 파일에서 잡히는가
    real = G.load_sv_wiring()
    check("R1 정본 공91 → SV_SERVICE.D5_GIFT_AMT", "SV_SERVICE.D5_GIFT_AMT" in real.get("공91", set()))
    check("R2 정본 공98 → SV_GA_SESSION 두 metric",
          {"SV_GA_SESSION.AVG_SESSION_ENGAGEMENT_SEC", "SV_GA_SESSION.AVG_SESSION_DURATION_SEC"} <= real.get("공98", set()))
    ag = G.load_agent_wiring()
    check("R3 Agent SV_GA_SESSION → AGENT_MARKETING", "AGENT_MARKETING" in ag.get("SV_GA_SESSION", set()))
    # 🆕 [O241] 괄호를 담은 동의어 뒤 토큰도 잡힌다(삽입기 1차 실패 = 「개발(건)」 괄호 오인 · 파서는 토큰만 본다)
    _, w4 = G.parse_sv_wiring_text(SV_WITH.replace("'공91B'", "'개발(건)', '공4'"))
    check("R4 괄호 동의어 뒤 토큰(공4)", w4.get("공4") == {"SV_TEST.M_ONE"})
    print(f"\n{'🟢 PASS' if not FAIL else '🔴 FAIL'} — 실패 {len(FAIL)}건")
    sys.exit(1 if FAIL else 0)


if __name__ == "__main__":
    main()

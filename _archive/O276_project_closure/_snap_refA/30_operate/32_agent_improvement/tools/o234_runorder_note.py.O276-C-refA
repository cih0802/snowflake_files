# O234 — 문서실행순서_보조주석.md 에 O234 주석·덧입히기 절차 추가(건수 검증 후 쓰기)
# Co-authored with CoCo
import io
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
P = os.path.join(ROOT, "문서실행순서_보조주석.md")

SUBS = [
    ("· [O233-A] FMC LAST_STOP_DATE_SK·OBS_TENURE_MONTHS_LAST·IS_STOPPED_OBS_LAST |",
     "· [O233-A] FMC LAST_STOP_DATE_SK·OBS_TENURE_MONTHS_LAST·IS_STOPPED_OBS_LAST · [O234] FMC OBS_\\*·\\*_LAST·FMCS COMMENT 「잠정」→확정(구조 무변경) |"),
    ("· 실측 O233 PASS=41 WARN=0 |",
     "· 실측 O233 PASS=41 WARN=0 · [O234] yml description·모델 주석 확정 문안(로직·vars 무변경 ⇒ 재build 불필요) |"),
    ("| 23 | `05_03_SV_DDL_MEMBER_COHORT.sql` | [O231·O232] 생존(KM) 표 FMCS · LTV 상한별 기대 유지개월(RMST) |",
     "| 23 | `05_03_SV_DDL_MEMBER_COHORT.sql` | [O231·O232] 생존(KM) 표 FMCS · LTV 상한별 기대 유지개월(RMST) · [O234] 현업 확정 문안(상한 80 + 무기한 9999 · 셀 최소 1) |"),
    ("· 코퍼스 수정 시 먼저 `python3 12_agent개선과제/tools/build_biz_definition_corpus.py` |",
     "· 코퍼스 수정 시 먼저 `python3 12_agent개선과제/tools/build_biz_definition_corpus.py` · [O234] 코퍼스 2,155행(RT-29 기대 유지개월 · RT-04/20 동의어 · 오버레이 +2) |"),
    ("| 51 | `09_2_AGENT_버전업.sql` | cortex_project/agents/\\* 정본 YAML → OPS 스테이지 동기화 후 실서비스 버전 발행 |",
     "| 51 | `09_2_AGENT_버전업.sql` | cortex_project/agents/\\* 정본 YAML → OPS 스테이지 동기화 후 실서비스 버전 발행 · [O234] MARKETING LTV 유지개월 지침 교체(개발계 VERSION$10) |"),
]

ADD = """### O234만 덧입힐 때
O233 덧입힘을 마친 뒤 아래를 한다(경위 = 인수인계 `99_NEXT_SESSION-O0234-B.md`). 🟢 구조·dbt 로직 변경 없음 ⇒ dbt build 불필요.
1. COMMENT 동기화 = FMC OBS_TENURE_DAYS·OBS_TENURE_MONTHS·IS_STOPPED_OBS·LAST_STOP_DATE_SK·OBS_TENURE_MONTHS_LAST·IS_STOPPED_OBS_LAST · FMCS LTV_CAP_MONTHS·테이블 COMMENT
   - 정본 = 06_DDL 문안 · 방법 = `ALTER TABLE … ALTER COLUMN … COMMENT` / `COMMENT ON TABLE`(소유자 롤 GN_DW_ADMIN) · 06_DDL 을 처음부터 돌리는 환경이면 생략
2. 코퍼스 재적재 = `python3 12_agent개선과제/tools/build_biz_definition_corpus.py --apply`(2,155행) → `ALTER CORTEX SEARCH SERVICE GN_DW.SERVING.SEARCH_BIZ_DEFINITION REFRESH`
   - 확인 = `python3 12_agent개선과제/tools/o234_search_probe.py`(개발계 hit@1 79% · hit@3 88%)
3. SV 재배포 = `05_03`(SV_MEMBER_COHORT) · 기대 = 상한 80 52.75 · 무기한 130.27
4. Agent 버전업(`09_2`) — MARKETING 스펙(LTV 유지개월 = 기대 유지개월 80/무기한)

"""

s = io.open(P, encoding="utf-8").read()
for a, b in SUBS:
    assert s.count(a) == 1, (a[:50], s.count(a))
    s = s.replace(a, b)
k = "_Co-authored with CoCo_"
assert s.count(k) == 1
s = s.replace(k, ADD + k)
io.open(P, "w", encoding="utf-8").write(s)
print("ok", s.count("O234"))

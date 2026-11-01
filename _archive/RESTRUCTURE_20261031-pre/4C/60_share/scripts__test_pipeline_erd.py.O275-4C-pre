"""
Pipeline ERD & Lineage Generator Test Suite
Tests scripts/gen_pipeline_erd.py outputs and structure
Co-authored with CoCo
"""

import os
import re
import sys
import glob

ROOT = "/workspace"
ERD_DIR = os.path.join(ROOT, "30_output_share", "erd")

passed = 0
failed = 0

def assert_true(cond, msg):
    global passed, failed
    if cond:
        passed += 1
        print(f"  🟢 {msg}")
    else:
        failed += 1
        print(f"  🔴 FAIL: {msg}")

print("=== Pipeline ERD & Lineage Generator Test Suite ===\n")

# [축1] 파일 생성 여부 (index.html + DIM/FACT 테이블 전건)
# 🆕 [O270] 기대 수를 하드코딩(38)하지 않고 생성기 입력 목록에서 유도한다(`R3-9 ㉦` · O269-C-1 ③).
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_pipeline_erd
expected_gold = sorted(m for m in gen_pipeline_erd.load_sql_metadata() if m.startswith(("DIM_", "FACT_")))
all_html_files = glob.glob(f"{ERD_DIR}/*.html")
html_files = [f for f in all_html_files if os.path.basename(f) == 'index.html' or os.path.basename(f).startswith(('DIM_', 'FACT_'))]
assert_true(os.path.exists(os.path.join(ERD_DIR, "index.html")), "index.html 실재")
assert_true(len(html_files) == len(expected_gold) + 1,
            f"HTML 파일 수 = 생성기 GOLD 대상 {len(expected_gold)} + index 1 (실측: {len(html_files)})")
missing_html = [g for g in expected_gold if not os.path.exists(os.path.join(ERD_DIR, g + ".html"))]
assert_true(not missing_html, f"생성기 대상 전건의 HTML 실재 (부재: {', '.join(missing_html[:5])})")

# [축2] 메타데이터 태그 및 엄격한 보안 준수 (Strict CSP)
sample_files = [
    os.path.join(ERD_DIR, "index.html"),
    os.path.join(ERD_DIR, "DIM_MEMBER.html"),
    os.path.join(ERD_DIR, "FACT_MEMBER_FEE.html"),
    os.path.join(ERD_DIR, "FACT_BUDGET.html")
]

for sf in sample_files:
    with open(sf, "r", encoding="utf-8") as f:
        content = f.read()
    fname = os.path.basename(sf)
    assert_true('name="snowflake-source"' in content, f"{fname} 에 snowflake-source 메타태그 포함")
    assert_true('id="snowflake-report-metadata"' in content, f"{fname} 에 report-metadata JSON 포함")
    assert_true('onclick=' not in content, f"{fname} 에 인라인 onclick 없음 (CSP 준수)")
    assert_true('eval(' not in content, f"{fname} 에 eval 없음 (CSP 준수)")

# [축3] Lineage & Mermaid 구조 점검
with open(os.path.join(ERD_DIR, "FACT_MEMBER_FEE.html"), "r", encoding="utf-8") as f:
    fmf_content = f.read()

assert_true("subgraph BRONZE" in fmf_content, "FACT_MEMBER_FEE 에 BRONZE 서브그래프 존재")
assert_true("subgraph SILVER" in fmf_content, "FACT_MEMBER_FEE 에 SILVER 서브그래프 존재")
assert_true("subgraph GOLD" in fmf_content, "FACT_MEMBER_FEE 에 GOLD 서브그래프 존재")
assert_true("CRM_PAYMENT_BILLING" in fmf_content, "FACT_MEMBER_FEE 에 CRM_PAYMENT_BILLING 연결")

# [축4] Mermaid erDiagram 문법 전수 검사 (37개 테이블)
ATTR_REGEX = re.compile(r"^[A-Za-z0-9_]+\s+[A-Za-z0-9_]+(\s+(PK|FK))?$")
REL_REGEX = re.compile(r'^[A-Za-z0-9_]+\s+\|\|[-.]{2}o\{\s+[A-Za-z0-9_]+\s+:\s+"[^"]*"$')

erd_syntax_errors = []
for hf in html_files:
    if os.path.basename(hf) == "index.html":
        continue
    with open(hf, "r", encoding="utf-8") as f:
        html_src = f.read()
    
    # Extract erDiagram block
    erd_blocks = re.findall(r'<pre class="mermaid">\s*(erDiagram.*?)</pre>', html_src, re.DOTALL)
    for b in erd_blocks:
        for line in b.strip().splitlines():
            s = line.strip()
            if not s or s in ("erDiagram", "}") or s.endswith("{"):
                continue
            if "o{" in s:
                if not REL_REGEX.match(s):
                    erd_syntax_errors.append((os.path.basename(hf), s))
            else:
                if not ATTR_REGEX.match(s):
                    erd_syntax_errors.append((os.path.basename(hf), s))

assert_true(len(erd_syntax_errors) == 0, f"37개 테이블 ERD Mermaid 문법 오류 0건 (실측 오류: {len(erd_syntax_errors)})")
if erd_syntax_errors:
    for fname, err_line in erd_syntax_errors[:5]:
        print(f"    · [{fname}] {err_line}")

# [축5] 한 줄 2000자 상한 전수 검사
max_len = 0
viol_count = 0
for hf in html_files:
    with open(hf, "r", encoding="utf-8") as f:
        for idx, line in enumerate(f, 1):
            line_len = len(line.rstrip("\r\n"))
            if line_len > max_len:
                max_len = line_len
            if line_len > 2000:
                viol_count += 1

assert_true(viol_count == 0, f"한 줄 2000자 초과 0건 (최대 길이: {max_len}자)")

print(f"\n============================================================")
print(f"단정 {passed + failed}건 · 🟢 통과 {passed} · 🔴 실패 {failed}")
if failed > 0:
    sys.exit(1)
print("🟢 ALL PASS")

"""O248 scratch: render a GOLD model's Jinja by simple substitution and run a check query on live.

Usage: python3 tmp/o248/render_check.py <model.sql> <out.sql> [event_month_filter]
Only handles the constructs used by O248 models (ref, var, gn_code, gold_meta, set start_dk).
"""
import re
import sys

CODES = {"DEV_NEW": "'1'", "DEV_INCREASE": "'2'", "DEV_DECREASE": "'3'", "DEV_REDONATE": "'4'", "DEV_STOP": "'5'"}
REF_SCHEMA = {"CRM_": "SILVER", "AGENCY_": "SILVER"}


def ref(name: str) -> str:
    for pfx, sch in REF_SCHEMA.items():
        if name.startswith(pfx):
            return f"GN_DW.{sch}.{name}"
    return f"GN_DW.GOLD.{name}"


def render(src: str, month_filter: str | None) -> str:
    src = re.sub(r"\{\{\s*config\(.*?\)\s*\}\}", "", src, flags=re.S)
    src = re.sub(r"\{%\s*set start_dk.*?%\}", "", src)
    src = src.replace("{{ start_dk }}", "20220101")
    src = re.sub(r"\{\{\s*ref\('(\w+)'\)\s*\}\}", lambda m: ref(m.group(1)), src)
    src = re.sub(r"\{\{\s*var\('billing_coverage_start_month'\)\s*\}\}", "202201", src)
    src = re.sub(r"\{\{\s*gn_code\('(\w+)'\)\s*\}\}", lambda m: CODES[m.group(1)], src)
    src = re.sub(
        r"\{\{\s*gold_meta\('(\w+)'\)\s*\}\}",
        lambda m: f"'{m.group(1)}' AS DW_SOURCE_SYSTEM, CURRENT_TIMESTAMP()::TIMESTAMP_NTZ AS DW_LOAD_TS, "
        "CURRENT_TIMESTAMP()::TIMESTAMP_NTZ AS DW_UPDATE_TS, 'O248_CHECK' AS DW_BATCH_ID",
        src,
    )
    if month_filter:
        src = src.replace("and DATE_SK >= 20220101", f"and DATE_SK between {month_filter}01 and {month_filter}31", 1)
    lines = [ln for ln in src.splitlines() if not ln.strip().startswith("--")]
    left = "\n".join(lines)
    if "{{" in left or "{%" in left:
        raise SystemExit("unrendered jinja remains")
    return left


if __name__ == "__main__":
    model, out = sys.argv[1], sys.argv[2]
    mf = sys.argv[3] if len(sys.argv) > 3 else None
    with open(model, encoding="utf-8") as f:
        body = render(f.read(), mf)
    with open(out, "w", encoding="utf-8") as f:
        f.write(body)
    print("rendered", out, len(body))

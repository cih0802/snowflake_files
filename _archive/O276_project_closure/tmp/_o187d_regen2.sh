#!/bin/sh
# [O187-D] 선행 스냅샷 + 누락 4종 재생성. 🔴 이 마운트는 >> 를 지원하지 않는다 ⇒ 단계마다 별도 파일(>)
cd /workspace
timeout 900 python3 scripts/dump_schema.py </dev/null >tmp/_s1.out 2>&1; echo "rc=$?" >tmp/_s1.rc
timeout 1500 python3 scripts/census_columns.py </dev/null >tmp/_s2.out 2>&1; echo "rc=$?" >tmp/_s2.rc
timeout 900 python3 scripts/gen_column_mapping.py </dev/null >tmp/_s3.out 2>&1; echo "rc=$?" >tmp/_s3.rc
timeout 900 python3 scripts/gen_silver_gold_retention.py </dev/null >tmp/_s4.out 2>&1; echo "rc=$?" >tmp/_s4.rc
timeout 900 python3 scripts/gen_metric_gold_mapping.py </dev/null >tmp/_s5.out 2>&1; echo "rc=$?" >tmp/_s5.rc
timeout 900 python3 scripts/gen_section_assembly.py </dev/null >tmp/_s6.out 2>&1; echo "rc=$?" >tmp/_s6.rc
timeout 900 python3 scripts/gen_concept_diagram.py </dev/null >tmp/_s7.out 2>&1; echo "rc=$?" >tmp/_s7.rc
timeout 900 python3 scripts/test_generators.py </dev/null >tmp/_s8.out 2>&1; echo "rc=$?" >tmp/_s8.rc

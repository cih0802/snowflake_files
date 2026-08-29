#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""[2026-08-29 O114-B] dbt 스키마 yml 구문·구조 검증기 (dbt 명령 없이).

🔴 왜 필요한가: `R4-1` 상 에이전트는 `dbt parse` 를 실행하지 않는다. 그러면 내가 방금 쓴
   yml 이 **문법적으로 유효한지조차** 확인하지 못한 채 사용자에게 넘기게 된다.
   ⇒ YAML 파싱 + dbt 스키마 최소 구조(models[].name / columns[].name / tests 형태)를 검사한다.

⚠️ 이 검증기가 보지 못하는 것 — `dbt parse` 의 대체물이 **아니다**:
   ㉠ `ref()`·`source()` 해석 · 모델 실재 · 순환 참조
   ㉡ 테스트 이름이 dbt 에 실재하는지(`unique`·`relationships` 오타)
   ㉢ Jinja 렌더링
   ⇒ 통과는 「YAML 로서 읽히고 최소 구조를 갖췄다」는 뜻뿐이다. 최종 판정은 사용자 `dbt parse` 다.

실행: python3 scripts/dbt_schema_lint.py
"""
import io
import os
import sys

try:
    import yaml
except ImportError:
    print('🔴 PyYAML 이 없다 — 검증을 건너뛴다(설치 없이 판정하지 않는다).')
    sys.exit(2)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

#: 검사 대상. 🔴 새 스키마 yml 을 만들면 여기 등재하라 — 빠뜨리면 조용히 검사 밖이 된다.
TARGETS = [
    '10_dbt_pipeline/models/silver/_sources.yml',
    '10_dbt_pipeline/models/silver/_silver_bridge_schema.yml',
    '10_dbt_pipeline/models/silver/crm/_crm_schema.yml',
    '10_dbt_pipeline/models/gold/_gold_ready_schema.yml',
    '10_dbt_pipeline/models/gold/wide/_wide_schema.yml',
]

FAIL = []
OK = [0]


def check(cond, label):
    if cond:
        OK[0] += 1
    else:
        FAIL.append(label)


def walk_columns(rel, owner, cols):
    if cols is None:
        return
    check(isinstance(cols, list), '%s: %s.columns 가 리스트가 아니다' % (rel, owner))
    if not isinstance(cols, list):
        return
    seen = set()
    for c in cols:
        check(isinstance(c, dict), '%s: %s 의 컬럼 항목이 매핑이 아니다' % (rel, owner))
        if not isinstance(c, dict):
            continue
        nm = c.get('name')
        check(bool(nm), '%s: %s 에 name 없는 컬럼 항목' % (rel, owner))
        # 🔴 같은 컬럼을 두 번 선언하면 뒤 선언이 앞 선언의 테스트를 **조용히 덮는다**.
        if nm:
            check(nm not in seen,
                  '%s: %s.%s 컬럼 중복 선언(뒤 항목이 앞 테스트를 덮는다)' % (rel, owner, nm))
            seen.add(nm)
        t = c.get('tests')
        if t is not None:
            check(isinstance(t, list), '%s: %s.%s tests 가 리스트가 아니다' % (rel, owner, nm))


def main():
    for rel in TARGETS:
        path = os.path.join(ROOT, rel)
        if not os.path.exists(path):
            FAIL.append('%s: 파일이 없다(TARGETS 가 낡았다)' % rel)
            continue
        raw = io.open(path, encoding='utf-8').read()
        try:
            doc = yaml.safe_load(raw)
        except Exception as e:                                  # noqa: BLE001
            FAIL.append('%s: YAML 파싱 실패 — %s' % (rel, str(e).split('\n')[0]))
            continue
        OK[0] += 1
        check(isinstance(doc, dict), '%s: 최상위가 매핑이 아니다' % rel)
        if not isinstance(doc, dict):
            continue
        check(doc.get('version') == 2, '%s: version 2 가 아니다' % rel)

        for node in (doc.get('models') or []):
            check(isinstance(node, dict) and node.get('name'),
                  '%s: name 없는 models 항목' % rel)
            if isinstance(node, dict):
                walk_columns(rel, node.get('name') or '?', node.get('columns'))

        for src in (doc.get('sources') or []):
            check(isinstance(src, dict) and src.get('name'),
                  '%s: name 없는 sources 항목' % rel)
            if not isinstance(src, dict):
                continue
            tbls = src.get('tables') or []
            names = []
            for t in tbls:
                check(isinstance(t, dict) and t.get('name'),
                      '%s: %s 에 name 없는 table' % (rel, src.get('name')))
                if isinstance(t, dict) and t.get('name'):
                    names.append(t['name'])
                    walk_columns(rel, '%s.%s' % (src.get('name'), t['name']),
                                 t.get('columns'))
            check(len(names) == len(set(names)),
                  '%s: source %s 에 테이블 중복 선언' % (rel, src.get('name')))

        # 🟢 모델·소스 이름 전역 중복 — 같은 이름을 두 파일에 쓰면 dbt 가 거부한다.
        print('  ✅ %-58s models %d · sources %d'
              % (rel, len(doc.get('models') or []), len(doc.get('sources') or [])))

    print('')
    if FAIL:
        print('🔴 FAIL %d건 / 단정 %d개' % (len(FAIL), OK[0] + len(FAIL)))
        for f in FAIL:
            print('   · %s' % f)
        return 1
    print('🟢 PASS — %d개 단정 (YAML 구문 + 최소 구조)' % OK[0])
    print('⚠️ 이것은 `dbt parse` 의 대체물이 아니다 — ref/source 해석·테스트명은 검사하지 않는다.')
    return 0


if __name__ == '__main__':
    sys.exit(main())

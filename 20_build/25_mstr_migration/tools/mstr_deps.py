# 1단계 — 의존성 탐색: 리포트 쿼리(또는 시드 객체)에서 원본 4종을 재귀 탐색해 이관 대상 목록 산출
#   사용: python3 mstr_deps.py --query "<리포트.sql>" [--exclude NAME ...] [--out deps.json]
#         python3 mstr_deps.py --seed F_MM_SPNSR_DVLP_SUM D_CMPGN_CD
#   규칙: ㉠ 쿼리/객체 본문에 나오는 MART/DBO 객체명 → 정의 파일에서 찾음(TABLE·VIEW·FUNCTION)
#         ㉡ 테이블이면 그 테이블을 INSERT/MERGE/UPDATE/TRUNCATE 하는 적재 프로시저(USP_<T>, USP_<T>_INIT)
#         ㉢ MSTR_ODS.DBO.<T> 는 원천 → BRONZE 실재 여부는 --check-bronze 로 라이브 확인
#         ㉣ 공통 헬퍼(USP_BCHLOG·USP_BCHERR·BCHLOG)는 프로시저가 하나라도 있으면 자동 포함
import argparse, io, json, re, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mstr_common as C

HELPERS = {'PROCEDURE': ['USP_BCHLOG', 'USP_BCHERR'], 'TABLE': ['BCHLOG']}
NOISE = {'MART', 'DBO', 'MSTR_ODS'}


def refs(text):
    """본문에서 MART./DBO. 접두 객체명과 MSTR_ODS.DBO.<원천> 을 분리 추출(주석 제거 후)"""
    t = re.sub(r'/\*.*?\*/', ' ', text, flags=re.S)
    t = re.sub(r'--[^\n]*', ' ', t)
    src = {m.upper() for m in re.findall(r'MSTR_ODS\s*\.\s*DBO\s*\.\s*\[?(\w+)\]?', t, re.I)}
    t2 = re.sub(r'MSTR_ODS\s*\.\s*DBO\s*\.\s*\[?\w+\]?', ' ', t, flags=re.I)
    obj = {m.upper() for m in re.findall(r'\b(?:MART|DBO)\s*\]?\s*\.\s*\[?(\w+)\]?', t2, re.I)}
    obj |= {m.upper() for m in re.findall(r'\b(FN_\w+)\s*\(', t2, re.I)}   # 스키마 없이 호출된 함수
    return obj - NOISE, src


def resolve(seeds, blocks, exclude):
    found = {k: set() for k in C.SRC_FILES}
    sources, edges, missing = set(), [], set()
    queue = list(seeds)
    seen = set()
    while queue:
        name = queue.pop()
        if name in seen or name in exclude:
            continue
        seen.add(name)
        kinds = [k for k in ('TABLE', 'VIEW', 'FUNCTION', 'PROCEDURE') if name in blocks[k]]
        if not kinds:
            missing.add(name)
            continue
        for k in kinds:
            found[k].add(name)
            o, s = refs(blocks[k][name][1])
            sources |= s
            for r in o:
                edges.append((name, r))
                queue.append(r)
        if 'TABLE' in kinds:                                  # ㉡ 적재 프로시저
            pat = re.compile(r'(?:INSERT\s+INTO|MERGE|UPDATE|TRUNCATE\s+TABLE)\s+\[?MART\]?\s*\.\s*\[?'
                             + re.escape(name) + r'\]?\b', re.I)
            for p in (name, name + '_INIT'):
                sp = 'USP_' + p
                if sp in blocks['PROCEDURE'] and pat.search(blocks['PROCEDURE'][sp][1]):
                    edges.append((name, sp))
                    queue.append(sp)
    if found['PROCEDURE']:                                    # ㉣
        for k, ns in HELPERS.items():
            for n in ns:
                if n not in exclude and n in blocks[k]:
                    found[k].add(n)
    return found, sources, edges, missing


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--query')
    ap.add_argument('--seed', nargs='*', default=[])
    ap.add_argument('--exclude', nargs='*', default=[])
    ap.add_argument('--out')
    ap.add_argument('--check-bronze', action='store_true')
    a = ap.parse_args()
    seeds = {s.upper() for s in a.seed}
    if a.query:
        o, _ = refs(io.open(a.query, encoding='utf-8').read().split('[분석엔진')[0])
        seeds |= o
    blocks = C.load_all()
    exclude = {e.upper() for e in a.exclude}
    found, sources, edges, missing = resolve(seeds, blocks, exclude)
    res = {'seeds': sorted(seeds), 'exclude': sorted(exclude),
           'objects': {k: sorted(v) for k, v in found.items()},
           'sources': sorted(sources), 'missing_definitions': sorted(missing),
           'edges': sorted(set(edges))}
    if a.check_bronze:
        cur = C.conn().cursor()
        cur.execute("SELECT TABLE_NAME FROM %s.INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = '%s'"
                    % (C.TARGET_DB, C.SOURCE_SCHEMA))
        have = {r[0].upper() for r in cur.fetchall()}
        res['sources_missing_in_bronze'] = sorted(s for s in sources if s not in have)
    for k, v in res['objects'].items():
        print('%-9s %3d  %s' % (k, len(v), ' '.join(v)))
    print('SOURCES   %3d  %s' % (len(sources), ' '.join(sorted(sources))))
    if 'sources_missing_in_bronze' in res:
        print('BRONZE 부재 %d  %s' % (len(res['sources_missing_in_bronze']), ' '.join(res['sources_missing_in_bronze'])))
    print('정의 없음  %d  %s' % (len(missing), ' '.join(sorted(missing))))
    if a.out:
        io.open(a.out, 'w', encoding='utf-8').write(json.dumps(res, ensure_ascii=False, indent=1))


if __name__ == '__main__':
    main()

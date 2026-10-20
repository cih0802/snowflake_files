# 2단계 — 추출: 매니페스트 대상(+제외 결정의 원본 근거)을 원본 4종에서 UTF-8 로 뽑아 추출 폴더에 저장
#   사용: python3 mstr_extract.py manifests/1차.json [--with-deps]
#         --with-deps = 매니페스트 objects 대신 deps 스냅샷 전체(제외 대상 포함 · 원본 근거 보존용)
import argparse, io, json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mstr_common as C

SEP = '\n\n-- ' + '=' * 70 + '\n\n'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('manifest')
    ap.add_argument('--with-deps', action='store_true')
    a = ap.parse_args()
    m = json.load(io.open(a.manifest, encoding='utf-8'))
    objs = {k: list(v) for k, v in m['objects'].items()}
    extra = [m.get('evidence', {})]
    if a.with_deps:                                           # 매니페스트 ∪ evidence ∪ deps(제외 대상 원본 근거 보존)
        extra.append(json.load(io.open(os.path.join(C.POC, m['deps_snapshot']), encoding='utf-8'))['objects'])
    for src in extra:
        for k, v in src.items():
            objs[k] = objs.get(k, []) + [x for x in v if x not in objs.get(k, [])]
    dst = os.path.join(C.POC, m['extract_dir'])
    blocks = C.load_all()
    rc = 0
    for kind, fname in C.SRC_FILES.items():
        out, miss = [], []
        for n in objs.get(kind, []):
            b = blocks[kind].get(n.upper())
            (out.append(b[1]) if b else miss.append(n))
        io.open(os.path.join(dst, fname), 'w', encoding='utf-8').write(SEP.join(out) + '\n')
        print('%-20s objects %2d  missing %s' % (fname, len(out), miss))
        rc |= bool(miss)
    sys.exit(rc)


if __name__ == '__main__':
    main()

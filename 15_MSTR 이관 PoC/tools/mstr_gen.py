# 3단계 — 생성: 템플릿 + 원본에서 기계 추출해야 하는 데이터(고정코드 VALUES 등)를 주입해 DDL 산출
#   사용: python3 mstr_gen.py manifests/1차.json
#   템플릿 규칙: templates/<batch>_<NN>_<name>.tmpl.sql → snowflake 적용 ddl/<NN>_<name>.sql
#                마커 --@@<KEY>@@ 는 아래 INJECTORS[KEY](blocks) 반환 문자열로 치환. 남은 마커 = 실패
#   --bake <생성본.sql> <KEY>  : 생성본의 주입 구간을 다시 마커로 되돌려 템플릿을 갱신(수정 반영용)
import argparse, glob, io, json, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mstr_common as C


def mart_codes(blocks):
    """USP_D_CMMN_DTL_CD 원문의 MART 고정코드 VALUES → Snowflake VALUES 행(원본 주석 블록 제외)"""
    blk = blocks['PROCEDURE']['USP_D_CMMN_DTL_CD'][1]
    i = blk.index('VALUES')
    vals = re.sub(r'/\*.*?\*/', '', blk[i:blk.index('SET @v_numrows', i)], flags=re.S)
    rows = re.findall(r"\(\s*'([^']*)',\s*'([^']*)',\s*'([^']*)',\s*'([^']*)'\s*,\s*(\d+)\s*,", vals)
    return '\n'.join("    %s('%s', '%s', '%s', '%s', %s)" % (((' ' if k == 0 else ','),) + r)
                     for k, r in enumerate(rows)), len(rows)


INJECTORS = {'MART_CODES': mart_codes}
BAKE_SPAN = {'MART_CODES': (r'(  FROM \(VALUES\n)(.*?)(\n  \) AS V \()', re.S)}


def generate(manifest):
    m = json.load(io.open(manifest, encoding='utf-8'))
    blocks = C.load_all()
    rc = 0
    for t in sorted(glob.glob(os.path.join(C.TEMPLATES, m['batch'] + '_*.tmpl.sql'))):
        name = os.path.basename(t)[len(m['batch']) + 1:].replace('.tmpl.sql', '.sql')
        text = io.open(t, encoding='utf-8').read()
        for key, fn in INJECTORS.items():
            mk = '--@@%s@@' % key
            if mk in text:
                body, n = fn(blocks)
                text = text.replace(mk, body)
                print('  inject', key, n, 'rows ->', name)
        left = re.findall(r'--@@\w+@@', text)
        if left:
            print('FAIL marker left', name, left); rc = 1; continue
        io.open(os.path.join(C.OUT_DDL, name), 'w', encoding='utf-8').write(text)
        print('GEN', name)
    return rc


def bake(generated, key, batch):
    nn = os.path.basename(generated).replace('.sql', '')
    tpl = os.path.join(C.TEMPLATES, '%s_%s.tmpl.sql' % (batch, nn))
    text = io.open(generated, encoding='utf-8').read()
    pat, fl = BAKE_SPAN[key]
    new, n = re.subn(pat, lambda mo: mo.group(1) + '--@@%s@@' % key + mo.group(3), text, count=1, flags=fl)
    if n != 1:
        sys.exit('bake span not found: ' + key)
    io.open(tpl, 'w', encoding='utf-8').write(new)
    print('BAKED', tpl)


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('manifest')
    ap.add_argument('--bake', nargs=2, metavar=('GENERATED_SQL', 'KEY'))
    a = ap.parse_args()
    if a.bake:
        bake(a.bake[0], a.bake[1], json.load(io.open(a.manifest, encoding='utf-8'))['batch'])
    else:
        sys.exit(generate(a.manifest))

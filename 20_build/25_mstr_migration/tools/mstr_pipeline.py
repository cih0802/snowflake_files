# MSTR 이관 파이프라인 — 리포트 쿼리 1개 → Snowflake DDL 6종 · 배포 · 검증 (스킬화 진입점)
#   사용: python3 mstr_pipeline.py manifests/1차.json --steps deps,extract,gen,deploy,run,verify --ym 202601
#   단계: deps    = 의존성 재탐색 → manifests/<batch>_deps.json 갱신 · 매니페스트와 차이 보고(결정은 사람)
#         extract = 원본 근거 추출(매니페스트 ∪ evidence ∪ deps)
#         gen     = 템플릿 → snowflake 적용 ddl/*.sql
#         deploy  = 00~04 배포 + 라이브 대조(--check)
#         run     = USP_RUN_MSTR_<BATCH>(ym, 'POC', I_HIST)
#         verify  = baseline 대조
#   🔴 mutating 단계(deploy·run)는 --apply 가 있어야 실행한다(기본 = 드라이런 표시만)
import argparse, io, json, os, subprocess, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mstr_common as C

T = C.TOOLS
PY = sys.executable


def sh(args):
    print('$', ' '.join(args))
    return subprocess.call(args, cwd=T)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('manifest')
    ap.add_argument('--steps', default='deps,extract,gen,verify')
    ap.add_argument('--ym', default='202601')
    ap.add_argument('--hist', action='store_true')
    ap.add_argument('--apply', action='store_true')
    a = ap.parse_args()
    m = json.load(io.open(a.manifest, encoding='utf-8'))
    for s in a.steps.split(','):
        if s == 'deps':
            rc = sh([PY, 'mstr_deps.py', '--query', os.path.join(C.POC, m['report_query']),
                     '--check-bronze', '--out', os.path.join(C.POC, m['deps_snapshot'])])
            d = json.load(io.open(os.path.join(C.POC, m['deps_snapshot']), encoding='utf-8'))['objects']
            ev = m.get('evidence', {})
            for k, v in d.items():
                new = sorted(set(v) - set(m['objects'].get(k, [])) - set(ev.get(k, [])))
                if new:
                    print('  ⚠ 매니페스트 미결정 %s: %s → objects 또는 evidence(+decisions) 에 등재' % (k, new))
        elif s == 'extract':
            rc = sh([PY, 'mstr_extract.py', a.manifest, '--with-deps'])
        elif s == 'gen':
            rc = sh([PY, 'mstr_gen.py', a.manifest])
        elif s == 'deploy':
            cmd = [PY, 'mstr_deploy.py', a.manifest, '00', '01', '02', '03', '04', '--check']
            rc = sh(cmd) if a.apply else print('  (dry) ' + ' '.join(cmd)) or 0
        elif s == 'run':
            sql = "CALL %s.%s.USP_RUN_MSTR_1ST('%s', 'POC', %s)" % (C.TARGET_DB, C.TARGET_SCHEMA, a.ym,
                                                                   'TRUE' if a.hist else 'FALSE')
            if a.apply:
                cur = C.conn().cursor(); cur.execute(sql); print(' ', cur.fetchone()[0][:300]); rc = 0
            else:
                print('  (dry) ' + sql); rc = 0
        elif s == 'verify':
            rc = sh([PY, 'mstr_verify.py', a.manifest, '--ym', a.ym])
        else:
            sys.exit('unknown step ' + s)
        if rc:
            sys.exit('STOP at %s rc=%s' % (s, rc))
    print('PIPELINE OK', a.steps)


if __name__ == '__main__':
    main()

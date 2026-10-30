"""O272-B 52번 USING 인자 교정(1회용) — 치환 건수를 단언한다."""
import hashlib
P = '/workspace/05_SV-Agent_ai/52_FIX_PROD_MANAGED_ACCESS_OPS_SILVER_ZL50263.sql'
t = open(P, encoding='utf-8').read()
h0 = hashlib.sha256(t.encode()).hexdigest()
DECL = '  n_bak INTEGER; left_cnt INTEGER; left_list VARCHAR; alter_err VARCHAR; err VARCHAR; stmt VARCHAR; tgt VARCHAR;\n'
EXTRA = '  p VARCHAR; o VARCHAR; g VARCHAR;\n'
# [2] 블록 선언(아직 EXTRA 없음) 1건만 보강
assert t.count(DECL + EXTRA) == 1 and t.count(DECL) == 2
i = t.index(DECL)
assert t[i + len(DECL):].startswith('  rs RESULTSET;')
t = t[:i] + DECL + EXTRA + t[i + len(DECL):]
R1 = ("      err := SQLERRM;\n"
      "      EXECUTE IMMEDIATE 'UPDATE ' || bak || ' SET REVOKE_ERR = ? WHERE GRANT_ON = ? AND GRANTEE = ?'\n"
      "        USING (err, r.GRANT_ON, r.GRANTEE);\n")
N1 = ("      err := SQLERRM; o := r.GRANT_ON; g := r.GRANTEE;   -- USING 에는 레코드 필드를 못 넘긴다(TQ68205 001003)\n"
      "      EXECUTE IMMEDIATE 'UPDATE ' || bak || ' SET REVOKE_ERR = ? WHERE GRANT_ON = ? AND GRANTEE = ?'\n"
      "        USING (err, o, g);\n")
R2 = ("      err := SQLERRM;\n"
      "      EXECUTE IMMEDIATE 'UPDATE ' || bak || ' SET REGRANT_ERR = ? WHERE PRIV = ? AND GRANT_ON = ? AND GRANTEE = ?'\n"
      "        USING (err, r.PRIV, r.GRANT_ON, r.GRANTEE);\n")
N2 = ("      err := SQLERRM; p := r.PRIV; o := r.GRANT_ON; g := r.GRANTEE;\n"
      "      EXECUTE IMMEDIATE 'UPDATE ' || bak || ' SET REGRANT_ERR = ? WHERE PRIV = ? AND GRANT_ON = ? AND GRANTEE = ?'\n"
      "        USING (err, p, o, g);\n")
assert t.count(R1) == 2 and t.count(R2) == 2, (t.count(R1), t.count(R2))
t = t.replace(R1, N1).replace(R2, N2)
assert 'r.GRANT_ON, r.GRANTEE)' not in t and t.count(EXTRA) == 2
open(P, 'w', encoding='utf-8').write(t)
print('FIX_OK', h0[:12], '->', hashlib.sha256(t.encode()).hexdigest()[:12], 'lines', t.count('\n'))

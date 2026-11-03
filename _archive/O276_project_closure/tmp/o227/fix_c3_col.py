#!/usr/bin/env python3
"""O227 ③-② C3 GOLD 컬럼 298 — 이슈ID 기계 제거 + 라이브 실측으로 거짓이 된 주장 덮어쓰기.
대상 = tmp/o227/c3_col.tsv(전수조사 4_위반상세 · C3 확정 · GOLD COLUMN).
정본 = 뷰 → 10_dbt_pipeline/models/gold/wide/_wide_schema.yml(👤 dbt build) · 테이블 → 03_top-down_gold/06_DDL.sql(라이브 ALTER).
사용: python3 tmp/o227/fix_c3_col.py [--apply]   · 산출 = tmp/o227/c3_col_diff.md(전후 대조) · 잔여 ID 가 있으면 ABORT.
라이브 실측(xh20001 · 2026-10-14 · O227) = tmp/o227/02_col_evidence.md.
Co-authored with CoCo
"""
import hashlib, io, json, re, sys
import yaml
sys.path.insert(0, '/workspace/scripts')

W = '/workspace/10_dbt_pipeline/models/gold/wide/_wide_schema.yml'
G = '/workspace/03_top-down_gold/06_DDL.sql'
OUT = '/workspace/tmp/o227/c3_col_diff.md'

ID = (r'(?:O\d{1,3}(?:-[A-Z]\d?)?(?:-[A-Z])?|DEC-?\d+(?:-[A-Z])?|P\d{2,3}|Q\d{1,2}|CONF-\d|R2-\d(?:-\d)*'
      r'|AD-\d|HOL-1|G-5|E-[14]|GATE-D|SPB-G|A4-[A-Z]|AC-1|N-24)')
IDL = ID + r'(?:\s*[·,/]\s*' + ID + r')*'

# 라이브 실측으로 거짓이 된 주장 — 문안 전체 대체(뷰.컬럼)
HOL = ('DIM_DATE.IS_HOLIDAY — {p}휴일여부. ⚠️공휴일 원천이 반영돼 TRUE 행이 있다 — '
       '휴일·평일 비교 시 기간마다 휴일 수가 다르므로 일평균으로 비교할 것.')
NB = '🔴값이 없는 행은 NULL 이다 — 0 이나 \'해당없음\' 으로 대체 해석하지 말 것.'
CMP = '⚠️캠페인이 연결되지 않은 행은 {s} — 캠페인별 합계는 전체보다 작다.'
SPN = '⚠️후원사업이 연결되지 않은 행은 {s} — 후원사업별 합계는 전체보다 작다.'
OVR = {
 ('WIDE_AD_BROADCAST', 'PERF_IS_HOLIDAY'): HOL.format(p='실적일 '),
 ('WIDE_AD_DIGITAL', 'PERF_IS_HOLIDAY'): HOL.format(p='실적일 '),
 ('WIDE_AD_PERFORMANCE', 'PERF_IS_HOLIDAY'): HOL.format(p='실적일 '),
 ('WIDE_BIGQUERY_BEHAVIOR', 'IS_HOLIDAY'): HOL.format(p=''),
 ('WIDE_BIGQUERY_BEHAVIOR', 'YEAR'): ('DIM_DATE.YEAR — 년. ⚠️BigQuery 적재 구간이 연도마다 고르지 않을 수 있다 — '
                                      '연도·계절 추이는 연도별 행수를 먼저 확인한 뒤 해석할 것.'),
 ('WIDE_BIGQUERY_BEHAVIOR', 'IDENTITY_MEMNUM'): ('DIM_MEMBER_IDENTITY.MEMNUM — memnum (#111). 🔴🔴 **이 뷰에서 전건 NULL** 이다 — '
                                                 '회원 귀속은 `IDENTITY_SK` 를 `DIM_MEMBER_IDENTITY` 브리지로 풀어야 하며 '
                                                 'unknown 비중을 분모에서 제외할지 먼저 정할 것.'),
 ('WIDE_MEMBER_MONTHLY', 'AMOUNT_BAND1'): '후원금액대1 5만 (#72). ' + NB,
 ('WIDE_MEMBER_MONTHLY', 'AMOUNT_BAND2'): '후원금액대2 1만 (#73). ' + NB,
 ('WIDE_MEMBER_MONTHLY', 'DEV_TYPE'): '개발구분 (#121). ⚠️채움이 일부다 — 개발구분별 비중은 값이 있는 행 기준임을 밝힐 것. ' + NB,
 ('WIDE_MEMBER_MONTHLY', 'INCREASE_FLAG'): '증액여부 (#33).',
 ('WIDE_MEMBER_MONTHLY', 'JOIN_DATE'): '캠페인 가입일 (#27).',
 ('WIDE_MEMBER_MONTHLY', 'NEW_EXISTING_FLAG'): '신규/기존(시점귀속, #113).',
 ('WIDE_MEMBER_MONTHLY', 'NEW_FLAG'): '신규여부 (#32).',
 ('WIDE_MEMBER_MONTHLY', 'PERIOD_BAND1'): '후원기간대1 5년 (#74).',
 ('WIDE_MEMBER_MONTHLY', 'PERIOD_BAND2'): '후원기간대2 1년 (#75).',
 ('WIDE_MEMBER_MONTHLY', 'REDONATE_FLAG'): '재후원여부 (#34).',
 ('WIDE_MEMBER_MONTHLY', 'STOP_DATE'): ('가입캠페인 중단일 (#26). ⚠️값이 있는 행은 일부다. '
                                        '🟢대체 경로 = `MEMBER_LAST_STOP_DATE`(DIM_MEMBER as-of) 또는 WIDE_MEMBER_EVENT.'),
 ('WIDE_MEMBER_MONTHLY', 'CAMPAIGN_BK'): 'DIM_CAMPAIGN.CAMPAIGN_BK — 캠페인 업무키. ' + CMP.format(s="`'(미매핑)'`"),
 ('WIDE_MEMBER_MONTHLY', 'CAMPAIGN_NAME'): 'DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 (#120). ' + CMP.format(s="`'(미매핑)'`"),
 ('WIDE_MEMBER_MONTHLY', 'CAMPAIGN_BRAND'): 'DIM_CAMPAIGN.BRAND — 공통브랜드 (#117). ' + CMP.format(s='NULL'),
 ('WIDE_MEMBER_MONTHLY', 'CAMPAIGN_PARENT'): 'DIM_CAMPAIGN.PARENT_CAMPAIGN — 공통상위캠페인 (#119). ' + CMP.format(s='NULL'),
 ('WIDE_MEMBER_MONTHLY', 'CAMPAIGN_PROMO_METHOD'): 'DIM_CAMPAIGN.PROMO_METHOD — 홍보방법 (#118). ' + CMP.format(s='NULL'),
 ('WIDE_MEMBER_MONTHLY', 'CAMPAIGN_TYPE'): 'DIM_CAMPAIGN.CAMPAIGN_TYPE — 캠페인 유형 (#17). ' + CMP.format(s='NULL'),
 ('WIDE_MEMBER_MONTHLY', 'SPONSORSHIP_ABBR'): ('DIM_SPONSORSHIP.SPONSORSHIP_ABBR — 약칭 (#124). 이 컬럼은 **코드(1~6)** 이고 라벨은 '
                                               'SPONSORSHIP_GROUP_NAME 이다(코드사전 CM003 후원약칭). ' + SPN.format(s='NULL')),
 ('WIDE_MEMBER_MONTHLY', 'SPONSORSHIP_BK'): 'DIM_SPONSORSHIP.SPONSORSHIP_BK — 후원사업 업무키. ' + SPN.format(s="`'(미매핑)'`"),
 ('WIDE_MEMBER_MONTHLY', 'SPONSORSHIP_NAME'): 'DIM_SPONSORSHIP.SPONSORSHIP_NAME — 후원사업 전체 (#123). ' + SPN.format(s="`'(미매핑)'`"),
 ('WIDE_MEMBER_MONTHLY', 'SPONSORSHIP_DIV_NAME'): ('후원사업 분류 **최상위** — 정기일시후원구분 라벨(코드사전 CM035): 정기후원 · 일시후원. '
                                                   '3계층 = DIV_NAME → GROUP_NAME → SPONSORSHIP_NAME. ' + SPN.format(s='NULL')),
 ('WIDE_MEMBER_MONTHLY', 'SPONSORSHIP_GROUP_NAME'): ('후원사업 분류 **중위** — SPONSORSHIP_ABBR(코드)을 코드사전 CM003(후원약칭)으로 해소한 라벨: '
                                                     '국내 · 결연 · 해외구호 · 북한 · 기타 · 해외 · 선물금(미사용). '
                                                     '🔴🔴**이 컬럼 단독으로 「해외」를 집계하지 말 것** — 해외구호와 해외가 갈라지고 해외는 일시후원에서만 나타난다 '
                                                     '⇒ 정확한 분류축은 **(DIV_NAME, GROUP_NAME) 쌍**이다. ' + SPN.format(s='NULL')),
 ('WIDE_MEMBER_EVENT', 'NEW_EXISTING_FLAG'): '신규기존.',
 ('WIDE_EVENT_PARTICIPATION', 'EVENT_BK'): 'DIM_EVENT.EVENT_BK — 행사 업무키. 행사 식별은 팩트 원천키 `PART_EVENT_BK` 를 쓴다.',
 ('WIDE_EVENT_PARTICIPATION', 'EVENT_NAME'): 'DIM_EVENT.EVENT_NAME — 행사명. ⚠️행사 마스터가 없는 행사는 이름이 합쳐질 수 있다 — 식별은 `PART_EVENT_BK` 로 한다.',
}
SEC = ('⚠️일부 행만 캠페인이 연결돼 있고 나머지는 {s} 다 — 캠페인별 합계는 전체보다 훨씬 작으므로 커버리지를 함께 밝힐 것.')
for c, lab, s in [('CAMPAIGN_BK', 'DIM_CAMPAIGN.CAMPAIGN_BK — 캠페인 업무키', "`'(미매핑)'`"),
                  ('CAMPAIGN_NAME', 'DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 (#120)', "`'(미매핑)'`"),
                  ('CAMPAIGN_BRAND', 'DIM_CAMPAIGN.BRAND — 공통브랜드 (#117)', 'NULL'),
                  ('CAMPAIGN_PARENT', 'DIM_CAMPAIGN.PARENT_CAMPAIGN — 공통상위캠페인 (#119)', 'NULL'),
                  ('CAMPAIGN_PROMO_METHOD', 'DIM_CAMPAIGN.PROMO_METHOD — 홍보방법 (#118)', 'NULL')]:
    OVR[('WIDE_SERVICE_EVENT', c)] = lab + '. ' + SEC.format(s=s)


def scrub(t):
    t = re.sub(r'(?:🔴|⚠️)?\s*\(?(?:실측 )?(?:규모|증가율|배율|혼입 규모|미매칭 규모|규모·근거|경위·규모|실측 배율)[^.()]*이슈원장[^.()]*[.)]?', '', t)
    t = re.sub(r'실측 규모는 이슈원장[^.]*\.', '', t)
    t = re.sub(r'\(회원당 버전 수는 이슈원장 참조\)', '', t)
    t = re.sub(r'\(기지 \*\*[^)]*소관\)', '', t)
    t = re.sub(r'\([^()]*(?:정본 = 문서30|처방 = `99_NEXT|전용축 판정 근거)[^()]*\)', '', t)
    t = re.sub(r'(?:정본 = 문서30 §[\w-]+\.?|전용축 판정 근거 = 이슈원장 §\d+\.?)', '', t)
    t = re.sub(r'BigQuery 원천 적재 범위 자체가 좁다\(G-5 하드블로커\)\.', '', t)
    t = re.sub(r'·?\s*문서20 N-24', '', t)
    # 대괄호 태그: ID·날짜를 지우고 남는 낱말이 실측/정정/보강/BRONZE 실측 뿐이면 태그 삭제
    def br(m):
        s = re.sub(r'\d{4}-\d{2}-\d{2}', '', m.group(1))
        s = re.sub(IDL, '', s).strip(' ·')
        return '' if s in ('', '실측', '정정', '보강', 'BRONZE 실측', '사용자 결정', '실측 2026-08-07', 'A안') else '[' + s + ']'
    t = re.sub(r'\[([^\[\]]*' + ID + r'[^\[\]]*)\]', br, t)
    # 괄호: ID 만 지우고 비면 괄호 삭제
    def pr(m):
        s = re.sub(IDL, '', m.group(1))
        s = re.sub(r'^\s*[·,/]\s*|\s*[·,/]\s*$', '', s).strip()
        return '' if s in ('', '교정', '분리', '개명', '이관', '정정', '해소', '처방') else '(' + s + ')'
    t = re.sub(r'\(([^()]*' + ID + r'[^()]*)\)', pr, t)
    t = re.sub(r'\s*·\s*' + IDL + r'(?=[\s.)·]|$)', '', t)
    t = re.sub(IDL + r'\s*(?:이관|교정|정정|보강|규약|계열|소관|판정|처방|하드블로커)?\s*[:·]?\s*', '', t)
    # 문서 좌표 · 경위 서사 잔재
    t = re.sub(r'\(해당 행·왜곡 규모는 문서10 §\d+\)', '', t)
    t = re.sub(r'\s*·?\s*실측값은 문서10 §\d+', '', t)
    t = re.sub(r'유효 커버리지와 파싱 시 회복률은 문서10 §\d+\.', '유효 커버리지가 낮다(파싱하면 대부분 회복).', t)
    t = re.sub(r'문서20 §\w+ 현업 확인 · ', '현업 확인 대상 · ', t)
    t = re.sub(r'\s*·?\s*(?:문서20 §[\w-]+|이슈원장 §[\w-]*)', '', t)
    t = re.sub(r'\s*—\s*도달률 실측은\s*\.', '.', t)
    t = re.sub(r'\(배수 실측 =\s*\)', '', t)
    t = re.sub(r'⚠️\(\d{4}-\d{2}-\d{2}\):\s*', '⚠️', t)
    t = re.sub(r'\s*·\s*\d{4}-\d{2}-\d{2} 판정', '', t)
    t = re.sub(r'\(\s*(?:도포본|오버레이가 여러 컬럼에 같은 문안을 도포한 결과)[^()]*\)', '', t)
    t = re.sub(r'\*\*\(코드그룹 미특정\)가 해소됐다\*\*', '**코드그룹이 특정됐다**', t)
    t = re.sub(r'🆕', '', t)
    t = re.sub(r'\(\s*``\s*\)|\s*·\s*``|``', '', t)
    t = re.sub(r'\s*·\s*계열\)', ')', t)
    t = re.sub(r'\(소관\s*·\s*⚠️\s*종전 문안의\s*병기는\s*가 철회했다 — 광고비는 원천 부재가 아니다\)', '', t)
    t = re.sub(r"⚠️종전 문안의 \*'코드그룹 미특정 · 6개 그룹이 전부 의미 무관'\* 은 이 실측으로 폐기한다\.?", '', t)
    t = re.sub(r'\(\s*소관\s*\)', '', t)
    t = re.sub(r'🔴🔴 종전 문안의 \*「[^」]*」\* 는 \*\*이 컬럼에 대해 거짓이었다\*\*\.\s*', '', t)
    t = re.sub(r'⚠️ ?종전 문안의 \*?「[^」]*」\*?는 \*?\*?거짓이었다\*?\*?(?:\([^()]*\))?\.?', '', t)
    t = re.sub(r'\*\*\s*\*\*', '', t)
    t = re.sub(r'\(\s*\)', '', t)
    t = re.sub(r'\s{2,}', ' ', t).replace(' .', '.').replace('..', '.').strip()
    return t


rows = [l.rstrip('\n').split('\t') for l in io.open('/workspace/tmp/o227/c3_col.tsv', encoding='utf-8')]
apply = '--apply' in sys.argv
for p in (W, G):
    a, b = (hashlib.sha256(open(p, 'rb').read()).hexdigest() for _ in range(2))
    assert a == b, 'hash unstable ' + p
WL = io.open(W, encoding='utf-8').read().split('\n')
GL = io.open(G, encoding='utf-8').read().split('\n')
# 뷰 모델 시작줄
mstart = {s[len('  - name: '):]: i for i, s in enumerate(WL) if s.startswith('  - name: ')}
mbound = sorted(mstart.values()) + [len(WL)]
# 테이블 시작줄(06_DDL)
tstart = {}
for i, s in enumerate(GL):
    m = re.match(r'CREATE OR REPLACE (?:TRANSIENT )?TABLE GN_DW\.GOLD\.(\w+)', s)
    if m:
        tstart[m.group(1)] = i
diff, resid, live = [], [], []
for obj, col, ev, _ in rows:
    if obj.startswith('WIDE_'):
        i0 = mstart[obj]; i1 = next(b for b in mbound if b > i0)
        k = next(k for k in range(i0, i1) if WL[k].strip() == '- name: ' + col)
        j = next(j for j in range(k + 1, k + 4) if WL[j].lstrip().startswith('description:'))
        old = yaml.safe_load(WL[j].strip())['description']
        new = OVR.get((obj, col)) or scrub(old)
        ind = WL[j][:len(WL[j]) - len(WL[j].lstrip())]
        WL[j] = ind + 'description: ' + json.dumps(new, ensure_ascii=False)
        assert yaml.safe_load(WL[j].strip())['description'] == new
    else:
        i0 = tstart[obj]
        k = next(k for k in range(i0, i0 + 400) if re.match(r'\s+' + col + r'\s', GL[k]))
        m = re.search(r"COMMENT '((?:[^']|'')*)'", GL[k])
        old = m.group(1).replace("''", "'")
        new = OVR.get((obj, col)) or scrub(old)
        GL[k] = GL[k][:m.start(1)] + new.replace("'", "''") + GL[k][m.end(1):]
        live.append((obj, col, new))
    left = sorted(set(re.findall(r'\b' + ID + r'\b', new)))
    if left:
        resid.append(f'{obj}.{col} {left}')
    diff.append(f'### {obj}.{col} {"(덮어쓰기)" if (obj, col) in OVR else ""}\n- 전: {old}\n- 후: {new}\n')
io.open(OUT, 'w', encoding='utf-8').write('# O227 C3 컬럼 전후 대조\n\n' + '\n'.join(diff) + '\n_Co-authored with CoCo_\n')
print('대상', len(rows), '· 덮어쓰기', sum((o, c) in OVR for o, c, _, _ in rows), '· 잔여ID', len(resid))
for r in resid:
    print('  잔여', r)
if resid:
    sys.exit('🔴 ABORT — 잔여 ID')
if apply:
    io.open(W, 'w', encoding='utf-8').write('\n'.join(WL))
    io.open(G, 'w', encoding='utf-8').write('\n'.join(GL))
    yaml.safe_load(open(W))
    from sfconn import conn
    cur = conn().cursor()
    for obj, col, new in live:
        cur.execute(f"ALTER TABLE GN_DW.GOLD.{obj} MODIFY COLUMN {col} COMMENT '" + new.replace("'", "''") + "'")
    print('APPLIED · 라이브 ALTER', len(live))
else:
    print('DRY-RUN')

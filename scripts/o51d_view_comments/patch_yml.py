# -*- coding: utf-8 -*-
"""[2026-08-07 O51-D] 생성된 columns 블록을 schema.yml 에 반영한다."""
import io, re, sys

WYML = '/workspace/10_dbt_pipeline/models/gold/wide/_wide_schema.yml'
GYML = '/workspace/10_dbt_pipeline/models/gold/_gold_ready_schema.yml'
OUT  = '/tmp/o51d_out/%s.cols.yml'

def load(t): return io.open(OUT % t, encoding='utf-8').read().rstrip('\n')

def split_models(txt):
    """헤더 + [(model, body)] 로 분해. body 는 '  - name: X' 다음 줄부터."""
    idx = [m.start() for m in re.finditer(r'(?m)^  - name: (\w+)\s*$', txt)]
    head = txt[:idx[0]]
    parts = []
    for i, s in enumerate(idx):
        e = idx[i+1] if i+1 < len(idx) else len(txt)
        blk = txt[s:e]
        name = re.match(r'  - name: (\w+)', blk).group(1)
        parts.append([name, blk])
    return head, parts

def drop_columns(blk):
    """블록에서 기존 columns: 서브블록(및 그 앞의 O51-C 경고 주석)을 제거."""
    lines = blk.split('\n')
    out, i = [], 0
    while i < len(lines):
        if re.match(r'^    columns:\s*$', lines[i]):
            i += 1
            while i < len(lines) and (lines[i].startswith('      ') or lines[i].strip()=='' ):
                i += 1
            continue
        out.append(lines[i]); i += 1
    return '\n'.join(out)

# ── ① _wide_schema.yml ────────────────────────────────────────────────────
txt = io.open(WYML, encoding='utf-8').read()
head, parts = split_models(txt)

WIDE = ['WIDE_MEMBER_MONTHLY','WIDE_MEMBER_EVENT','WIDE_SERVICE_EVENT',
        'WIDE_EVENT_PARTICIPATION','WIDE_MEMBER_FEE','WIDE_DEV_ACHIEVEMENT']

FEE_NOTE = (
"    # ✅ [2026-08-07 O51-D] 39/39 컬럼 문안 완성 — materialized='gn_view_commented' 전환 완료.\n"
"    #   경위: 이 뷰의 문안은 `10_WIDE VIEW 코멘트.sql`(13/16뷰)에 **없었고** post_hook 에만 있었으며\n"
"    #   그 post_hook 자신도 17/39(44%) 만 덮고 있었다 — 「post_hook 이 완전하다」는 O50 의 전제가 여기서도 거짓이었다.\n"
"    #   잔여 22컬럼은 O51-D 에서 **BRONZE 코드사전 × 실적재 distinct 전수 재스캔**을 근거로 신규 작성했다.\n"
"    #   🟢 부수 성과 — PAYMENT_METHOD_NAME·SETLE_CD 문안이 지목했던 **O45-B(결제수단 코드그룹 미특정)가 해소**됐다.\n"
"    #      SETLE_CD 실측 11종이 PM040(결제정보) 사전에 11/11 존재한다 ⇒ 미매핑 원인은 코드 미상이 아니라\n"
"    #      DIM_PAYMENT 를 결제수단 마스터(TM_PM_SETLE_INFO) distinct 로 만든 것이다(재배선은 별건).\n")

O51D_NOTE = (
"    # ✅ [2026-08-07 O51-D] 컬럼 문안 전량 등재 · ORDINAL_POSITION 순서로 기계 생성(손 이관 금지).\n"
"    #   ⚠️ Snowflake 제약: CREATE VIEW 컬럼목록은 SELECT 의 전 컬럼과 **개수·순서가 정확히 일치**해야 한다.\n"
"    #      모델 SELECT 순서를 바꾸면 이 블록도 동시에 재생성할 것(scripts 없이 손으로 고치지 말 것).\n"
"    #   문안 출처 = ① `03_top-down_gold/10_WIDE VIEW 코멘트.sql` 이관 ② O51-D BRONZE 전수 재스캔 신규.\n"
"    #   🔴 `10_` 의 컬럼명 20건은 O26 리네임 미반영 유령이라 폐기했다(MEMBER_GENDER→MEMBER_GENDER_NAME 등).\n")

new = [head]
for name, blk in parts:
    if name in WIDE:
        blk = drop_columns(blk).rstrip('\n') + '\n'
        blk += (FEE_NOTE if name == 'WIDE_MEMBER_FEE' else O51D_NOTE)
        blk += load(name) + '\n'
    new.append(blk)
res = ''.join(new)

# 헤더의 stale 기술 정정
res = res.replace(
"# 🔴 [2026-08-07 O50] GOLD dbt 뷰는 이 폴더에만 있지 않다 — 전량 **16개**다.",
"# 🔴 [2026-08-07 O50 · O51-D 갱신] GOLD dbt 뷰는 이 폴더에만 있지 않다 — 전량 **16개**다.")
res = res.replace(
"#   ⚠️ 이 2종은 어느 schema.yml 에도 `- name:` 등재가 없어 dbt 문서·테스트 커버리지가 0 이다(O50 잔여).",
"#   ✅ [O51-D] 이 2종을 `_gold_ready_schema.yml` 에 `- name:` 등재하고 columns[] 45개를 부여했다(O50 잔여 해소).")
io.open(WYML,'w',encoding='utf-8').write(res)
print(f"✅ _wide_schema.yml {len(res):,}B")

# ── ② _gold_ready_schema.yml — DIM 2종 신규 등재 ──────────────────────────
g = io.open(GYML, encoding='utf-8').read()
if '- name: DIM_MEMBER_CURRENT' in g:
    sys.exit("이미 등재됨 — 중복 방지 위해 중단")

DIMS = (
"  # ── [2026-08-07 O51-D 신규 등재] materialized='view' 오버라이드로 dim/ 에 있는 GOLD 뷰 2종.\n"
"  #   O50 이 「어느 schema.yml 에도 등재 없음 → dbt 문서·테스트 커버리지 0」으로 적발했던 잔여를 해소한다.\n"
"  #   ⚠️ 두 모델은 `materialized='gn_view_commented'` 이므로 columns[] 는 **SELECT 전 컬럼·순서 일치**가 필수다.\n"
"  - name: DIM_MEMBER_CURRENT\n"
"    description: \"🟢 GOLD 직접조회 분석가의 기본 진입점 — 회원 1명 = 1행. DIM_MEMBER 는 SCD2(평균 4.50버전·최대 218)이므로 "
"FACT 와 MEMBER_DK 직접 조인 시 팬아웃한다(실측 202606 단월 3.60배 · 납입회비 2.96배 과대). 과거 시점 상태가 필요할 때만 DIM_MEMBER 를 "
"EFFECTIVE_FROM/EFFECTIVE_TO 로 시점조인할 것 — 예측·피처 생성은 이 시점조인이 정답이며 현재값을 과거 행에 붙이면 정답 누설이다. "
"🔴 상태 기반 분포·이탈률·예측 모집단은 MEMBER_TYPE='FDRM' 으로 한정할 것(일시회원 ONCE 는 회원상태·가입경로 개념이 원천에 없다). "
"본 뷰는 DIM_MEMBER 의 순수 투영이며 라벨 정의는 DIM_MEMBER.sql 단일 소유. 전건 NULL 7컬럼은 오답 방지를 위해 미노출(문서30 DEC-27 §17-C). "
"⚠️SERVING.DIM_MEMBER_CURRENT 와 동명이나 컬럼 집합이 다르다.\"\n"
+ load('DIM_MEMBER_CURRENT') + "\n"
"  - name: DIM_MEMBER_ACQUISITION\n"
"    description: \"회원 획득(가입) 귀속 차원 — 1행=1회원. base=FACT_MEMBER_COHORT(단일 정의 지점·저장 중복 0). "
"🔴모든 ACQ_* 는 **획득 시점** 값이며 현재 속성이 아니다(현재 연령·현주소는 BRONZE 에 축이 없어 산출 불가·O34). "
"🔴「부서」·「후원사업」은 같은 라벨로 두 축이 존재한다 — 사건 부서=FACT_MEMBER_EVENT.ORG_SK · 납입 대상 후원사업=FACT_MEMBER_FEE.SPONSORSHIP_SK. "
"🔴팩트와는 반드시 LEFT JOIN — 개발 사건이 없는 회원이 사라진다(FMM 미매칭 1.61%). "
"신설 경위(O45): FMM 의 CAMPAIGN_SK·SPONSORSHIP_SK 가 전건 센티넬인 것은 원천 부재가 아니라 다중캠페인 후원(7.98%·회원-월 최대 60개)의 "
"귀속 규칙이 없어서였고, 임의 귀속 대신 「획득 시점」이라는 명시된 규칙을 채택했다(O8 우회).\"\n"
+ load('DIM_MEMBER_ACQUISITION') + "\n"
)
# DIM_SEND_TYPE 블록 앞(마지막 DIM 군집 뒤)에 붙이지 않고 파일 끝에 추가한다.
g = g.rstrip('\n') + '\n' + DIMS
io.open(GYML,'w',encoding='utf-8').write(g)
print(f"✅ _gold_ready_schema.yml {len(g):,}B")

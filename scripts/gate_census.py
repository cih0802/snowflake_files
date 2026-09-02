# -*- coding: utf-8 -*-
"""[2026-08-30 O121-B] **게이트 분모 게이트** — 「이번 세션이 돌려야 하는 게이트」를 기계로 확정한다.

🔴🔴 왜 필요한가(실측 경위 · **5세션 연속 같은 축에서 결함**):
   O118-B → O119 → O119-B → O120 → **O121** 이 전부 「게이트 목록의 분모」에서 결함을 냈다.
   · O118-B = SV 전용 게이트 3종을 하나도 안 돌렸다.
   · O119   = 인수인계의 「SV 게이트 3종」이 실제 4종이었다 ⇒ 「`ls scripts/` 로 다시 세라」를 신설.
   · O119-B = 그 판정식을 신설하고 **스스로 어겼다**(미실행 2종).
   · O120   = 목록을 14종으로 발행했으나 실제 16종이었고 종료코드도 파이프의 것이었다.
   · O121   = 도메인 게이트를 **손으로 8종 골라** 「전건 rc=0」이라고 보고했다.
   ⇒ 🔴 **「`ls scripts/` 로 세라」는 사람에게 맡기면 5번 실패한 지시다.** 그래서 기계화한다.

🔴🔴 **왜 「내용 휴리스틱」이 답이 아닌가 — O121-B 초판이 그것으로 실패했다.**
   초판은 `CREATE OR REPLACE`·`GRANT` 같은 토큰이 있으면 「라이브를 바꾼다」로 분류했다.
   🔴 그 결과 **`audit_ddl_rule7`·`sv_unit_gate`·`table_ddl_column_gate` 를 「실행 금지」로 오분류**했다 —
   이들은 **DDL 파일을 입력으로 읽는 판정 게이트**다(실측 = `execute(` 호출은 읽기뿐).
   ⇒ 그대로 두면 이 도구가 **분모를 반대 방향으로 깨뜨렸을 것이다**(3종을 빼라고 지시).
   🟢 **그래서 휴리스틱을 버리고 `doc_type_gate` 의 검증된 패턴을 쓴다 = 명시 등재 + 미분류 FAIL.**
   새 스크립트를 추가하면 이 게이트가 **막는다** — 등재를 강제하는 것이 목적이고, 추측이 아니다.

🔴🔴 **왜 「전부 무인자로 돌려보기」가 답이 아닌가:**
   `scripts/` 에는 라이브·파일을 바꾸는 스크립트가 섞여 있다(`deploy_*`·`retire_*`·`split_doc`·`patch_*`).
   무인자 일괄 실행은 **DDL 실행·문서 재작성**을 부를 수 있다(`R4-4-3`).
   ⇒ `--run` 은 **`JUDGE` 로 등재된 것만** 실행한다.

분류 6종
  · `JUDGE`      — 무인자로 **위반 0/1 판정**을 낸다. **이것이 「돌려야 하는 게이트」의 분모다.**
  · `OBSERVE`    — 무인자 실행은 안전하지만 **판정이 아니다.**
    🔴 그 출력 수치를 위반 건수로 인용하지 마라(O120 이 `sv_dim_cardinality` 로 그렇게 오단정했다).
  · `TEST`       — `test_*.py` 음성 테스트. `--run-tests` 로 함께 순회한다.
  · `NEEDS_ARGS` — 필수 인자가 있다. ⚠️ **무인자 크래시를 FAIL 로 세지 마라**(O120 판정식 ㉢ · 규약 exit 2).
  · `GEN`        — 생성기(`--write` 계열). 무인자는 출력만 하지만 분모에서 분리해 둔다.
  · `MUTATES`    — 🔴🔴 **실행 금지.** 라이브 DDL/DML 또는 다중 파일 재작성(`R4-4-3` 승인 대상).

종료코드 = 0 통과 · 1 위반(미분류 존재 또는 `--run` 에서 rc≠0) · 2 사용법 오류.
🔴 `--run` 의 rc 는 **개별 프로세스에서 파이프 없이** 받은 값이다(O120 판정식 ㉠).
"""
import sys
import os
import glob
import argparse
import subprocess

ROOT = '/workspace'
SCRIPTS = os.path.join(ROOT, 'scripts')

# 🔴 등재는 「이름 → 축」이다. 축을 적지 않으면 다음 세션이 무엇을 재는지 모른다.
JUDGE = {
    'agent_object_ref_gate':  'Agent 스펙 본문의 DB·스키마·객체명이 라이브에 실재하는가',
    'agent_tool_claim_gate':  'Agent 도구 주장 모순 + 스펙 description 규칙7 수치',
    'audit_ddl_rule7':        'DDL COMMENT 규칙7(실측 수치 금지) — DDL 파일을 **읽는다**',
    'clause_order_gate':      '조문 번호 역전·중복',
    'comment_drift_gate':     '파일 정본 ↔ 라이브 COMMENT 드리프트 + 금지 문안',
    'dbt_schema_lint':        'dbt schema yml 정합',
    'decision_closure_gate':  '내 결정을 인용한 정본이 stale 인가(경고 전용)',
    'doc_census':             '문서 조각 수·바이트 stale + 분할 분모 대조',
    'doc_coord_gate':         '인용 좌표 실재(`R1-6-22`)',
    'doc_heading_gate':       '제목 유실',
    'doc_line_length_gate':   '정본 한 줄 2000자',
    'doc_type_gate':          '문서 유형 미선언·상한 초과·여유 부족',
    'eval_expectation_gate':  '평가셋 기대값',
    'gate_census':            '이 파일 — 게이트 분모 미분류',
    # 🆕 [2026-08-31 O126] GOLD ERD 의 FK 커버리지 — 라이브를 **읽을 뿐** 바꾸지 않는다 ⇒ JUDGE.
    #   🔴 판정식이 「고립 0」이 아니라 **「미분류 고립 0」**이다(degen key 는 고립이 정상).
    #   🔴 `gen_gold_erd` 가 이 게이트를 import 해 `LOGICAL_FK` 를 읽는다 ⇒ 규칙 정본은 여기 1곳뿐이다.
    'gold_erd_coverage_gate':  'GOLD ERD FK 3소스 커버리지 — FACT 키 컬럼 중 **미분류 고립** '
                               '(dbt relationships·물리 FK 어디에도 없는 축)을 blocking 으로 강제',
    'handoff_ddl_gate':       '인수인계 DDL 주장',
    'id_collision_gate':      'ID 중복(`DEC`·`P`·`O`·`Q`)',
    'index_row_gate':         '원장 표 행 키 유실·중복',
    'merge_check':            '임시파일 내용이 정본에 반영됐는가(삭제 안전 판정)',
    'o125_layer_census':      'SILVER·GOLD·SERVING 설계 정본 ↔ 라이브 객체·컬럼 집합 — 라이브를 **읽는다**',
    'sv_code_label_gate':     'SV 코드값·라벨 열거',
    'sv_identifier_gate':     'SV 식별자 실재(`DESCRIBE SEMANTIC VIEW` 대조)',
    'sv_rule7_scan':          'SV DDL 규칙7',
    'sv_unit_gate':           'SV COMMENT 단위·수치 — 라이브를 **읽는다**',
    'table_ddl_column_gate':  'DDL 파일 ↔ 모델 컬럼 순서 — 라이브를 **읽는다**',
    'wide_select_yml_gate':   'WIDE 뷰 SELECT ↔ yml',
}

OBSERVE = {
    'alias_census':        '모델 SELECT 별칭 P/L/X 관측 — 🔴 판정 분모 정본은 `scripts/o122_name_drift.sql`(라이브) 이다',
    'classify_doc_type':   '문서 유형 추천(등재 정본은 원장 §0)',
    'comment_len_probe':   'COMMENT 길이 분포 관측',
    'cortex_analyst_30_exec': 'Cortex Analyst 생성 SQL 라이브 실행 검증 러너',
    'cortex_analyst_30_runner': 'Cortex Analyst 30개 추천 질문 자연어 질의 러너',
    'o123_member_dk_footprint': '컬럼명 소비처 footprint 관측(축 분리 = archive/현행/코드/문서) — 🔴 판정이 아니다 · 개명 전 grep 범위 산정용',
    'sv_dim_cardinality':  '차원 카디널리티 관측 — 🔴 판정 정본은 `sv_code_label_gate` 다',
    'wrap_for_read':       '긴 줄 접기 보조',
    '_o128_dim_probe':     'DIM 키 컬럼 고립 관측',
    '_o128_probe':         '관계선 관측',
    '_o128_rel_violations':'relationships 위반 관측',
    '_o130_ga4_rename':    'GA4 명칭 변경 관측',
}

NEEDS_ARGS = {
    'line_len':          '검사할 경로(필수)',
    'o54_sv_value_gate': '비교 대상 2개(무인자는 사용법 + exit 2 · O120 시정)',
    'ws_stage_verify':   '파일목록 또는 `--o53`(무인자는 사용법 + exit 2 · **O121-B 시정**)',
}

GEN = {
    'gen_arch_map': '아키텍처 지도', 'gen_bronze_exposure_audit': 'BRONZE 노출 감사',
    'gen_code_system_gates': '코드체계 게이트', 'gen_column_inventory_20260811': '컬럼 인벤토리',
        'gen_concept_diagram':  '개념도',
    'gen_gold_erd':         'GOLD 테이블별 ERD(HTML · Mermaid) — dbt yml + INFORMATION_SCHEMA · `--yaml-only` 로 라이브 없이도 돈다',
    'gen_pipeline_erd':     'Bronze > Silver > Gold 전체 파이프라인 ERD & 계보 카탈로그(HTML · Mermaid)',
    'gen_measure_backlog': '실측필요 후속작업',
    'gen_metric_gold_mapping': '지표↔GOLD 매핑', 'gen_section_assembly': '절 조립',
    'gen_silver_gold_retention': 'SILVER·GOLD 보존', 'session_brief': '착수 브리핑(`00_BRIEF.md`)',
    # 🆕 [2026-08-30 O123-C] MUTATES 오분류 2건을 GEN 으로 이동했다 — O121-B 가 고친 것과 **같은 유형**이다
    #   (「DDL 문자열을 **입력으로 읽는**」 도구를 「DDL 을 **발행하는**」 도구로 오분류).
    #   · gen_column_mapping  = 라이브 접속 참조 **0** · `.execute` **0** — `ALTER VIEW` 는
    #       dbt 모델 `post_hook` 에서 컬럼 COMMENT 를 **파싱하는 대상 문자열**이다(같은 파일 143행 docstring).
    #   · run_bronze_audit_host = DDL/DML 키워드 **0** · `SELECT`/`INFORMATION_SCHEMA` 조회만 + 파일 기록.
    #   🔴 오분류의 실해 = 「실행 금지」로 표시돼 **30_output_share 정본 산출물 04·06 을 재생성할 수 없었다.**
    'gen_column_mapping': '컬럼계보매핑 04 — 🔴 라이브 접속 0(모델 파싱 전용)',
    'run_bronze_audit_host': 'BRONZE 노출감사 06 **정본 러너** — 조회 전용(무인자 = 직접조회)',
    # 🆕 [2026-08-30 O124] 손으로 쓴 산출물 `미해결이슈_요약_O102.md` 를 생성기로 대체했다.
    #   근거 = 그 판본이 2행 stale 이었고 파일명에 세션 라벨이 박혀 판본이 늘어났다.
    'gen_unresolved_issue_summary': '미해결이슈 요약 11 — 정본 추출 전용(라이브 접속 0)',
}

MUTATES = {
    'apply_table_comment_drift': '라이브 COMMENT 반영',
    'apply_silver_comment_drift': 'SILVER 라이브 COMMENT 반영',
    'deploy_ml_semantic_views': 'SV 배포', 'deploy_ml_serving_views': 'SERVING 뷰 배포',
    'deploy_sv': 'SV 배포', 'extract_sv_deploy': '배포 SQL 추출·실행',
    'fix_stale_counts': '문서 다중 치환',
    'gen_o53_ad_combined': 'CREATE OR REPLACE', 'gen_o53_gold_ddl': 'CREATE OR REPLACE',
    'move_o63_history_entry': '이력 이동', 'o54_sv_header_patch': 'SV 헤더 패치',
    'o54_sv_note_patch': 'SV 주석 패치', 'o59d_snapshot': 'GRANT 포함 스냅샷',
    'patch_o63_wide_yml': 'yml 패치', 'patch_o63f_label_null_reason': 'COMMENT 패치',
    'patch_o63k_view_mislabel': '뷰 라벨 패치', 'patch_o64_wide_fee_lineage': '계보 패치',
    'patch_sv_enum_comments': 'SV 열거 패치', 'polish_sv_enum_comments': 'SV 열거 정리',
    'retire_rows': '원장 행 은퇴(다중 파일)', 'retire_sections': '절 본문 은퇴(다중 파일)',
    'run_o53_new_tables': '테이블 생성',
    'split_doc': '허브·조각 재작성', 'split_issue_index': '원장 분할',
    'split_narrative': '사례집 이관',
}

LIB = {
    'add_column_comments': '', 'add_gold_comments': '', 'census_columns': '',
    'dump_schema': '', 'field_mapping_override': '', 'o59g_paren_scan': '',
    'o59l_rule7_context': '', 'o70_stale_scan': '', 'rebuild_inventory': '',
    'run_gold_ddl': '', 'sfconn': '접속 헬퍼', 'snapshot_util': '스냅샷 단일 경유점',
}

BUCKETS = [('JUDGE', JUDGE), ('OBSERVE', OBSERVE), ('NEEDS_ARGS', NEEDS_ARGS),
           ('GEN', GEN), ('MUTATES', MUTATES), ('LIB', LIB)]


def inventory():
    """분모는 `ls scripts/*.py` 실측이다 — 문서나 이 파일의 등재표가 아니다."""
    return sorted(os.path.basename(p)[:-3]
                  for p in glob.glob(os.path.join(SCRIPTS, '*.py')))


def _rc(name, timeout):
    """개별 프로세스로 실행해 **종료코드만** 받는다 — 🔴 파이프를 경유하지 않는다."""
    p = os.path.join(SCRIPTS, name + '.py')
    try:
        return subprocess.run([sys.executable, p], cwd=ROOT, timeout=timeout,
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                              stdin=subprocess.DEVNULL).returncode
    except subprocess.TimeoutExpired:
        return 'TIMEOUT'


def audit():
    names = inventory()
    tests = [n for n in names if n.startswith('test_')]
    known, dup = {}, []
    for label, d in BUCKETS:
        for n in d:
            if n in known:
                dup.append((n, known[n], label))
            known[n] = label
    unclassified = [n for n in names if n not in known and not n.startswith('test_')]
    ghost = [n for n in known if n not in names]
    return names, tests, known, unclassified, ghost, dup


def main():
    ap = argparse.ArgumentParser(
        description='「돌려야 하는 게이트」의 분모를 명시 등재로 확정한다(미분류는 FAIL).')
    ap.add_argument('--run', action='store_true', help='JUDGE 만 개별 실행해 종료코드 표를 낸다.')
    ap.add_argument('--run-tests', action='store_true', help='TEST 도 함께 실행한다.')
    ap.add_argument('--timeout', type=int, default=300)
    try:
        a = ap.parse_args()
    except SystemExit:
        return 2

    names, tests, known, unclassified, ghost, dup = audit()
    print('=' * 72)
    print('게이트 분모 게이트 — 분모 = `ls scripts/*.py` 실측 **%d개**' % len(names))
    print('=' * 72)
    print('🔴 이 표가 정본이다 — 게이트 목록을 문서에서 읽거나 손으로 고르지 마라(5세션 연속 결함 축).')
    for label, d in BUCKETS:
        live = sorted(n for n in d if n in names)
        print('-' * 72)
        print('[%s] %d개' % (label, len(live)))
        if label == 'MUTATES':
            print('  🔴🔴 **실행 금지** — 라이브 DDL/DML 또는 다중 파일 재작성(`R4-4-3`).')
        if label == 'NEEDS_ARGS':
            print('  ⚠️ 무인자 크래시를 FAIL 로 세지 마라(O120 판정식 ㉢ · 규약 exit 2).')
        if label == 'OBSERVE':
            print('  🔴 판정이 아니다 — 이 출력의 수치를 위반 건수로 인용하지 마라.')
        for n in live:
            print('    · %-28s %s' % (n, d[n]))
    print('-' * 72)
    print('[TEST] %d개 — `--run-tests` 로 순회' % len(tests))

    fail = []
    print('=' * 72)
    print('불변식')
    print('  미분류 %d건 · 등재됐으나 파일 부재(유령) %d건 · 중복 등재 %d건'
          % (len(unclassified), len(ghost), len(dup)))
    if unclassified:
        fail.append('미분류 %d건' % len(unclassified))
        for n in unclassified:
            print('    🔴 미분류: %s — 이 파일의 6분류 중 하나에 **축과 함께** 등재하라' % n)
    if ghost:
        fail.append('유령 등재 %d건' % len(ghost))
        for n in sorted(ghost):
            print('    🟠 유령 등재(파일 부재): %s — 등재를 지워라' % n)
    if dup:
        fail.append('중복 등재 %d건' % len(dup))
        for n, x, y in dup:
            print('    🔴 중복 등재: %s (%s ↔ %s)' % (n, x, y))

    if a.run or a.run_tests:
        targets = sorted(n for n in JUDGE if n in names) if a.run else []
        if a.run_tests:
            targets += tests
        print('=' * 72)
        print('개별 실행 — 대상 %d개 · 🔴 파이프 없이 종료코드 수신' % len(targets))
        print('=' * 72)
        bad = []
        for n in targets:
            r = _rc(n, a.timeout)
            print('  %s %-28s rc=%s' % ('🟢' if r == 0 else '🔴', n, r))
            if r != 0:
                bad.append((n, r))
        print('-' * 72)
        if bad:
            fail.append('실행 rc≠0 %d건' % len(bad))
            print('🔴 rc≠0 = %d건' % len(bad))
        else:
            print('🟢 대상 전건 rc=0')

        # 🔴🔴 [O121-B 신설 축] 「사용법 출력은 exit 2」 규약을 **집행**한다.
        #    실사고 = `ws_stage_verify` 가 무인자에서 `sys.exit(__doc__)`(=rc 1)를 냈고,
        #    O121 의 게이트 순회가 그것을 **위반 1건으로 거짓 계상**했다.
        #    🔴 스크립트 하나를 고치는 것으로는 재발한다 — 규약을 축으로 만든다.
        #    🟢 `NEEDS_ARGS` 는 정의상 무인자 실행이 사용법만 내므로 실행이 안전하다.
        print('=' * 72)
        print('종료코드 규약 축 — `NEEDS_ARGS` 무인자 실행은 **rc=2** 여야 한다')
        print('=' * 72)
        wrong = []
        for n in sorted(x for x in NEEDS_ARGS if x in names):
            r = _rc(n, a.timeout)
            ok = (r == 2)
            print('  %s %-28s rc=%s%s' % ('🟢' if ok else '🔴', n, r,
                                          '' if ok else '  ← 사용법인데 위반 코드를 낸다'))
            if not ok:
                wrong.append((n, r))
        if wrong:
            fail.append('사용법 exit 2 위반 %d건' % len(wrong))
            print('🔴 규약 위반 %d건 — `print(__doc__); sys.exit(2)` 로 고쳐라' % len(wrong))
        else:
            print('🟢 규약 준수 — 사용법은 전건 rc=2 (위반 1 과 구별된다)')

    print('=' * 72)
    if fail:
        print('🔴 FAIL — ' + ' · '.join(fail))
        return 1
    print('🟢 PASS — 미분류 0 · 유령 0 · 중복 0')
    return 0


if __name__ == '__main__':
    sys.exit(main())

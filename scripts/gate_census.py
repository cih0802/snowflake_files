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
    # 🆕 [2026-09-10 O155 신설] 개명된 객체의 **옛 이름 잔여**(기준선 대비 증가) —
    #   🔴 기존 게이트 어디에도 이 축이 없었다: `comment_drift_gate` 는 파일↔라이브 **일치**만
    #   보므로 **둘이 똑같이 틀리면 🟢**(실물 = `SV_MEMBER_EVENT` COMMENT 가 라이브에 없는
    #   `GOLD.FACT_MEMBER_EVENT` 를 가리켰다). 그래서 O154-B 가 5파일 분모로 「0건」을 보고한
    #   사이 전 워크스페이스에는 536건이 남아 있었다(O155 실측 · `R3-9 ㉡` + `O111 ㉠` 결합).
    'rename_stale_gate':      '개명 전 객체명이 살아있는 정본에 병기 없이 남았는가(기준선 대비 증가 = FAIL)',
    'verify_wide_doc':        '09_빅테이블 VIEW 정의서 ↔ Live Snowflake ↔ dbt 모델 100% 정합 검증',
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
    'sv_comment_object_gate': 'SV COMMENT 가 가리키는 객체가 라이브에 실재하는가 — 라이브를 **읽는다** · 🔴 정합(`comment_drift_gate`)이 아니라 **정확성** 축(파일·라이브가 같이 틀리면 그쪽은 🟢 다)',
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
    # 🆕 [2026-09-10 O155 신설] 개명 잔여 **1회성 탐색** 관측 — 🔴 판정 정본은 `rename_stale_gate` 다.
    #   이 파일은 게이트를 만들기 전에 규모(버킷별 분포)를 재려고 쓴 탐침이고, 판정식이 4회 바뀐
    #   과정을 주석으로 남긴다(줄 전체 키워드 → 매치 이웃 판정 · `O111 ㉢` 실물 3회차).
    '_o155_rename_scan':   '개명 전 이름 잔여 규모 관측(버킷별) — 🔴 판정 정본은 `rename_stale_gate`',
    # 🆕 [2026-09-16 O169 신설] 축1 좌표의 **원문 덤프** — 「지시」/「기록」을 사람이 가르기 위한 관측이다.
    #   🔴 쓰기 없음(읽기 전용) · 판정 정본은 `rename_stale_gate` 다.
    #   축 = 분모를 `rename_stale_gate.scan()` 에서 **import 해서** 받는다.
    #   🔎 왜 그렇게 했나 = 초판은 `--list` 출력을 파싱하고 파일을 직접 재스캔했는데 게이트의
    #      `qualified()` 면제를 몰라 **71 vs 68** 로 어긋났다(`J8` 「분모를 하나로 두라」 실물).
    '_o169_dump_axis1':    '개명 축1 좌표 원문 덤프(지시/기록 분류용) — 🔴 판정 정본은 `rename_stale_gate`',
    # 🆕 [2026-09-10 O154-B 신설 1종] 세션 한정 자기검토 보조 — 판정이 아니다.
    '_o154b_pyc_probe':    '트랜스크립트의 `python3 -c` 원문 전건 열거 관측 — '
                           '🔴 `o145_transcript_audit` 는 「발견/없음」만 내고 원문을 §4-B 에 싣지 않아 '
                           '`R1-7-9` 위반 여부를 사람이 판정할 수 없었다(O111 ㉢ 축). '
                           '🔴 「쓰기 의심」 표시는 `open(` 만 보므로 **읽기도 걸린다** ⇒ '
                           '실제 판정은 `open(...,\'w\')`·`.write(` 로 재확인하라(O154-B 자기시정)',
    # 🆕 [2026-09-17 O170 신설 2종] GOLD 미주입 컬럼 **재집계·집합대조** 관측 — 🔴 판정이 아니다.
    #   🔴 쓰기 없음(`/tmp` 산출물만) · 원 판정식 정본은 O43/O167(`COUNT_IF(<>0)` · `DW_*` 제외)이다.
    #   축 = census 를 **스스로 세지 않고** `census_columns.py` 산출물 `/tmp/census.json` 을 읽는다
    #   ⇒ `J8` 「도구의 분모와 게이트의 분모를 하나로 두라」를 설계로 지켰다.
    '_o170_gold_unfilled': 'GOLD 미주입 컬럼 재집계(전건0/전건NULL/0행 분해) — 🔴 분모는 `census_columns` 산출물',
    #   🔴 이 파일은 O167 열거 95건을 **원문 전사**해 담고 `assert len == 95` 로 전사 오류를 막는다
    #   ⇒ 전사가 틀리면 「해소/신규」가 조용히 왜곡되므로 단정을 코드에 박았다.
    '_o170_unfilled_diff': '미주입 집합 차이 대조(해소/신규/누락) — 🔴 총계가 아니라 집합으로 진척을 증명한다',
    # 🆕 [2026-09-17 O170 신설] `99_NEXT` 승계(=현행 아님) 인수인계 절의 조각별 규모 관측.
    #   🔴 쓰기 없음 · 은퇴 대상 선정은 **사람이** 한다(`R1-6-24` — 「닫힘」은 이모지 판정일 뿐이다).
    #   🔴🔴 축 = 판정식을 **창작하지 않고** `session_brief.superseded()` 를 import 한다.
    #      🔎 왜 = 초판은 자작 판정식(`'~~' in title or '승계됐다' in title`)을 썼고
    #      **현행 절까지 승계로 잡았다**(현행 절 제목이 「§0-WWWW/O171 은 승계됐다」를 담기 때문 ·
    #      `J8` 자기참조). 정본은 **방향을 구별**한다 = `로 승계`·`시작점은`(자기 승계)만 신호다.
    '_o170_superseded_census': '99_NEXT 승계 절 조각별 규모 관측 — 🔴 판정식은 `session_brief` 에서 import',
    # 🆕 [2026-09-17 O170-D 신설] 미배정 GOLD 컬럼의 **차단 근거**를 컬럼 단위로 판정하는 관측.
    #   🔴 쓰기 없음 · 버킷을 **확정하지 않는다**(후보와 근거를 내고 사람이 가른다 · `R1-6-24` 축).
    #   축 = ㉠ 모델이 그 컬럼을 채우는 방식(리터럴 주입 ↔ 실산출식) ㉡ 원천 동명 컬럼 신호
    #        ㉢ census 는 **선택 의존**이다(`/tmp` 는 턴 사이에 비워진다 · 없으면 non-NULL 열만 `—`).
    #   🔴🔴 **파서를 4회 고쳤다** — 콤마까지 / 고정폭 200자 / 줄 전체 / 최상위콤마+`$` 가 각각 다르게
    #      틀렸고 그중 하나는 B 44 → 33 **회귀**였다. 최종 = **괄호 인식 최상위 콤마 분할 +
    #      식별자 경계 앵커**. 🟢 판정식 = **파서의 원자는 「구분자」도 「줄」도 「고정폭」도 아니라 「문법」이다.**
    #   🔴 `?`(실산출식·판정불가)는 **사람이 모델을 읽어 확정한다** — 도구 출력으로 닫지 마라.
    '_o170_unassigned_probe': '미배정 GOLD 컬럼 차단근거 판정(모델 구현 분류 + 원천 신호) — 🔴 버킷 미확정',
}

NEEDS_ARGS = {
    'new_tool':          '🆕 [O174] 도구 생성 + 이 파일 등재를 **한 동작**으로 — `--name`·`--bucket`·'
                         '`--axis` 필수(무인자 exit 2). 🔴 등재 실패 시 파일을 만들지 않는다(원자성) '
                         '⇒ 「생성 후 등재 지연」이 구조적으로 불가능해진다. 승격 = `--promote-scratch`',
    'line_len':          '검사할 경로(필수)',
    'o54_sv_value_gate': '비교 대상 2개(무인자는 사용법 + exit 2 · O120 시정)',
    'ws_stage_verify':   '파일목록 또는 `--o53`(무인자는 사용법 + exit 2 · **O121-B 시정**)',
    # 🆕 [2026-09-08 O145-B 신설 2종]
    #   🔴 둘 다 무인자에서 **사용법 + exit 2** 를 낸다(규약) ⇒ 크래시를 FAIL 로 세지 마라(축31).
    'snapshot_cli':      '스냅샷할 경로 + `--op`(무인자 exit 2) — `snapshot_util` 의 CLI 진입점. '
                         '🟢 `_archive/` 에만 쓰고 **절대 덮지 않는다**(동일=재사용 · 상이=접미) ⇒ '
                         'MUTATES 가 아니다. 신설 사유 = `R1-7-9` 가 금지한 `python3 -c` 인라인이 '
                         '유일한 경로였다(`D7`)',
    'o145_transcript_audit': '트랜스크립트 JSON/JSONL 경로(무인자 exit 2) — 세션의 실행 SQL·파일쓰기·'
                             'bash 를 추출하고 위험 신호 6종(`rm -rf`·dbt 실행·파이프 뒤 rc·awk length·'
                             '`python3 -c`·quoted heredoc)을 판정한다. 🔴 자기검토 **재료**이고 판정이 아니다',
}

# 🆕 [2026-09-08 O145-B] O144 가 남긴 일회성 라이브 프로브 6종을 `OBSERVE` 로 등재했다.
#   🔴 이 게이트가 O145-B 착수 시점에 이미 FAIL(미분류 8건 = 그 6 + 신설 2) 이었다.
#   🟢 분류 근거(실측) = 6종 전부 ㉠ DDL/DML 키워드 **0건** ㉡ 파일 쓰기 **0건**
#      ⇒ 라이브를 읽고 stdout 으로만 낸다 ⇒ `OBSERVE` 로 분류했다.
#
# ➔ 🟢 [2026-09-08 O144-E 종결] **등재를 철회했다 — 6종을 `scripts/_archive/` 로 보관했기 때문이다.**
#   🔴 경위 = O144-E 세션이 그 6종의 원작자이고, 세션 종료 시 일회성 스크립트를
#      `_archive/` 로 내리는 것이 이 워크스페이스 관례(`S3` 교훈)다. O145-B 가 등재한 직후
#      원작자가 보관 처리하면서 **미분류 6건 ➔ 유령 등재 6건**으로 결함 유형만 바뀌었다.
#   🔴🔴 **여기서 배울 것 — 남의 세션이 만든 파일을 등재해 미분류를 지우면, 그 파일이
#      정리될 때 유령으로 되살아난다.** 미분류를 본 세션은 「등재」와 「원작자에게 정리 요청」
#      중 무엇이 맞는지 먼저 판정해야 한다. 일회성(`_oNNN*` 접두)은 **등재가 아니라 보관**이 정답이다.
#   ⚠️ 따라서 `_oNNN*` 접두 일회성 프로브는 이 등록부에 올리지 않는다 — `_archive/` 로 내린다.
#      (보관된 파일은 `ls scripts/*.py` 분모에서 빠지므로 미분류로도 잡히지 않는다.)

GEN = {
    'gen_arch_map': '아키텍처 지도', 'gen_bronze_exposure_audit': 'BRONZE 노출 감사',
    'gen_code_system_gates': '코드체계 게이트', 'gen_column_inventory_20260811': '컬럼 인벤토리',
        'gen_concept_diagram':  '개념도',
    'gen_gold_erd':         'GOLD 테이블별 ERD(HTML · Mermaid) — dbt yml + INFORMATION_SCHEMA · `--yaml-only` 로 라이브 없이도 돈다',
    'gen_pipeline_erd':     'Bronze > Silver > Gold 전체 파이프라인 ERD & 계보 카탈로그(HTML · Mermaid)',
    'gen_measure_backlog': '실측필요 후속작업',
    # 🆕 [2026-09-17 O172 신설] 인수인계 **라벨 파일** 작성기(`R1-6-27`).
    #   🔴 GEN 인 이유 = **신규 파일만** 만들고 기존 파일을 재작성하지 않는다(`--index` 는 자기 산출물 재생성).
    #   🔴 덮지 않는다(이미 있으면 SKIP) · 쓰기 전 2,000자 가드 · 쓴 뒤 **도달 재검사**(O167 계약).
    #   축 = 파일명 규격 정본을 `doc_census.label_rx`·`label_paths` 에서 **import** 한다(같은 것을 다르게 재지 않는다).
    'handoff_write': '인수인계 라벨 파일 작성 + 색인 재생성(`--label`/`--index`/`--next`)',
    'gen_metric_gold_mapping': '지표↔GOLD 매핑', 'gen_section_assembly': '절 조립',
    'gen_silver_gold_retention': 'SILVER·GOLD 보존', 'session_brief': '착수 브리핑(`00_BRIEF.md`)',
    'build_wide_doc': '09_빅테이블 VIEW 정의서 생성기',
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
    # 🆕 [2026-09-17 O163] DDL 파일 ↔ 라이브 컬럼 집합 대조. `--live <TSV>` 필수라 무인자 판정 불가.
    #   🔴 라이브를 **읽지도 않는다** — 호출자가 INFORMATION_SCHEMA 결과를 파일로 넘긴다
    #   (커넥션 의존을 두지 않기 위한 설계 · MUTATES 가 아니다).
    'o163_ddl_live_drift': 'DDL↔라이브 컬럼집합 대조 — `--live` 필수(라이브 접속 0)',
    # 🆕 [2026-09-16 O167] 마운트 ↔ 스테이지 대조. 착수표 ⑩ 「스테이지 내용 해시 축」의 **대체 축**.
    #   🔴 해시가 아니라 **크기 패딩식**이다 — 스테이지 md5 는 암호화 blob 해시여서 평문과 다르다
    #   (실측 = `.md` 423건 전건 불일치). 🟢 `stage == 16*(local//16)+16` 은 2,741/2,741 성립.
    'stage_mount_size_gate': '마운트↔스테이지 크기 패딩식 대조(내용 드리프트) — 해시 대조는 원리적 불가',
    # 🆕 [2026-09-16 O167] NL 스모크 응답(`tmp/nlsmoke/*.txt`)을 읽어 라우팅·SQL·오류를 판정한다.
    #   🔴 라이브 접속 0 · 과금 0(파일만 읽는다) ⇒ 러너(`nl_routing_smoke`)와 달리 MUTATES 가 아니다.
    #   🔴 판정 한계 = 「도구를 썼다」는 관측이고 「올바른 도구를 썼다」는 사람이 정한다(축 ㉢ 은 기계 판정 불가).
    'nl_routing_judge': 'NL 스모크 응답 판정 — 라우팅 관측 · SQL 생성 · 오류표면(파일 전용)',
    # 🆕 [2026-09-16 O167] `init_ihcho` 스킬이 정본(`00_guides/03_init_ihcho_스킬_정본.md` §6)과
    #   **바이트 동일**한지 + 형식 불변식 7종(I1~I7)을 지키는지 본다. 🔴 라이브 접속 0 · 파일만 읽는다.
    #   🔴 I7 은 「하드코딩 수치 금지」다 — 실제로 초판에서 「게이트 6종」 기재를 잡아냈다.
    'verify_init_ihcho_skill': '스킬 ↔ 정본 바이트 동일 + 형식 불변식 7종(줄수·조문집합·수치금지)',
}

MUTATES = {
    # 🆕 [2026-09-16 O167] `init_ihcho` 스킬 빌더 — 정본 §6 → `SKILL.md` 를 **통째로 다시 쓴다**.
    #   🔴 대상이 생성물이라 `R1-7-1`(부분 치환 기본)의 예외이지만, **파일 하나를 전량 재작성**하므로
    #   여기 둔다. 기본 dry-run · `--apply` 로만 쓰고 스냅샷은 `snapshot_util` 경유(`R1-7-10`).
    'build_init_ihcho_skill': '스킬 정본 → SKILL.md 재작성(--apply · 스냅샷 선행)',
    # 🆕 [2026-09-16 O167] 착수표 ㉗ NL 라우팅 스모크 러너 — DDL·DML 을 하지 않는다.
    #   🔴 그래도 여기 등재하는 이유는 **과금**이다: `DATA_AGENT_RUN` 33회는 LLM 호출이고
    #   되돌릴 수는 있어도 **크레딧은 되돌아오지 않는다** ⇒ `R4-4-3` 「승인 대상」과 같이 다룬다.
    #   🟢 응답 원문은 `tmp/nlsmoke/` 로 흘린다(세션 컨텍스트에 적재하지 않는다).
    'nl_routing_smoke': 'Agent 3종 NL 라우팅 스모크 — 🔴 과금 호출(승인 후 실행)',
    # 🆕 [2026-09-17 O163] DEC-50 개명 일괄 치환 — `--apply` 로 **다중 파일을 재작성**한다(`R4-4-3`).
    #   기본은 dry-run 이고, 원천 `EP_GA_SESSION_*` 개수 불변·줄 수 불변을 단정한 뒤에만 쓴다.
    'o163_dec50_rename': 'DEC-50 개명 다중 파일 치환(--apply)',
    # 🆕 [2026-09-16 O166] 개명 잔여 일괄 정정 — `--apply` 로 **다중 파일을 재작성**한다(`R4-4-3`).
    #   기본 dry-run 이고 치환 줄을 전건 출력해 사람이 검토한 뒤에만 적용한다.
    #   개명 대응은 하드코딩하지 않고 `rename_stale_gate.RENAMES` 를 재사용한다(같은 것을 다르게 재지 않는다).
    '_o166_rename_fix': '개명 잔여 다중 파일 치환(--apply)',
    # 🆕 🔴 [2026-09-16 O169] 구 `DIM_MEMBER_CURRENT` 축1 68건의 **병기** 집행기 — `--apply` 로
    #   **다중 파일을 재작성**한다(`R4-4-3`) ⇒ 여기 등재한다. 기본 dry-run.
    #   🔴 `_o166_rename_fix` 와 **성격이 다르다**: 치환기가 아니라 **병기기**다 —
    #   구 `DIM_MEMBER_CURRENT` 는 개명이 아니라 **객체 소멸**이므로 우변 치환이 자기모순을 만든다
    #   (`rename_stale_gate.RENAMES` 주석 O166-B 가 같은 경고를 한다).
    #   축 = ㉠ 분모를 `rename_stale_gate.scan()` 에서 받는다(같은 것을 다르게 재지 않는다)
    #        ㉡ 원문 문자를 **삭제하지 않는다**(축A 「구 」 삽입 · 축B 줄말미 병기)
    #        ㉢ 「지시」 줄은 `EXCLUDE` 로 빼고 **사람이** 가른다
    #        ㉣ 사후단정 4축(`verify()`)을 통과하지 않은 줄은 쓰지 않는다
    #   음성 테스트 = `test_o169_axis1_biwi`(8축 · 고치기 전 구현의 실패를 실증)
    '_o169_axis1_biwi': '개명 축1 병기 집행(--apply · 원문 무삭제 · 스냅샷 선행)',
    # 🆕 🔴 [2026-09-16 O169] SV 재배포 러너 — **라이브 객체를 고친다**(`R4-4-3`) ⇒ 여기 등재한다.
    #   🟢 본문이 `CREATE OR ALTER SEMANTIC VIEW` 라 **GRANT·소유권이 보존**된다(실측 확인 = 재배포 후
    #      GRANT 7건 전건 잔존 · `created_on` 불변 · OWNERSHIP = `GN_DW_ADMIN`).
    #   🔴 가드 = 실행 전 `CREATE OR REPLACE` 혼입 검사(있으면 중단 · `P125` 파괴 경로) +
    #      `^CREATE OR ALTER` 행 시작 확인. 실행 후 **라이브 COMMENT 를 되읽어 도달을 단정**한다.
    #   🔴 배포문은 `extract_sv_deploy.py` 가 뽑은 것만 쓴다(스모크 SELECT 를 섞지 않는다).
    '_o169_sv_redeploy': 'SV_MEMBER_EVENT 재배포(CREATE OR ALTER · GRANT 보존 · 도달 확인)',
    # 🆕 [2026-09-17 O170 신설] 원장 §1 대시보드에 **라벨 선점 1행**을 삽입한다(`R1-4-3`).
    #   🔴 쓰기 대상은 `00_INDEX_이슈원장-001.md` **1파일**이고 표 머리 직후에 넣는다.
    #   🔴 가드 3중 = ㉠ `O170` 이 이미 있으면 SKIP(멱등) ㉡ 삽입 후 바이트가 상한 40,960 을
    #      넘으면 **쓰지 않고 ABORT** ㉢ 실행 후 `index_row_gate` 로 행 유실 0 을 확인한다.
    #   🔎 왜 도구를 만들었나 = 그 조각의 행이 1,700~1,900자라 `edit` 앵커로 다루면 `R1-7-8`
    #      제목·행 파괴 경로에 들어가고, 본문에 백틱이 있어 셸 경유가 금지된다(`R1-7-9`).
    '_o170_reserve': '원장 §1 에 라벨 선점 1행 삽입(멱등 · 상한 초과 시 ABORT)',
    # 🆕 [2026-09-17 O170 신설] 인수인계 절 삽입 + 직전 절의 「여기서 시작한다」 승계 표기.
    #   🔴 왜 도구인가 = 이 마운트는 `cat >>`(append)를 **조용히 유실**한다(O167 실사고) ⇒
    #      python 전량 쓰기가 유일한 안전 경로이고, 본문에 백틱·`$` 가 있어 셸 경유도 금지다(`R1-7-9`).
    #   🔴 가드 4중 = ㉠ 절 라벨이 이미 있으면 SKIP(멱등) ㉡ 승계 대상 **제목줄 전체**를 앵커로 쓰고
    #      못 찾으면 ABORT(부분 접두 금지 · `R1-7-8` 제목 파괴 경로) ㉢ 말미 서명을 못 찾으면 ABORT
    #      ㉣ 쓰기 직후 **도달 토큰 6축 재검사**(구 시작문구 잔존 0 을 포함한 양방향 단정).
    #   🔴 이 도구는 세션 라벨을 인자로 받지 않는다 — 상수를 고쳐 재사용하라(1회성).
    '_o170_handoff_append': '인수인계 절 삽입 + 직전 절 승계 표기(전량 쓰기 · 도달 6축 재검사)',
    # 🆕 🔴 [2026-09-17 O170] 승계 인수인계 절 **은퇴 배치 드라이버** — 다중 파일을 재작성한다(`R4-4-3`).
    #   🔴 승인 = 2026-09-17 사용자 「retire_sections.py 를 승인」.
    #   🟢 축 = 승계 판정은 `session_brief.superseded()` import(분모 일원화) · 선택자는
    #      **`날짜 + 세션 라벨`** 이고 **그 조각 전 제목에서 유일함을 단정한 뒤** 넘긴다
    #      (🔎 `--sections` 가 부분문자열 매치라 라벨 선택자는 그 라벨을 인용하는 다른 절까지 잡는다).
    #   🔴🔴 **이 도구의 자기 계약 ㉠ 은 부분적으로 거짓이다** — *"제목 줄은 전건 원본에 남는다
    #      ⇒ doc_heading_gate 유실 0"* 이라 적었으나 실측은 **유실 8건**이었다. 이유는 같은 파일 ㉡ 이
    #      스스로 적는다 = `##` span 이 다음 동급 이상까지이므로 **하위 `###` 제목이 본문과 함께 간다.**
    #      🟢 실유실은 0 이다(전건 목적지 실재 확인) ⇒ 🟢 **판정식 = 「제목을 남긴다」는 계약은
    #      「어느 수준의 제목인가」를 말해야 한다.** 은퇴 후 제목 골든은 사유와 함께 재발행한다.
    #   🔴 진척은 22/63절이다(부분 집행) — 잔여 41절은 `_o170_superseded_census` 로 세어 확인하라.
    '_o170_retire_driver': '승계 인수인계 절 은퇴 배치(--force · 실패 즉시 중단 · 조각별 rc 기록)',
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
    # 🆕 [2026-09-10 O154-B 신설 1종] dbt 스키마 yml 3파일의 **폐기 처방 문안**을 일괄 정정한다.
    #   🟢 기본 dry-run · `--apply` 로만 쓴다 · 치환 전 `snapshot_util` 경유 스냅샷(`R1-7-10`) ·
    #     기대 건수 불일치 시 **쓰지 않고 exit 1** · 치환 후 폐기 문안 처방 잔여 0 을 되읽어 단정.
    #   🔴 왜 스크립트인가 = `edit` 의 `replace_all` 이 듣지 않고 대상 줄이 매우 길어 앵커가 위험했다
    #     ⇒ `R1-7-8` 이 명시한 예외 경로(줄 인덱스 지정 치환)다.
    '_o154b_orphan_comment_fix': '「전량입고 후 warn→error 승격」 폐기 문안 일괄 정정(dbt yml 3파일)',
}

LIB = {
    'add_column_comments': '', 'add_gold_comments': '', 'census_columns': '',
    'dump_schema': '', 'field_mapping_override': '', 'o59g_paren_scan': '',
    'o59l_rule7_context': '', 'o70_stale_scan': '', 'rebuild_inventory': '',
    'run_gold_ddl': '', 'sfconn': '접속 헬퍼', 'snapshot_util': '스냅샷 단일 경유점',
}

BUCKETS = [('JUDGE', JUDGE), ('OBSERVE', OBSERVE), ('NEEDS_ARGS', NEEDS_ARGS),
           ('GEN', GEN), ('MUTATES', MUTATES), ('LIB', LIB)]

# 🆕 🔴🔴 [2026-09-21 O174 신설 · 구조 결정] **임시 계측기 접두 `_scratch_` 신설 — 미분류 재발을 구조로 막는다.**
#   🔎 경위 = `O170` 이 미분류를 **4회** 방치했고 1차가 `O171` 라벨 오용을 유발했다.
#      `O173` 도 임시 계측기 5개가 미분류 FAIL 을 냈고 **삭제로만** 해소했다(구조가 아니라 규율).
#   🔴 **왜 경고로는 멈추지 않는가** = 미분류는 세션 **끝**에 발견된다. 그때는 이미 그 파일로
#      판정을 냈고, 등재하면 「남의 파일을 등재해 유령을 만드는」 결함(위 O145-B 축)으로 바뀐다.
#   🟢 **구조 = 선택지를 둘로 줄이고 둘 다 기계가 강제한다:**
#      ㉠ **영구 도구** ⇒ `scripts/new_tool.py` 로만 만든다 — 파일 생성과 등재가 **한 동작**이고
#         등재에 실패하면 **파일도 만들지 않는다**(원자성) ⇒ 「생성 후 등재 지연」이 존재할 수 없다.
#      ㉡ **임시 계측기** ⇒ 파일명을 `_scratch_*.py` 로 짓는다 — 등재 **불요**(자동 면제)이고
#         `--run`·TEST 분모에서 제외된다. 🔴 대신 **`--final` 에서 잔존하면 FAIL** 이다
#         ⇒ 세션을 닫으려면 **지우거나 영구 도구로 승격**해야 한다(수명이 강제된다).
#   🟢🟢 판정식 = **면제를 주지 않으면 규율로 버티게 되고, 수명을 안 걸면 면제가 구멍이 된다.**
#      ⇒ 면제와 수명은 **한 쌍으로만** 도입한다.
SCRATCH_PREFIX = '_scratch_'


def is_scratch(name):
    """임시 계측기인가 — 등재 면제 대상이고 `--final` 에서는 잔존이 FAIL 이다."""
    return name.startswith(SCRATCH_PREFIX)


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
    scratch = [n for n in names if is_scratch(n)]
    known, dup = {}, []
    for label, d in BUCKETS:
        for n in d:
            if n in known:
                dup.append((n, known[n], label))
            known[n] = label
    # 🆕 [O174] 미분류 분모에서 `test_*` 와 `_scratch_*` 를 함께 뺀다 —
    #   🔴 `_scratch_` 는 **면제이고 승인이 아니다**(`--final` 이 잔존을 FAIL 로 잡는다).
    unclassified = [n for n in names
                   if n not in known and not n.startswith('test_') and not is_scratch(n)]
    ghost = [n for n in known if n not in names]
    return names, tests, known, unclassified, ghost, dup, scratch


def main():
    ap = argparse.ArgumentParser(
        description='「돌려야 하는 게이트」의 분모를 명시 등재로 확정한다(미분류는 FAIL).')
    ap.add_argument('--run', action='store_true', help='JUDGE 만 개별 실행해 종료코드 표를 낸다.')
    ap.add_argument('--run-tests', action='store_true', help='TEST 도 함께 실행한다.')
    ap.add_argument('--timeout', type=int, default=300)
    ap.add_argument('--final', action='store_true',
                    help='세션 종료 판정 — `_scratch_*` 임시 계측기가 잔존하면 FAIL (O174 수명 강제).')
    try:
        a = ap.parse_args()
    except SystemExit:
        return 2

    names, tests, known, unclassified, ghost, dup, scratch = audit()
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

    # 🆕 🔴🔴 [O174] 임시 계측기 수명 축 — 면제의 짝이다(면제만 주면 구멍이 된다).
    print('  임시 계측기(`%s*`) %d건 — 등재 면제 · 🔴 `--final` 에서는 잔존이 FAIL'
          % (SCRATCH_PREFIX, len(scratch)))
    for n in scratch:
        print('    ⚪ 임시: %s' % n)
    if a.final and scratch:
        fail.append('임시 계측기 잔존 %d건' % len(scratch))
        print('    🔴 세션을 닫으려면 **지우거나** `new_tool.py` 로 **영구 도구로 승격**하라')

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

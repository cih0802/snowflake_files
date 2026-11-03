# O206-C — 00_작업계획.md 정정 5건 + §9-4 추가 (단일 파일 1회 쓰기 · 앵커 1회 일치 검증)
# Co-authored with CoCo
import hashlib, io, sys
P = '12_agent개선과제/00_작업계획.md'
h = lambda: hashlib.sha256(open(P, 'rb').read()).hexdigest()
assert h() == h()
t = io.open(P, encoding='utf-8').read()
L = t.split('\n')


def sub_line(prefix, new):
    idx = [i for i, l in enumerate(L) if l.startswith(prefix)]
    if len(idx) != 1:
        sys.exit(f'🔴 앵커 {prefix!r} = {len(idx)}')
    L[idx[0]] = new


sub_line('| U4 | 현업 확인 4건 |',
         '| ~~U4~~ | ~~현업 확인 4건~~ ➔ 🟢 [O206] 사용자 지시로 원천 재확인·처리(회신 대기 해제) | 🟢 §9 V2 | `20_현업확인_요청-010.md` N-27 결과표 | 🔴 회신을 기다리지 마라 — 처리 완료 |')
sub_line('| V1 | 표 헤더 한글 강제(3중) |',
         '| V1 | 표 헤더 한글 강제(3중) | 🟢 SV 28/28 · Agent 4종 · 표 헤더 판정 42건 = 41 PASS · 1 FAIL(E1 차트 `Value`) → O206-B 차트 규칙 후 재측정 PASS | 05 SV DDL 20파일 · `cortex_project/agents/*/agent_spec.yaml` | 다른 부서 회신 시 `tmp/o206_judge.py` 로 재확인 |')
sub_line('| 3 | 연사업 회비예측 |',
         '| 3 | 연사업 회비예측 | — | ⭕(O206-C) | mbrfee_prdt_actl(회원실 자체 수식) · 🔴 VERSION$5 는 연간 합계를 직접 더해 오기(1,667.6억 ↔ 실제 1,627.6억) → O206-C 후 SQL ROLLUP 합계 |')
sub_line('| 9 | 충성회원 예측 |',
         '| 9 | 충성회원 예측 | — | ⭕(O206-C) | ml_member_risk · 🔴 VERSION$5 는 등급별 고유 회원수를 더해 분모 오기(43,666 ↔ 실제 43,498) → O206-C 후 별도 COUNT DISTINCT |')
sub_line('- 집계 = ⭕ 11 · △ 4 · ✕ 0',
         '- 집계 = ⭕ 11 · △ 4 · ✕ 0 (CSV 시점 「불가」 7건 → 전부 답변). 🔴 [O206-C 정정] VERSION$5 판정은 표 헤더만 봤다 — 본문 수치 오류 2건(#3 · #9)을 놓쳤다 ⇒ §9-4.')
L.append('')
L += [
    '### 9-4. O206-C 비판적 검토 · 보완 (2026-10-07)',
    '',
    '| # | 구분 | 발견 | 처분 | 검증 |',
    '|---|---|---|---|---|',
    '| C1 | 🔴 판정 사각지대 | 표 헤더 판정기만 PASS 기준이었다 — 답변 본문 수치를 대조하지 않음 | 수치 근거 판정기 `tmp/o206_numcheck.py` 신설(본문 금액·명·건 ↔ 모든 도구 결과 셀·열 합) | 저장 원문 32건 = 근거없음 6 → 분해 |',
    '| C2 | 🔴 본문 수치 오류 | #3 연간 합계 오기 · #9 분모 오기 · Q4 「127억」(실제 1.27억) 단위 오기 — 기존 O198 합계 규칙이 있었는데도 직접 계산 | SV 28종 `[O206-C 합계 규칙]`(합계·분모는 SQL · ROLLUP · COUNT DISTINCT 별도) · Agent 4종 `[O206-C 수치 근거]`(답변 직전 셀 대조 자가점검 · 수치 없는 예시 = 규칙7 준수) | 라이브 SV 28/28 · EXEC·MKT·MEMBER VERSION$6 · MSTR VERSION$7 · 재측정 10건 헤더 10/10 · 오류 3건 해소(R03 ROLLUP · R09 43,498 · Q4 SQL 합계) |',
    '| C3 | 🟠 잔여 | R11 = 「80+24=104」·「63+60=123」 두 행 덧셈(값은 정확) | 규칙 추가 강화 안 함(서술 경직 우려) — △ 로 남김 | 수치 근거 판정기 CHECK 2 |',
    '| C4 | 🟠 규칙 누락 | Q3 매핑근거 열 미표시(규칙 (12) 미준수) | 05_18 규칙 (12) 「모든 수신 지표 쿼리에 MATCH_BASIS · 생략 금지」로 강화 · 재배포 | Q3 재측정 표 헤더 PASS |',
    '| C5 | 🟠 stale | `_wide_schema.yml` 테이블·컬럼 설명 「임시 규칙(현업 확인 대기)」 3곳 · 이 문서 §8 U4 「회신 대기」 | 교정(yml 은 **다음 dbt build 때** 라이브 뷰 COMMENT 반영) | yaml 파싱 OK · 2000자 PASS |',
    '| C6 | 🔴 진입점 오류 | 06 생성기 실패를 「환경 제약」으로 보고했으나 실제는 **정식 러너 `run_bronze_audit_host.py` 를 쓰지 않은 것** | 정식 러너로 재생성(rc=0 · 기존본 `_archive` 스냅샷) · 생성기에 넣었던 대체 경로는 원복 | 06 md·csv·xlsx 재생성 |',
    '| C7 | 🟡 절차 | 직전 답변에서 원문 검색이 빈 결과를 냈는데 확인 없이 수치 인용(결과는 맞았음) | 원문 재대조로 확정 | `tmp/o206_round3/R03.json` content[9] |',
    '',
]
io.open(P, 'w', encoding='utf-8', newline='').write('\n'.join(L))
print('WROTE', h()[:12])

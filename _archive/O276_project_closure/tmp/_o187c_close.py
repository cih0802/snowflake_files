"""[O187-C] 단위 종료 기록 — 원장 행 · 인수인계 본문 생성(셸 파서 회피용 파일 실행)."""
import io
P = '20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md'
L = io.open(P, encoding='utf-8').read().split('\n')
if not any(l.startswith('| 🟢 **`O187-C`**') for l in L):
    i = next(k for k, l in enumerate(L) if l.startswith('| 🟢 **`O187-B`**'))
    L.insert(i, '| 🟢 **`O187-C`** — 리스트 var `--vars` 전달 확인 · 백필 런북 ARGS 1줄로 단순화(재배포 불요) | 🟢 문서20 신규 회신 0 | '
                '**[2026-09-28 O187-C · xf98254 · 정본 = 라벨 `-O0187-C.md`]** | 원장 §1 · 이력 §O187-C |')
    o = '\n'.join(L); n = len(o.encode()); assert n <= 40960
    io.open(P, 'w', encoding='utf-8', newline='').write(o); print('ledger free', 40960 - n)

io.open('tmp/_o187c_hist.md', 'w', encoding='utf-8').write(
"\n> #### 🟢 [2026-09-28 O187-C] 리스트 var `--vars` 전달 확인 → 백필 런북을 ARGS 1줄로 단순화\n\n"
"- 사용자 실험 = `--vars '{\"bigquery_dt_ranges\": [[\"2025-06-01\", \"2025-06-30\"]]}'` → 창 `EVENT_DATE between '20250601' and '20250630'` 렌더(xf98254)\n"
"- 백필 정본 = `EXECUTE DBT PROJECT … ARGS` 1줄(파일 편집·재배포 불요) · 종전 주석 슬롯 ㉠~㉤ 는 대체 경로로 강등 ⇒ 재잠금 누락 위험 소멸\n"
"- 정정 4곳 = `02_dbt_parse_compile_build.sql` Step3 · macro 헤더 · `dbt_project.yml` vars 주석 · `11_…/00_개요_및_실행순서.md`\n"
"- 문서20 판정줄 56 · 기록 20 · 미회신 36(신규 회신 0)\n")

t = io.open('tmp/_o187b_handoff.md', encoding='utf-8').read()
t = t.replace('O187-B-', 'O187-C-').replace('99_NEXT_SESSION-O0187-B.md', '99_NEXT_SESSION-O0187-C.md')
head = ("### ▣ O187-C-0 🟢 이 단위가 끝낸 것 (2026-09-28 · xf98254)\n\n"
        "- **리스트 var 전달 확인** — `bigquery_dt_ranges` 가 `--vars` 로 전달돼 창 `between '20250601' and '20250630'` 렌더\n"
        "- **백필 런북 단순화** — 정본 = `EXECUTE DBT PROJECT … ARGS` 1줄(compile 로 창 확인 → build) · 주석 슬롯 ㉠~㉤ 는 대체 경로\n"
        "- 문서20 = 기록 20 · 미회신 36(신규 회신 0)\n\n---\n\n")
t = head + t[t.index('### ▣ O187-C-1'):]
old2 = [l for l in t.split('\n') if l.startswith('| 2 | 운영 |')]
assert len(old2) == 1; t = t.replace(old2[0] + '\n', '')
t = t.replace("🟢 닫힘(O187-B) = 구 2(`--vars` 원인) — 경로 한정으로 확정 · 런북 4곳 정정.",
              "🟢 닫힘(O187-B·C) = `--vars` 원인 확정 + 리스트 var 전달 확인 → 백필 런북 ARGS 1줄.")
a = t.index('### ▣ O187-C-2'); b = t.index('### ▣ O187-C-3')
t = t[:a] + ("### ▣ O187-C-2 ⏸ 사용자 실행 대기 항목 — 없음\n\n"
             "- 이번 변경은 주석뿐이다(로직 무변경) ⇒ 배포본 반영은 **다음 모델 변경 때 함께**(선택):\n"
             "  `ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE DEPLOY FROM 'snow://workspace/USER$.PUBLIC.\"snowflake_files\"/versions/live/10_dbt_pipeline/';`\n\n---\n\n") + t[b:]
lines = t.split('\n'); k = [i for i, l in enumerate(lines) if l.startswith('3. ▣2 실험 결과')]
assert len(k) == 1
lines[k[0]] = '3. 문서20 신규 회신이 없으면 에이전트 단독 착수 가능 항목(Agent 행 · 선택 과금)만 진행하고 대기한다.'
io.open('tmp/_o187c_handoff.md', 'w', encoding='utf-8').write('\n'.join(lines)); print('handoff body ok')

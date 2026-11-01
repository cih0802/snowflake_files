#!/usr/bin/env python3
"""마운트 ↔ 스테이지 대조 게이트 (착수표 ⑩ 「스테이지 내용 해시 축」의 **대체 축**).

🔴🔴 **왜 해시가 아니라 크기인가 — 실측으로 확정된 제약이다.**
  `cortex ws ls` 는 파일마다 `md5` 를 준다. 그러나 그것은 **암호화 blob 의 해시**이고
  평문 md5 와 **다르다**: O167 실측 = `.md` **423건 전건 불일치**(일치 0).
  ⇒ 🔴 **스테이지 md5 를 내용 동일성 근거로 쓰지 마라**(착수표 ㉔ 의 「md5 대조 불가」와 같은 결론).

🟢 **대신 크기 패딩이 결정적이다** — 단, **경계에서 크기만으로 결정되지 않는다.**

      stage_size == 16 * (local_size // 16) + 16        # local % 16 != 0 일 때만 유일해
      stage_size in {local_size, local_size + 16}       # 🔴 local % 16 == 0 이면 **두 값 다 실재**

  🆕 🔴🔴 **[2026-09-23 O181 실측 정정]** 종전 문안은 *"로컬이 16의 배수여도 한 블록을 더 붙인다"*
  라고 단정하고 O167 실측 **2,741/2,741 성립**을 근거로 들었다. 🔴 **그 단정이 틀렸다.**
  · 📏 재실측(`.md` **615건** · 2026-09-23) =
      · `local % 16 != 0` **516건** ⇒ 차이가 전건 `16 - (local % 16)` (= **다음 16배수로 반올림**)
      · `local % 16 == 0` **99건** ⇒ 차이가 **`+16` 40건 · `0` 59건 으로 갈린다**
  · ⇒ 🟢 **판정식 = 배수 경계는 「반올림」과 「블록 추가」가 섞이므로 두 값을 모두 허용한다.**
    🔴 한쪽으로 고정하면 반대쪽이 전건 오탐이다(실사고 = `+16` 고정이 **41건 오탐**을 냈고
    그것이 게이트를 「항상 빨간」 상태로 만들었다 · `P130`).
  · 🟠 **대가를 명시한다** — 배수 경계 파일이 **정확히 16 B 만큼** 바뀌면 이 게이트가 놓친다
    (전 분모의 1/16 에서 16 B 단위 변화만 · 그 밖의 변화는 여전히 1 B 단위로 잡힌다).
  · 🔴 **O167 의 「전건 성립」은 거짓이 아니라 분모가 달랐을 것이다** — 어느 쪽이든
    **수치를 인용하지 말고 재라**(`R2-8-4`). 이 주석의 615/516/99 도 같은 대상이다.

  ⇒ 🟢 이 식은 **크기 드리프트를 1 바이트 단위로 잡는다.** 내용 변경 중 크기가 같은
  치환(같은 길이 오타)은 못 잡지만, 종전 「size+last_modified 눈대중」보다 강하다.

🔴 **판정 설계**
  ㉠ 식 불성립 = **드리프트**(마운트와 스테이지가 다르다) ⇒ blocking.
  ㉡ 스테이지에 있고 마운트에 없음 = `.folder`(디렉터리 마커)면 **정상**, 그 외는 경고.
  ㉢ 마운트에 있고 스테이지에 없음 = **미발행**(경고 · 아직 커밋되지 않은 신규 파일).
  ㉣ 🔴 **낡은 뷰 주의**(`O165 D13`) — 방금 쓴 파일은 마운트가 늦게 동기화된다.
     불성립이 나오면 **수 초 뒤 재실행**해 재현되는지 보고 판정하라.

실행 = `python3 scripts/stage_mount_size_gate.py [--all]`
  기본은 `.md` 만 본다(문서 정본 축) · `--all` 은 전 확장자.
"""
import io
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WS = 'USER$.PUBLIC."snowflake_files"'
PREFIX = '/versions/live/'
# 🔴 마운트에 없어도 정상인 것 = 디렉터리 마커.
DIR_MARKERS = ('.folder',)
# 🔴 마운트 전용(스테이지 미발행이 정상) = 세션 산출 임시물.
UNPUBLISHED_OK = ('tmp/', '_snapshots/', '.git/')


def stage_list():
    """`cortex ws ls` 를 파싱한다.

    🔴🔴 **구분자는 탭이다 — 공백으로 자르지 마라.** O167 초판이 `split('  ')` 로 잘라
    **0건**을 냈다(그리고 0건은 「깨끗하다」가 아니라 **판정식 실패**였다 · `O111 ㉠`).
    🟢 탭으로 자르면 **공백이 든 파일명**(`Untitled 3.sql` 등)도 정확히 대조된다.
    """
    r = subprocess.run(['cortex', 'ws', 'ls', WS], capture_output=True, text=True, timeout=600)
    if r.returncode != 0:
        raise SystemExit(f'[게이트 미판정] cortex ws ls rc={r.returncode}\n{r.stderr[:400]}')
    out = {}
    for line in r.stdout.splitlines():
        if not line.startswith(PREFIX):
            continue
        parts = line.split('\t')  # name \t size \t md5 \t last_modified
        if len(parts) < 2 or not parts[1].strip().isdigit():
            continue
        out[parts[0][len(PREFIX):]] = int(parts[1])
    return out


def expected(local_size):
    """대표 기대값(표시·기존 테스트 호환) = 다음 16배수 + (경계면 한 블록 추가)."""
    return 16 * (local_size // 16) + 16


def accepted(local_size):
    """🆕 [O181] **허용 집합**이 판정 정본이다 — 경계는 크기만으로 결정되지 않는다.

    · `local % 16 != 0` ⇒ 값 1개(다음 16배수) · 실측 516/516 성립.
    · `local % 16 == 0` ⇒ 값 **2개**(`local` 과 `local+16`) · 실측이 40:59 로 갈렸다.
    🔴 한쪽으로 고정하면 반대쪽이 전건 오탐이 된다(O181 실사고 41건 · `P130`).
    """
    if local_size % 16:
        return {16 * (local_size // 16) + 16}
    return {local_size, local_size + 16}


def run(only_md=True):
    stage = stage_list()
    if not stage:
        raise SystemExit('[게이트 미판정] 스테이지 목록이 0건이다 — 판정식이 실패한 것이다(O111 ㉠).')
    drift, stage_only, mount_only, ok = [], [], [], 0
    for rel, ssz in sorted(stage.items()):
        base = os.path.basename(rel)
        if base in DIR_MARKERS:
            continue
        if only_md and not rel.endswith('.md'):
            continue
        p = os.path.join(ROOT, rel)
        if not os.path.isfile(p):
            stage_only.append(rel)
            continue
        lsz = os.path.getsize(p)
        # 🔴 [O181] 판정 정본은 `accepted()` 집합이다(`expected()` 는 표시용 대표값).
        if ssz in accepted(lsz):
            ok += 1
        else:
            drift.append((rel, lsz, ssz, sorted(accepted(lsz))))
    for cur, _d, fs in os.walk(ROOT):
        rel_dir = os.path.relpath(cur, ROOT)
        if rel_dir == '.':
            rel_dir = ''
        if any((rel_dir + '/').startswith(u) for u in UNPUBLISHED_OK):
            continue
        for f in fs:
            rel = os.path.join(rel_dir, f) if rel_dir else f
            if only_md and not rel.endswith('.md'):
                continue
            if rel not in stage:
                mount_only.append(rel)

    print(f'대조 대상 {ok + len(drift)}건 · 일치 {ok} · 드리프트 {len(drift)}')
    print(f'스테이지 전용 {len(stage_only)}건 · 마운트 전용(미발행) {len(mount_only)}건')
    for rel, lsz, ssz, exp in drift[:40]:
        print(f'  🔴 드리프트 {rel} 마운트 {lsz} → 허용 {exp} · 스테이지 {ssz}')
    for rel in stage_only[:20]:
        print(f'  🟠 스테이지 전용 {rel}')
    for rel in mount_only[:20]:
        print(f'  🟠 미발행 {rel}')
    if drift:
        print('🔴 FAIL — 마운트와 스테이지가 다르다. '
              '🔴 방금 쓴 파일이면 수 초 뒤 재실행해 재현 여부를 먼저 보라(O165 D13 낡은 뷰).')
        return 1
    print('✅ PASS — 크기 패딩식 전건 성립(내용 드리프트 없음)')
    return 0


if __name__ == '__main__':
    sys.exit(run(only_md='--all' not in sys.argv))

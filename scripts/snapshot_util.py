#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""snapshot_util.py — `_archive/` 스냅샷을 만드는 **단일 경로**.

[2026-08-28 O109 신설 · 인수인계 §0-NNN ▣WWW ① 집행 도구]

🔴 이 도구가 푸는 결함 2건 (O108 자기검토 ㉣ · 인수 ②)
--------------------------------------------------------------------------
㉠ **라벨 하드코딩** — 스냅샷 이름의 세션 라벨이 소스에 박혀 있었다.
   `split_doc.py` 4개 지점이 각각 `O82-presplit` · `O107-prehub` ·
   `O83B-prerebalance` · `O107-pretooutdir` 로 고정돼 있어, **어느 세션이
   만든 스냅샷이든 그 옛 라벨로 기록**됐다.
   실증 = O109 가 돌린 `--rebalance` 의 스냅샷이
   `99_NEXT_SESSION.md.O83B-prerebalance` 로 남았다(O83-B 것이 아니다).
   ⇒ 스냅샷의 「누가·언제」가 **거짓**이 되므로 되돌림 판단의 근거가 못 된다.
㉡ 🔴🔴 **조용한 덮어쓰기** — 같은 base 를 재발행하면 `shutil.copyfile` 이
   기존 스냅샷을 **경고 없이 덮었다**. 실증 = O108 이 `00_INDEX` 를 3회
   republish 했으므로 **최초 상태는 이미 없다**.
   ⇒ 스냅샷은 이 워크스페이스의 **유일한 되돌리기 수단**이다
   (`R1-7-6`: `USER$` 는 `head == live` 라 redo 경로가 없다).
   그것을 덮는 것은 **되돌림 경로 파괴**이고 `R1-7-1`(조용한 소실)과 같은 뿌리다.

🟢 처방 — 이 모듈만 쓰면 두 결함이 원리적으로 재발하지 않는다
--------------------------------------------------------------------------
* **라벨은 인자로 받는다**(하드코딩 금지). 해소 순서 =
  ① 호출자가 넘긴 값 → ② 환경변수 `SESSION_LABEL` → ③ `UNLABELED`(경고).
  🔴 ③ 에서 **중단하지 않는다** — 스냅샷을 못 남기는 것이 라벨이 없는 것보다 나쁘다.
* **절대 덮지 않는다.** 같은 경로가 이미 있으면
  · 내용이 **바이트 동일**하면 재사용한다(멱등 · 파일 수 증가 0)
  · 다르면 `.2` · `.3` … **접미를 붙여 새로 만든다**(상한 `MAX_SUFFIX`)
  · 접미가 소진되면 `SnapshotError` 로 **중단**한다(조용한 소실보다 실패가 낫다).
* 바이트 단위로 복사한다(인코딩·개행 변환 없음 · 원본과 SHA256 동일).

사용법
--------------------------------------------------------------------------
    from snapshot_util import snapshot, add_label_arg, SnapshotError
    snap, status = snapshot(path, 'prerebalance', label=args.label)
    # status = 'created' | 'reused' | 'suffixed'

🔴 음성 테스트 = `scripts/test_snapshot_util.py`(R3-2 — 게이트·생성기를
   새로 만들면 음성 테스트를 같이 만든다).
"""

import hashlib
import io
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARCHIVE = os.path.join(ROOT, '_archive')

#: 라벨 미지정 시 읽는 환경변수. 세션 시작에 `export SESSION_LABEL=O109` 하면
#: 그 세션의 모든 스냅샷이 자동으로 옳은 라벨을 얻는다.
LABEL_ENV = 'SESSION_LABEL'

#: 라벨을 끝내 알 수 없을 때 쓰는 값. 🔴 중단하지 않는다(스냅샷 확보가 우선).
LABEL_FALLBACK = 'UNLABELED'

#: 접미 상한. 같은 op 스냅샷이 이만큼 쌓이면 사람이 정리해야 한다.
MAX_SUFFIX = 99


class SnapshotError(Exception):
    """스냅샷을 안전하게 만들 수 없을 때 던진다(덮어쓰기 대신 실패한다)."""


def resolve_label(explicit=None, env=None):
    """스냅샷 라벨을 정한다 — 인자 → 환경변수 → `UNLABELED`.

    🔴 하드코딩된 세션 라벨을 기본값으로 쓰지 마라(㉠ 의 재발 경로다).
    """
    if explicit:
        lab = str(explicit).strip()
        if lab:
            return _sanitize(lab)
    got = (env if env is not None else os.environ.get(LABEL_ENV, ''))
    got = str(got).strip()
    if got:
        return _sanitize(got)
    return LABEL_FALLBACK


def _sanitize(name):
    """파일명에 쓸 수 없는 문자를 막는다(경로 탈출 · 구분자 혼입 방지)."""
    bad = [os.sep, '/', '\\', '\n', '\r', '\t', '\0']
    for ch in bad:
        if ch in name:
            raise SnapshotError('라벨·연산명에 경로 구분자를 쓸 수 없다: %r' % name)
    if name in ('.', '..'):
        raise SnapshotError('라벨·연산명이 %r 일 수 없다' % name)
    return name


def sha256_bytes(data):
    return hashlib.sha256(data).hexdigest()


def _read_bytes(path):
    with io.open(path, 'rb') as fh:
        return fh.read()


def snapshot_name(path, op, label):
    """스냅샷 파일명 = `<base>.<label>-<op>` (기존 관례 유지)."""
    return '%s.%s-%s' % (os.path.basename(path), label, op)


def dated_snapshot_name(path, date_str):
    """확장자를 보존하는 날짜 기반 이름 = `foo.html` + `20260830` → `foo_20260830.html`.

    🆕 [2026-08-31 O126] **왜 별 이름 규칙이 필요한가** — 기본 `snapshot_name()` 은
    `foo.html.O126-prerun` 을 만든다. 이것은 `_archive/` 안에서 **`.html` 확장자가
    뒤로 밀려 브라우저가 열지 못한다**. 이력·원장처럼 「되돌리기용 원본」이면 무해하지만,
    **현업에 배포하는 산출물의 과거 판본**은 그 자체로 열려야 값이 있다.
    ⇒ 산출물 회전(rotation)에는 이 이름을, 문서 되돌리기에는 `snapshot_name()` 을 쓴다.
    🔴 두 규칙 모두 **이 모듈 안에** 둔다 — 호출자가 경로를 조립하면 `R1-7-10` 우회다.
    """
    stem, ext = os.path.splitext(os.path.basename(path))
    return '%s_%s%s' % (stem, date_str, ext)


def _collide_name(base_path, n, keep_ext):
    """충돌 시 후보 경로. `keep_ext` 면 접미를 **확장자 앞**에 넣는다.

    🔴 종전 규칙(`base.2`)을 바꾸지 않는다 — `keep_ext=False` 가 기본이다.
      `keep_ext=True` 일 때만 `foo_20260830_2.html` 처럼 확장자를 지킨다
      (그러지 않으면 회전 산출물이 두 번째 판본부터 열리지 않는다).
    """
    if not keep_ext:
        return '%s.%d' % (base_path, n)
    stem, ext = os.path.splitext(base_path)
    return '%s_%d%s' % (stem, n, ext)


def snapshot(path, op, label=None, archive=None, quiet=False, env=None,
             name=None, keep_ext=False):
    """`path` 를 `_archive/` 에 복사하고 `(스냅샷경로, 상태)` 를 돌려준다.

    상태 = `created`(새로 만들었다) · `reused`(바이트 동일 스냅샷이 이미 있다) ·
           `suffixed`(내용이 다른 스냅샷이 있어 접미를 붙여 새로 만들었다).

    🔴 **어떤 경우에도 기존 파일을 덮지 않는다.**

    🆕 [O126] `name` = 스냅샷 basename 을 직접 지정한다(기본 = `snapshot_name()`).
       `keep_ext` = 충돌 접미를 **확장자 앞**에 넣는다(산출물 회전용).
       🔴 둘 다 **기본값이 종전과 같다** ⇒ 기존 호출자 동작 불변.
    """
    if not os.path.exists(path):
        raise SnapshotError('스냅샷 원본이 없다: %s' % path)
    return snapshot_content(path, op, _read_bytes(path), label=label,
                            archive=archive, quiet=quiet, env=env,
                            name=name, keep_ext=keep_ext)


def snapshot_content(name_src, op, data, label=None, archive=None,
                     quiet=False, env=None, name=None, keep_ext=False):
    """**메모리 상의 내용**을 스냅샷한다 — 파일과 같은 덮어쓰기 금지 규칙을 쓴다.

    쓰이는 곳 = `--rebalance` 처럼 스냅샷 대상이 디스크의 한 파일이 아니라
    **조각 concat(논리 문서)** 인 경우. 이름은 `name_src` 의 basename 에서 만든다.
    `data` 는 bytes 또는 str(UTF-8 로 인코딩한다).

    🆕 [O126] `name` 을 주면 그 basename 을 쓴다(경로 구분자는 거부한다).
    """
    if not op or not str(op).strip():
        raise SnapshotError('연산명(op)이 비어 있다 — 스냅샷 이름을 만들 수 없다')
    op = _sanitize(str(op).strip())
    lab = resolve_label(label, env=env)
    arch = archive if archive is not None else ARCHIVE
    if not isinstance(data, bytes):
        data = data.encode('utf-8')
    if not os.path.isdir(arch):
        os.makedirs(arch)

    # 🔴 이름을 직접 받더라도 경로 탈출은 막는다(`_sanitize` 를 통과시킨다).
    fname = _sanitize(name) if name else snapshot_name(name_src, op, lab)
    base = os.path.join(arch, fname)
    cand = base
    n = 1
    while os.path.exists(cand):
        if _read_bytes(cand) == data:
            if not quiet:
                _emit(cand, 'reused', lab, data)
            return cand, 'reused'
        n += 1
        if n > MAX_SUFFIX:
            raise SnapshotError(
                '스냅샷 접미가 소진됐다(2~%d 전부 사용중) — `_archive/` 를 정리하라: %s'
                % (MAX_SUFFIX, os.path.basename(base)))
        cand = _collide_name(base, n, keep_ext)

    with io.open(cand, 'wb') as fh:
        fh.write(data)
    status = 'created' if cand == base else 'suffixed'
    if not quiet:
        _emit(cand, status, lab, data)
    return cand, status


def _emit(snap, status, label, src_bytes):
    rel = os.path.relpath(snap, ROOT)
    tag = {
        'created': '스냅샷',
        'reused': '스냅샷(기존 재사용 · 바이트 동일)',
        'suffixed': '🟠 스냅샷(기존 보존 · 접미 신설)',
    }[status]
    sys.stdout.write('%s = %s  [%s · %s B · %s]\n' % (
        tag, rel, label, format(len(src_bytes), ','), sha256_bytes(src_bytes)[:16]))
    if label == LABEL_FALLBACK:
        sys.stdout.write(
            '   🟠 라벨 미지정 — `--label O1NN` 또는 `export %s=O1NN` 을 쓰라'
            '(스냅샷의 「누가」가 비어 있다).\n' % LABEL_ENV)


def add_label_arg(ap, help_text=None):
    """argparse 파서에 `--label` 을 붙인다 — 🔴 기본값을 하드코딩하지 않는다."""
    ap.add_argument(
        '--label', default=None,
        help=help_text or ('스냅샷·포인터에 적을 세션 라벨(예: O109). 생략하면 환경변수 %s, '
                           '그것도 없으면 %s' % (LABEL_ENV, LABEL_FALLBACK)))
    return ap

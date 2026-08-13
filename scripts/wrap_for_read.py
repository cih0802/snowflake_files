#!/usr/bin/env python3
"""긴 줄(>2,000자) 파일을 `read` 툴로 **전량 확보**하기 위한 소프트랩 사본 생성기.

왜 필요한가 (2026-08-13 O67):
  지침 `R1-3-2` 는 「`read` 1회 2,000줄 · 1줄 2,000자 한도로 잘리면 offset/limit 을 옮겨
  끝까지 반복 호출」이라 규정하지만, **1줄이 2,000자를 넘는 경우는 offset 을 옮겨도 복원되지 않는다**
  (offset 은 줄 단위다). 그리고 `R1-3-4` 는 `cat`/`sed` 로 문서를 읽는 것을 금지한다
  — 출력 절단으로 내용이 손실되기 때문이다.
  ⇒ 두 조항을 모두 지키려면 **읽기 전용 사본에서 줄을 접는 것**이 한 경로다.
  🔴🔴 **[2026-08-13 O68 정정] 종전 이 자리의 「원문을 접을 수 없다」는 거짓이었다.**
  종전 기술: *"SV DDL 의 `COMMENT`·`AI_SQL_GENERATION` 과 Agent 스펙의 `instructions` 는
  구문상 한 줄에 들어가야 하므로 원문을 접을 수 없다"* ⇒ **실측으로 반증됐다**:
    · SQL `COMMENT` = 문자열 연결(`||`)은 **문법 오류**지만 **여러 줄 리터럴은 허용**되고
      개행이 값에 보존된다(스크래치 테이블 생성→확인→삭제로 실측). ⇒ 접을 수 있고, 대가는
      「값에 개행이 들어가므로 라이브 재배포가 필요하고 판정은 공백 정규화 후 완전 일치」다.
    · YAML `instructions` = 이중인용은 **줄 끝 `\\` 이스케이프 개행**, 단일인용은 **flow folding**
      으로 접힌다 ⇒ 값이 **바이트 완전 동일**하다(왕복 실측). 재배포조차 필요 없다.
  ⇒ 따라서 이 사본 생성기는 **「접을 수 없을 때의 유일한 수단」이 아니라 「원문을 아직 접지 않았을 때
     읽기 위한 보조 수단」**이다. 원문이 `R1-5` 를 지키면 이 스크립트는 필요하지 않다.
     🔴 위반을 정당화하는 근거로 인용하지 말 것 — O67 이 정확히 그렇게 썼다(O67-B A2).

계약:
  · 원문은 **읽기만** 한다. 사본은 `$HOME` 밖으로 나가지 않으며 산출물이 아니다.
  · 접는 위치에 `⏎` 표시를 남긴다 — 사본을 원문으로 착각하지 않도록.
  · 접기는 **문자 삭제·추가 0**(표시 문자 제외)이며 `--verify` 로 왕복 복원해 확인한다.
사용:
  python3 scripts/wrap_for_read.py <파일...> [--width 1200] [--outdir DIR]
"""
import sys
from pathlib import Path

MARK = '⏎'


def wrap_line(s, width):
    return [s[i:i + width] for i in range(0, len(s), width)] or ['']


def main():
    argv = sys.argv[1:]
    width = int(argv[argv.index('--width') + 1]) if '--width' in argv else 1200
    outdir = Path(argv[argv.index('--outdir') + 1]) if '--outdir' in argv else Path.home() / 'wrapped'
    files = [a for a in argv if not a.startswith('--') and not a.isdigit() and a not in
             {argv[argv.index('--outdir') + 1] if '--outdir' in argv else ''}]
    outdir.mkdir(parents=True, exist_ok=True)
    for fp in files:
        src = Path(fp)
        lines = src.read_text(encoding='utf-8').splitlines()
        out, restored = [], []
        for n, line in enumerate(lines, 1):
            if len(line) <= width:
                out.append(f'{n}| {line}')
                restored.append(line)
                continue
            parts = wrap_line(line, width)
            for k, p in enumerate(parts):
                tail = MARK if k < len(parts) - 1 else ''
                out.append(f'{n}.{k + 1}| {p}{tail}')
            restored.append(''.join(parts))
        assert restored == lines, f'복원 불일치: {src}'   # 문자 삭제·추가 0 자기검증
        # 🔴 basename 만 쓰면 충돌한다 — 실측: `agents/AGENT_MEMBER/agent_spec.yaml` 과
        #   `agents/AGENT_OVERALL/agent_spec.yaml` 이 같은 사본을 덮어써 MEMBER 판본이 사라졌다.
        #   ⇒ 부모 디렉터리를 이름에 포함한다.
        stem = f'{src.parent.name}__{src.name}' if src.parent.name else src.name
        dst = outdir / (stem + '.wrapped.txt')
        dst.write_text('\n'.join(out) + '\n', encoding='utf-8')
        over = sum(1 for line in lines if len(line) > width)
        print(f'{src.name}: {len(lines)}줄 · 접은 줄 {over} · 복원 일치 OK → {dst}')
    return 0


if __name__ == '__main__':
    sys.exit(main())

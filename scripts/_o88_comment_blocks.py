# 07_동적적재_GA4_EVENTS.sql 의 지정 구간을 주석 처리한다 (2026-08-19 O88).
# Co-authored with CoCo
#
# 왜 스크립트인가 (지침 R1-7-9)
#   대상 본문에 백틱·`$`(예: `$prune_from`)·`!` 가 들어 있다. 그것을 `bash -c` 인라인
#   python 문자열로 넘기면 셸이 백틱을 명령치환으로, `$` 를 변수로 해석해 **조용히 지워진다**
#   (2026-08-18 O83-H 실사고: 23줄에서 백틱 구간이 전부 삭제된 채 기록됐다).
#   ⇒ 파일로 쓰고 파일을 실행한다.
#
# 왜 아래에서 위로 처리하는가
#   마커 헤더를 삽입하면 그 아래 행번호가 밀린다. 역순 처리로 좌표 붕괴를 막는다.
#
# 판정
#   · 이미 '--' 로 시작하는 줄은 건드리지 않는다(이중 주석 방지 · 원문 보존).
#   · 처리 전후 줄 수 차이 = 삽입한 마커 줄 수와 정확히 일치해야 한다(자기검증).

import io
import sys

PATH = '/workspace/50_handoff/07_동적적재_GA4_EVENTS.sql'

# (시작행, 끝행, 마커 사유) — 1-based 포함 구간. 반드시 행번호 내림차순으로 둔다.
BLOCKS = [
    (1067, 1166,
     '부록 LOAD_SCHEMA_DYNAMIC — 범용 동적 로더(ML·BRONZE_CRM 등 타 스키마용).\n'
     '이 판의 대상은 BRONZE_BIGQUERY 적재뿐이므로 실행하지 않는다.\n'
     '이 문서 1110행이 스스로 "BRONZE_BIGQUERY 에는 쓰지 않는다" 고 못박고 있다.'),
    (928, 962,
     '8장 헤더 prefix 사전검증 — 스테이지 전량 CSV 헤더 스캔이라 3개월 샘플링 취지와 어긋난다.\n'
     '🔴 대가 = 이것이 위치 기반 적재의 유일한 사전 방어선이다(0장 (3)ⓑ).\n'
     '   이 판은 사후 확증(7장 (2) + 엄격 PARSE_JSON)으로 대체한다 — 상세·한계는 0-B장.'),
    (883, 886,
     '7장 (6) 프루닝 실측 — CLUSTER BY 불필요는 구 계정에서 이미 확정됐다(3,006 중 19 파티션).\n'
     '3개월 샘플에서 다시 재도 판정이 달라지지 않는다.'),
    (866, 871,
     '7장 (5) EVENT_DT ↔ "event_date" 불일치 — 구 계정 911테이블 전수 0건으로 확정됐다.'),
    (795, 808,
     '7장 (4) VARIANT 파싱 확인 — 엄격 PARSE_JSON 이므로 파싱 실패는 COPY 중단으로 먼저 드러난다.'),
    (781, 785,
     '7장 (3) 중복 적재 검출 — 64일 경과 재실행이 없는 단발 적재라 이번 범위에서는 발생 경로가 없다.\n'
     '⚠️ 64일 이후 재적재하거나 files>0 이 반복되면 이 블록을 되살려 먼저 확인할 것.'),
]

MARK = '-- 🔴🔴 [2026-08-19 O88] 아래 블록은 주석 처리했다 (경계 근거 = 0-B장).'
NOTE = '--    되살리려면 이 마커부터 블록 끝까지 선행 "-- " 를 제거한다.'


def main() -> int:
    with io.open(PATH, 'r', encoding='utf-8') as fh:
        lines = fh.read().split('\n')

    n_before = len(lines)
    inserted = 0
    commented = 0

    for start, end, reason in BLOCKS:
        # 1-based → 0-based
        i0, i1 = start - 1, end - 1
        for i in range(i0, i1 + 1):
            s = lines[i]
            if s.lstrip().startswith('--'):
                continue
            if s.strip() == '':
                continue
            lines[i] = '-- ' + s
            commented += 1
        header = [MARK]
        for ln in reason.split('\n'):
            header.append('--    ' + ln)
        header.append(NOTE)
        lines[i0:i0] = header
        inserted += len(header)

    with io.open(PATH, 'w', encoding='utf-8') as fh:
        fh.write('\n'.join(lines))

    n_after = len(lines)
    print('lines %d -> %d (delta %d) | inserted %d | commented %d'
          % (n_before, n_after, n_after - n_before, inserted, commented))
    if n_after - n_before != inserted:
        print('FAIL: 줄 수 증가분이 삽입 마커 수와 다르다')
        return 1
    print('PASS: 줄 수 자기검증 통과')
    return 0


if __name__ == '__main__':
    sys.exit(main())

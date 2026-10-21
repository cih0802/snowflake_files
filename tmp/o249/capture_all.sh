#!/bin/sh
# O249 — 체크리스트 ② 캡처 15종(SR61467) · 결과 = /tmp/capture.log
cd /workspace
D="85_실제 인수인계 문서"
run() { python3 scripts/env_capture.py --id "$1" "$2" </dev/null >>/tmp/capture.log 2>&1; echo "RC $1 $?" >>/tmp/capture.log; }
: >/tmp/capture.log
run A0  "$D/10_실무자_인수인계/A0_환경실사_baseline.sql"
run A1  "$D/10_실무자_인수인계/A1_운영자가이드_근거.sql"
run A2  "$D/10_실무자_인수인계/A2_롤별_접근권한_근거.sql"
run A3  "$D/10_실무자_인수인계/A3_CoCo_ANALYST_차단_근거.sql"
run A6  "$D/10_실무자_인수인계/A6_일배치_장애대응_런북.sql"
run A7  "$D/10_실무자_인수인계/A7_정기점검_근거.sql"
run B1  "$D/_근거쿼리/B1_구조_근거.sql"
run B2  "$D/_근거쿼리/B2_지표_근거.sql"
run D10 "$D/_근거쿼리/D10_운영매뉴얼_근거.sql"
run D12 "$D/_근거쿼리/D12_현업활용_근거.sql"
run N01 "$D/_근거쿼리/N01_DMF_사전점검.sql"
run N04 "$D/_근거쿼리/N04_배치SLA_근거.sql"
run N05 "$D/_근거쿼리/N05_테스트결과_근거.sql"
run N06 "$D/_근거쿼리/N06_비용_근거.sql"
run N08 "$D/_근거쿼리/N08_완료보고_근거.sql"
echo CAPTURE_DONE >>/tmp/capture.log

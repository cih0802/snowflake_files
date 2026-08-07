#!/bin/sh
# /workspace 마운트 사망 시 스테이지에서 작업 사본을 재구성한다(운영 지뢰 §10 우회).
#
# 🔴 2026-08-06 발견 — 디렉터리 단위 `cortex ws cp <dir>/` 는 **하위 디렉터리를 상위로 플래튼**한다.
#    그 결과 `_archive/202607/04_*.csv` 가 현재본 `04_*.csv` 를 조용히 덮어써
#    **아카이브 판본을 현재본으로 착각**하게 만든다(실측: 132,608B → 15,701B).
#    ⇒ 반드시 `cortex ws ls` 로 파일 목록을 받아 **파일 단위**로 내려받는다.
# 사용: sh /tmp/mirror.sh [경로접두 ...]     (기본 = 아래 ROOTS)
set -e
WSREF='USER$.PUBLIC."snowflake_files"'
ROOTS="${*:-scripts 30_output_share 03_top-down_gold 99_provided_definition 20_issue 05_SV-Agent_ai 02_GN_DW_building 10_dbt_pipeline cortex_project}"
mkdir -p /tmp/ws
for r in $ROOTS; do
  cortex ws ls "$WSREF:/$r/" --no-header 2>/dev/null | awk '{print $1}' \
    | sed 's|^/versions/[^/]*/||' | grep -v '/\.folder$' \
    | grep -v '^10_dbt_pipeline/target/' | grep -v '^10_dbt_pipeline/logs/' \
  > /tmp/_files.txt
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    d=$(dirname "$p")
    mkdir -p "/tmp/ws/$d"
    [ -f "/tmp/ws/$p" ] && continue
    cortex ws cp "$WSREF:/$p" "/tmp/ws/$d/" >/dev/null 2>&1 || echo "MISS $p"
  done < /tmp/_files.txt
  echo "$r: $(grep -c . /tmp/_files.txt) files"
done
echo "mirror ready: $(find /tmp/ws -type f | wc -l) files"

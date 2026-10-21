#!/bin/sh
# 사용: sync80.sh <시작줄> <개수>  — ch80.txt 의 상대경로를 workspace 80번에 반영(원본 백업이 없으면 먼저 백업)
W="/workspace/80_인수인계_프로젝트완료 및 유지보수용"; B="/workspace/95_작업기록_인수인계정제/_backup_80_원본_20261021"
sed -n "$1,$(($1+$2-1))p" ~/w/ch80.txt | while IFS= read -r rel; do
  [ -f "$B/$rel" ] || { mkdir -p "$B/$(dirname "$rel")"; cp "$HOME/w/80_orig/$rel" "$B/$rel"; }
  cp "$HOME/w/80/$rel" "$W/$rel"
done
echo "batch $1 done"

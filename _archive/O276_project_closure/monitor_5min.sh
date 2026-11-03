#!/bin/sh
# 5분(300초)마다 O276 잔여 이동 진행률과 통계를 기록하는 모니터링 데몬
LOG_FILE="/workspace/_archive/O276_project_closure/status_5min.log"
echo "=== O276 5분 자동 모니터링 시작: $(date) ===" > "$LOG_FILE"

while true; do
    STAT=$(python3 /workspace/_archive/O276_project_closure/o276_resume.py </dev/null 2>&1)
    PROG=$(cat /workspace/_archive/O276_project_closure/_progress.txt 2>/dev/null || echo "0")
    # rows 5477 already XXXX to_move YYYY problems Z
    ALREADY=$(echo "$STAT" | grep -o 'already [0-9]*' | awk '{print $2}')
    TO_MOVE=$(echo "$STAT" | grep -o 'to_move [0-9]*' | awk '{print $2}')
    if [ -n "$ALREADY" ] && [ -n "$TO_MOVE" ]; then
        PCT=$(awk "BEGIN {printf \"%.2f\", ($ALREADY / 5477) * 100}")
        MIN_LEFT=$(awk "BEGIN {printf \"%.1f\", $TO_MOVE / 30}")
        echo "[$(date '+%Y-%m-%d %H:%M:%S UTC')] 진행률: ${PCT}% | 완료: ${ALREADY}/5477 | 잔여: ${TO_MOVE}건 | 예상잔여: 약 ${MIN_LEFT}분" >> "$LOG_FILE"
        if [ "$TO_MOVE" = "0" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S UTC')] 🎉 이동 작업 전체 완료!" >> "$LOG_FILE"
            break
        fi
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S UTC')] 상태 조회 중... (current progress: $PROG)" >> "$LOG_FILE"
    fi
    sleep 300
done

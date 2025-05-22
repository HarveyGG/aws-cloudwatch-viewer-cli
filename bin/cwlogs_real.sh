#!/bin/bash

REGION="us-west-2"
DEFAULT_LOG_GROUP="UNIEXPRESS-OLD-PRODUCTION-ASG-QA-CA"
DEFAULT_RANGE="1h"
TIME_RANGE="$DEFAULT_RANGE"

declare -A LOG_STREAM_MAP=(
  ["delivery20"]="container-delivery_2_api-ip.*"
  ["delivery15"]="delivery_service_dsp_api-"
  ["delivery15-job"]="delivery_service_dsp_queue_delivery2-"
  ["dispatch"]="container-dispatch_service_api-ip"
  ["dispatch-job"]="container-dispatch_service_queue_dispatch-ip"
  ["common"]="container-common_service_api-"
  ["common-job"]="container-common_service_queue_"
)

POSITIONAL=()

# 参数解析
HIGHLIGHT_PATTERNS=""
POSITIONAL=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --range=*)
      TIME_RANGE="${1#*=}"
      shift
      ;;
    --range)
      TIME_RANGE="$2"
      shift 2
      ;;
    --highlight=*)
      HIGHLIGHT_PATTERNS="${1#*=}"
      shift
      ;;
    --highlight)
      HIGHLIGHT_PATTERNS="$2"
      shift 2
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

set -- "${POSITIONAL[@]}"
SHORT_NAME="$1"
KEYWORD_FILTER="$2"
LOG_GROUP="$3"

if [ -z "$SHORT_NAME" ]; then
  echo "❌ Usage: $0 <logStream-alias> [message-keyword] [logGroup] [--range=5m|30m|1h]"
  echo "🔁 Available aliases:"
  for key in "${!LOG_STREAM_MAP[@]}"; do
    echo "   $key → ${LOG_STREAM_MAP[$key]}"
  done
  exit 1
fi

LOG_GROUP="${LOG_GROUP:-$DEFAULT_LOG_GROUP}"

# 匹配 log stream 正则
LOG_STREAM_FILTER="${LOG_STREAM_MAP[$SHORT_NAME]}"
echo "🔍 Mapped alias '$SHORT_NAME' to: $LOG_STREAM_FILTER"
if [ -z "$LOG_STREAM_FILTER" ]; then
  echo "❌ Unknown alias: '$SHORT_NAME'"
  echo "🔁 Available aliases:"
  for key in "${!LOG_STREAM_MAP[@]}"; do
    echo "   $key → ${LOG_STREAM_MAP[$key]}"
  done
  exit 1
fi

# 处理时间范围
case "$TIME_RANGE" in
  5m)  START_TIME=$(($(date +%s) - 300)) ;;
  30m) START_TIME=$(($(date +%s) - 1800)) ;;
  1h)  START_TIME=$(($(date +%s) - 3600)) ;;
  *)   echo "❌ Invalid --range value: $TIME_RANGE. Use 5m, 30m, or 1h"; exit 1 ;;
esac

END_TIME=$(date +%s)

# 构建 Insights 查询
QUERY="fields @message | filter @logStream like /$LOG_STREAM_FILTER/"
if [ -n "$KEYWORD_FILTER" ]; then
  QUERY="$QUERY | filter @message like /$KEYWORD_FILTER/"
fi
QUERY="$QUERY | sort @timestamp desc | limit 1000"

echo "🚀 Running query:"
echo "   Log Alias:     $SHORT_NAME"
echo "   Real Filter:   $LOG_STREAM_FILTER"
echo "   Keyword:       ${KEYWORD_FILTER:-<none>}"
echo "   Log Group:     $LOG_GROUP"
echo "   Time Range:    $TIME_RANGE"

# 执行查询
QUERY_ID=$(aws logs start-query \
  --region "$REGION" \
  --log-group-names "$LOG_GROUP" \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --query-string "$QUERY" \
  --query 'queryId' \
  --output text)

if [ -z "$QUERY_ID" ]; then
  echo "❌ Failed to start query."
  exit 1
fi

echo "⏳ Query ID: $QUERY_ID"

# 等待查询完成
MAX_RETRIES=30
RETRY=0
while [ $RETRY -lt $MAX_RETRIES ]; do
  STATUS=$(aws logs get-query-results \
    --query-id "$QUERY_ID" \
    --region "$REGION" \
    --query 'status' \
    --output text 2>/dev/null)

  if [ "$STATUS" = "Complete" ]; then
    echo "✅ Query complete!"
    break
  elif [ "$STATUS" = "Failed" ] || [ "$STATUS" = "Cancelled" ]; then
    echo "❌ Query failed or cancelled. Status: $STATUS"
    exit 1
  fi

  echo "⌛ Waiting... ($RETRY/$MAX_RETRIES) Status: $STATUS"
  sleep 2
  ((RETRY++))
done

if [ "$STATUS" != "Complete" ]; then
  echo "⚠️ Timed out waiting for query to complete."
  exit 1
fi

RESULT_JSON=$(aws logs get-query-results --query-id "$QUERY_ID" --region "$REGION")

# 处理 --keep 参数
KEEP_HTML=false
for arg in "$@"; do
  if [[ "$arg" == "--keep" ]]; then
    KEEP_HTML=true
    break
  fi
done

# 写入 /tmp 目录
HTML_FILE="/tmp/cloudwatch_logs_$(date +%Y%m%d_%H%M%S).html"

# 写入 HTML 表头
cat <<EOF > "$HTML_FILE"
<html>
<head>
  <meta charset='UTF-8'>
  <title>CloudWatch Logs</title>
  <style>
    body { font-family: sans-serif; padding: 20px; }
    table { border-collapse: collapse; width: 100%; }
    th, td { border: 1px solid #ddd; padding: 8px; }
    th { background-color: #f4f4f4; text-align: left; }
    tr:hover { background-color: #f1f1f1; }
    pre { margin: 0; white-space: pre-wrap; }
    mark { background-color: yellow; }
  </style>
</head>
<body>
  <h2>CloudWatch Logs ($SHORT_NAME - $TIME_RANGE)</h2>
  <table>
    <tr><th>Message</th></tr>
EOF

# 高亮函数
highlight_msg() {
  local raw="$1"
  local patterns="$HIGHLIGHT_PATTERNS"
  if [ -z "$patterns" ]; then
    echo "$raw"
    return
  fi
  for keyword in $(echo "$patterns" | tr '|' ' '); do
    raw=$(echo "$raw" | sed -E "s/($keyword)/<mark>\1<\/mark>/Ig")
  done
  echo "$raw"
}

# 写入内容
echo "$RESULT_JSON" | jq -c '.results[]' | while read -r row; do
  raw_msg=$(echo "$row" | jq -r '.[] | select(.field=="@message").value')
  msg=$(highlight_msg "$raw_msg")
  echo "<tr><td><pre>$msg</pre></td></tr>" >> "$HTML_FILE"
done

# 写入 HTML 尾部
cat <<EOF >> "$HTML_FILE"
  </table>
</body>
</html>
EOF

# 打开浏览器
if which open >/dev/null; then
  open "$HTML_FILE"
elif which xdg-open >/dev/null; then
  xdg-open "$HTML_FILE"
else
  echo "✅ HTML saved to: $HTML_FILE"
fi

# 删除逻辑
if [ "$KEEP_HTML" = false ]; then
  echo "🧹 This file will be deleted after 5 seconds..."
  sleep 5
  rm -f "$HTML_FILE"
else
  echo "📄 Kept file: $HTML_FILE"
fi


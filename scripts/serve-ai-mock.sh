#!/usr/bin/env bash
#
# serve-ai-mock.sh — coconutH5App AI 工具 mock 服务启动器（house 风格包装）
#
# 直接转发 flags 给 node scripts/ai-mock-server.mjs：
#   --port <n>    监听端口（默认 8043）
#   --delay <ms>  模拟推理延迟基数（默认 600）
#   --quiet       只输出错误
#   -h|--help     显示帮助
#
# 退出码：透传 node 进程（0 正常退出 / 1 端口占用 / 2 参数错误）
#
# 模拟器访问地址（与 serve-hot-update.sh 同语义）：
#   iOS sim : http://localhost:8043
#   Android : http://10.0.2.2:8043（或 adb reverse tcp:8043 tcp:8043）
#   Harmony : hdc rport tcp:8043 tcp:8043 后 http://127.0.0.1:8043

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVER="$REPO_ROOT/scripts/ai-mock-server.mjs"

if [[ ! -f "$SERVER" ]]; then
  echo "✗ Missing: $SERVER" >&2
  exit 2
fi

for arg in "$@"; do
  if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
    sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
    echo "node flags 透传：--port <n> / --delay <ms> / --quiet（详见 ai-mock-server.mjs 头注释）"
    exit 0
  fi
done

exec node "$SERVER" "$@"

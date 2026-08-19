#!/usr/bin/env bash
#
# serve-hot-update.sh — 热更新 e2e fixture 服务器
#
# 从 Android bundled 离线包拷出 demo 模块 → bump patch 版本 → index.html 注入
# marker（<div>HOT UPDATE vX.Y.Z</div>）→ 重算 manifest（fileHashes/md5，镜像
# build-offline-package.sh 的算法）→ python3 http.server 起在 8000 端口。
#
# 目录形态 = 远端更新服务器：<serve-root>/manifest.json + 文件平铺
# （native 端 manifestUrl = http://<host>:8000/manifest.json，
#   文件从 http://<host>:8000/<file> 逐个下载）。
#
# 模拟器访问地址：
#   Android : http://10.0.2.2:8000/manifest.json
#   iOS sim : http://localhost:8000/manifest.json
#   Harmony : http://<Mac 局域网 IP>:8000/manifest.json
#
# Flags:
#   --corrupt   篡改 manifest 里一个 fileHashes 条目（e2e 失败路径：
#               更新被拒 + 旧版本原封不动）
#   --quiet     只输出错误
#   -h|--help   显示帮助
#
# 退出码：
#   0 = 服务器正常退出（Ctrl-C）
#   1 = 端口被占用
#   2 = 源缺失 / 参数错误
#
# 注意：Mac 首次跑 python3 http.server 可能弹防火墙授权窗口，允许即可。

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$REPO_ROOT/AndroidWebBox/app/src/main/assets/coconut-web/demo"
PORT=8000

CORRUPT=0
QUIET=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --corrupt) CORRUPT=1; shift ;;
    --quiet) QUIET=1; shift ;;
    -h|--help)
      sed -n '2,35p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Unknown flag: $1" >&2; exit 2 ;;
  esac
done

log()   { [[ "$QUIET" -eq 0 ]] && echo "$@" || true; }
errlog() { echo "$@" >&2; }

# 1. 前置校验 + 读源版本
if [[ ! -f "$SRC_DIR/manifest.json" ]]; then
  errlog "✗ Missing: $SRC_DIR/manifest.json (run scripts/build-offline-package.sh first)"
  exit 2
fi
OLD_VERSION="$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$SRC_DIR/manifest.json" | head -1)"
if [[ -z "$OLD_VERSION" ]]; then
  errlog "✗ Cannot read version from source manifest"
  exit 2
fi

# 2. bump patch：1.0.0 → 1.0.1
MAJOR="${OLD_VERSION%%.*}"
REST="${OLD_VERSION#*.}"
MINOR="${REST%%.*}"
PATCH="${REST##*.}"
NEW_VERSION="$MAJOR.$MINOR.$((PATCH + 1))"

# 3. 组装 serving 目录
SERVE_DIR="$(mktemp -d /tmp/coconut-hotupdate.XXXXXX)"
cp -R "$SRC_DIR/." "$SERVE_DIR/"
rm -f "$SERVE_DIR/manifest.json"
find "$SERVE_DIR" -name '.DS_Store' -delete

# 4. 注 marker 到 index.html（<body> 之后）
MARKER="<div>HOT UPDATE v$NEW_VERSION</div>"
if ! sed -i '' "s|<body>|<body>$MARKER|" "$SERVE_DIR/index.html"; then
  errlog "✗ Failed to inject marker into index.html"
  exit 2
fi
if ! grep -q "$MARKER" "$SERVE_DIR/index.html"; then
  errlog "✗ Marker not found after injection"
  exit 2
fi

# 5. 重算 manifest（镜像 build-offline-package.sh：排序遍历 + md5 -q + combined md5）
cd "$SERVE_DIR"
MANIFEST_FILES_JSON=""
FILE_HASHES_JSON=""
COMBINED=""
while IFS= read -r f; do
  H="$(md5 -q "$f")"
  MANIFEST_FILES_JSON+="${MANIFEST_FILES_JSON:+,}\"$f\""
  FILE_HASHES_JSON+="${FILE_HASHES_JSON:+,}\"$f\":\"$H\""
  COMBINED+="$H"
done < <(find . -type f | sed 's|^\./||' | sort)

if [[ "$CORRUPT" -eq 1 ]]; then
  # 篡改 index.html 的 hash（更新应被 md5 校验拒绝）。glob 必须吃掉原 hash，
  # 只插 closing quote 会留下旧值拼在后面 → JSON 解析直接失败（测不到 md5 路径）。
  FILE_HASHES_JSON="${FILE_HASHES_JSON/\"index.html\":\"[0-9a-f]*\"/\"index.html\":\"deadbeefdeadbeefdeadbeefdeadbeef\"}"
  log "☠ --corrupt: index.html fileHashes entry tampered (update must be rejected)"
fi

PKG_MD5="$(printf '%s' "$COMBINED" | md5 -q)"
cat > manifest.json <<EOF
{
  "moduleId": "demo",
  "version": "$NEW_VERSION",
  "entry": "index.html",
  "files": [${MANIFEST_FILES_JSON}],
  "md5": "$PKG_MD5",
  "fileHashes": {${FILE_HASHES_JSON}}
}
EOF

# 6. 起服务器（前台，Ctrl-C 退出）
log "📦 Hot update fixture: demo v$OLD_VERSION → v$NEW_VERSION, marker: $MARKER"
log "📂 Serving: $SERVE_DIR"
log "🌐 manifest: http://localhost:$PORT/manifest.json"
log "   Android emulator: http://10.0.2.2:$PORT/manifest.json"
log "   Harmony emulator: http://<Mac-LAN-IP>:$PORT/manifest.json"
if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  errlog "✗ Port $PORT already in use"
  rm -rf "$SERVE_DIR"
  exit 1
fi
python3 -m http.server "$PORT" -d "$SERVE_DIR"
STATUS=$?
rm -rf "$SERVE_DIR"
exit $STATUS

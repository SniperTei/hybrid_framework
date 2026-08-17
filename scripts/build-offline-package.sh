#!/usr/bin/env bash
#
# build-offline-package.sh — 构建 coconutWebBox 离线包并分发到三端 native 资源目录
#
# 流程：
#   1. npm run build（vite，base './' + 无 hash 文件名，见 vite.config.js）→ dist/
#   2. dist/ 产物 + 生成的 manifest.json 组装到 staging 的 coconut-web/<moduleId>/
#   3. staging 复制到三端（每次全量重建，drift 不可能）：
#      Android : AndroidWebBox/app/src/main/assets/coconut-web/demo/
#      iOS     : iOSWebBox/iOSWebBox/coconut-web/demo/
#      Harmony : HarmonyWebBox/entry/src/main/resources/rawfile/coconut-web/demo/
#
# manifest.json 是 Android OfflineResourceManager ModuleVersion 解析器的超集
# （fileHashes 本轮 native 不消费，为热更新预留）。
#
# Flags:
#   --check   只构建 + diff 三端已有目录（dry-run，CI 可用）；exit 1 表示不一致
#   --quiet   只输出错误
#
# 退出码：
#   0 = 构建并分发成功（--check 时 = 三端一致）
#   1 = --check 发现不一致
#   2 = 源缺失 / 构建失败 / 参数错误

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
H5_DIR="$REPO_ROOT/coconutWebBox"
MODULE_ID="demo"

ANDROID_BASE="$REPO_ROOT/AndroidWebBox/app/src/main/assets/coconut-web"
IOS_BASE="$REPO_ROOT/iOSWebBox/iOSWebBox/coconut-web"
HARMONY_BASE="$REPO_ROOT/HarmonyWebBox/entry/src/main/resources/rawfile/coconut-web"

CHECK_ONLY=0
QUIET=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) CHECK_ONLY=1; shift ;;
    --quiet) QUIET=1; shift ;;
    -h|--help)
      sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Unknown flag: $1" >&2; exit 2 ;;
  esac
done

log()   { [[ "$QUIET" -eq 0 ]] && echo "$@" || true; }
errlog() { echo "$@" >&2; }

# 1. 前置校验
if [[ ! -f "$H5_DIR/package.json" ]]; then
  errlog "✗ Missing: $H5_DIR/package.json"
  exit 2
fi
VERSION="$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$H5_DIR/package.json" | head -1)"
if [[ -z "$VERSION" ]]; then
  errlog "✗ Cannot read version from $H5_DIR/package.json"
  exit 2
fi

# 2. 构建（--check 也重建：确定性构建是 diff 的前提；dist/ 是纯构建产物）
log "🔨 Building coconutWebBox (v$VERSION) ..."
if [[ "$QUIET" -eq 1 ]]; then
  (cd "$H5_DIR" && npm run build --silent >/dev/null) || {
    errlog "✗ vite build failed"
    exit 2
  }
else
  (cd "$H5_DIR" && npm run build --silent) || {
    errlog "✗ vite build failed"
    exit 2
  }
fi
if [[ ! -f "$H5_DIR/dist/index.html" ]]; then
  errlog "✗ Build output missing: $H5_DIR/dist/index.html"
  exit 2
fi

# 3. 组装 staging 包：dist/ → coconut-web/<moduleId>/ + manifest.json
STAGING="$(mktemp -d /tmp/coconut-offline-pkg.XXXXXX)"
trap 'rm -rf "$STAGING"' EXIT
PKG_DIR="$STAGING/$MODULE_ID"
mkdir -p "$PKG_DIR"
cp -R "$H5_DIR/dist/." "$PKG_DIR/"
find "$PKG_DIR" -name '.DS_Store' -delete

cd "$PKG_DIR"
MANIFEST_FILES_JSON=""
FILE_HASHES_JSON=""
COMBINED=""
while IFS= read -r f; do
  H="$(md5 -q "$f")"
  MANIFEST_FILES_JSON+="${MANIFEST_FILES_JSON:+,}\"$f\""
  FILE_HASHES_JSON+="${FILE_HASHES_JSON:+,}\"$f\":\"$H\""
  COMBINED+="$H"
done < <(find . -type f | sed 's|^\./||' | sort)

PKG_MD5="$(printf '%s' "$COMBINED" | md5 -q)"
cat > manifest.json <<EOF
{
  "moduleId": "$MODULE_ID",
  "version": "$VERSION",
  "entry": "index.html",
  "files": [${MANIFEST_FILES_JSON}],
  "md5": "$PKG_MD5",
  "fileHashes": {${FILE_HASHES_JSON}}
}
EOF
log "📝 manifest.json: $MODULE_ID v$VERSION, $(find "$PKG_DIR" -type f ! -name manifest.json | wc -l | tr -d ' ') files"

# 4. 分发 / diff 三端
MISMATCH=0
for spec in "android:$ANDROID_BASE" "ios:$IOS_BASE" "harmony:$HARMONY_BASE"; do
  platform="${spec%%:*}"
  tgt="${spec#*:}/$MODULE_ID"
  if [[ "$CHECK_ONLY" -eq 1 ]]; then
    if [[ ! -d "$tgt" ]]; then
      errlog "✗ [$platform] missing: $tgt"
      MISMATCH=1
      continue
    fi
    if ! diff -r "$PKG_DIR" "$tgt" >/dev/null 2>&1; then
      errlog "✗ [$platform] differs: $tgt"
      MISMATCH=1
    else
      log "  ✓ [$platform] in sync"
    fi
  else
    rm -rf "$tgt"
    mkdir -p "$tgt"
    cp -R "$PKG_DIR/." "$tgt/"
    find "$tgt" -name '.DS_Store' -delete
    log "  ✓ [$platform] $tgt"
  fi
done

# 5. 结果
if [[ "$CHECK_ONLY" -eq 1 ]]; then
  if [[ "$MISMATCH" -eq 0 ]]; then
    log "✅ Offline package in sync across 3 platforms."
    exit 0
  else
    errlog "❌ Mismatches found. Run without --check to rebuild + distribute."
    exit 1
  fi
else
  log "✅ Offline package $MODULE_ID v$VERSION built + distributed to 3 platforms."
  log "   Verify with: bash scripts/build-offline-package.sh --check"
  exit 0
fi

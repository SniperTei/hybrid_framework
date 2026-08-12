#!/usr/bin/env bash
#
# sync-h5-assets.sh — 把 coconutWebBox/public/ 的 H5 资源同步到三端 native 资源目录
#
# 当前同步两个文件（v3.2.0+ 起 coconut.js 从 coconut_index.html 拆出来独立 bundle）：
#   1. coconut.js           —— SDK 源文件
#   2. coconut_index.html   —— 三端共享 conformance test 页
#
# Source of truth：coconutWebBox/public/
# 目标三端：
#   Android  : AndroidWebBox/app/src/main/assets/
#   iOS      : iOSWebBox/iOSWebBox/
#   Harmony  : HarmonyWebBox/entry/src/main/resources/rawfile/
#
# Flags:
#   --check   只 diff 不 cp（dry-run，CI 可用）；exit 1 表示有不一致
#   --quiet   只输出错误
#
# 退出码：
#   0 = 全一致（--check）或同步成功
#   1 = --check 发现不一致
#   2 = 源文件缺失或参数错误

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="$REPO_ROOT/coconutWebBox/public"

# 目标三端目录（路径前缀，文件名后拼）
ANDROID_DIR="$REPO_ROOT/AndroidWebBox/app/src/main/assets"
IOS_DIR="$REPO_ROOT/iOSWebBox/iOSWebBox"
HARMONY_DIR="$REPO_ROOT/HarmonyWebBox/entry/src/main/resources/rawfile"

FILES=(
  "coconut.js"
  "coconut.d.ts"
  "coconut_index.html"
)

CHECK_ONLY=0
QUIET=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) CHECK_ONLY=1; shift ;;
    --quiet) QUIET=1; shift ;;
    -h|--help)
      sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Unknown flag: $1" >&2; exit 2 ;;
  esac
done

log()   { [[ "$QUIET" -eq 0 ]] && echo "$@" || true; }
errlog() { echo "$@" >&2; }

# 1. 校验源文件存在
for f in "${FILES[@]}"; do
  if [[ ! -f "$SOURCE_DIR/$f" ]]; then
    errlog "✗ Source missing: $SOURCE_DIR/$f"
    errlog "  (coconut_index.html 不在 coconutWebBox/public/ 是正常情况 ——"
    errlog "   三端 coconut_index.html 由 coconutWebBox 源生成或独立维护。"
    errlog "   若要纳入同步，请把任意一端 copy 放到 coconutWebBox/public/)"
    # coconut_index.html 不一定在源目录 —— 只 warn，不 fatal
    if [[ "$f" == "coconut.js" || "$f" == "coconut.d.ts" ]]; then
      errlog "  $f 是必需源文件，缺失无法继续。"
      exit 2
    fi
  fi
done

# 计算需要同步的文件列表（只含源存在的）
SYNC_FILES=()
for f in "${FILES[@]}"; do
  if [[ -f "$SOURCE_DIR/$f" ]]; then
    SYNC_FILES+=("$f")
  fi
done

if [[ ${#SYNC_FILES[@]} -eq 0 ]]; then
  errlog "✗ No source files to sync."
  exit 2
fi

# 2. 同步或 diff
MISMATCH=0

sync_file() {
  local file="$1"
  local src="$SOURCE_DIR/$file"
  local -a targets=(
    "$ANDROID_DIR/$file"
    "$IOS_DIR/$file"
    "$HARMONY_DIR/$file"
  )

  for tgt in "${targets[@]}"; do
    local platform
    case "$tgt" in
      */AndroidWebBox/*)    platform="android" ;;
      */iOSWebBox/*)        platform="ios" ;;
      */HarmonyWebBox/*)    platform="harmony" ;;
      *)                    platform="unknown" ;;
    esac

    if [[ "$CHECK_ONLY" -eq 1 ]]; then
      if [[ ! -f "$tgt" ]]; then
        errlog "✗ [$platform] missing: $tgt"
        MISMATCH=1
        continue
      fi
      if ! diff -q "$src" "$tgt" >/dev/null 2>&1; then
        errlog "✗ [$platform] differs: $tgt"
        MISMATCH=1
      fi
    else
      mkdir -p "$(dirname "$tgt")"
      cp "$src" "$tgt"
      log "  ✓ [$platform] $file"
    fi
  done
}

for f in "${SYNC_FILES[@]}"; do
  if [[ "$CHECK_ONLY" -eq 1 ]]; then
    log "🔍 Checking $f..."
  else
    log "📦 Syncing $f →"
  fi
  sync_file "$f"
done

# 3. 结果
if [[ "$CHECK_ONLY" -eq 1 ]]; then
  if [[ "$MISMATCH" -eq 0 ]]; then
    log "✅ All ${#SYNC_FILES[@]} file(s) in sync across 3 platforms."
    exit 0
  else
    errlog "❌ Mismatches found. Run without --check to sync."
    exit 1
  fi
else
  log "✅ Synced ${#SYNC_FILES[@]} file(s) to 3 platforms."
  log "   Verify with: bash scripts/sync-h5-assets.sh --check"
  exit 0
fi

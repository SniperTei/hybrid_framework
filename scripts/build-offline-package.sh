#!/usr/bin/env bash
#
# build-offline-package.sh — 构建 H5 离线包并分发到三端 native 资源目录
#
# 模块注册表（moduleId → 项目目录）：
#   demo  → coconutWebBox（测试面板 + 设置页）
#   h5app → coconutH5App（真实业务试点：4 tab 移动端 app）
# 分发目标（真实业务形态：业务离线包归宿主 app 自己的 assets，SDK 只提供
# coconut:// 加载框架；demo 模块仅发三端 WebBox 开发容器，h5app 额外发
# CoconutAndroidApp）：
#   三端 WebBox coconut-web/<moduleId>/ 子目录（模块间天然隔离）
#   + CoconutAndroidApp/app/src/main/assets/coconut-web/h5app/（RealApp）
#
# 流程（每模块独立执行）：
#   1. npm run build（vite，base './' + 无 hash 文件名，见各项目 vite.config.js）→ dist/
#   2. dist/ 产物 + 生成的 manifest.json 组装到 staging 的 coconut-web/<moduleId>/
#   3. staging 复制到三端（每次全量重建，drift 不可能）：
#      Android : AndroidWebBox/app/src/main/assets/coconut-web/<moduleId>/
#      iOS     : iOSWebBox/CoconutSDK/Sources/CoconutSDK/Resources/coconut-web/<moduleId>/ (SPM resource)
#      Harmony : HarmonyWebBox/entry/src/main/resources/rawfile/coconut-web/<moduleId>/
#
# h5app 构建前额外做 coconut.js drift check：coconutH5App/public/coconut.js(.d.ts)
# 必须与源头 coconutWebBox/public/ 字节级一致（双拷贝防漂移，硬门禁）。
#
# manifest.json 是 Android OfflineResourceManager ModuleVersion 解析器的超集
# （fileHashes 本轮 native 不消费，为热更新预留）。
#
# Flags:
#   --check         只构建 + diff 三端已有目录（dry-run，CI 可用）；exit 1 表示不一致
#   --module <id>   只构建指定模块；默认构建全部
#   --quiet         只输出错误
#
# 退出码：
#   0 = 构建并分发成功（--check 时 = 三端一致）
#   1 = --check 发现不一致 / h5app coconut.js drift
#   2 = 源缺失 / 构建失败 / 参数错误

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ANDROID_BASE="$REPO_ROOT/AndroidWebBox/app/src/main/assets/coconut-web"
# RealApp（真实业务宿主）：h5app 模块随宿主 app 的 assets 分发
REALAPP_ANDROID_BASE="$REPO_ROOT/CoconutAndroidApp/app/src/main/assets/coconut-web"
# iOS: 离线包放 CoconutSDK SPM resources（.copy 保留目录结构）；
# iOSWebBox/iOSWebBox/ 是 PBXFileSystemSynchronizedRootGroup，会把子目录平铺到
# bundle 根（文件名冲突 + 丢 coconut-web/<moduleId>/ 路径），不可用。
IOS_BASE="$REPO_ROOT/iOSWebBox/CoconutSDK/Sources/CoconutSDK/Resources/coconut-web"
HARMONY_BASE="$REPO_ROOT/HarmonyWebBox/entry/src/main/resources/rawfile/coconut-web"

ALL_MODULES="demo h5app"

CHECK_ONLY=0
QUIET=0
MODULES=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) CHECK_ONLY=1; shift ;;
    --quiet) QUIET=1; shift ;;
    --module)
      [[ -z "${2:-}" ]] && { echo "--module requires an argument" >&2; exit 2; }
      MODULES="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,37p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Unknown flag: $1" >&2; exit 2 ;;
  esac
done
MODULES="${MODULES:-$ALL_MODULES}"

log()   { [[ "$QUIET" -eq 0 ]] && echo "$@" || true; }
errlog() { echo "$@" >&2; }

module_dir() {
  case "$1" in
    demo)  echo "$REPO_ROOT/coconutWebBox" ;;
    h5app) echo "$REPO_ROOT/coconutH5App" ;;
    *) errlog "✗ Unknown module: $1 (known: $ALL_MODULES)"; return 1 ;;
  esac
}

# h5app 双拷贝防漂移：coconut.js 源头在 coconutWebBox/public/
drift_check_h5app() {
  local dir="$1"
  for f in coconut.js coconut.d.ts; do
    if ! diff -q "$REPO_ROOT/coconutWebBox/public/$f" "$dir/public/$f" >/dev/null 2>&1; then
      errlog "✗ [h5app] coconut.js drift: $dir/public/$f != coconutWebBox/public/$f (源头唯一)"
      errlog "  修复：cp coconutWebBox/public/$f $dir/public/"
      return 1
    fi
  done
  return 0
}

STAGING="$(mktemp -d /tmp/coconut-offline-pkg.XXXXXX)"
trap 'rm -rf "$STAGING"' EXIT

MISMATCH=0

# 构建 + 组装 + manifest + 分发（--check 时 diff）一个模块
build_and_distribute() {
  local module_id="$1"
  local h5_dir
  h5_dir="$(module_dir "$module_id")" || exit 2

  # 1. 前置校验
  if [[ ! -f "$h5_dir/package.json" ]]; then
    errlog "✗ Missing: $h5_dir/package.json"
    exit 2
  fi
  local version
  version="$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$h5_dir/package.json" | head -1)"
  if [[ -z "$version" ]]; then
    errlog "✗ Cannot read version from $h5_dir/package.json"
    exit 2
  fi

  # h5app：coconut.js drift 硬门禁（构建前）
  if [[ "$module_id" == "h5app" ]]; then
    if ! drift_check_h5app "$h5_dir"; then
      exit 1
    fi
    log "  ✓ [h5app] coconut.js in sync with coconutWebBox (source of truth)"
  fi

  # 2. 构建（--check 也重建：确定性构建是 diff 的前提；dist/ 是纯构建产物）
  log "🔨 Building $module_id (v$version) ..."
  if [[ "$QUIET" -eq 1 ]]; then
    (cd "$h5_dir" && npm run build --silent >/dev/null) || {
      errlog "✗ vite build failed: $h5_dir"
      exit 2
    }
  else
    (cd "$h5_dir" && npm run build --silent) || {
      errlog "✗ vite build failed: $h5_dir"
      exit 2
    }
  fi
  if [[ ! -f "$h5_dir/dist/index.html" ]]; then
    errlog "✗ Build output missing: $h5_dir/dist/index.html"
    exit 2
  fi

  # 3. 组装 staging 包：dist/ → coconut-web/<moduleId>/ + manifest.json
  local pkg_dir="$STAGING/$module_id"
  mkdir -p "$pkg_dir"
  cp -R "$h5_dir/dist/." "$pkg_dir/"
  find "$pkg_dir" -name '.DS_Store' -delete

  # vite 即使在 iife 输出下仍给入口 script 写 type="module" crossorigin；
  # module script 规范上永远走 CORS 模式请求，而离线 scheme（resource:// 等）
  # origin 为 null → 必被网络层拒绝。剥成 classic script 走 no-cors 本地加载。
  # 必须在 manifest 哈希之前。
  sed -i '' -e 's/ crossorigin//g' -e 's/ type="module"//g' "$pkg_dir/index.html"
  if grep -qE 'crossorigin|type="module"' "$pkg_dir/index.html"; then
    errlog "✗ Failed to strip module/crossorigin attrs from $pkg_dir/index.html"
    exit 2
  fi

  (
    cd "$pkg_dir"
    local manifest_files_json="" file_hashes_json="" combined=""
    while IFS= read -r f; do
      local h
      h="$(md5 -q "$f")"
      manifest_files_json+="${manifest_files_json:+,}\"$f\""
      file_hashes_json+="${file_hashes_json:+,}\"$f\":\"$h\""
      combined+="$h"
    done < <(find . -type f | sed 's|^\./||' | sort)

    local pkg_md5
    pkg_md5="$(printf '%s' "$combined" | md5 -q)"
    cat > manifest.json <<EOF
{
  "moduleId": "$module_id",
  "version": "$version",
  "entry": "index.html",
  "files": [${manifest_files_json}],
  "md5": "$pkg_md5",
  "fileHashes": {${file_hashes_json}}
}
EOF
    log "📝 manifest.json: $module_id v$version, $(find "$pkg_dir" -type f ! -name manifest.json | wc -l | tr -d ' ') files"
  )

  # 4. 分发 / diff 三端（h5app 额外发 CoconutAndroidApp RealApp）
  local targets="android:$ANDROID_BASE ios:$IOS_BASE harmony:$HARMONY_BASE"
  if [[ "$module_id" == "h5app" ]]; then
    targets="$targets realapp-android:$REALAPP_ANDROID_BASE"
  fi
  for spec in $targets; do
    platform="${spec%%:*}"
    tgt="${spec#*:}/$module_id"
    if [[ "$CHECK_ONLY" -eq 1 ]]; then
      if [[ ! -d "$tgt" ]]; then
        errlog "✗ [$platform/$module_id] missing: $tgt"
        MISMATCH=1
        continue
      fi
      if ! diff -r "$pkg_dir" "$tgt" >/dev/null 2>&1; then
        errlog "✗ [$platform/$module_id] differs: $tgt"
        MISMATCH=1
      else
        log "  ✓ [$platform/$module_id] in sync"
      fi
    else
      rm -rf "$tgt"
      mkdir -p "$tgt"
      cp -R "$pkg_dir/." "$tgt/"
      find "$tgt" -name '.DS_Store' -delete
      log "  ✓ [$platform/$module_id] $tgt"
    fi
  done
}

for m in $MODULES; do
  build_and_distribute "$m"
done

# 5. 结果
if [[ "$CHECK_ONLY" -eq 1 ]]; then
  if [[ "$MISMATCH" -eq 0 ]]; then
    log "✅ Offline packages ($MODULES) in sync across 3 platforms."
    exit 0
  else
    errlog "❌ Mismatches found. Run without --check to rebuild + distribute."
    exit 1
  fi
else
  log "✅ Offline packages ($MODULES) built + distributed to 3 platforms."
  log "   Verify with: bash scripts/build-offline-package.sh --check"
  exit 0
fi

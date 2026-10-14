#!/bin/bash
# 从仓库 vendor 的上游源码直接编译 mpvpaper 引擎。
# 为什么不用上游 meson：UOS/deepin V25 源里没有 libmpv-dev（meson 会探不到
# 依赖），而运行时 libmpv.so.2 是在的——所以走 wayland-scanner 生成协议
# C 源 + gcc 直链运行库这条无 dev 包路线（2026-10 在 UOS 25 上验证）。
set -euo pipefail
cd "$(dirname "$0")"

WS=$(command -v wayland-scanner || true)
[ -n "$WS" ] || { echo "缺 wayland-scanner（apt install libwayland-bin）" >&2; exit 1; }

mkdir -p gen
# 两个 wlr 协议随仓库 vendor（上游 proto/）；稳定的 xdg-shell 用系统的。
XDG_PROTO="$(pkg-config --variable=pkgdatadir wayland-protocols 2>/dev/null || echo /usr/share/wayland-protocols)/stable/xdg-shell/xdg-shell.xml"
[ -r "$XDG_PROTO" ] || { echo "缺 xdg-shell 协议（apt install wayland-protocols）" >&2; exit 1; }

for p in wlr-layer-shell-unstable-v1 wlr-foreign-toplevel-management-unstable-v1; do
  "$WS" client-header "proto/$p.xml" "gen/$p-client-protocol.h"
  "$WS" private-code  "proto/$p.xml" "gen/$p-protocol.c"
done
"$WS" client-header "$XDG_PROTO" gen/xdg-shell-client-protocol.h
"$WS" private-code   "$XDG_PROTO" gen/xdg-shell-protocol.c

# UOS 源无 *-dev 包，没有 libxxx.so 软链——用 ldconfig 把带版本号的
# 运行库解析成全路径直接链（链接器会正确记录 DT_NEEDED）。
# 注：不能用管道+awk（提前 exit 会 SIGPIPE 上游，pipefail 下反杀本脚本）。
LDCACHE="$(ldconfig -p 2>/dev/null || true)"
resolve_lib() {
  local n="lib$1.so" line
  while IFS= read -r line; do
    case "$line" in *"$n"*) printf '%s\n' "${line##* }"; return 0 ;; esac
  done <<< "$LDCACHE"
  return 1
}
LIBS=""
for l in mpv wayland-client wayland-egl EGL GL; do
  p=$(resolve_lib "$l") || { echo "缺运行库 lib$l（看 README 依赖表）" >&2; exit 1; }
  LIBS="$LIBS $p"
done

gcc -O2 -o mpvpaper \
  src/main.c src/cflogprinter.c src/glad.c gen/*.c \
  -Isrc -Iinc -Igen -Impv-headers \
  $LIBS

echo "编译完成: $(pwd)/mpvpaper"

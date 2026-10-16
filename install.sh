#!/bin/bash
# 用户级安装：全部落在 $HOME 下，无需 root。
#   引擎+薄壳 → ~/.local/bin
#   systemd 单元 → ~/.config/systemd/user
#   配置模板   → ~/.config/mpvpaper-wallpaper.conf（已存在则不覆盖）
#   桌面入口   → ~/.local/share/applications
set -euo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$HOME/.local/bin"
die() { echo "[install] $*" >&2; exit 1; }

# ---- 环境检查：本项目仅适配 deepin V25 / UOS 25（Treeland 会话） ----
case " ${XDG_CURRENT_DESKTOP:-} ${XDG_SESSION_DESKTOP:-} " in
  *"eepin"*) : ;;
  *)
    echo "[警告] 本项目仅适配 deepin V25 / UOS 25（Treeland 会话）。"
    echo "        当前会话: ${XDG_CURRENT_DESKTOP:-未知}/${XDG_SESSION_DESKTOP:-未知}"
    read -rp "仍要安装? [y/N] " ans
    case "$ans" in y|Y) ;; *) exit 1 ;; esac
    ;;
esac

# ---- 依赖检查（缺什么给 apt 包名） ----
for c in gcc wayland-scanner socat busctl dbus-monitor python3 systemctl; do
  command -v "$c" >/dev/null 2>&1 || die "缺命令 $c"
done
python3 -c 'import PyQt5' 2>/dev/null \
  || echo "[提示] 缺 PyQt5（控制面板要用）: sudo apt install python3-pyqt5"
ldconfig -p 2>/dev/null | grep -q libmpv.so \
  || echo "[提示] 缺 libmpv（引擎要用）: sudo apt install libmpv2"

# ---- 编译并安装引擎 ----
( cd "$REPO/engine" && ./build.sh ) || die "引擎编译失败（看上方输出）"
install -m 755 "$REPO/engine/mpvpaper" "$BIN_DIR/mpvpaper"

# ---- 薄壳 / 单元 / 配置 / 桌面入口 ----
install -m 755 "$REPO/bin/mpvpaper-wallpaper" \
               "$REPO/bin/mpvpaper-wallpaper-watch" \
               "$REPO/bin/mpvpaper-wallpaper-ui" "$BIN_DIR/"
mkdir -p "$HOME/.config/systemd/user" "$HOME/.local/share/applications"
install -m 644 "$REPO/systemd/mpvpaper-wallpaper.service" \
               "$REPO/systemd/mpvpaper-wallpaper-watch.service" \
               "$HOME/.config/systemd/user/"
CONF="$HOME/.config/mpvpaper-wallpaper.conf"
[ -f "$CONF" ] || install -m 644 "$REPO/conf/mpvpaper-wallpaper.conf.example" "$CONF"
sed -e "s|@PYTHON@|$(command -v python3)|g" -e "s|@BINDIR@|$BIN_DIR|g" \
  "$REPO/data/mpvpaper-dde.desktop.in" \
  > "$HOME/.local/share/applications/mpvpaper-dde.desktop"
install -D -m 0644 "$REPO/data/icons/512x512/mpvpaper-dde.png" \
  "$HOME/.local/share/icons/hicolor/512x512/apps/mpvpaper-dde.png"
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
systemctl --user daemon-reload

echo
echo "安装完成。启用（开机自启 + 立即生效）："
echo "  systemctl --user enable --now mpvpaper-wallpaper.service mpvpaper-wallpaper-watch.service"
echo "控制面板：应用菜单搜「视频壁纸控制」；配置：$CONF"

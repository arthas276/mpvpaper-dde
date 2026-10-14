#!/bin/bash
# 卸载：停用并移除程序文件。--purge 连同配置与视频库一并删除。
set -euo pipefail
BIN_DIR="$HOME/.local/bin"
UNITS=(mpvpaper-wallpaper.service mpvpaper-wallpaper-watch.service)

systemctl --user disable --now "${UNITS[@]}" 2>/dev/null || true
rm -f "$HOME/.config/systemd/user/"mpvpaper-wallpaper*.service
systemctl --user daemon-reload
rm -f "$BIN_DIR/mpvpaper" "$BIN_DIR/mpvpaper-wallpaper" \
      "$BIN_DIR/mpvpaper-wallpaper-watch" "$BIN_DIR/mpvpaper-wallpaper-ui" \
      "$HOME/.local/share/applications/mpvpaper-wallpaper-ui.desktop"
rm -rf "$HOME/.local/state/mpvpaper-wallpaper"
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

if [ "${1:-}" = "--purge" ]; then
  rm -f "$HOME/.config/mpvpaper-wallpaper.conf"
  rm -rf "$HOME/.local/share/wallpaper-videos"
  echo "已连同配置与视频库一起删除。"
else
  echo "已卸载。保留了 ~/.config/mpvpaper-wallpaper.conf 与视频库"
  echo "（~/.local/share/wallpaper-videos）；要一并删除: $0 --purge"
fi

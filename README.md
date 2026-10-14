# mpvpaper-dde — deepin V25 / UOS 25 桌面动态壁纸

在 deepin V25 / UOS 25（Treeland 合成器）桌面上播放视频壁纸：
[mpvpaper](https://github.com/GhostNaN/mpvpaper) 引擎 + 一层专为 DDE 会话写的集成薄壳。

> English summary: video wallpaper for the deepin V25 / UOS 25 (Treeland) desktop.
> mpvpaper engine (vendored, unmodified) + a DDE integration layer: takes over the
> official wallpaper value when it points to a video, yields the desktop when it's
> a static image, and keeps the lock screen safe. User-level install, no root.
> See TROUBLESHOOTING.md. License: GPL-3.0.

## 为什么需要它

deepin V25 桌面线的官方动态壁纸是残缺的：

- 控制中心选动态壁纸**只预览、不落值**（`Set ss wallpaper` 调用根本不发出）；
- 会话内外观服务的壁纸列表接口返回空；
- 会话内没有任何视频渲染组件；
- 更坑的是**锁屏渲染器消费同一个 `wallpaper` 键**：该值是 mp4 时锁屏直接黑屏。

本项目绕过整条官方线：视频壁纸由 mpvpaper 以 layer-shell background 层自渲染，
官方壁纸值由接管钩子治理（视频→接管播放；静态图→让出桌面；接管期间回写一张
静态占位图，保锁屏不黑屏）。

## 组成

```
engine/   上游 mpvpaper 源码 vendor（commit fc5ed28，零改动）+ build.sh
          （UOS 源缺 libmpv-dev，走 wayland-scanner 生成协议 C + gcc 直链
           运行库的路线，已在本机验证可复现）
bin/      我们写的集成薄壳：
          mpvpaper-wallpaper        启动器（conf 驱动、等合成器就绪、
                                    挂起/锁屏暂停、崩溃自重启循环）
          mpvpaper-wallpaper-watch  官方壁纸值接管钩子（监听 Appearance1.Changed：
                                    视频→拉起/热切；静态图→停栈让位；
                                    锁屏治理；静态占位回写+豁免防抖）
          mpvpaper-wallpaper-ui     PyQt5 控制面板（换视频/加视频/暂停/修复叠放）
systemd/   两个 user 单元（壁纸栈 Before= dde-shell 画布，保证叠放次序）
conf/      配置模板（VIDEO / OUTPUT / MPV_OPTS / DEFAULT_STATIC）
data/      桌面入口模板（install.sh 填充实际路径）
```

## 依赖

| 组件 | apt 包 | 用途 |
|---|---|---|
| gcc | gcc | 编译引擎 |
| wayland-scanner | libwayland-bin | 生成协议 C 源 |
| wayland-protocols | wayland-protocols | xdg-shell 协议 |
| libmpv 运行库 | libmpv2 | 引擎播放 |
| socat | socat | 向 mpv IPC 发命令 |
| busctl / dbus-monitor | dbus / dbus 走 base 系统 | 接管钩子 |
| python3 + PyQt5 | python3-pyqt5 | 控制面板 |

## 安装（用户级，无需 root）

```bash
git clone <本仓库> && cd mpvpaper-dde
./install.sh
systemctl --user enable --now mpvpaper-wallpaper.service mpvpaper-wallpaper-watch.service
```

装好后把视频路径写进 `~/.config/mpvpaper-wallpaper.conf` 的 `VIDEO=`，或直接用
应用菜单里的「视频壁纸控制」面板。

## 使用

- **控制面板**：应用菜单搜「视频壁纸控制」——换视频、把新视频加进库、暂停/恢复、
  修复叠放（重启 dde-shell 桌面画布，图标跑到视频下面时用）。
- **配置**：`~/.config/mpvpaper-wallpaper.conf`（`OUTPUT=auto` 自动探测单屏输出名，
  多屏手动指定；改完 `systemctl --user restart mpvpaper-wallpaper`）。
- **从外观服务设置**：把一个视频文件设为官方壁纸（比如文件管理器里"设为壁纸"），
  watch 钩子会自动接管播放——官方值随后被回写成静态占位（保锁屏），不影响播放。
- **日志**：`journalctl --user -u mpvpaper-wallpaper -u mpvpaper-wallpaper-watch -f`。

## 已知边界

- 仅适配 deepin V25 / UOS 25（dde-session-core + Treeland）。V23 及其他发行版未测。
- `OUTPUT=auto` 取第一个已连接 DRM 连接器，多屏请手动指定。
- 接管钩子依赖 V25 外观服务的 DBus 行为（`Appearance1.Changed` 信号、
  `GetCurrentWorkspaceBackground`）。官方若修复动态壁纸线，watch 自动让位逻辑
  依然安全，最多变得多余。
- 本项目**不附带任何视频**。系统自带素材在 `deepin-livewallpapers` 系列包里
  （`/usr/share/wallpapers/deepin-livewallpapers/`），其余请自备并注意素材授权。

## 致谢与许可

- 引擎上游：[GhostNaN/mpvpaper](https://github.com/GhostNaN/mpvpaper)（GPL-3.0），
  源码按 commit `fc5ed28` 原样 vendor 于 `engine/`，无任何修改。
- 整个项目按 **GPL-3.0** 发布（见 [LICENSE](LICENSE)）。
- 排障手册：[TROUBLESHOOTING.md](TROUBLESHOOTING.md)（含各怪象的根因与处置）。

# 排障手册（TROUBLESHOOTING）

按症状找条目。通用调试入口：

```bash
journalctl --user -u mpvpaper-wallpaper -u mpvpaper-wallpaper-watch -b --no-pager
```

## 壁纸盖住桌面图标（点不到"计算机/回收站"）

**根因**：layer-shell 的 background 层内，叠放次序 = surface 映射先后（晚映射者
在上）。如果壁纸在 dde-shell 桌面画布**之后**映射，就会盖住画布（图标层）。

**处置**：单元里 `Before=dde-shell-plugin@org.deepin.ds.desktop.service` 保证启动
次序。运行中被 dde-shell 崩溃重启打乱时，用控制面板的「修复叠放」按钮
（只重启桌面画布插件，不动其他 shell 组件）。

## 锁屏黑屏

**根因**：V25 的锁屏（`treeland --lockscreen`）自渲染背景，且**消费官方
`wallpaper` 键**；该值是 mp4 时它渲染不出来 → 黑屏。这是官方缺陷。

**机制**：watch 钩子在接管视频后，把官方壁纸值回写成一张静态占位图（记录在
`~/.local/state/mpvpaper-wallpaper/static-uri`，回写触发的 Changed 会被豁免分支
吸收，不打断播放）。

**若仍黑屏**：确认该状态文件存在且指向存在的图片；手动恢复：
`busctl --user call org.deepin.dde.Appearance1 /org/deepin/dde/Appearance1 org.deepin.dde.Appearance1 Set ss wallpaper "file:///某静态图.jpg"`

## 控制中心选动态壁纸没反应

**根因**：V25 桌面线官方动态壁纸残缺——控制中心只预览，`Set ss wallpaper`
不发出；外观服务的壁纸列表接口也返回空。

**处置**：用本项目控制面板设置视频；或把视频文件设为官方壁纸（watch 会接管）。

## 服务起不来：start-limit-hit

systemd 对连续失败有熔断。watch 钩子拉起前会 `reset-failed`；手动恢复：
`systemctl --user reset-failed mpvpaper-wallpaper.service && systemctl --user start mpvpaper-wallpaper.service`

## 登录后壁纸迟迟不出现

启动器会等合成器 socket 就绪（最长约 30s）再拉 mpvpaper；仍失败看日志里
`探测输出名失败`——多屏或命名特殊时在 conf 里手动写 `OUTPUT=`。
查看合法输出名：`~/.local/bin/mpvpaper -d`。

## 挂起唤醒后壁纸冻住 / 黑掉

启动器订阅 logind 挂起事件：挂起前暂停 mpv、唤醒后恢复。若仍异常：
`systemctl --user restart mpvpaper-wallpaper.service`。
偶发的 mpv 早期启动失败由主循环自动重启兜底。

## 换视频没生效

conf 的 `VIDEO=` 是启动器读取的；watch 接管时会热切（`loadfile`）。
手动改 conf 后需 `systemctl --user restart mpvpaper-wallpaper.service`。

## 锁屏时壁纸停在静帧、解锁不恢复

watch 订阅了两条锁屏信号链（dde SessionManager + login1）：
锁屏→停壁纸栈（让位锁屏自己的动态背景），解锁→仅在"接管态"拉回。
不恢复说明 want 状态丢了（`/run/user/$UID/mpvpaper-watch.want`），
重启 watch：`systemctl --user restart mpvpaper-wallpaper-watch.service`。

## dbus-monitor 断流后钩子失灵

钩子里的监听循环外层带 5s 自愈（子进程退出即重拉）。彻底排查：
看 watch 日志是否有周期性重连记录；无则说明监听活着，问题在别处。

## 卸载

`./uninstall.sh`（保留配置与视频库），`./uninstall.sh --purge`（全删）。

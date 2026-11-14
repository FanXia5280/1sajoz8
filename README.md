# ScarLog —— Scar 车机桌面一键抓日志 IPA

> 🔴🔴 **2026-11-12 换 AI 全量状态同步（本文件其余旧结论均为历史存档，以本块 + `scar/AI交接文档.md` 为准）**：Scar `0.13.26 / versionCode 171` 已推云；**HUD 歌词已同步、不用管**（通道 = `sendMediaSource(JSON)`，0.13.22 真车已显示）。Scar 已删干净 D 桌面 native 歌词 SDK（libnc.so + 4 java + HudController 5 处调用），保留通用 `TombstoneProbe`。**高德主线 = modder 成品「纯情完美飞屏包+转向卡」共存版 `com.scar.amap`**，产物 `d:\IPA备份\amap_flyscreen_coexist_hud.apk`（AOSP 平台签名 `c8a2e9bc`，**v11**）：**退回 v8 画底色**（撤销 v9 fitWindow 黄框裁剪，模拟器恢复小窗）+ **修 V8 飞屏挂主屏**（真车三屏同名「HDMI 屏幕」→ `prepare` 置空 displayName 强制走 `deviceId-1000==displayId`，deviceId = selectDisplay 选中屏 displayId+1000）。**🎯 用户 2026-11-12 换 AI：下一轮主要改「高德地图」**（Scar 0.13.26 歌词已通、不用动、别误伤）。**v11（2026-11-12 第二百零四批）已修「飞屏后 0.5s 闪退」= Java NPE**：SecondaryGuideOverlay.univSmallWindowChanged 对恒 null 的 layer 调 setVisibility（由 modder PresentationUIView.onSizeChanged 飞屏窗口 resize 触发，停转向卡的连带缺陷）→ 改成只记状态。**模拟器已验**：3s 自动飞屏到副屏黄框（deviceId=1003=displayId 3+1000、displayName='null'）、60s+ 不崩、crash buffer 空。**待真车验 3 件**：① 真车飞屏是否到 HUD 黄框、主屏无小窗、长时间导航不崩；② 罗盘「圈」是否还在（要不要去圈先问用户）；③ 车标观感。**权威文档 = `scar/AI交接文档.md`（2026-11-12 全量重写、唯一权威）「一、当前状态」+「二、下一轮主线：高德地图」（含待验证清单 / 测试步骤 / 打包命令 / 已知坑）+ `scar/README.md` §7 第二百零三批 + §10 顶部 11-12 快照 + `MEMORY.md` 下一步待办。**


配套 [Scar 新桌面](https://github.com/FanXia5280) 的日志抓取 + 云更新 iPhone App。
**本仓库只放 iOS 代码，Android 代码不在此仓库。**

## 功能
- 输入车机 IP → 拉 `http://车机IP:8889/log` 日志（车机端 `ScarLogServer` 常驻端点）
- 一键复制 / 分享日志 txt（微信等）
- 云更新（同 CarDash）：检查 → 弹窗 → 下载 IPA 到 `文件 → 我的 iPhone → Scar日志 → 下载` → 分享页导入 **LCsgn 自签名安装**

## 构建（GitHub Actions）
- 推 `main` 分支自动出 unsigned IPA（GitHub Release 的 `ScarLog-unsigned.ipa`）
- 本地构建：`xcodegen generate` → `xcodebuild -project ScarLog.xcodeproj -scheme ScarLog ...`

## 发布新版本（脚本化，⚠️ 别只 push GitHub 就停）

> 🔴 硬性要求（2026-10-26 用户明确）：push 后必须走完「查 tag → 下载 IPA → 推 Gitee 云更新」全流程，不能只 push 就完事。ScarLog 和 CarDash 一样都要推云。

1. **改版本号**：`project.yml` 的 `MARKETING_VERSION`（+ `CURRENT_PROJECT_VERSION`）
2. **push main** 触发 CI 出 unsigned IPA（Release tag = `build-{run_number}`，asset = `ScarLog-unsigned.ipa`）
3. **查最新 tag**（🔴 用 git，不用 Python 直连——本机常不开代理、`github.com` 会超时）：
   ```bash
   cd d:\IPA备份\scar-ios
   git ls-remote --tags origin        # 看最新 build-N
   ```
4. **下载 unsigned IPA**（走 gh-proxy 加速，落到 `_work\ipa<版本>\ScarLog-unsigned.ipa`）：
   ```bash
   cd d:\IPA备份
   python scar-ios\tools\fetch_ipa.py --tag build-N --ver 1.0.x
   ```
   （`--check` 只看 tag；`--wait --baseline build-N` 蹲新包；脚本带前台心跳 + 下载进度）
5. **推 Gitee 云更新**（写 `scar-ios-update.json` + `scar/ScarLog.ipa`，压平历史 + force push + 回读自检）：
   ```bash
   cd d:\IPA备份
   python scar-ios\tools\upload_release.py --ipa "D:\IPA备份\_work\ipa1.0.x\ScarLog-unsigned.ipa" --ios-version 1.0.x --notes "说明"
   ```
   ⚠️ 看到输出 **`[OK] 远端已就绪`** 才算发布完成（回读自检通过）。
6. App 内「检查更新」即可拉取

### 关键信息
- GitHub 仓库：`FanXia5280/1sajoz8`，asset = `ScarLog-unsigned.ipa`，tag = `build-{run_number}`
- 云更新清单：Gitee `cardash` 仓 `scar-ios-update.json`（`{version,url,size,md5,notes}`），IPA 存 `scar/ScarLog.ipa`
- 与 CarDash 同 Gitee 仓（`_work\gitee-cardash`）不同文件，互不干扰
- Gitee 配置在 `_env\gitee.txt`（TOKEN/OWNER/REPO）

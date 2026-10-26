# ScarLog —— Scar 车机桌面一键抓日志 IPA

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

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

## 发布新版本
1. 改 `project.yml` 的 `MARKETING_VERSION`
2. push → CI 出 IPA → 下载 unsigned IPA
3. 上传 IPA 到 Gitee cardash 仓 `scar/ScarLog.ipa`
4. 更新 `scar-ios-update.json`（Gitee cardash 仓根目录）：
   ```json
   { "version": "1.0.1", "url": "https://gitee.com/enjoying-life-to-the-fullest/cardash/raw/master/scar/ScarLog.ipa", "size": 1234567, "notes": "更新说明" }
   ```
5. App 内「检查更新」即可拉取

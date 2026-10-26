import SwiftUI
import UIKit

/// 一键抓日志：点「连接车机」→ 自动同步 :8889/log（持续自动拉取 + 自动滚动到底部）
/// → 测试完「复制」当前日志；云更新 → 下载 IPA → 分享给 LCsgn。
/// 🔴 1.0.4 新增「应用列表」模式：拉 :8889/packages（包名+应用名）→ 复制/分享成 txt。
struct ContentView: View {
    @State private var ip: String = UserDefaults.standard.string(forKey: "carIP") ?? "192.168.1.100"
    @State private var logText: String = ""
    // 🔴 全量日志（从车机拉到的完整内容）：复制/分享用它——用户分享的日志"前面丢失"
    //    根因是 APK 端环只有 500 条（已改 20000）；IPA 端 SwiftUI Text 渲染上万行会卡，
    //    所以显示只留尾部、复制/分享始终用全量。
    @State private var fullLog: String = ""
    @State private var connected = false
    @State private var lastSyncAt = ""    // 最后一次成功同步时刻
    @State private var fetching = false   // 自动查找中（扫描网段）
    @State private var message = ""
    @State private var showShare = false
    @State private var shareItems: [Any] = []
    @State private var syncTimer: Timer?
    @StateObject private var updater = Updater()

    // 🔴 应用列表提取：mode 0=日志 / 1=应用列表；pkgText = 车机 /packages 返回的列表
    @State private var mode = 0
    @State private var pkgText = ""
    @State private var pkgFetching = false
    // 🔴 诊断文件提取：mode 2=诊断；diagText = 车机 /crash 或 /kill 返回的内容
    @State private var diagText = ""
    @State private var diagFetching = false
    @State private var diagName = ""   // "崩溃日志" / "KILL日志"

    var body: some View {
        NavigationView {
            VStack(spacing: 14) {
                HStack(spacing: 10) {
                    TextField("车机 IP", text: $ip)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numbersAndPunctuation)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .disabled(connected)
                    Button("自动查找") { autoDiscover() }
                        .buttonStyle(.bordered)
                        .disabled(fetching || connected)
                    Button(connected ? "断开" : "连接车机") { toggleConnect() }
                        .buttonStyle(.borderedProminent)
                        .tint(connected ? .red : .accentColor)
                }
                .padding(.horizontal)

                if fetching {
                    ProgressView()
                }

                // 🔴 模式切换：日志 / 应用列表 / 诊断（崩溃日志 + KILL.log）
                Picker("", selection: $mode) {
                    Text("日志").tag(0)
                    Text("应用列表").tag(1)
                    Text("诊断").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .onChange(of: mode) { _ in
                    if mode == 1 && pkgText.isEmpty { fetchPackages() }
                }

                // 🔴 自动同步状态行：已连接时显示「自动同步中 · 最后更新 HH:mm:ss」
                if connected && mode == 0 {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text(lastSyncAt.isEmpty ? "已连接，正在自动同步…" : "自动同步中 · 最后更新 \(lastSyncAt)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                }

                if mode == 0 {
                    // 🔴 日志显示：自动滚动到底部（最新日志），测试完点「复制」拿当下日志
                    ScrollViewReader { proxy in
                        ScrollView {
                            Text(logText.isEmpty
                                 ? (connected ? "正在同步车机日志…" : "输入车机 IP 后点「连接车机」\n（车机端 Scar 会开 :8889/log 端点）")
                                 : logText)
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .id("logBottom")
                        }
                        .onChange(of: logText) { _ in
                            proxy.scrollTo("logBottom", anchor: .bottom)
                        }
                    }
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                    .padding(.horizontal)
                } else if mode == 1 {
                    // 🔴 应用列表显示：包名 + 应用名，可复制/分享成 txt（给 AI/别人看）
                    ScrollView {
                        Text(pkgText.isEmpty
                             ? (pkgFetching ? "正在拉取应用列表…" : "点「提取」从车机拉取应用列表\n（车机端 Scar 会开 :8889/packages 端点）")
                             : pkgText)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                    .padding(.horizontal)
                } else {
                    // 🔴 诊断显示：崩溃日志 / KILL.log，一键提取 + 分享
                    ScrollView {
                        Text(diagText.isEmpty
                             ? "点下面「提取崩溃日志」或「提取KILL日志」\n（车机端 Scar 会开 :8889/crash 和 :8889/kill 端点）"
                             : diagText)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }

                HStack(spacing: 12) {
                    if mode == 0 {
                        Button("复制") {
                            UIPasteboard.general.string = fullLog
                            message = "已复制全量日志"
                        }
                        .disabled(fullLog.isEmpty)

                        Button("分享") { shareLog() }
                            .disabled(fullLog.isEmpty)
                    } else if mode == 1 {
                        Button("提取") { fetchPackages() }
                            .disabled(pkgFetching)

                        Button("复制") {
                            UIPasteboard.general.string = pkgText
                            message = "已复制应用列表"
                        }
                        .disabled(pkgText.isEmpty)

                        Button("分享") { sharePackages() }
                            .disabled(pkgText.isEmpty)
                    } else {
                        Button("崩溃日志") { fetchDiag("crash") }
                            .disabled(diagFetching)

                        Button("KILL日志") { fetchDiag("kill") }
                            .disabled(diagFetching)

                        Button("分享") { shareDiag() }
                            .disabled(diagText.isEmpty)
                    }

                    Button("检查更新") { updater.check() }
                }

                if !message.isEmpty {
                    Text(message).font(.footnote).foregroundColor(.secondary)
                }
                if let msg = updater.message {
                    Text(msg).font(.footnote).foregroundColor(.secondary)
                }
                if updater.downloading {
                    ProgressView()
                }
            }
            .padding(.vertical)
            .navigationTitle("Scar 日志")
            .alert("发现新版本 \(updater.info?.version ?? "")", isPresented: $updater.showUpdate) {
                Button("稍后") { updater.info = nil }
                Button("立即更新") { updater.download() }
            } message: {
                Text(updater.info?.notes ?? "更新详情")
            }
            .sheet(isPresented: $showShare) {
                ActivityView(items: shareItems)
            }
            .sheet(isPresented: $updater.showShare) {
                if let url = updater.downloadedURL {
                    ActivityView(items: [url])
                }
            }
            .onDisappear { disconnect() }
        }
    }

    // ── 连接 / 断开 ──

    private func toggleConnect() {
        connected ? disconnect() : connect()
    }

    /// 🔴 连接车机：保存 IP → 立即同步一次 → 启动定时器每 2 秒自动同步。
    private func connect() {
        guard !ip.isEmpty else { return }
        UserDefaults.standard.set(ip, forKey: "carIP")
        connected = true
        message = ""
        syncOnce()
        let t = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            syncOnce()
        }
        RunLoop.main.add(t, forMode: .common)
        syncTimer = t
    }

    private func disconnect() {
        connected = false
        syncTimer?.invalidate()
        syncTimer = nil
    }

    /// 同步一次日志（自动模式：失败静默保留旧日志，不清空；成功更新 + 记时刻）。
    private func syncOnce() {
        guard connected, !ip.isEmpty else { return }
        let url = URL(string: "http://\(ip):8889/log")!
        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                guard self.connected else { return }  // 已断开则丢弃迟到结果
                if let data, let s = String(data: data, encoding: .utf8) {
                    self.fullLog = s
                    self.logText = Self.tail(s, 500)   // 显示只留尾部（防 SwiftUI 大文本卡）
                    let f = DateFormatter()
                    f.dateFormat = "HH:mm:ss"
                    self.lastSyncAt = f.string(from: Date())
                }
                // 失败静默：不覆盖旧日志、不打断自动同步（车机短暂断连自动恢复）
            }
        }.resume()
    }

    /// 🔴 提取应用列表：拉 :8889/packages（包名+应用名），一次性。
    private func fetchPackages() {
        guard !ip.isEmpty else {
            pkgText = "请先输入车机 IP"
            return
        }
        pkgFetching = true
        message = ""
        let url = URL(string: "http://\(ip):8889/packages")!
        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                self.pkgFetching = false
                if let data, let s = String(data: data, encoding: .utf8), !s.isEmpty {
                    self.pkgText = s
                } else {
                    self.pkgText = "拉取失败：\(error?.localizedDescription ?? "无响应")（确认车机 Scar 已打开）"
                }
            }
        }.resume()
    }

    /// 🔴 自动发现车机：车机连 iPhone 热点时，热点网段固定 172.20.10.x（.1 是 iPhone 自己），
    /// 扫该网段 + 常见局域网段，探测 :8889/log 端口，命中即自动填入 IP 并连接。
    private func autoDiscover() {
        guard !fetching else { return }
        fetching = true
        message = "正在自动查找车机…"

        var ips: [String] = []
        for i in 2...15 { ips.append("172.20.10.\(i)") }   // iOS 个人热点网段
        for i in 2...254 { ips.append("192.168.1.\(i)") }  // 常见局域网兜底（同一 WiFi）

        let sem = DispatchSemaphore(value: 20) // 并发上限
        let group = DispatchGroup()
        let lock = NSLock()
        var found: String?

        for ip in ips {
            group.enter()
            DispatchQueue.global(qos: .utility).async {
                sem.wait()
                defer { sem.signal(); group.leave() }

                lock.lock(); let already = found != nil; lock.unlock()
                if already { return }

                guard let url = URL(string: "http://\(ip):8889/log") else { return }
                var req = URLRequest(url: url)
                req.timeoutInterval = 1.5
                let done = DispatchSemaphore(value: 0)
                var hit = false
                URLSession.shared.dataTask(with: req) { data, _, _ in
                    if let d = data, !d.isEmpty { hit = true }
                    done.signal()
                }.resume()
                done.wait()
                if hit {
                    lock.lock()
                    if found == nil { found = ip }
                    lock.unlock()
                }
            }
        }

        group.notify(queue: .main) {
            self.fetching = false
            if let f = found {
                self.ip = f
                self.message = "已找到车机 \(f)，正在自动同步"
                self.connect()
            } else {
                self.message = "未找到车机，请确认车机已连热点/同一 WiFi 并打开 Scar"
            }
        }
    }

    private func shareLog() {
        let name = "scar-log-\(Int(Date().timeIntervalSince1970)).txt"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try fullLog.write(to: url, atomically: true, encoding: .utf8)
            shareItems = [url]
            showShare = true
        } catch {
            message = "写入临时文件失败：\(error.localizedDescription)"
        }
    }

    /// 🔴 分享应用列表（包名+应用名）成 txt。
    private func sharePackages() {
        let name = "scar-packages-\(Int(Date().timeIntervalSince1970)).txt"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try pkgText.write(to: url, atomically: true, encoding: .utf8)
            shareItems = [url]
            showShare = true
        } catch {
            message = "写入临时文件失败：\(error.localizedDescription)"
        }
    }

    /// 🔴 提取诊断文件：name = "crash"（崩溃日志）/ "kill"（KILL.log），拉 :8889/crash 或 :8889/kill。
    private func fetchDiag(_ name: String) {
        guard !ip.isEmpty else {
            diagText = "请先输入车机 IP"
            return
        }
        diagFetching = true
        diagName = name == "crash" ? "崩溃日志" : "KILL日志"
        message = ""
        let url = URL(string: "http://\(ip):8889/\(name)")!
        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                self.diagFetching = false
                if let data, let s = String(data: data, encoding: .utf8), !s.isEmpty {
                    self.diagText = s
                } else {
                    self.diagText = "拉取失败：\(error?.localizedDescription ?? "无响应")（确认车机 Scar 已打开）"
                }
            }
        }.resume()
    }

    /// 🔴 分享诊断文件（崩溃日志 / KILL.log）成 txt。
    private func shareDiag() {
        let kind = diagName.isEmpty ? "diag" : diagName
        let name = "scar-\(kind)-\(Int(Date().timeIntervalSince1970)).txt"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try diagText.write(to: url, atomically: true, encoding: .utf8)
            shareItems = [url]
            showShare = true
        } catch {
            message = "写入临时文件失败：\(error.localizedDescription)"
        }
    }

    /// 🔴 取文本尾部 limit 行（显示用；复制/分享走全量 fullLog）。
    private static func tail(_ s: String, _ limit: Int) -> String {
        var lines = s.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.count > limit else { return s }
        return lines.suffix(limit).joined(separator: "\n")
    }
}

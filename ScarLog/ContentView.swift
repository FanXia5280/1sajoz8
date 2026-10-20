import SwiftUI
import UIKit

/// 一键抓日志：连车机 IP 拉 :8889/log → 显示 + 复制 + 分享；云更新 → 下载 IPA → 分享给 LCsgn。
struct ContentView: View {
    @State private var ip: String = UserDefaults.standard.string(forKey: "carIP") ?? "192.168.1.100"
    @State private var logText: String = ""
    @State private var fetching = false
    @State private var message = ""
    @State private var showShare = false
    @State private var shareItems: [Any] = []
    @StateObject private var updater = Updater()

    var body: some View {
        NavigationView {
            VStack(spacing: 14) {
                HStack(spacing: 10) {
                    TextField("车机 IP", text: $ip)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numbersAndPunctuation)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    Button("抓取日志") { fetch() }
                        .buttonStyle(.borderedProminent)
                        .disabled(fetching)
                }
                .padding(.horizontal)

                if fetching {
                    ProgressView()
                }

                ScrollView {
                    Text(logText.isEmpty ? "输入车机 IP 后点「抓取日志」\n（车机端 Scar 会开 :8889/log 端点）" : logText)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
                .padding(.horizontal)

                HStack(spacing: 12) {
                    Button("复制") {
                        UIPasteboard.general.string = logText
                        message = "已复制到剪贴板"
                    }
                    .disabled(logText.isEmpty)

                    Button("分享") { shareLog() }
                        .disabled(logText.isEmpty)

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
        }
    }

    private func fetch() {
        guard !ip.isEmpty else { return }
        UserDefaults.standard.set(ip, forKey: "carIP")
        fetching = true
        message = ""
        let url = URL(string: "http://\(ip):8889/log")!
        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                fetching = false
                if let error {
                    message = "抓取失败：\(error.localizedDescription)"
                    return
                }
                if let data, let s = String(data: data, encoding: .utf8) {
                    logText = s
                    message = "已抓取 \(s.count) 字符"
                } else {
                    message = "返回内容无法解析"
                }
            }
        }.resume()
    }

    private func shareLog() {
        let name = "scar-log-\(Int(Date().timeIntervalSince1970)).txt"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try logText.write(to: url, atomically: true, encoding: .utf8)
            shareItems = [url]
            showShare = true
        } catch {
            message = "写入临时文件失败：\(error.localizedDescription)"
        }
    }
}

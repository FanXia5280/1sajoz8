import Foundation
import SwiftUI

/// 云端最新版本信息（scar-ios-update.json，Gitee cardash 仓根目录）。
struct UpdateInfo: Codable, Equatable {
    var version: String
    var url: String
    var size: Int64?
    var notes: String?
}

/// 云更新（跟 CarDash 一样）：检查 → 弹窗 → 下载 IPA 到 Documents → 分享给 LCsgn 自签名。
final class Updater: NSObject, ObservableObject {

    static let jsonURL =
        "https://gitee.com/enjoying-life-to-the-fullest/cardash/raw/master/scar-ios-update.json"
    static let token = "d78934bff5c12d4f36f1a98b015e3a0d"

    @Published var info: UpdateInfo?
    @Published var message: String?
    @Published var downloading = false
    @Published var downloadedURL: URL?
    @Published var showUpdate = false
    @Published var showShare = false

    private var session: URLSession?
    private var checking = false

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    static func isNewer(_ remote: String, than local: String) -> Bool {
        let r = remote.split(separator: ".").compactMap { Int($0) }
        let l = local.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(r.count, l.count) {
            let rv = i < r.count ? r[i] : 0
            let lv = i < l.count ? l[i] : 0
            if rv != lv { return rv > lv }
        }
        return false
    }

    func check() {
        guard !checking else { return }
        checking = true
        message = nil
        var req = URLRequest(url: URL(string: Self.jsonURL)!, timeoutInterval: 15)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.setValue("Bearer \(Self.token)", forHTTPHeaderField: "Authorization")
        req.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.checking = false
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                if code == 404 {
                    self.info = nil
                    self.message = "已是最新版本"
                    return
                }
                if let error {
                    self.info = nil
                    self.message = "检查失败：\(error.localizedDescription)"
                    return
                }
                if let data, let info = try? JSONDecoder().decode(UpdateInfo.self, from: data) {
                    if Self.isNewer(info.version, than: Self.currentVersion) {
                        self.info = info
                        self.showUpdate = true
                    } else {
                        self.info = nil
                        self.message = "已是最新版本"
                    }
                } else {
                    self.info = nil
                    self.message = "检查失败：云端返回异常（HTTP \(code)）"
                }
            }
        }.resume()
    }

    func download() {
        guard let info, let url = URL(string: info.url) else {
            message = "下载地址无效"
            return
        }
        downloading = true
        message = nil
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 30
        cfg.timeoutIntervalForResource = 600
        let s = URLSession(configuration: cfg, delegate: self, delegateQueue: nil)
        session = s
        var req = URLRequest(url: url, timeoutInterval: 60)
        req.setValue("Bearer \(Self.token)", forHTTPHeaderField: "Authorization")
        s.downloadTask(with: req).resume()
    }
}

extension Updater: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        do {
            let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("下载", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let dest = dir.appendingPathComponent("ScarLog-\(info?.version ?? "update").ipa")
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.moveItem(at: location, to: dest)
            DispatchQueue.main.async {
                self.downloadedURL = dest
                self.downloading = false
                self.message = "已下载，请在分享页导入 LCsgn 签名安装"
                self.showShare = true
            }
        } catch {
            DispatchQueue.main.async {
                self.downloading = false
                self.message = "保存失败：\(error.localizedDescription)"
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            DispatchQueue.main.async {
                self.downloading = false
                self.message = "下载失败：\(error.localizedDescription)"
            }
        }
        DispatchQueue.main.async { self.session = nil }
    }
}

/// 系统分享面板（把日志 txt / 下载好的 IPA 导出，用户导入 LCsgn 自签名）。
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

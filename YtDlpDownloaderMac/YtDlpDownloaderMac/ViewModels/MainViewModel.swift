import AppKit
import Foundation

@MainActor
final class MainViewModel: ObservableObject {
    @Published var urlText = ""
    @Published var selectedTab: DownloadTab = .simple
    @Published var selectedOptionID: String?
    @Published var statusTitle = "等待链接"
    @Published var statusMessage = "输入视频链接，然后点击解析"
    @Published var statusHint = "第 1 步：粘贴视频链接并点击解析。"
    @Published var progressValue = 0.0
    @Published var saveDirectory = NSString(string: "~/Downloads").expandingTildeInPath
    @Published var outputFileName = ""
    @Published var mergeFormat = "mp4"
    @Published var cookiesPath = ""
    @Published var cookiesSource = "不使用"
    @Published var proxyText = ""
    @Published var subtitleLanguages = "zh-Hans,zh-CN,en"
    @Published var conflictPolicy = "自动改名（推荐）"
    @Published var rateLimit = ""
    @Published var retryCount = "10"
    @Published var concurrentFragments = "5"
    @Published var shouldWriteSubtitles = false
    @Published var shouldWriteAutoSubtitles = false
    @Published var shouldWriteThumbnail = false
    @Published var isParsing = false
    @Published var isDownloading = false
    @Published var video = VideoSummary.empty
    @Published var simpleOptions: [DownloadOption] = []
    @Published var advancedOptions: [DownloadOption] = []
    @Published var downloadProgress = DownloadProgress.idle
    @Published var lastDownloadedFileURL: URL?
    @Published var componentStatuses: [ComponentStatus] = [
        ComponentStatus(kind: .ytDlp, path: nil, version: nil, hasChecked: false),
        ComponentStatus(kind: .ffmpeg, path: nil, version: nil, hasChecked: false),
        ComponentStatus(kind: .deno, path: nil, version: nil, hasChecked: false)
    ]
    @Published var isCheckingComponents = false
    @Published var isRepairingComponents = false
    @Published var logText = """
    下载核心 yt-dlp: 尚未检测
    视频合并 ffmpeg: 尚未检测
    兼容组件 Deno: 尚未检测
    """

    private let ytDlpService = YtDlpService()
    private let downloadService = DownloadService()
    private let componentRepairService = ComponentRepairService()

    var selectedOption: DownloadOption? {
        (simpleOptions + advancedOptions).first { $0.id == selectedOptionID }
    }

    var canParse: Bool {
        !isParsing && !isDownloading && !urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canStartDownload: Bool {
        !isParsing && !isDownloading && selectedOption != nil && video.sourceURL.isEmpty == false
    }

    var canCancelDownload: Bool {
        isDownloading
    }

    var canRepairComponents: Bool {
        !isParsing && !isDownloading && !isRepairingComponents
    }

    func refreshComponents() async {
        guard !isCheckingComponents else { return }
        isCheckingComponents = true
        appendLog("正在检测组件...")

        let statuses = await componentRepairService.checkStatuses()
        componentStatuses = statuses

        for status in statuses {
            appendLog(status.path == nil ? status.displayText : "\(status.displayText)  \(status.path ?? "")")
        }

        isCheckingComponents = false
    }

    func repairMissingComponents() async {
        guard canRepairComponents else { return }
        isRepairingComponents = true
        statusTitle = "修复组件"
        statusMessage = "正在下载缺失组件，请稍等..."
        statusHint = "会安装到当前用户目录，不需要手动配置 PATH。"
        appendLog("开始修复缺失组件...")

        do {
            try await componentRepairService.repairMissing { [weak self] line in
                Task { @MainActor in
                    self?.appendLog(line)
                }
            }

            appendLog("缺失组件修复完成。")
            statusTitle = "组件正常"
            statusMessage = "组件检测完成，可以继续解析和下载。"
            statusHint = "如果网站提示需要登录，可以在下载设置中选择 cookies.txt。"
            await refreshComponents()
        } catch {
            statusTitle = "修复失败"
            statusMessage = error.localizedDescription
            statusHint = "可以稍后重试，或检查网络后再点击修复缺失。"
            appendLog("修复失败：\(error.localizedDescription)")
        }

        isRepairingComponents = false
    }

    func updateYtDlpCore() async {
        guard canRepairComponents else { return }
        isRepairingComponents = true
        statusTitle = "更新核心"
        statusMessage = "正在更新 yt-dlp 下载核心..."
        statusHint = "更新后会自动重新检测组件状态。"
        appendLog("开始更新 yt-dlp...")

        do {
            try await componentRepairService.updateYtDlp { [weak self] line in
                Task { @MainActor in
                    self?.appendLog(line)
                }
            }

            appendLog("yt-dlp 更新完成。")
            statusTitle = "更新完成"
            statusMessage = "yt-dlp 已更新。"
            statusHint = "如果某个网站突然解析失败，优先尝试更新核心。"
            await refreshComponents()
        } catch {
            statusTitle = "更新失败"
            statusMessage = error.localizedDescription
            statusHint = "可以检查网络后重试。"
            appendLog("更新失败：\(error.localizedDescription)")
        }

        isRepairingComponents = false
    }

    func parseVideo() async {
        guard canParse else {
            statusTitle = "等待链接"
            statusMessage = "请先粘贴完整的视频链接"
            statusHint = "例如：https://www.youtube.com/watch?v=..."
            return
        }

        isParsing = true
        progressValue = 0.08
        statusTitle = "解析中"
        statusMessage = "正在读取标题、封面和可下载格式..."
        statusHint = "第 2 步：解析完成后选择一个下载选项。"
        appendLog("开始解析：\(urlText)")
        let parseStart = Date()

        do {
            let parsed = try await ytDlpService.parse(
                urlText: urlText,
                cookiesPath: cookiesPath,
                cookiesBrowser: selectedCookiesBrowser,
                proxyText: proxyText,
                onLog: { [weak self] line in
                    Task { @MainActor in
                        self?.appendLog(line)
                    }
                }
            )

            video = parsed.summary
            advancedOptions = parsed.advancedOptions
            simpleOptions = Self.defaultSimpleOptions
            outputFileName = parsed.suggestedFileName
            selectedOptionID = simpleOptions.first?.id
            selectedTab = .simple
            progressValue = 0
            statusTitle = "已解析"
            statusMessage = "请选择清晰度，然后点击开始下载"
            statusHint = "将下载：\(selectedOption?.title ?? "未选择")，合并为 \(mergeFormat)，保存到 \(saveDirectory)"
            appendLog("解析成功：\(parsed.summary.title)")
            appendLog("可下载格式：\(parsed.advancedOptions.count) 个")
            appendLog("解析总耗时：\(Self.formatElapsed(since: parseStart))")
        } catch {
            video = .empty
            simpleOptions = []
            advancedOptions = []
            selectedOptionID = nil
            progressValue = 0
            statusTitle = "解析失败"
            statusMessage = error.localizedDescription
            statusHint = "请更换链接，或在下载设置里配置 cookies / 代理后重试。"
            appendLog("解析失败：\(error.localizedDescription)")
            appendLog("解析总耗时：\(Self.formatElapsed(since: parseStart))")
        }

        isParsing = false
    }

    func startDownload() async {
        guard canStartDownload else { return }
        guard normalizeAndValidateSettings() else { return }
        guard let selectedOption else { return }

        let request = DownloadRequest(
            url: video.sourceURL.isEmpty ? urlText : video.sourceURL,
            option: selectedOption,
            outputDirectory: saveDirectory,
            outputFileName: outputFileName,
            mergeFormat: mergeFormat,
            cookiesPath: cookiesPath,
            cookiesBrowser: selectedCookiesBrowser,
            proxyText: proxyText,
            subtitleLanguages: subtitleLanguages,
            conflictPolicy: conflictPolicy,
            rateLimit: rateLimit,
            retryCount: retryCount,
            concurrentFragments: concurrentFragments,
            shouldWriteSubtitles: shouldWriteSubtitles,
            shouldWriteAutoSubtitles: shouldWriteAutoSubtitles,
            shouldWriteThumbnail: shouldWriteThumbnail
        )

        isDownloading = true
        lastDownloadedFileURL = nil
        progressValue = 0
        downloadProgress = .idle
        statusTitle = "下载中"
        statusMessage = "正在准备下载：\(selectedOption.title)"
        statusHint = "请保持网络连接，下载过程中可以查看底部日志。"
        appendLog("开始下载：\(selectedOption.title) -> \(saveDirectory)")
        appendLog("下载设置：合并格式 \(mergeFormat)，冲突策略 \(conflictPolicy)，并发分片 \(concurrentFragments)，重试 \(retryCount)")
        appendLog("附加内容：字幕 \(shouldWriteSubtitles ? "开" : "关")，自动字幕 \(shouldWriteAutoSubtitles ? "开" : "关")，封面 \(shouldWriteThumbnail ? "开" : "关")")

        do {
            let downloadedFile = try await downloadService.download(
                request: request,
                onProgress: { [weak self] progress in
                    Task { @MainActor in
                        self?.apply(progress)
                    }
                },
                onLog: { [weak self] line in
                    Task { @MainActor in
                        self?.appendLog(line)
                    }
                }
            )

            lastDownloadedFileURL = downloadedFile
            progressValue = 1
            statusTitle = "下载完成"
            statusMessage = "已保存：\(downloadedFile?.path ?? saveDirectory)"
            statusHint = "可以打开文件或所在目录。"
            appendLog("下载完成：\(downloadedFile?.path ?? saveDirectory)")
        } catch {
            progressValue = 0
            statusTitle = error.localizedDescription == "下载已取消。" ? "已取消" : "下载失败"
            statusMessage = error.localizedDescription
            statusHint = "可以检查网络、cookies、代理或组件状态后重试。"
            appendLog("下载结束：\(error.localizedDescription)")
        }

        isDownloading = false
    }

    func cancelDownload() {
        guard isDownloading else { return }
        appendLog("正在取消下载...")
        downloadService.cancel()
    }

    func select(_ option: DownloadOption) {
        selectedOptionID = option.id
        statusTitle = "已选择清晰度"
        statusMessage = "将下载：\(option.title)，合并为 \(mergeFormat)"
        statusHint = "第 3 步：确认保存位置后点击开始下载。"
    }

    func chooseSaveDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "选择"

        if panel.runModal() == .OK, let url = panel.url {
            saveDirectory = url.path
            statusHint = "保存到 \(saveDirectory)"
        }
    }

    func chooseCookiesFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "选择"
        panel.message = "选择从浏览器导出的 cookies.txt 文件"

        if panel.runModal() == .OK, let url = panel.url {
            cookiesPath = url.path
            cookiesSource = "cookies.txt"
            appendLog("已选择 cookies：\(cookiesPath)")
        }
    }

    func openSaveDirectory() {
        NSWorkspace.shared.open(URL(fileURLWithPath: NSString(string: saveDirectory).expandingTildeInPath))
    }

    func openDownloadedFile() {
        guard let lastDownloadedFileURL else { return }
        NSWorkspace.shared.open(lastDownloadedFileURL)
    }

    func copyLog() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(logText, forType: .string)
    }

    func clearLog() {
        logText = ""
    }

    func appendLog(_ text: String) {
        if logText.isEmpty {
            logText = text
        } else {
            logText += "\n\(text)"
        }
    }

    private func apply(_ progress: DownloadProgress) {
        downloadProgress = progress

        if let percentage = progress.percentage {
            progressValue = min(max(percentage / 100, 0), 1)
            statusMessage = "\(String(format: "%.1f", percentage))%  \(progress.downloadedSize)  \(progress.speed)  ETA \(progress.eta)"
        } else {
            statusMessage = progress.stage
        }

        statusHint = progress.stage
    }

    private func normalizeAndValidateSettings() -> Bool {
        mergeFormat = mergeFormat.lowercased() == "mkv" ? "mkv" : "mp4"

        if subtitleLanguages.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            subtitleLanguages = "zh-Hans,zh-CN,en"
        }

        if retryCount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            retryCount = "10"
        }

        if concurrentFragments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            concurrentFragments = "5"
        }

        guard let retryValue = Int(retryCount), retryValue >= 0, retryValue <= 100 else {
            rejectSetting("重试次数请输入 0 到 100 之间的数字。")
            return false
        }

        guard let fragmentsValue = Int(concurrentFragments), fragmentsValue >= 1, fragmentsValue <= 16 else {
            rejectSetting("并发分片数请输入 1 到 16 之间的数字，推荐 5。")
            return false
        }

        if !rateLimit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !matches(rateLimit, pattern: #"^\d+(\.\d+)?[KMG]?$"#) {
            rejectSetting("限速格式不正确。可以留空，或填写 500K、2M、10M。")
            return false
        }

        if !proxyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !matches(proxyText, pattern: #"^(http|https|socks4|socks5)://.+"#) {
            rejectSetting("代理格式不正确，例如 http://127.0.0.1:7897 或 socks5://127.0.0.1:7890。")
            return false
        }

        if cookiesSource == "cookies.txt",
           !cookiesPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !FileManager.default.fileExists(atPath: NSString(string: cookiesPath).expandingTildeInPath) {
            rejectSetting("cookies 文件不存在，请重新选择 cookies.txt。")
            return false
        }

        return true
    }

    private func rejectSetting(_ message: String) {
        statusTitle = "设置有误"
        statusMessage = message
        statusHint = "请在下载设置里修改后再开始下载。"
        appendLog("设置有误：\(message)")
        selectedTab = .settings
    }

    private func matches(_ text: String, pattern: String) -> Bool {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.range(of: pattern, options: .regularExpression) != nil
    }

    private static func formatElapsed(since start: Date) -> String {
        String(format: "%.1f 秒", Date().timeIntervalSince(start))
    }

    private static let defaultSimpleOptions: [DownloadOption] = [
        DownloadOption(
            id: "best",
            title: "最佳画质（推荐）",
            kind: .merged,
            resolution: "最高可用",
            container: "自动",
            videoCodec: "自动",
            audioCodec: "自动",
            fps: "自动",
            fileSize: "未知",
            expression: "bestvideo+bestaudio/best",
            note: "优先下载最高画质，必要时自动合并音频和视频。"
        ),
        DownloadOption(
            id: "1080p",
            title: "1080p",
            kind: .merged,
            resolution: "1080p 或以下",
            container: "自动",
            videoCodec: "自动",
            audioCodec: "自动",
            fps: "自动",
            fileSize: "未知",
            expression: "bv*[height<=1080]+ba/b[height<=1080]/best[height<=1080]",
            note: "适合普通屏幕观看，清晰度和文件大小比较均衡。"
        ),
        DownloadOption(
            id: "720p",
            title: "720p",
            kind: .merged,
            resolution: "720p 或以下",
            container: "自动",
            videoCodec: "自动",
            audioCodec: "自动",
            fps: "自动",
            fileSize: "未知",
            expression: "bv*[height<=720]+ba/b[height<=720]/best[height<=720]",
            note: "下载更快，占用空间更小。"
        ),
        DownloadOption(
            id: "mp4-single",
            title: "单文件 MP4",
            kind: .single,
            resolution: "自动",
            container: "mp4",
            videoCodec: "自动",
            audioCodec: "自动",
            fps: "自动",
            fileSize: "未知",
            expression: "best[ext=mp4]/best",
            note: "优先选择已经包含音频的视频文件，兼容性好。"
        ),
        DownloadOption(
            id: "audio",
            title: "仅音频",
            kind: .audio,
            resolution: "音频",
            container: "自动",
            videoCodec: "none",
            audioCodec: "最佳音频",
            fps: "-",
            fileSize: "未知",
            expression: "bestaudio/best",
            note: "只保存音频内容。"
        )
    ]

    private var selectedCookiesBrowser: String {
        switch cookiesSource {
        case "Chrome":
            return "chrome"
        case "Safari":
            return "safari"
        default:
            return ""
        }
    }
}

enum DownloadTab: String, CaseIterable, Identifiable {
    case simple = "简单下载"
    case advanced = "高级格式"
    case settings = "下载设置"

    var id: String { rawValue }
}

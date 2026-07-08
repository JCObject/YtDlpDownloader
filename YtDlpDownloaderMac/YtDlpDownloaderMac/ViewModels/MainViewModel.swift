import AppKit
import Foundation

@MainActor
final class MainViewModel: ObservableObject {
    @Published var urlText = ""
    @Published var language: AppLanguage = .english
    @Published var pendingLanguage: AppLanguage?
    @Published var isShowingLanguageRestartPrompt = false
    @Published var selectedTab: DownloadTab = .simple
    @Published var selectedOptionID: String?
    @Published var statusTitle = ""
    @Published var statusMessage = ""
    @Published var statusHint = ""
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
    @Published var logText = ""

    private let ytDlpService = YtDlpService()
    private let downloadService = DownloadService()
    private let componentRepairService = ComponentRepairService()

    init() {
        let savedLanguage = UserDefaults.standard.string(forKey: "uiLanguage")
        language = AppLanguage(rawValue: savedLanguage ?? "") ?? .english
        resetInitialText()
    }

    func text(_ key: TextKey) -> String {
        LocalizedText.get(key, language)
    }

    private func localized(zh: String, en: String) -> String {
        language == .english ? en : zh
    }

    func requestLanguageChange(_ newLanguage: AppLanguage) {
        guard newLanguage != language else { return }
        pendingLanguage = newLanguage
        isShowingLanguageRestartPrompt = true
    }

    func cancelLanguageChange() {
        pendingLanguage = nil
        isShowingLanguageRestartPrompt = false
    }

    func confirmLanguageChangeAndRestart() {
        guard let pendingLanguage else { return }
        UserDefaults.standard.set(pendingLanguage.rawValue, forKey: "uiLanguage")
        UserDefaults.standard.synchronize()
        let appPath = Bundle.main.bundleURL.path.replacingOccurrences(of: "'", with: "'\\''")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "sleep 0.4; open '\(appPath)'"]
        try? process.run()
        NSApp.terminate(nil)
    }

    private func resetInitialText() {
        statusTitle = text(.statusWaitingTitle)
        statusMessage = text(.statusWaitingMessage)
        statusHint = text(.statusWaitingHint)
        logText = text(.logInitial)
    }

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

    func tabTitle(_ tab: DownloadTab) -> String {
        switch tab {
        case .simple:
            return text(.simpleTab)
        case .advanced:
            return text(.advancedTab)
        case .settings:
            return text(.settingsTab)
        }
    }

    func optionKindText(_ kind: DownloadOptionKind) -> String {
        switch kind {
        case .merged:
            return text(.kindMerged)
        case .single:
            return text(.kindSingle)
        case .audio:
            return text(.kindAudio)
        }
    }

    func optionTitle(_ option: DownloadOption) -> String {
        switch option.id {
        case "best":
            return text(.bestTitle)
        case "mp4-single":
            return text(.singleMp4Title)
        case "audio":
            return text(.audioTitle)
        default:
            return option.title
        }
    }

    func optionResolution(_ option: DownloadOption) -> String {
        switch option.id {
        case "best":
            return text(.highestAvailable)
        case "1080p":
            return text(.p1080Resolution)
        case "720p":
            return text(.p720Resolution)
        case "mp4-single":
            return text(.auto)
        case "audio":
            return text(.audioResolution)
        default:
            return option.resolution
        }
    }

    func optionContainer(_ option: DownloadOption) -> String {
        if ["best", "1080p", "720p", "audio"].contains(option.id) {
            return text(.auto)
        }

        return option.container
    }

    func optionNote(_ option: DownloadOption) -> String {
        switch option.id {
        case "best":
            return text(.bestNote)
        case "1080p":
            return text(.p1080Note)
        case "720p":
            return text(.p720Note)
        case "mp4-single":
            return text(.singleNote)
        case "audio":
            return text(.audioNote)
        default:
            guard language == .english else { return option.note }
            switch option.kind {
            case .merged:
                return "Video only; the best audio will be merged automatically."
            case .single:
                return "Single file with video and audio already together."
            case .audio:
                return "Audio only."
            }
        }
    }

    func refreshComponents() async {
        guard !isCheckingComponents else { return }
        isCheckingComponents = true
        appendLog(localized(zh: "正在检测组件...", en: "Checking components..."))

        let statuses = await componentRepairService.checkStatuses()
        componentStatuses = statuses

        for status in statuses {
            let statusText = status.displayText(language: language)
            appendLog(status.path == nil ? statusText : "\(statusText)  \(status.path ?? "")")
        }

        isCheckingComponents = false
    }

    func repairMissingComponents() async {
        guard canRepairComponents else { return }
        isRepairingComponents = true
        statusTitle = localized(zh: "修复组件", en: "Repairing components")
        statusMessage = localized(zh: "正在下载缺失组件，请稍等...", en: "Downloading missing components, please wait...")
        statusHint = localized(zh: "会安装到当前用户目录，不需要手动配置 PATH。", en: "Components are installed in your user folder; PATH setup is not required.")
        appendLog(localized(zh: "开始修复缺失组件...", en: "Repairing missing components..."))

        do {
            try await componentRepairService.repairMissing { [weak self] line in
                Task { @MainActor in
                    self?.appendLog(line)
                }
            }

            appendLog(localized(zh: "缺失组件修复完成。", en: "Missing components repaired."))
            statusTitle = localized(zh: "组件正常", en: "Components OK")
            statusMessage = localized(zh: "组件检测完成，可以继续解析和下载。", en: "Component check completed. You can analyze and download now.")
            statusHint = localized(zh: "如果网站提示需要登录，可以在下载设置中选择 cookies.txt。", en: "If a site asks you to sign in, choose a cookies source in Settings.")
            await refreshComponents()
        } catch {
            statusTitle = localized(zh: "修复失败", en: "Repair failed")
            statusMessage = localizedError(error.localizedDescription)
            statusHint = localized(zh: "可以稍后重试，或检查网络后再点击修复缺失。", en: "Check the network and try Repair Missing again later.")
            appendLog(localized(zh: "修复失败：\(error.localizedDescription)", en: "Repair failed: \(localizedError(error.localizedDescription))"))
        }

        isRepairingComponents = false
    }

    func updateYtDlpCore() async {
        guard canRepairComponents else { return }
        isRepairingComponents = true
        statusTitle = localized(zh: "更新核心", en: "Updating core")
        statusMessage = localized(zh: "正在更新 yt-dlp 下载核心...", en: "Updating the yt-dlp download core...")
        statusHint = localized(zh: "更新后会自动重新检测组件状态。", en: "Component status will be checked again after updating.")
        appendLog(localized(zh: "开始更新 yt-dlp...", en: "Updating yt-dlp..."))

        do {
            try await componentRepairService.updateYtDlp { [weak self] line in
                Task { @MainActor in
                    self?.appendLog(line)
                }
            }

            appendLog(localized(zh: "yt-dlp 更新完成。", en: "yt-dlp update completed."))
            statusTitle = localized(zh: "更新完成", en: "Update complete")
            statusMessage = localized(zh: "yt-dlp 已更新。", en: "yt-dlp has been updated.")
            statusHint = localized(zh: "如果某个网站突然解析失败，优先尝试更新核心。", en: "If a site suddenly fails to analyze, try Update Core first.")
            await refreshComponents()
        } catch {
            statusTitle = localized(zh: "更新失败", en: "Update failed")
            statusMessage = localizedError(error.localizedDescription)
            statusHint = localized(zh: "可以检查网络后重试。", en: "Check the network and try again.")
            appendLog(localized(zh: "更新失败：\(error.localizedDescription)", en: "Update failed: \(localizedError(error.localizedDescription))"))
        }

        isRepairingComponents = false
    }

    func parseVideo() async {
        guard canParse else {
            statusTitle = text(.statusWaitingTitle)
            statusMessage = language == .english ? "Please paste a complete video link first" : "请先粘贴完整的视频链接"
            statusHint = localized(zh: "例如：https://www.youtube.com/watch?v=...", en: "For example: https://www.youtube.com/watch?v=...")
            return
        }

        isParsing = true
        progressValue = 0.08
        statusTitle = language == .english ? "Analyzing" : "解析中"
        statusMessage = language == .english ? "Reading title, thumbnail, and download formats..." : "正在读取标题、封面和可下载格式..."
        statusHint = language == .english ? "Step 2: choose a download option after analysis." : "第 2 步：解析完成后选择一个下载选项。"
        appendLog(localized(zh: "开始解析：\(urlText)", en: "Analyzing: \(urlText)"))
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
            statusTitle = text(.parsedTitle)
            statusMessage = language == .english ? "Choose a quality, then click Start Download" : "请选择清晰度，然后点击开始下载"
            statusHint = language == .english
                ? "Will download: \(selectedOption.map { optionTitle($0) } ?? "not selected"), merge as \(mergeFormat), save to \(saveDirectory)"
                : "将下载：\(selectedOption.map { optionTitle($0) } ?? "未选择")，合并为 \(mergeFormat)，保存到 \(saveDirectory)"
            appendLog(localized(zh: "解析成功：\(parsed.summary.title)", en: "Analyze succeeded: \(parsed.summary.title)"))
            appendLog(localized(zh: "可下载格式：\(parsed.advancedOptions.count) 个", en: "Downloadable formats: \(parsed.advancedOptions.count)"))
            appendLog(localized(zh: "解析总耗时：\(formatElapsed(since: parseStart))", en: "Analyze time: \(formatElapsed(since: parseStart))"))
        } catch {
            video = .empty
            simpleOptions = []
            advancedOptions = []
            selectedOptionID = nil
            progressValue = 0
            statusTitle = text(.parseFailedTitle)
            statusMessage = localizedError(error.localizedDescription)
            statusHint = language == .english ? "Try another link, or configure cookies / proxy in Settings and retry." : "请更换链接，或在下载设置里配置 cookies / 代理后重试。"
            appendLog(localized(zh: "解析失败：\(error.localizedDescription)", en: "Analyze failed: \(localizedError(error.localizedDescription))"))
            appendLog(localized(zh: "解析总耗时：\(formatElapsed(since: parseStart))", en: "Analyze time: \(formatElapsed(since: parseStart))"))
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
        statusTitle = language == .english ? "Downloading" : "下载中"
        statusMessage = language == .english ? "Preparing download: \(optionTitle(selectedOption))" : "正在准备下载：\(optionTitle(selectedOption))"
        statusHint = language == .english ? "Keep the network connected. You can check the log at the bottom." : "请保持网络连接，下载过程中可以查看底部日志。"
        appendLog(localized(zh: "开始下载：\(optionTitle(selectedOption)) -> \(saveDirectory)", en: "Starting download: \(optionTitle(selectedOption)) -> \(saveDirectory)"))
        appendLog(localized(
            zh: "下载设置：合并格式 \(mergeFormat)，冲突策略 \(conflictPolicy)，并发分片 \(concurrentFragments)，重试 \(retryCount)",
            en: "Download settings: merge format \(mergeFormat), file conflict \(conflictPolicyText), concurrent fragments \(concurrentFragments), retries \(retryCount)"
        ))
        appendLog(localized(
            zh: "附加内容：字幕 \(shouldWriteSubtitles ? "开" : "关")，自动字幕 \(shouldWriteAutoSubtitles ? "开" : "关")，封面 \(shouldWriteThumbnail ? "开" : "关")",
            en: "Extras: subtitles \(onOff(shouldWriteSubtitles)), auto subtitles \(onOff(shouldWriteAutoSubtitles)), thumbnail \(onOff(shouldWriteThumbnail))"
        ))

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
            statusTitle = language == .english ? "Download complete" : "下载完成"
            statusMessage = language == .english ? "Saved: \(downloadedFile?.path ?? saveDirectory)" : "已保存：\(downloadedFile?.path ?? saveDirectory)"
            statusHint = language == .english ? "You can open the file or its folder." : "可以打开文件或所在目录。"
            appendLog(localized(zh: "下载完成：\(downloadedFile?.path ?? saveDirectory)", en: "Download complete: \(downloadedFile?.path ?? saveDirectory)"))
        } catch {
            progressValue = 0
            statusTitle = error.localizedDescription == "下载已取消。" ? text(.canceledTitle) : text(.downloadFailedTitle)
            statusMessage = localizedError(error.localizedDescription)
            statusHint = language == .english ? "Check network, cookies, proxy, or component status and retry." : "可以检查网络、cookies、代理或组件状态后重试。"
            appendLog(localized(zh: "下载结束：\(error.localizedDescription)", en: "Download ended: \(localizedError(error.localizedDescription))"))
        }

        isDownloading = false
    }

    func cancelDownload() {
        guard isDownloading else { return }
        appendLog(localized(zh: "正在取消下载...", en: "Canceling download..."))
        downloadService.cancel()
    }

    func select(_ option: DownloadOption) {
        selectedOptionID = option.id
        statusTitle = text(.selectedTitle)
        statusMessage = language == .english ? "Will download: \(optionTitle(option)), merge as \(mergeFormat)" : "将下载：\(optionTitle(option))，合并为 \(mergeFormat)"
        statusHint = language == .english ? "Step 3: confirm the save location, then click Start Download." : "第 3 步：确认保存位置后点击开始下载。"
    }

    func chooseSaveDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = text(.browse)

        if panel.runModal() == .OK, let url = panel.url {
            saveDirectory = url.path
            statusHint = localized(zh: "保存到 \(saveDirectory)", en: "Save to \(saveDirectory)")
        }
    }

    func chooseCookiesFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = text(.browse)
        panel.message = localized(zh: "选择从浏览器导出的 cookies.txt 文件", en: "Choose a cookies.txt file exported from your browser")

        if panel.runModal() == .OK, let url = panel.url {
            cookiesPath = url.path
            cookiesSource = "cookies.txt"
            appendLog(localized(zh: "已选择 cookies：\(cookiesPath)", en: "Selected cookies: \(cookiesPath)"))
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
        let text = localizedLogLine(text)
        if logText.isEmpty {
            logText = text
        } else {
            logText += "\n\(text)"
        }
    }

    private var conflictPolicyText: String {
        switch conflictPolicy {
        case "覆盖":
            return text(.conflictOverwrite)
        case "跳过":
            return text(.conflictSkip)
        default:
            return text(.conflictRename)
        }
    }

    private func onOff(_ value: Bool) -> String {
        language == .english ? (value ? "on" : "off") : (value ? "开" : "关")
    }

    private func localizedError(_ message: String) -> String {
        guard language == .english else { return message }

        if message.contains("下载已取消") {
            return "Download canceled."
        }

        if message.contains("未找到 yt-dlp") {
            return "yt-dlp was not found. Click Repair Missing to download the required component."
        }

        if message.contains("保存目录无效") {
            return "The save folder is invalid. Please choose another location."
        }

        if message.contains("没有获取到可下载格式") {
            return "No downloadable formats were found. The link may not be a specific video, or the site may require sign-in / cookies."
        }

        if message.contains("YouTube 要求确认不是机器人") {
            return "YouTube asks to confirm you are not a bot. Choose Chrome/Safari cookies or a valid cookies.txt in Settings, then analyze again."
        }

        if message.contains("YouTube 当前签名或挑战解析失败") {
            return "YouTube signature or challenge solving failed. Click Update Core and try again. If it still fails, yt-dlp may need time to adapt."
        }

        if message.contains("当前视频没有拿到所选格式") {
            return "The selected format is not available for this video. Update yt-dlp or try Best quality."
        }

        if message.contains("B站拒绝了请求") {
            return "Bilibili rejected the request (412). Update yt-dlp, or choose Chrome/Safari cookies or cookies.txt in Settings."
        }

        if message.contains("这个链接暂时无法识别") {
            return "This link is not recognized. Make sure it is a specific video page, not a homepage, recommendation page, or search page."
        }

        if message.contains("解析失败，但 yt-dlp 没有返回错误信息") {
            return "Analyze failed, but yt-dlp did not return an error message."
        }

        if message.contains("下载失败，但 yt-dlp 没有返回错误信息") {
            return "Download failed, but yt-dlp did not return an error message."
        }

        return message
    }

    private func localizedLogLine(_ line: String) -> String {
        guard language == .english else { return line }

        if line == "正在检测组件..." {
            return "Checking components..."
        }

        if line == "yt-dlp 已存在，跳过下载。" {
            return "yt-dlp already exists. Skipping download."
        }

        if line == "ffmpeg 已存在，跳过下载。" {
            return "ffmpeg already exists. Skipping download."
        }

        if line == "Deno 已存在，跳过下载。" {
            return "Deno already exists. Skipping download."
        }

        if line == "正在下载 yt-dlp..." {
            return "Downloading yt-dlp..."
        }

        if line == "正在下载 Deno..." {
            return "Downloading Deno..."
        }

        if line.hasPrefix("正在下载 ffmpeg") {
            return line.replacingOccurrences(of: "正在下载 ffmpeg", with: "Downloading ffmpeg")
        }

        if line.hasPrefix("ffmpeg 下载源不可用，尝试下一个。") {
            return line.replacingOccurrences(of: "ffmpeg 下载源不可用，尝试下一个。", with: "ffmpeg source is unavailable. Trying the next source. ")
        }

        if line == "快速解析：不启用 Deno，优先减少等待时间。" {
            return "Fast analysis: Deno is disabled first to reduce waiting time."
        }

        if line.hasPrefix("快速解析完成，用时 ") {
            return line.replacingOccurrences(of: "快速解析完成，用时 ", with: "Fast analysis completed in ")
                .replacingOccurrences(of: "。", with: ".")
        }

        if line.hasPrefix("快速解析未拿到可下载格式，用时 ") {
            return line.replacingOccurrences(of: "快速解析未拿到可下载格式，用时 ", with: "Fast analysis found no downloadable formats in ")
                .replacingOccurrences(of: "。", with: ".")
        }

        if line == "兼容解析：启用 Deno 处理 YouTube 签名 / challenge。" {
            return "Compatibility analysis: using Deno for YouTube signature / challenge solving."
        }

        if line.hasPrefix("兼容解析完成，用时 ") {
            return line.replacingOccurrences(of: "兼容解析完成，用时 ", with: "Compatibility analysis completed in ")
                .replacingOccurrences(of: "。", with: ".")
        }

        if line.hasPrefix("兼容解析失败，用时 ") {
            return line.replacingOccurrences(of: "兼容解析失败，用时 ", with: "Compatibility analysis failed in ")
                .replacingOccurrences(of: "。", with: ".")
        }

        if line.contains(" 秒") {
            return line.replacingOccurrences(of: " 秒", with: " s")
        }

        return line
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
            rejectSetting(localized(zh: "重试次数请输入 0 到 100 之间的数字。", en: "Retries must be a number from 0 to 100."))
            return false
        }

        guard let fragmentsValue = Int(concurrentFragments), fragmentsValue >= 1, fragmentsValue <= 16 else {
            rejectSetting(localized(zh: "并发分片数请输入 1 到 16 之间的数字，推荐 5。", en: "Concurrent fragments must be a number from 1 to 16. 5 is recommended."))
            return false
        }

        if !rateLimit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !matches(rateLimit, pattern: #"^\d+(\.\d+)?[KMG]?$"#) {
            rejectSetting(localized(zh: "限速格式不正确。可以留空，或填写 500K、2M、10M。", en: "Rate limit format is invalid. Leave it empty, or use values like 500K, 2M, 10M."))
            return false
        }

        if !proxyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !matches(proxyText, pattern: #"^(http|https|socks4|socks5)://.+"#) {
            rejectSetting(localized(zh: "代理格式不正确，例如 http://127.0.0.1:7897 或 socks5://127.0.0.1:7890。", en: "Proxy format is invalid, for example http://127.0.0.1:7897 or socks5://127.0.0.1:7890."))
            return false
        }

        if cookiesSource == "cookies.txt",
           !cookiesPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !FileManager.default.fileExists(atPath: NSString(string: cookiesPath).expandingTildeInPath) {
            rejectSetting(localized(zh: "cookies 文件不存在，请重新选择 cookies.txt。", en: "The cookies file does not exist. Please choose cookies.txt again."))
            return false
        }

        return true
    }

    private func rejectSetting(_ message: String) {
        statusTitle = localized(zh: "设置有误", en: "Invalid settings")
        statusMessage = message
        statusHint = localized(zh: "请在下载设置里修改后再开始下载。", en: "Fix it in Settings before starting the download.")
        appendLog(localized(zh: "设置有误：\(message)", en: "Invalid settings: \(message)"))
        selectedTab = .settings
    }

    private func matches(_ text: String, pattern: String) -> Bool {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.range(of: pattern, options: .regularExpression) != nil
    }

    private func formatElapsed(since start: Date) -> String {
        let seconds = Date().timeIntervalSince(start)
        return language == .english ? String(format: "%.1f s", seconds) : String(format: "%.1f 秒", seconds)
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

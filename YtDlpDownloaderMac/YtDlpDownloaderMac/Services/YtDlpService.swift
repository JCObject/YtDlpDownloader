import Foundation

enum YtDlpServiceError: LocalizedError {
    case missingYtDlp
    case invalidURL
    case emptyJSON
    case noFormats
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingYtDlp:
            return "未找到 yt-dlp。请先点击「修复缺失」自动下载组件。"
        case .invalidURL:
            return "请输入完整的视频链接，例如 https://www.youtube.com/watch?v=..."
        case .emptyJSON:
            return "yt-dlp 没有返回有效的视频信息。"
        case .noFormats:
            return "没有获取到可下载格式。这个链接可能不是具体视频，或当前网站需要登录 / cookies。"
        case .commandFailed(let message):
            return message
        }
    }
}

struct YtDlpService {
    private let toolPathService = ToolPathService()
    private let processRunner = ProcessRunner()

    func parse(
        urlText: String,
        cookiesPath: String,
        cookiesBrowser: String,
        proxyText: String,
        onLog: (@Sendable (String) -> Void)? = nil
    ) async throws -> ParsedVideo {
        guard let url = URL(string: urlText.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme.lowercased()),
              url.host != nil else {
            throw YtDlpServiceError.invalidURL
        }

        guard let ytDlp = toolPathService.ytDlpPath() else {
            throw YtDlpServiceError.missingYtDlp
        }

        let fastStart = Date()
        onLog?("快速解析：不启用 Deno，优先减少等待时间。")
        let fastArguments = buildParseArguments(
            url: url,
            cookiesPath: cookiesPath,
            cookiesBrowser: cookiesBrowser,
            proxyText: proxyText,
            includeDeno: false
        )
        let fastResult = try await processRunner.run(executablePath: ytDlp, arguments: fastArguments)

        if let parsed = try parseResult(fastResult, originalURL: url) {
            onLog?("快速解析完成，用时 \(Self.formatElapsed(since: fastStart))。")
            return parsed
        }

        let fastOutput = fastResult.stderr + fastResult.stdout
        onLog?("快速解析未拿到可下载格式，用时 \(Self.formatElapsed(since: fastStart))。")

        guard toolPathService.denoPath() != nil, Self.shouldRetryWithDeno(output: fastOutput) else {
            if fastResult.exitCode == 0 {
                let warning = fastResult.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                if !warning.isEmpty {
                    throw YtDlpServiceError.commandFailed(Self.friendlyError(from: warning))
                }
                throw YtDlpServiceError.noFormats
            }

            throw YtDlpServiceError.commandFailed(Self.friendlyError(from: fastOutput))
        }

        let compatibleStart = Date()
        onLog?("兼容解析：启用 Deno 处理 YouTube 签名 / challenge。")
        let compatibleArguments = buildParseArguments(
            url: url,
            cookiesPath: cookiesPath,
            cookiesBrowser: cookiesBrowser,
            proxyText: proxyText,
            includeDeno: true
        )
        let compatibleResult = try await processRunner.run(executablePath: ytDlp, arguments: compatibleArguments)

        if let parsed = try parseResult(compatibleResult, originalURL: url) {
            onLog?("兼容解析完成，用时 \(Self.formatElapsed(since: compatibleStart))。")
            return parsed
        }

        let compatibleOutput = compatibleResult.stderr + compatibleResult.stdout
        onLog?("兼容解析失败，用时 \(Self.formatElapsed(since: compatibleStart))。")
        if compatibleResult.exitCode == 0 {
            let warning = compatibleResult.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if !warning.isEmpty {
                throw YtDlpServiceError.commandFailed(Self.friendlyError(from: warning))
            }
            throw YtDlpServiceError.noFormats
        }

        throw YtDlpServiceError.commandFailed(Self.friendlyError(from: compatibleOutput))
    }

    private func buildParseArguments(
        url: URL,
        cookiesPath: String,
        cookiesBrowser: String,
        proxyText: String,
        includeDeno: Bool
    ) -> [String] {
        var arguments = [
            "--no-config",
            "--dump-single-json",
            "--ignore-no-formats-error",
            "--no-playlist",
            "--encoding",
            "utf-8"
        ]

        if includeDeno, let deno = toolPathService.denoPath() {
            arguments.append(contentsOf: ["--js-runtimes", "deno:\(deno)"])
        }

        let browserValue = cookiesBrowser.trimmingCharacters(in: .whitespacesAndNewlines)
        let cookieValue = cookiesPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !browserValue.isEmpty {
            arguments.append(contentsOf: ["--cookies-from-browser", browserValue])
        } else if !cookieValue.isEmpty {
            arguments.append(contentsOf: ["--cookies", NSString(string: cookieValue).expandingTildeInPath])
        }

        let proxyValue = proxyText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !proxyValue.isEmpty {
            arguments.append(contentsOf: ["--proxy", proxyValue])
        }

        if url.host?.contains("bilibili.com") == true {
            arguments.append(contentsOf: ["--referer", "https://www.bilibili.com/"])
        }

        arguments.append(url.absoluteString)

        return arguments
    }

    private func parseResult(_ result: ProcessResult, originalURL url: URL) throws -> ParsedVideo? {
        guard result.exitCode == 0 else {
            return nil
        }

        guard let data = result.stdout.data(using: .utf8), !data.isEmpty else {
            throw YtDlpServiceError.emptyJSON
        }

        let raw = try JSONDecoder().decode(RawYtDlpVideoInfo.self, from: data)
        let options = Self.buildAdvancedOptions(from: raw.formats ?? [])
        guard !options.isEmpty else {
            return nil
        }

        let title = raw.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let summary = VideoSummary(
            title: title?.isEmpty == false ? title! : "未命名视频",
            author: raw.uploader ?? raw.channel ?? "",
            duration: Self.formatDuration(raw.duration),
            thumbnailURL: raw.thumbnail.flatMap(URL.init(string:)),
            sourceURL: raw.webpageURL ?? url.absoluteString
        )

        return ParsedVideo(
            summary: summary,
            advancedOptions: options,
            suggestedFileName: Self.sanitizeFileName(title ?? "video")
        )
    }

    private static func buildAdvancedOptions(from formats: [RawYtDlpFormat]) -> [DownloadOption] {
        formats.compactMap { format in
            guard let id = format.formatID, !id.hasPrefix("sb") else {
                return nil
            }

            let vcodec = format.vcodec ?? "unknown"
            let acodec = format.acodec ?? "unknown"
            let hasVideo = vcodec != "none"
            let hasAudio = acodec != "none"
            let kind: DownloadOptionKind = hasVideo && hasAudio ? .single : (hasAudio ? .audio : .merged)
            let resolution = Self.resolutionText(format)
            let fps = format.fps.map { Self.trimmedNumber($0) } ?? "-"
            let size = Self.formatBytes(format.filesize ?? format.filesizeApprox)
            let note: String

            switch kind {
            case .merged:
                note = "只有视频轨，下载时会自动合并最佳音频。"
            case .single:
                note = "单文件，视频和音频已经在一起。"
            case .audio:
                note = "仅音频。"
            }

            return DownloadOption(
                id: id,
                title: id,
                kind: kind,
                resolution: resolution,
                container: format.ext ?? "unknown",
                videoCodec: vcodec,
                audioCodec: acodec,
                fps: fps,
                fileSize: size,
                expression: id,
                note: note
            )
        }
        .sorted { lhs, rhs in
            let leftHeight = Int(lhs.resolution.split(separator: "x").last ?? "0") ?? 0
            let rightHeight = Int(rhs.resolution.split(separator: "x").last ?? "0") ?? 0
            if leftHeight != rightHeight {
                return leftHeight > rightHeight
            }
            return lhs.id < rhs.id
        }
    }

    private static func resolutionText(_ format: RawYtDlpFormat) -> String {
        if let resolution = format.resolution, resolution != "none" {
            return resolution
        }

        if let width = format.width, let height = format.height {
            return "\(width)x\(height)"
        }

        if format.vcodec == "none" {
            return "audio only"
        }

        return "unknown"
    }

    private static func formatDuration(_ duration: Double?) -> String {
        guard let duration else {
            return "未知时长"
        }

        let total = Int(duration.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%02d:%02d", minutes, seconds)
    }

    private static func formatBytes(_ bytes: Int64?) -> String {
        guard let bytes, bytes > 0 else {
            return "未知"
        }

        let units = ["B", "KB", "MB", "GB"]
        var value = Double(bytes)
        var unitIndex = 0

        while value >= 1024, unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }

        return String(format: "%.1f %@", value, units[unitIndex])
    }

    private static func trimmedNumber(_ value: Double) -> String {
        if value.rounded() == value {
            return "\(Int(value))"
        }

        return String(format: "%.2f", value)
    }

    private static func sanitizeFileName(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let cleaned = name.components(separatedBy: invalid).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned.isEmpty ? "video" : cleaned
    }

    private static func formatElapsed(since start: Date) -> String {
        String(format: "%.1f 秒", Date().timeIntervalSince(start))
    }

    private static func shouldRetryWithDeno(output: String) -> Bool {
        output.contains("Signature solving failed") ||
            output.contains("challenge solving failed") ||
            output.contains("Requested format is not available") ||
            output.contains("No video formats found") ||
            output.contains("Only images are available") ||
            output.localizedCaseInsensitiveContains("javascript runtime") ||
            output.localizedCaseInsensitiveContains("js runtime")
    }

    private static func friendlyError(from output: String) -> String {
        if output.localizedCaseInsensitiveContains("Sign in") || output.localizedCaseInsensitiveContains("not a bot") || output.localizedCaseInsensitiveContains("cookies") {
            return "YouTube 要求确认不是机器人，当前网络下需要登录 cookies。请在「下载设置」里选择从浏览器导出的 cookies.txt 后重新解析。\n\n\(output)"
        }

        if output.contains("Signature solving failed") || output.contains("challenge solving failed") || output.contains("Only images are available") {
            return "YouTube 当前签名或挑战解析失败，yt-dlp 没有拿到可下载的视频格式。请先点击「更新核心」后重试；如果仍失败，通常是 YouTube 规则临时变化，需要等待 yt-dlp 适配。cookies 不一定能解决这个问题。\n\n\(output)"
        }

        if output.contains("Requested format is not available") {
            return "当前视频没有拿到所选格式。请先更新 yt-dlp，或换用「最佳画质」重新解析后下载。\n\n\(output)"
        }

        if output.contains("HTTP Error 412") || output.contains("Precondition Failed") {
            return "B站拒绝了请求（412）。请先更新 yt-dlp；如果仍失败，在下载设置里选择 cookies.txt 后重试。\n\n\(output)"
        }

        if output.localizedCaseInsensitiveContains("Unsupported URL") {
            return "这个链接暂时无法识别。请确认它是具体的视频页面，而不是首页、推荐页或搜索页。\n\n\(output)"
        }

        return output.isEmpty ? "解析失败，但 yt-dlp 没有返回错误信息。" : output
    }
}

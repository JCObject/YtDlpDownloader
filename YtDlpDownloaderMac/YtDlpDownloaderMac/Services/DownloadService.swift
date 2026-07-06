import Foundation

enum DownloadServiceError: LocalizedError {
    case missingYtDlp
    case invalidOutputDirectory
    case commandFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .missingYtDlp:
            return "未找到 yt-dlp。请先点击「修复缺失」自动下载组件。"
        case .invalidOutputDirectory:
            return "保存目录无效，请重新选择保存位置。"
        case .commandFailed(let message):
            return message
        case .cancelled:
            return "下载已取消。"
        }
    }
}

final class DownloadService: @unchecked Sendable {
    private let toolPathService = ToolPathService()
    private let processLock = NSLock()
    private var currentProcess: Process?

    func cancel() {
        processLock.lock()
        let process = currentProcess
        processLock.unlock()
        process?.terminate()
    }

    func download(
        request: DownloadRequest,
        onProgress: @escaping @Sendable (DownloadProgress) -> Void,
        onLog: @escaping @Sendable (String) -> Void
    ) async throws -> URL? {
        guard let ytDlp = toolPathService.ytDlpPath() else {
            throw DownloadServiceError.missingYtDlp
        }

        let outputDirectory = NSString(string: request.outputDirectory).expandingTildeInPath
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: outputDirectory, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw DownloadServiceError.invalidOutputDirectory
        }

        let outputTemplate = Self.outputTemplate(
            directory: outputDirectory,
            fileName: request.outputFileName,
            conflictPolicy: request.conflictPolicy,
            mergeFormat: request.mergeFormat
        )

        let arguments = buildArguments(
            request: request,
            outputTemplate: outputTemplate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: ytDlp)
            process.arguments = arguments

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            let outputCollector = LockedOutputCollector()

            let handleData: @Sendable (Data) -> Void = { data in
                guard !data.isEmpty else { return }
                let text = String(decoding: data, as: UTF8.self)
                outputCollector.append(text)

                for line in text.components(separatedBy: .newlines) where !line.isEmpty {
                    onLog(line)
                    if let progress = Self.parseProgressLine(line) {
                        onProgress(progress)
                    } else if line.contains("[Merger]") {
                        onProgress(DownloadProgress(percentage: nil, downloadedSize: "", speed: "", eta: "", stage: "合并音视频", rawLine: line))
                    } else if line.localizedCaseInsensitiveContains("Extracting") {
                        onProgress(DownloadProgress(percentage: nil, downloadedSize: "", speed: "", eta: "", stage: "准备下载", rawLine: line))
                    }
                }
            }

            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                handleData(handle.availableData)
            }

            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                handleData(handle.availableData)
            }

            process.terminationHandler = { [weak self] finishedProcess in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                self?.setCurrentProcess(nil)

                if finishedProcess.terminationReason == .uncaughtSignal {
                    continuation.resume(throwing: DownloadServiceError.cancelled)
                    return
                }

                if finishedProcess.terminationStatus == 0 {
                    continuation.resume(returning: Self.findNewestDownloadedFile(in: outputDirectory))
                } else {
                    let output = outputCollector.text
                    continuation.resume(throwing: DownloadServiceError.commandFailed(output.isEmpty ? "下载失败，但 yt-dlp 没有返回错误信息。" : output))
                }
            }

            do {
                setCurrentProcess(process)
                try process.run()
            } catch {
                setCurrentProcess(nil)
                continuation.resume(throwing: ProcessRunnerError.launchFailed("无法启动 yt-dlp：\(error.localizedDescription)"))
            }
        }
    }

    private func setCurrentProcess(_ process: Process?) {
        processLock.lock()
        currentProcess = process
        processLock.unlock()
    }

    private func buildArguments(request: DownloadRequest, outputTemplate: String) -> [String] {
        var arguments: [String] = [
            "--no-config",
            "--no-playlist",
            "--newline",
            "--progress",
            "--encoding",
            "utf-8",
            "-f",
            formatExpression(for: request.option),
            "-o",
            outputTemplate,
            "--merge-output-format",
            request.mergeFormat
        ]

        if let ffmpeg = toolPathService.ffmpegPath() {
            arguments.append(contentsOf: ["--ffmpeg-location", URL(fileURLWithPath: ffmpeg).deletingLastPathComponent().path])
        }

        if let deno = toolPathService.denoPath() {
            arguments.append(contentsOf: ["--js-runtimes", "deno:\(deno)"])
        }

        if !request.cookiesBrowser.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            arguments.append(contentsOf: ["--cookies-from-browser", request.cookiesBrowser.trimmingCharacters(in: .whitespacesAndNewlines)])
        } else if !request.cookiesPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            arguments.append(contentsOf: ["--cookies", NSString(string: request.cookiesPath).expandingTildeInPath])
        }

        if !request.proxyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            arguments.append(contentsOf: ["--proxy", request.proxyText.trimmingCharacters(in: .whitespacesAndNewlines)])
        }

        if !request.rateLimit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            arguments.append(contentsOf: ["--limit-rate", request.rateLimit.trimmingCharacters(in: .whitespacesAndNewlines)])
        }

        if !request.retryCount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            arguments.append(contentsOf: ["--retries", request.retryCount.trimmingCharacters(in: .whitespacesAndNewlines)])
            arguments.append(contentsOf: ["--fragment-retries", request.retryCount.trimmingCharacters(in: .whitespacesAndNewlines)])
        }

        if !request.concurrentFragments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            arguments.append(contentsOf: ["--concurrent-fragments", request.concurrentFragments.trimmingCharacters(in: .whitespacesAndNewlines)])
        }

        if request.conflictPolicy == "覆盖" {
            arguments.append("--force-overwrites")
        } else if request.conflictPolicy == "跳过" {
            arguments.append("--no-overwrites")
        } else {
            arguments.append("--no-overwrites")
        }

        if request.shouldWriteSubtitles {
            arguments.append("--write-subs")
        }

        if request.shouldWriteAutoSubtitles {
            arguments.append("--write-auto-subs")
        }

        if request.shouldWriteSubtitles || request.shouldWriteAutoSubtitles {
            arguments.append(contentsOf: ["--sub-langs", request.subtitleLanguages])
        }

        if request.shouldWriteThumbnail {
            arguments.append("--write-thumbnail")
        }

        if URL(string: request.url)?.host?.contains("bilibili.com") == true {
            arguments.append(contentsOf: ["--referer", "https://www.bilibili.com/"])
        }

        arguments.append(request.url)
        return arguments
    }

    private func formatExpression(for option: DownloadOption) -> String {
        switch option.kind {
        case .merged:
            if option.expression.rangeOfCharacter(from: CharacterSet(charactersIn: "+/[]<>=*")) == nil {
                return "\(option.expression)+bestaudio/best"
            }

            return option.expression
        case .single, .audio:
            return option.expression
        }
    }

    private static func outputTemplate(directory: String, fileName: String, conflictPolicy: String, mergeFormat: String) -> String {
        let name = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            return URL(fileURLWithPath: directory).appendingPathComponent("%(title)s.%(ext)s").path
        }

        var baseName = sanitizeFileName(name)

        if conflictPolicy == "自动改名（推荐）", likelyConflictingFileExists(directory: directory, baseName: baseName, mergeFormat: mergeFormat) {
            baseName += " \(timestamp())"
        }

        let templateName = "\(baseName).%(ext)s"
        return URL(fileURLWithPath: directory).appendingPathComponent(templateName).path
    }

    private static func likelyConflictingFileExists(directory: String, baseName: String, mergeFormat: String) -> Bool {
        let extensions = Set(["mp4", "mkv", "webm", "m4a", "mp3", mergeFormat.lowercased()])
        return extensions.contains(where: { ext in
            FileManager.default.fileExists(atPath: URL(fileURLWithPath: directory).appendingPathComponent("\(baseName).\(ext)").path)
        })
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }

    private static func sanitizeFileName(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let cleaned = name.components(separatedBy: invalid).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned.isEmpty ? "video" : cleaned
    }

    private static func parseProgressLine(_ line: String) -> DownloadProgress? {
        guard line.contains("[download]") else {
            return nil
        }

        let percentPattern = #"(\d+(?:\.\d+)?)%"#
        let sizePattern = #"of\s+([^\s]+)"#
        let speedPattern = #"at\s+([^\s]+)"#
        let etaPattern = #"ETA\s+([^\s]+)"#

        let percent = firstMatch(in: line, pattern: percentPattern).flatMap(Double.init)
        let size = firstMatch(in: line, pattern: sizePattern) ?? ""
        let speed = firstMatch(in: line, pattern: speedPattern) ?? ""
        let eta = firstMatch(in: line, pattern: etaPattern) ?? ""

        return DownloadProgress(
            percentage: percent,
            downloadedSize: size,
            speed: speed,
            eta: eta,
            stage: "下载中",
            rawLine: line
        )
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: text) else {
            return nil
        }

        return String(text[valueRange])
    }

    private static func findNewestDownloadedFile(in directory: String) -> URL? {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: URL(fileURLWithPath: directory),
            includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        return urls
            .filter { url in
                let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
                return values?.isDirectory == false
            }
            .sorted { lhs, rhs in
                let leftDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rightDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return leftDate > rightDate
            }
            .first
    }
}

private final class LockedOutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = ""

    var text: String {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func append(_ text: String) {
        lock.lock()
        storage += text
        lock.unlock()
    }
}

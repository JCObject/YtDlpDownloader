import Foundation

enum ComponentRepairError: LocalizedError {
    case unsupportedArchitecture(String)
    case downloadFailed(String)
    case missingExecutable(String)
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedArchitecture(let arch):
            return "暂不支持当前架构：\(arch)"
        case .downloadFailed(let message):
            return "下载组件失败：\(message)"
        case .missingExecutable(let name):
            return "下载完成，但没有找到 \(name) 可执行文件。"
        case .commandFailed(let message):
            return message
        }
    }
}

struct ComponentRepairService {
    private let toolPathService = ToolPathService()
    private let runner = ProcessRunner()

    func checkStatuses() async -> [ComponentStatus] {
        async let ytDlp = status(kind: .ytDlp, path: toolPathService.ytDlpPath(), versionArguments: ["--version"])
        async let ffmpeg = status(kind: .ffmpeg, path: toolPathService.ffmpegPath(), versionArguments: ["-version"])
        async let deno = status(kind: .deno, path: toolPathService.denoPath(), versionArguments: ["--version"])
        return await [ytDlp, ffmpeg, deno]
    }

    func repairMissing(onLog: @escaping @Sendable (String) -> Void) async throws {
        try prepareToolsDirectory()

        if toolPathService.ytDlpPath() == nil {
            try await installYtDlp(onLog: onLog)
        } else {
            onLog("yt-dlp 已存在，跳过下载。")
        }

        if toolPathService.ffmpegPath() == nil {
            try await installFFmpeg(onLog: onLog)
        } else {
            onLog("ffmpeg 已存在，跳过下载。")
        }

        if toolPathService.denoPath() == nil {
            try await installDeno(onLog: onLog)
        } else {
            onLog("Deno 已存在，跳过下载。")
        }
    }

    func updateYtDlp(onLog: @escaping @Sendable (String) -> Void) async throws {
        try prepareToolsDirectory()
        try await installYtDlp(onLog: onLog)
    }

    private func status(kind: ComponentKind, path: String?, versionArguments: [String]) async -> ComponentStatus {
        guard let path else {
            return ComponentStatus(kind: kind, path: nil, version: nil)
        }

        let version = try? await versionText(path: path, arguments: versionArguments)
        return ComponentStatus(kind: kind, path: path, version: version)
    }

    private func versionText(path: String, arguments: [String]) async throws -> String {
        let result = try await runner.run(executablePath: path, arguments: arguments)
        let output = [result.stdout, result.stderr].joined(separator: "\n")
        let firstLine = output
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if path.hasSuffix("/ffmpeg"), let firstLine {
            if let range = firstLine.range(of: #"ffmpeg version\s+([^\s]+)"#, options: .regularExpression) {
                return String(firstLine[range]).replacingOccurrences(of: "ffmpeg version ", with: "")
            }
        }

        return firstLine ?? ""
    }

    private func installYtDlp(onLog: @escaping @Sendable (String) -> Void) async throws {
        let destination = toolPathService.toolsDirectory.appendingPathComponent("yt-dlp")
        let source = URL(string: "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos")!
        onLog("正在下载 yt-dlp...")
        try await downloadFile(from: source, to: destination)
        try await chmodExecutable(destination)
        onLog("yt-dlp 已安装：\(destination.path)")
    }

    private func installDeno(onLog: @escaping @Sendable (String) -> Void) async throws {
        let arch = machineArchitecture()
        let assetName: String
        switch arch {
        case "arm64":
            assetName = "deno-aarch64-apple-darwin.zip"
        case "x86_64":
            assetName = "deno-x86_64-apple-darwin.zip"
        default:
            throw ComponentRepairError.unsupportedArchitecture(arch)
        }

        let source = URL(string: "https://github.com/denoland/deno/releases/latest/download/\(assetName)")!
        let temp = try temporaryDirectory()
        let archive = temp.appendingPathComponent(assetName)
        let extractDirectory = temp.appendingPathComponent("deno")
        onLog("正在下载 Deno...")
        try await downloadFile(from: source, to: archive)
        try recreateDirectory(extractDirectory)
        try await unzip(archive: archive, to: extractDirectory)
        try installExecutable(named: "deno", from: extractDirectory, onLog: onLog)
    }

    private func installFFmpeg(onLog: @escaping @Sendable (String) -> Void) async throws {
        let arch = machineArchitecture()
        let candidates: [URL]
        switch arch {
        case "arm64":
            candidates = [
                URL(string: "https://www.osxexperts.net/ffmpeg6arm.zip")!
            ]
        case "x86_64":
            candidates = [
                URL(string: "https://evermeet.cx/ffmpeg/getrelease/zip")!,
                URL(string: "https://www.osxexperts.net/ffmpeg6intel.zip")!
            ]
        default:
            throw ComponentRepairError.unsupportedArchitecture(arch)
        }

        let temp = try temporaryDirectory()
        let archive = temp.appendingPathComponent("ffmpeg.zip")
        let extractDirectory = temp.appendingPathComponent("ffmpeg")
        var lastError: Error?

        for source in candidates {
            do {
                onLog("正在下载 ffmpeg：\(source.host ?? source.absoluteString)")
                try await downloadFile(from: source, to: archive)
                try recreateDirectory(extractDirectory)
                try await unzip(archive: archive, to: extractDirectory)
                try installExecutable(named: "ffmpeg", from: extractDirectory, onLog: onLog)
                return
            } catch {
                lastError = error
                onLog("ffmpeg 下载源不可用，尝试下一个。\(error.localizedDescription)")
            }
        }

        throw lastError ?? ComponentRepairError.downloadFailed("所有 ffmpeg 下载源都不可用。")
    }

    private func installExecutable(named name: String, from directory: URL, onLog: @escaping @Sendable (String) -> Void) throws {
        guard let found = findExecutable(named: name, under: directory) else {
            throw ComponentRepairError.missingExecutable(name)
        }

        let destination = toolPathService.toolsDirectory.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: found, to: destination)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destination.path)
        onLog("\(name) 已安装：\(destination.path)")
    }

    private func downloadFile(from source: URL, to destination: URL) async throws {
        let (downloadedURL, response) = try await URLSession.shared.download(from: source)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw ComponentRepairError.downloadFailed("HTTP \(http.statusCode)")
        }

        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }

        try FileManager.default.moveItem(at: downloadedURL, to: destination)
    }

    private func unzip(archive: URL, to destination: URL) async throws {
        let result = try await runner.run(
            executablePath: "/usr/bin/unzip",
            arguments: ["-oq", archive.path, "-d", destination.path]
        )

        guard result.exitCode == 0 else {
            throw ComponentRepairError.commandFailed(result.stderr.isEmpty ? result.stdout : result.stderr)
        }
    }

    private func chmodExecutable(_ url: URL) async throws {
        let result = try await runner.run(executablePath: "/bin/chmod", arguments: ["755", url.path])
        guard result.exitCode == 0 else {
            throw ComponentRepairError.commandFailed(result.stderr.isEmpty ? result.stdout : result.stderr)
        }
    }

    private func findExecutable(named name: String, under directory: URL) -> URL? {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        for case let url as URL in enumerator where url.lastPathComponent == name {
            return url
        }

        return nil
    }

    private func prepareToolsDirectory() throws {
        try FileManager.default.createDirectory(at: toolPathService.toolsDirectory, withIntermediateDirectories: true)
    }

    private func recreateDirectory(_ url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("YtDlpDownloaderMac-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func machineArchitecture() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
    }
}

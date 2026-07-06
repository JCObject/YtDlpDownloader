import Foundation

struct ToolPathService {
    var appSupportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("YtDlp Downloader", isDirectory: true)
    }

    var toolsDirectory: URL {
        appSupportDirectory.appendingPathComponent("tools", isDirectory: true)
    }

    func ytDlpPath() -> String? {
        findExecutable(named: "yt-dlp")
    }

    func ffmpegPath() -> String? {
        findExecutable(named: "ffmpeg")
    }

    func denoPath() -> String? {
        findExecutable(named: "deno")
    }

    private func findExecutable(named name: String) -> String? {
        var candidates: [String] = []

        candidates.append(toolsDirectory.appendingPathComponent(name).path)

        if let resourceURL = Bundle.main.resourceURL {
            candidates.append(resourceURL.appendingPathComponent("tools/\(name)").path)
        }

        candidates.append(FileManager.default.currentDirectoryPath + "/tools/\(name)")
        candidates.append("/usr/local/bin/\(name)")
        candidates.append("/opt/homebrew/bin/\(name)")
        candidates.append("/usr/bin/\(name)")
        candidates.append("/bin/\(name)")

        if let pathValue = ProcessInfo.processInfo.environment["PATH"] {
            candidates.append(contentsOf: pathValue.split(separator: ":").map { "\($0)/\(name)" })
        }

        return candidates.first { path in
            FileManager.default.isExecutableFile(atPath: path)
        }
    }
}

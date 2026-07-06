import Foundation

enum ComponentKind: String, CaseIterable, Identifiable {
    case ytDlp = "yt-dlp"
    case ffmpeg = "ffmpeg"
    case deno = "Deno"

    var id: String { rawValue }
}

struct ComponentStatus: Identifiable {
    let kind: ComponentKind
    let path: String?
    let version: String?

    var id: String { kind.id }

    var isInstalled: Bool {
        path != nil
    }

    var displayText: String {
        guard isInstalled else {
            return "\(kind.rawValue): 缺失"
        }

        if let version, !version.isEmpty {
            return "\(kind.rawValue): 正常  \(version)"
        }

        return "\(kind.rawValue): 正常"
    }
}

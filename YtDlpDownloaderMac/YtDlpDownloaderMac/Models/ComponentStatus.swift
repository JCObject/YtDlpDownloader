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
    let hasChecked: Bool

    init(kind: ComponentKind, path: String?, version: String?, hasChecked: Bool = true) {
        self.kind = kind
        self.path = path
        self.version = version
        self.hasChecked = hasChecked
    }

    var id: String { kind.id }

    var isInstalled: Bool {
        path != nil
    }

    var isMissing: Bool {
        hasChecked && !isInstalled
    }

    var displayText: String {
        guard hasChecked else {
            return "\(kind.rawValue): 尚未检测"
        }

        guard isInstalled else {
            return "\(kind.rawValue): 缺失"
        }

        if let version, !version.isEmpty {
            return "\(kind.rawValue): 正常  \(version)"
        }

        return "\(kind.rawValue): 正常"
    }
}

import Foundation

enum DownloadOptionKind: String, CaseIterable, Identifiable {
    case merged = "需合并"
    case single = "单文件"
    case audio = "音频"

    var id: String { rawValue }
}

struct DownloadOption: Identifiable, Hashable {
    let id: String
    let title: String
    let kind: DownloadOptionKind
    let resolution: String
    let container: String
    let videoCodec: String
    let audioCodec: String
    let fps: String
    let fileSize: String
    let expression: String
    let note: String
}

import Foundation

struct VideoSummary {
    var title: String
    var author: String
    var duration: String
    var thumbnailURL: URL?
    var sourceURL: String

    static let empty = VideoSummary(
        title: "尚未解析视频",
        author: "",
        duration: "未知时长",
        thumbnailURL: nil,
        sourceURL: ""
    )
}

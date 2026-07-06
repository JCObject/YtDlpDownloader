import Foundation

struct ParsedVideo {
    let summary: VideoSummary
    let advancedOptions: [DownloadOption]
    let suggestedFileName: String
}

struct RawYtDlpVideoInfo: Decodable {
    let title: String?
    let uploader: String?
    let channel: String?
    let duration: Double?
    let thumbnail: String?
    let webpageURL: String?
    let formats: [RawYtDlpFormat]?

    enum CodingKeys: String, CodingKey {
        case title
        case uploader
        case channel
        case duration
        case thumbnail
        case webpageURL = "webpage_url"
        case formats
    }
}

struct RawYtDlpFormat: Decodable {
    let formatID: String?
    let formatNote: String?
    let ext: String?
    let vcodec: String?
    let acodec: String?
    let resolution: String?
    let width: Int?
    let height: Int?
    let fps: Double?
    let filesize: Int64?
    let filesizeApprox: Int64?
    let tbr: Double?

    enum CodingKeys: String, CodingKey {
        case formatID = "format_id"
        case formatNote = "format_note"
        case ext
        case vcodec
        case acodec
        case resolution
        case width
        case height
        case fps
        case filesize
        case filesizeApprox = "filesize_approx"
        case tbr
    }
}

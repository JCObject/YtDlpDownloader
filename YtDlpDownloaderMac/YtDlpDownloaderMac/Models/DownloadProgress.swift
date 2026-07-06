import Foundation

struct DownloadProgress {
    var percentage: Double?
    var downloadedSize: String
    var speed: String
    var eta: String
    var stage: String
    var rawLine: String

    static let idle = DownloadProgress(
        percentage: nil,
        downloadedSize: "",
        speed: "",
        eta: "",
        stage: "等待下载",
        rawLine: ""
    )
}

struct DownloadRequest {
    let url: String
    let option: DownloadOption
    let outputDirectory: String
    let outputFileName: String
    let mergeFormat: String
    let cookiesPath: String
    let cookiesBrowser: String
    let proxyText: String
    let subtitleLanguages: String
    let conflictPolicy: String
    let rateLimit: String
    let retryCount: String
    let concurrentFragments: String
    let shouldWriteSubtitles: Bool
    let shouldWriteAutoSubtitles: Bool
    let shouldWriteThumbnail: Bool
}

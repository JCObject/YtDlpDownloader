import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        }
    }
}

enum TextKey: String {
    case statusWaitingTitle, statusWaitingMessage, statusWaitingHint
    case noVideoTitle, unknownDuration, logInitial
    case restartTitle, restartMessage, restartNow, cancel
    case headerSteps, urlPlaceholder, analyze, analyzing
    case videoInfo, components, refresh, checking, repairMissing, repairing, updateCore
    case save, saveTo, fileName, fileNamePlaceholder, browse, openFolder, openFile
    case optionsIntro, simpleTab, advancedTab, settingsTab
    case emptySimpleTitle, emptySimpleMessage, emptyAdvancedTitle, emptyAdvancedMessage
    case columnOption, columnType, columnQuality, columnFormat, columnDescription
    case columnVideoCodec, columnAudioCodec, columnSize, columnExpression
    case language, mergeFormat, cookiesSource, cookiesNone, cookiesFile, cookiesFilePlaceholder
    case proxy, proxyPlaceholder, extras, subtitles, autoSubtitles, thumbnail
    case subtitleLanguages, fileConflict, conflictRename, conflictOverwrite, conflictSkip
    case rateLimit, rateLimitPlaceholder, retries, concurrentFragments
    case log, copyLog, clear, startDownload, downloading
    case bestTitle, highestAvailable, auto, unknown, bestNote
    case p1080Resolution, p1080Note, p720Resolution, p720Note
    case singleMp4Title, singleNote, audioTitle, audioResolution, bestAudio, audioNote
    case kindMerged, kindSingle, kindAudio
    case selectedTitle, parsedTitle, parseFailedTitle, downloadFailedTitle, canceledTitle
}

enum LocalizedText {
    static func get(_ key: TextKey, _ language: AppLanguage) -> String {
        switch language {
        case .english:
            return english[key] ?? key.rawValue
        case .simplifiedChinese:
            return chinese[key] ?? english[key] ?? key.rawValue
        }
    }

    private static let english: [TextKey: String] = [
        .statusWaitingTitle: "Waiting",
        .statusWaitingMessage: "Paste a video link, then click Analyze",
        .statusWaitingHint: "Step 1: paste a video link and click Analyze.",
        .noVideoTitle: "No video analyzed yet",
        .unknownDuration: "Unknown duration",
        .logInitial: "Download core yt-dlp: not checked\nMedia merge ffmpeg: not checked\nCompatibility runtime Deno: not checked",
        .restartTitle: "Restart Required",
        .restartMessage: "The language setting will be saved. Restart the app to fully apply it.",
        .restartNow: "Restart Now",
        .cancel: "Cancel",
        .headerSteps: "1 Paste link  ->  2 Choose quality  ->  3 Start download",
        .urlPlaceholder: "Paste a YouTube, Bilibili, or other yt-dlp supported video link",
        .analyze: "Analyze",
        .analyzing: "Analyzing...",
        .videoInfo: "Video Info",
        .components: "Components",
        .refresh: "Refresh",
        .checking: "Checking...",
        .repairMissing: "Repair Missing",
        .repairing: "Repairing...",
        .updateCore: "Update Core",
        .save: "Save",
        .saveTo: "Save To",
        .fileName: "File Name",
        .fileNamePlaceholder: "Filled after analyzing; can be edited",
        .browse: "Browse",
        .openFolder: "Open Folder",
        .openFile: "Open File",
        .optionsIntro: "Paste a video link and click Analyze to see recommended download options. Advanced formats are for users who understand format_id.",
        .simpleTab: "Simple",
        .advancedTab: "Advanced",
        .settingsTab: "Settings",
        .emptySimpleTitle: "Waiting for analysis",
        .emptySimpleMessage: "After analyzing a link, recommended options such as best quality, 1080p, 720p, and audio only will appear here.",
        .emptyAdvancedTitle: "No advanced formats yet",
        .emptyAdvancedMessage: "After analyzing, format_id, codecs, quality, and file size will appear here. Most users should use Simple.",
        .columnOption: "Option",
        .columnType: "Type",
        .columnQuality: "Quality",
        .columnFormat: "Format",
        .columnDescription: "Description",
        .columnVideoCodec: "Video Codec",
        .columnAudioCodec: "Audio Codec",
        .columnSize: "Size",
        .columnExpression: "Expression",
        .language: "Language",
        .mergeFormat: "Merge Format",
        .cookiesSource: "Cookies Source",
        .cookiesNone: "None",
        .cookiesFile: "Cookies File",
        .cookiesFilePlaceholder: "Used only when cookies.txt is selected; Chrome/Safari read browser login automatically",
        .proxy: "Proxy",
        .proxyPlaceholder: "For example: http://127.0.0.1:7897",
        .extras: "Extras",
        .subtitles: "Subtitles",
        .autoSubtitles: "Auto Subtitles",
        .thumbnail: "Thumbnail",
        .subtitleLanguages: "Subtitle Languages",
        .fileConflict: "File Conflict",
        .conflictRename: "Auto rename (recommended)",
        .conflictOverwrite: "Overwrite",
        .conflictSkip: "Skip",
        .rateLimit: "Rate Limit",
        .rateLimitPlaceholder: "Leave empty for no limit, for example 5M",
        .retries: "Retries",
        .concurrentFragments: "Concurrent Fragments",
        .log: "Log",
        .copyLog: "Copy Log",
        .clear: "Clear",
        .startDownload: "Start Download",
        .downloading: "Downloading...",
        .bestTitle: "Best quality (recommended)",
        .highestAvailable: "Highest available",
        .auto: "Auto",
        .unknown: "Unknown",
        .bestNote: "Downloads the best quality first and merges audio/video automatically when needed.",
        .p1080Resolution: "1080p or lower",
        .p1080Note: "Balanced quality and file size for normal screens.",
        .p720Resolution: "720p or lower",
        .p720Note: "Faster download and smaller file size.",
        .singleMp4Title: "Single MP4",
        .singleNote: "Prefers a video file that already contains audio for better compatibility.",
        .audioTitle: "Audio only",
        .audioResolution: "Audio",
        .bestAudio: "Best audio",
        .audioNote: "Saves audio only.",
        .kindMerged: "Needs merge",
        .kindSingle: "Single file",
        .kindAudio: "Audio",
        .selectedTitle: "Quality selected",
        .parsedTitle: "Analyzed",
        .parseFailedTitle: "Analyze failed",
        .downloadFailedTitle: "Download failed",
        .canceledTitle: "Canceled"
    ]

    private static let chinese: [TextKey: String] = [
        .statusWaitingTitle: "等待链接",
        .statusWaitingMessage: "输入视频链接，然后点击解析",
        .statusWaitingHint: "第 1 步：粘贴视频链接并点击解析。",
        .noVideoTitle: "尚未解析视频",
        .unknownDuration: "未知时长",
        .logInitial: "下载核心 yt-dlp: 尚未检测\n视频合并 ffmpeg: 尚未检测\n兼容组件 Deno: 尚未检测",
        .restartTitle: "需要重启",
        .restartMessage: "语言设置将被保存。重启应用后会完整生效。",
        .restartNow: "现在重启",
        .cancel: "取消",
        .headerSteps: "1 输入链接  ->  2 选择清晰度  ->  3 开始下载",
        .urlPlaceholder: "粘贴 YouTube、B站或其它 yt-dlp 支持的视频链接",
        .analyze: "解析",
        .analyzing: "解析中...",
        .videoInfo: "视频信息",
        .components: "组件状态",
        .refresh: "刷新",
        .checking: "检测中...",
        .repairMissing: "修复缺失",
        .repairing: "修复中...",
        .updateCore: "更新核心",
        .save: "保存设置",
        .saveTo: "保存目录",
        .fileName: "文件名",
        .fileNamePlaceholder: "解析后自动填充，可手动修改",
        .browse: "选择",
        .openFolder: "打开目录",
        .openFile: "打开文件",
        .optionsIntro: "输入视频链接后，点击解析即可看到推荐下载选项。高级格式适合了解 format_id 的用户。",
        .simpleTab: "简单下载",
        .advancedTab: "高级格式",
        .settingsTab: "下载设置",
        .emptySimpleTitle: "等待解析",
        .emptySimpleMessage: "粘贴视频链接并点击解析后，这里会显示最佳画质、1080p、720p 和仅音频等推荐选项。",
        .emptyAdvancedTitle: "暂无高级格式",
        .emptyAdvancedMessage: "解析成功后会显示 format_id、编码、清晰度和文件大小。普通下载建议优先使用简单下载。",
        .columnOption: "选项",
        .columnType: "类型",
        .columnQuality: "清晰度",
        .columnFormat: "格式",
        .columnDescription: "说明",
        .columnVideoCodec: "视频编码",
        .columnAudioCodec: "音频编码",
        .columnSize: "大小",
        .columnExpression: "表达式",
        .language: "语言",
        .mergeFormat: "合并格式",
        .cookiesSource: "cookies 来源",
        .cookiesNone: "不使用",
        .cookiesFile: "cookies 文件",
        .cookiesFilePlaceholder: "选择 cookies.txt 时使用；Chrome/Safari 会自动读取浏览器登录态",
        .proxy: "代理",
        .proxyPlaceholder: "例如 http://127.0.0.1:7897",
        .extras: "附加内容",
        .subtitles: "字幕文件",
        .autoSubtitles: "自动字幕",
        .thumbnail: "封面图片",
        .subtitleLanguages: "字幕语言",
        .fileConflict: "文件冲突",
        .conflictRename: "自动改名（推荐）",
        .conflictOverwrite: "覆盖",
        .conflictSkip: "跳过",
        .rateLimit: "限速",
        .rateLimitPlaceholder: "留空不限速，例如 5M",
        .retries: "重试次数",
        .concurrentFragments: "并发分片数",
        .log: "日志",
        .copyLog: "复制日志",
        .clear: "清空",
        .startDownload: "开始下载",
        .downloading: "下载中...",
        .bestTitle: "最佳画质（推荐）",
        .highestAvailable: "最高可用",
        .auto: "自动",
        .unknown: "未知",
        .bestNote: "优先下载最高画质，必要时自动合并音频和视频。",
        .p1080Resolution: "1080p 或以下",
        .p1080Note: "适合普通屏幕观看，清晰度和文件大小比较均衡。",
        .p720Resolution: "720p 或以下",
        .p720Note: "下载更快，占用空间更小。",
        .singleMp4Title: "单文件 MP4",
        .singleNote: "优先选择已经包含音频的视频文件，兼容性好。",
        .audioTitle: "仅音频",
        .audioResolution: "音频",
        .bestAudio: "最佳音频",
        .audioNote: "只保存音频内容。",
        .kindMerged: "需合并",
        .kindSingle: "单文件",
        .kindAudio: "音频",
        .selectedTitle: "已选择清晰度",
        .parsedTitle: "已解析",
        .parseFailedTitle: "解析失败",
        .downloadFailedTitle: "下载失败",
        .canceledTitle: "已取消"
    ]
}

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

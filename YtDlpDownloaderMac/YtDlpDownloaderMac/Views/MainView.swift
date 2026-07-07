import SwiftUI

struct MainView: View {
    @StateObject private var viewModel = MainViewModel()

    var body: some View {
        VStack(spacing: 12) {
            HeaderView(viewModel: viewModel)
                .frame(height: 62)

            HStack(alignment: .top, spacing: 12) {
                SidebarView(viewModel: viewModel)
                    .frame(width: 320)

                OptionsPanelView(viewModel: viewModel)
            }
            .frame(height: 410)

            StatusBarView(viewModel: viewModel)
                .frame(height: 92)

            LogPanelView(viewModel: viewModel)
                .frame(height: 175)
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .frame(minWidth: 1080, idealWidth: 1180, minHeight: 790, idealHeight: 820)
        .task {
            await viewModel.refreshComponents()
        }
    }
}

private struct HeaderView: View {
    @ObservedObject var viewModel: MainViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("1 输入链接  ->  2 选择清晰度  ->  3 开始下载")
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                TextField("粘贴 YouTube、B站或其它 yt-dlp 支持的视频链接", text: $viewModel.urlText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 15))
                    .disabled(viewModel.isParsing || viewModel.isDownloading)

                Button(viewModel.isParsing ? "解析中..." : "解析") {
                    Task {
                        await viewModel.parseVideo()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!viewModel.canParse)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

private struct SidebarView: View {
    @ObservedObject var viewModel: MainViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                GroupBox("视频信息") {
                    VStack(alignment: .leading, spacing: 12) {
                        ThumbnailView(url: viewModel.video.thumbnailURL)
                            .frame(height: 175)

                        Text(viewModel.video.title)
                            .font(.title3.weight(.semibold))
                            .lineLimit(3)

                        if !viewModel.video.author.isEmpty {
                            Text(viewModel.video.author)
                                .foregroundStyle(.secondary)
                        }

                        Text(viewModel.video.duration)
                            .foregroundStyle(.secondary)

                        if !viewModel.video.sourceURL.isEmpty {
                            Text(viewModel.video.sourceURL)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }

                GroupBox("组件状态") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(viewModel.componentStatuses) { status in
                            ComponentStatusRow(status: status)
                        }

                        HStack {
                            Button(viewModel.isCheckingComponents ? "检测中..." : "刷新") {
                                Task {
                                    await viewModel.refreshComponents()
                                }
                            }
                            .disabled(viewModel.isCheckingComponents || viewModel.isRepairingComponents)

                            Button(viewModel.isRepairingComponents ? "修复中..." : "修复缺失") {
                                Task {
                                    await viewModel.repairMissingComponents()
                                }
                            }
                            .disabled(!viewModel.canRepairComponents)

                            Button("更新核心") {
                                Task {
                                    await viewModel.updateYtDlpCore()
                                }
                            }
                            .disabled(!viewModel.canRepairComponents)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }

                GroupBox("保存设置") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("保存目录")
                                .frame(width: 62, alignment: .leading)
                            TextField("", text: $viewModel.saveDirectory)
                            Button("选择") {
                                viewModel.chooseSaveDirectory()
                            }
                        }

                        HStack {
                            Text("文件名")
                                .frame(width: 62, alignment: .leading)
                            TextField("解析后自动填充，可手动修改", text: $viewModel.outputFileName)
                        }

                        HStack {
                            Button("打开目录") {
                                viewModel.openSaveDirectory()
                            }
                            Button("打开文件") {
                                viewModel.openDownloadedFile()
                            }
                            .disabled(viewModel.lastDownloadedFileURL == nil)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxHeight: .infinity)
        .clipped()
    }
}

private struct ComponentStatusRow: View {
    let status: ComponentStatus

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(status.displayText)
                    .foregroundStyle(status.isMissing ? Color.red : Color.primary)
                if let path = status.path {
                    Text(path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        } icon: {
            Image(systemName: iconName)
                .foregroundStyle(status.isInstalled ? .green : (status.isMissing ? .orange : .secondary))
        }
    }

    private var iconName: String {
        switch status.kind {
        case .ytDlp:
            return "arrow.down.circle"
        case .ffmpeg:
            return "film"
        case .deno:
            return "shippingbox"
        }
    }
}

private struct ThumbnailView: View {
    let url: URL?
    @State private var image: NSImage?
    @State private var isLoading = false

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(nsColor: .quaternaryLabelColor))
            .overlay {
                if let url {
                    Group {
                        if let image {
                            Image(nsImage: image)
                                .resizable()
                                .scaledToFill()
                        } else if isLoading {
                            ProgressView()
                        } else {
                            placeholder
                        }
                    }
                    .task(id: url) {
                        await loadImage(from: url)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    placeholder
                }
            }
            .clipped()
    }

    @MainActor
    private func loadImage(from url: URL) async {
        image = nil
        isLoading = true
        defer { isLoading = false }

        do {
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
            if url.host?.contains("hdslb.com") == true || url.host?.contains("bilibili.com") == true {
                request.setValue("https://www.bilibili.com/", forHTTPHeaderField: "Referer")
            }

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode),
                  let loadedImage = NSImage(data: data) else {
                return
            }

            image = loadedImage
        } catch {
            image = nil
        }
    }

    private var placeholder: some View {
        Image(systemName: "play.rectangle")
            .font(.system(size: 42))
            .foregroundStyle(.secondary)
    }
}

private struct OptionsPanelView: View {
    @ObservedObject var viewModel: MainViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("输入视频链接后，点击解析即可看到推荐下载选项。高级格式适合了解 format_id 的用户。")
                .foregroundStyle(.secondary)

            Picker("", selection: $viewModel.selectedTab) {
                ForEach(DownloadTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 360)

            GroupBox {
                switch viewModel.selectedTab {
                case .simple:
                    if viewModel.simpleOptions.isEmpty {
                        EmptyOptionsView(
                            title: "等待解析",
                            message: "粘贴视频链接并点击解析后，这里会显示最佳画质、1080p、720p 和仅音频等推荐选项。"
                        )
                    } else {
                        OptionTableView(options: viewModel.simpleOptions, selectedOptionID: $viewModel.selectedOptionID) { option in
                            viewModel.select(option)
                        }
                    }
                case .advanced:
                    if viewModel.advancedOptions.isEmpty {
                        EmptyOptionsView(
                            title: "暂无高级格式",
                            message: "解析成功后会显示 format_id、编码、清晰度和文件大小。普通下载建议优先使用简单下载。"
                        )
                    } else {
                        AdvancedFormatTableView(options: viewModel.advancedOptions, selectedOptionID: $viewModel.selectedOptionID) { option in
                            viewModel.select(option)
                        }
                    }
                case .settings:
                    DownloadSettingsView(viewModel: viewModel)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
    }
}

private struct EmptyOptionsView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "link.badge.plus")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title3.weight(.semibold))
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
        }
        .frame(maxWidth: .infinity, minHeight: 330, maxHeight: .infinity)
    }
}

private struct OptionTableView: View {
    let options: [DownloadOption]
    @Binding var selectedOptionID: String?
    let onSelect: (DownloadOption) -> Void

    var body: some View {
        Table(options, selection: $selectedOptionID) {
            TableColumn("选项") { option in
                Text(option.title)
            }
            TableColumn("类型") { option in
                Text(option.kind.rawValue)
            }
            TableColumn("清晰度") { option in
                Text(option.resolution)
            }
            TableColumn("格式") { option in
                Text(option.container)
            }
            TableColumn("说明") { option in
                Text(option.note)
                    .lineLimit(2)
            }
        }
        .onChange(of: selectedOptionID) { newValue in
            if let option = options.first(where: { $0.id == newValue }) {
                onSelect(option)
            }
        }
        .frame(minHeight: 330)
    }
}

private struct AdvancedFormatTableView: View {
    let options: [DownloadOption]
    @Binding var selectedOptionID: String?
    let onSelect: (DownloadOption) -> Void

    var body: some View {
        Table(options, selection: $selectedOptionID) {
            TableColumn("format_id") { option in
                Text(option.id)
            }
            TableColumn("清晰度") { option in
                Text(option.resolution)
            }
            TableColumn("类型") { option in
                Text(option.kind.rawValue)
            }
            TableColumn("格式") { option in
                Text(option.container)
            }
            TableColumn("视频编码") { option in
                Text(option.videoCodec)
            }
            TableColumn("音频编码") { option in
                Text(option.audioCodec)
            }
            TableColumn("FPS") { option in
                Text(option.fps)
            }
            TableColumn("大小") { option in
                Text(option.fileSize)
            }
            TableColumn("表达式") { option in
                Text(option.expression)
            }
        }
        .onChange(of: selectedOptionID) { newValue in
            if let option = options.first(where: { $0.id == newValue }) {
                onSelect(option)
            }
        }
        .frame(minHeight: 330)
    }
}

private struct DownloadSettingsView: View {
    @ObservedObject var viewModel: MainViewModel

    var body: some View {
        ScrollView {
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 12) {
                GridRow {
                    Text("合并格式")
                    Picker("", selection: $viewModel.mergeFormat) {
                        Text("mp4").tag("mp4")
                        Text("mkv").tag("mkv")
                    }
                    .frame(width: 180)
                    .disabled(viewModel.isDownloading)
                }

                GridRow {
                    Text("cookies 来源")
                    Picker("", selection: $viewModel.cookiesSource) {
                        Text("不使用").tag("不使用")
                        Text("cookies.txt").tag("cookies.txt")
                        Text("Chrome").tag("Chrome")
                        Text("Safari").tag("Safari")
                    }
                    .frame(width: 260)
                    .disabled(viewModel.isDownloading)
                }

                GridRow {
                    Text("cookies 文件")
                    HStack {
                        TextField("选择 cookies.txt 时使用；Chrome/Safari 会自动读取浏览器登录态", text: $viewModel.cookiesPath)
                            .disabled(viewModel.isDownloading || viewModel.cookiesSource != "cookies.txt")
                        Button("选择") {
                            viewModel.chooseCookiesFile()
                        }
                        .disabled(viewModel.isDownloading)
                    }
                }

                GridRow {
                    Text("代理")
                    TextField("例如 http://127.0.0.1:7897", text: $viewModel.proxyText)
                        .disabled(viewModel.isDownloading)
                }

                GridRow {
                    Text("附加内容")
                    HStack(spacing: 16) {
                        Toggle("字幕文件", isOn: $viewModel.shouldWriteSubtitles)
                        Toggle("自动字幕", isOn: $viewModel.shouldWriteAutoSubtitles)
                        Toggle("封面图片", isOn: $viewModel.shouldWriteThumbnail)
                    }
                    .disabled(viewModel.isDownloading)
                }

                GridRow {
                    Text("字幕语言")
                    TextField("zh-Hans,zh-CN,en", text: $viewModel.subtitleLanguages)
                        .disabled(viewModel.isDownloading)
                }

                GridRow {
                    Text("文件冲突")
                    Picker("", selection: $viewModel.conflictPolicy) {
                        Text("自动改名（推荐）").tag("自动改名（推荐）")
                        Text("覆盖").tag("覆盖")
                        Text("跳过").tag("跳过")
                    }
                    .frame(width: 200)
                    .disabled(viewModel.isDownloading)
                }

                GridRow {
                    Text("限速")
                    TextField("留空不限速，例如 5M", text: $viewModel.rateLimit)
                        .disabled(viewModel.isDownloading)
                }

                GridRow {
                    Text("重试次数")
                    TextField("", text: $viewModel.retryCount)
                        .frame(width: 120)
                        .disabled(viewModel.isDownloading)
                }

                GridRow {
                    Text("并发分片数")
                    TextField("", text: $viewModel.concurrentFragments)
                        .frame(width: 120)
                        .disabled(viewModel.isDownloading)
                }
            }
            .padding(8)
        }
        .frame(minHeight: 330)
    }
}

private struct StatusBarView: View {
    @ObservedObject var viewModel: MainViewModel

    var body: some View {
        GroupBox {
            HStack(spacing: 18) {
                Text(viewModel.statusTitle)
                    .font(.title2.weight(.semibold))
                    .frame(width: 120, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.statusMessage)
                        .font(.headline)
                        .lineLimit(2)
                    Text(viewModel.statusHint)
                        .foregroundStyle(.secondary)
                    ProgressView(value: viewModel.progressValue)
                        .frame(maxWidth: 560)
                }

                Spacer()

                Button("打开目录") {
                    viewModel.openSaveDirectory()
                }
                .controlSize(.large)

                Button("打开文件") {
                    viewModel.openDownloadedFile()
                }
                .controlSize(.large)
                .disabled(viewModel.lastDownloadedFileURL == nil)

                Button("取消下载") {
                    viewModel.cancelDownload()
                }
                .controlSize(.large)
                .disabled(!viewModel.canCancelDownload)

                Button(viewModel.isDownloading ? "下载中..." : "开始下载") {
                    Task {
                        await viewModel.startDownload()
                    }
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canStartDownload)
            }
            .padding(.vertical, 8)
        }
    }
}

private struct LogPanelView: View {
    @ObservedObject var viewModel: MainViewModel

    var body: some View {
        GroupBox("日志") {
            VStack(alignment: .trailing, spacing: 8) {
                HStack {
                    Spacer()
                    Button("复制日志") {
                        viewModel.copyLog()
                    }
                    Button("清空") {
                        viewModel.clearLog()
                    }
                }

                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(viewModel.logText)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(8)
                            Color.clear
                                .frame(height: 1)
                                .id("log-bottom")
                        }
                    }
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .frame(height: 110)
                    .onChange(of: viewModel.logText) { _ in
                        proxy.scrollTo("log-bottom", anchor: .bottom)
                    }
                }
            }
        }
    }
}

#Preview {
    MainView()
}

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
        .alert(viewModel.text(.restartTitle), isPresented: $viewModel.isShowingLanguageRestartPrompt) {
            Button(viewModel.text(.restartNow)) {
                viewModel.confirmLanguageChangeAndRestart()
            }
            Button(viewModel.text(.cancel), role: .cancel) {
                viewModel.cancelLanguageChange()
            }
        } message: {
            Text(viewModel.text(.restartMessage))
        }
    }
}

private struct HeaderView: View {
    @ObservedObject var viewModel: MainViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.text(.headerSteps))
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                TextField(viewModel.text(.urlPlaceholder), text: $viewModel.urlText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 15))
                    .disabled(viewModel.isParsing || viewModel.isDownloading)

                Button(viewModel.isParsing ? viewModel.text(.analyzing) : viewModel.text(.analyze)) {
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
                GroupBox(viewModel.text(.videoInfo)) {
                    VStack(alignment: .leading, spacing: 12) {
                        ThumbnailView(url: viewModel.video.thumbnailURL)
                            .frame(height: 175)

                        Text(viewModel.video.sourceURL.isEmpty ? viewModel.text(.noVideoTitle) : viewModel.video.title)
                            .font(.title3.weight(.semibold))
                            .lineLimit(3)

                        if !viewModel.video.author.isEmpty {
                            Text(viewModel.video.author)
                                .foregroundStyle(.secondary)
                        }

                        Text(viewModel.video.sourceURL.isEmpty ? viewModel.text(.unknownDuration) : viewModel.video.duration)
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

                GroupBox(viewModel.text(.components)) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(viewModel.componentStatuses) { status in
                            ComponentStatusRow(viewModel: viewModel, status: status)
                        }

                        HStack {
                            Button(viewModel.isCheckingComponents ? viewModel.text(.checking) : viewModel.text(.refresh)) {
                                Task {
                                    await viewModel.refreshComponents()
                                }
                            }
                            .disabled(viewModel.isCheckingComponents || viewModel.isRepairingComponents)

                            Button(viewModel.isRepairingComponents ? viewModel.text(.repairing) : viewModel.text(.repairMissing)) {
                                Task {
                                    await viewModel.repairMissingComponents()
                                }
                            }
                            .disabled(!viewModel.canRepairComponents)

                            Button(viewModel.text(.updateCore)) {
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

                GroupBox(viewModel.text(.save)) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(viewModel.text(.saveTo))
                                .frame(width: 62, alignment: .leading)
                            TextField("", text: $viewModel.saveDirectory)
                            Button(viewModel.text(.browse)) {
                                viewModel.chooseSaveDirectory()
                            }
                        }

                        HStack {
                            Text(viewModel.text(.fileName))
                                .frame(width: 62, alignment: .leading)
                            TextField(viewModel.text(.fileNamePlaceholder), text: $viewModel.outputFileName)
                        }

                        HStack {
                            Button(viewModel.text(.openFolder)) {
                                viewModel.openSaveDirectory()
                            }
                            Button(viewModel.text(.openFile)) {
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
    @ObservedObject var viewModel: MainViewModel
    let status: ComponentStatus

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(status.displayText(language: viewModel.language))
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
            Text(viewModel.text(.optionsIntro))
                .foregroundStyle(.secondary)

            Picker("", selection: $viewModel.selectedTab) {
                ForEach(DownloadTab.allCases) { tab in
                    Text(viewModel.tabTitle(tab)).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 360)

            GroupBox {
                switch viewModel.selectedTab {
                case .simple:
                    if viewModel.simpleOptions.isEmpty {
                        EmptyOptionsView(
                            title: viewModel.text(.emptySimpleTitle),
                            message: viewModel.text(.emptySimpleMessage)
                        )
                    } else {
                        OptionTableView(viewModel: viewModel, options: viewModel.simpleOptions, selectedOptionID: $viewModel.selectedOptionID) { option in
                            viewModel.select(option)
                        }
                    }
                case .advanced:
                    if viewModel.advancedOptions.isEmpty {
                        EmptyOptionsView(
                            title: viewModel.text(.emptyAdvancedTitle),
                            message: viewModel.text(.emptyAdvancedMessage)
                        )
                    } else {
                        AdvancedFormatTableView(viewModel: viewModel, options: viewModel.advancedOptions, selectedOptionID: $viewModel.selectedOptionID) { option in
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
    @ObservedObject var viewModel: MainViewModel
    let options: [DownloadOption]
    @Binding var selectedOptionID: String?
    let onSelect: (DownloadOption) -> Void

    var body: some View {
        Table(options, selection: $selectedOptionID) {
            TableColumn(viewModel.text(.columnOption)) { option in
                Text(viewModel.optionTitle(option))
            }
            TableColumn(viewModel.text(.columnType)) { option in
                Text(viewModel.optionKindText(option.kind))
            }
            TableColumn(viewModel.text(.columnQuality)) { option in
                Text(viewModel.optionResolution(option))
            }
            TableColumn(viewModel.text(.columnFormat)) { option in
                Text(viewModel.optionContainer(option))
            }
            TableColumn(viewModel.text(.columnDescription)) { option in
                Text(viewModel.optionNote(option))
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
    @ObservedObject var viewModel: MainViewModel
    let options: [DownloadOption]
    @Binding var selectedOptionID: String?
    let onSelect: (DownloadOption) -> Void

    var body: some View {
        Table(options, selection: $selectedOptionID) {
            TableColumn("format_id") { option in
                Text(option.id)
            }
            TableColumn(viewModel.text(.columnQuality)) { option in
                Text(option.resolution)
            }
            TableColumn(viewModel.text(.columnType)) { option in
                Text(viewModel.optionKindText(option.kind))
            }
            TableColumn(viewModel.text(.columnFormat)) { option in
                Text(option.container)
            }
            TableColumn(viewModel.text(.columnVideoCodec)) { option in
                Text(option.videoCodec)
            }
            TableColumn(viewModel.text(.columnAudioCodec)) { option in
                Text(option.audioCodec)
            }
            TableColumn("FPS") { option in
                Text(option.fps)
            }
            TableColumn(viewModel.text(.columnSize)) { option in
                Text(option.fileSize)
            }
            TableColumn(viewModel.text(.columnExpression)) { option in
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
                    Text(viewModel.text(.language))
                    Picker("", selection: Binding(
                        get: { viewModel.language },
                        set: { viewModel.requestLanguageChange($0) }
                    )) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .frame(width: 180)
                    .disabled(viewModel.isDownloading)
                }

                GridRow {
                    Text(viewModel.text(.mergeFormat))
                    Picker("", selection: $viewModel.mergeFormat) {
                        Text("mp4").tag("mp4")
                        Text("mkv").tag("mkv")
                    }
                    .frame(width: 180)
                    .disabled(viewModel.isDownloading)
                }

                GridRow {
                    Text(viewModel.text(.cookiesSource))
                    Picker("", selection: $viewModel.cookiesSource) {
                        Text(viewModel.text(.cookiesNone)).tag("不使用")
                        Text("cookies.txt").tag("cookies.txt")
                        Text("Chrome").tag("Chrome")
                        Text("Safari").tag("Safari")
                    }
                    .frame(width: 260)
                    .disabled(viewModel.isDownloading)
                }

                GridRow {
                    Text(viewModel.text(.cookiesFile))
                    HStack {
                        TextField(viewModel.text(.cookiesFilePlaceholder), text: $viewModel.cookiesPath)
                            .disabled(viewModel.isDownloading || viewModel.cookiesSource != "cookies.txt")
                        Button(viewModel.text(.browse)) {
                            viewModel.chooseCookiesFile()
                        }
                        .disabled(viewModel.isDownloading)
                    }
                }

                GridRow {
                    Text(viewModel.text(.proxy))
                    TextField(viewModel.text(.proxyPlaceholder), text: $viewModel.proxyText)
                        .disabled(viewModel.isDownloading)
                }

                GridRow {
                    Text(viewModel.text(.extras))
                    HStack(spacing: 16) {
                        Toggle(viewModel.text(.subtitles), isOn: $viewModel.shouldWriteSubtitles)
                        Toggle(viewModel.text(.autoSubtitles), isOn: $viewModel.shouldWriteAutoSubtitles)
                        Toggle(viewModel.text(.thumbnail), isOn: $viewModel.shouldWriteThumbnail)
                    }
                    .disabled(viewModel.isDownloading)
                }

                GridRow {
                    Text(viewModel.text(.subtitleLanguages))
                    TextField("zh-Hans,zh-CN,en", text: $viewModel.subtitleLanguages)
                        .disabled(viewModel.isDownloading)
                }

                GridRow {
                    Text(viewModel.text(.fileConflict))
                    Picker("", selection: $viewModel.conflictPolicy) {
                        Text(viewModel.text(.conflictRename)).tag("自动改名（推荐）")
                        Text(viewModel.text(.conflictOverwrite)).tag("覆盖")
                        Text(viewModel.text(.conflictSkip)).tag("跳过")
                    }
                    .frame(width: 200)
                    .disabled(viewModel.isDownloading)
                }

                GridRow {
                    Text(viewModel.text(.rateLimit))
                    TextField(viewModel.text(.rateLimitPlaceholder), text: $viewModel.rateLimit)
                        .disabled(viewModel.isDownloading)
                }

                GridRow {
                    Text(viewModel.text(.retries))
                    TextField("", text: $viewModel.retryCount)
                        .frame(width: 120)
                        .disabled(viewModel.isDownloading)
                }

                GridRow {
                    Text(viewModel.text(.concurrentFragments))
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

                Button(viewModel.text(.openFolder)) {
                    viewModel.openSaveDirectory()
                }
                .controlSize(.large)

                Button(viewModel.text(.openFile)) {
                    viewModel.openDownloadedFile()
                }
                .controlSize(.large)
                .disabled(viewModel.lastDownloadedFileURL == nil)

                Button(viewModel.text(.cancel)) {
                    viewModel.cancelDownload()
                }
                .controlSize(.large)
                .disabled(!viewModel.canCancelDownload)

                Button(viewModel.isDownloading ? viewModel.text(.downloading) : viewModel.text(.startDownload)) {
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
        GroupBox(viewModel.text(.log)) {
            VStack(alignment: .trailing, spacing: 8) {
                HStack {
                    Spacer()
                    Button(viewModel.text(.copyLog)) {
                        viewModel.copyLog()
                    }
                    Button(viewModel.text(.clear)) {
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

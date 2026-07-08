# YtDlp Downloader

English | [中文说明](#中文说明)

YtDlp Downloader is a simple desktop video downloader powered by `yt-dlp`.
It provides a friendly UI for analyzing video links, choosing download quality,
monitoring progress, and merging video/audio with `ffmpeg`.

Current platforms:

- Windows: .NET 8 + WPF
- macOS: Swift + SwiftUI

> Please use this tool only for content you have the right to download. Respect
> website terms of service and local copyright laws.

## Quick Start

### Windows

1. Download `YtDlpDownloader-v0.1.2-win-x64.zip` from GitHub Releases.
2. Extract the zip file.
3. Run `YtDlpDownloader.exe`.
4. If any component is missing, click `Repair Missing`.
5. Paste a video link and click `Analyze`.
6. Choose a quality and click `Start Download`.

### macOS

1. Download `YtDlpDownloader-macOS-universal.dmg` from GitHub Releases.
2. Open the dmg file.
3. Drag `YtDlp Downloader.app` to `Applications`.
4. If macOS blocks the app because the developer cannot be verified, open
   `System Settings -> Privacy & Security` and allow it manually.
5. If any component is missing, click `Repair Missing`.
6. Paste a video link and click `Analyze`.
7. Choose a quality and click `Start Download`.

## Important: Cookies

Some sites require sign-in, identity verification, or anti-bot checks. A video
playing in your browser does not always mean `yt-dlp` can download it directly.
In these cases, you need to provide browser cookies.

Typical logs that mean cookies are needed:

```text
Sign in to confirm you're not a bot
No video formats found
Requested format is not available
cookies are no longer valid
HTTP Error 412: Precondition Failed
```

Recommended order:

1. Make sure the video can play normally in your browser.
2. In `Settings`, set `Cookies Source` to your browser:
   - Windows: `Chrome` or `Edge`
   - macOS: `Chrome` or `Safari`
3. Try `Analyze` again.
4. If browser cookies fail, export a `cookies.txt` file and choose
   `cookies.txt` as the cookies source.
5. If the log says cookies are invalid or expired, export cookies again.

### Export cookies.txt

For Chrome, the easiest option is usually the extension
`Get cookies.txt LOCALLY`.

Steps:

1. Open Chrome and sign in to the target site, for example YouTube.
2. Install `Get cookies.txt LOCALLY` from Chrome Web Store.
3. Open the target site page.
4. Use the extension to export cookies for that site as `cookies.txt`.
5. In YtDlp Downloader, open `Settings`.
6. Set `Cookies Source` to `cookies.txt`.
7. Choose the exported `cookies.txt` file.
8. Analyze the link again.

Cookies are sensitive. Do not upload `cookies.txt` to GitHub, cloud drives, or
public chat rooms. Anyone with your cookies may be able to temporarily act as
your logged-in browser session.

Official yt-dlp references:

- [How do I pass cookies to yt-dlp?](https://github.com/yt-dlp/yt-dlp/wiki/FAQ#how-do-i-pass-cookies-to-yt-dlp)
- [Exporting YouTube cookies](https://github.com/yt-dlp/yt-dlp/wiki/Extractors#exporting-youtube-cookies)

## Required Components

YtDlp Downloader can use bundled/local tools or tools already available in
system `PATH`.

Required or recommended components:

- `yt-dlp`: the download core, used to analyze and download videos
- `ffmpeg`: required for merging separated video and audio streams
- `Deno` / `Node.js`: compatibility runtime used by yt-dlp for some YouTube
  signature or challenge solving logic

The app provides:

- `Repair Missing`: downloads missing components automatically
- `Update Core`: updates `yt-dlp`

Most users do not need to download these tools manually. If the component status
is red, click `Repair Missing`.

## Features

- Analyze video links and show basic metadata
- Show title, author/channel, duration, thumbnail, and source URL
- Simple options: best quality, 1080p, 720p, single-file MP4, audio only
- Advanced formats: `format_id`, codecs, resolution, FPS, size, expression
- Download progress, speed, ETA, and current stage
- Open downloaded file or output folder
- Settings for cookies, proxy, subtitles, thumbnail, rate limit, retries,
  concurrent fragments, and file conflict policy
- Component check, component repair, and yt-dlp core update
- English and Simplified Chinese UI

## YouTube Notes

YouTube may ask to confirm that you are not a bot. This can happen on Windows or
macOS depending on network, proxy, browser login state, cookies, and YouTube risk
checks.

If YouTube works on one computer but not another, it is usually caused by:

- different public IP / proxy / DNS / IPv6 route
- different browser login state
- expired cookies
- YouTube anti-bot verification
- macOS Keychain permission when reading Chrome cookies
- older Intel Macs being slower when reading browser cookies or running
  compatibility logic

Try browser cookies first. On macOS, if a Keychain permission prompt appears,
choose `Allow` or `Always Allow`.

## Bilibili Notes

If Bilibili returns:

```text
HTTP Error 412: Precondition Failed
```

it usually means Bilibili rejected the current request. Common fixes:

1. Click `Update Core`.
2. Confirm the video can play in your browser.
3. Use browser cookies:
   - Windows: `Chrome` or `Edge`
   - macOS: `Chrome` or `Safari`
4. If browser cookies fail, use `cookies.txt`.

## Build

Windows:

```powershell
dotnet build
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=false
```

macOS:

```bash
cd YtDlpDownloaderMac
./package-macos.sh
```

macOS package outputs:

```text
YtDlpDownloaderMac/dist/YtDlpDownloader-macOS-universal.dmg
YtDlpDownloaderMac/dist/YtDlpDownloader-macOS-universal.zip
```

Release packages should be uploaded to GitHub Releases, not committed to the
source repository. The local `releases/` folder is ignored by Git.

## Tech Stack

Windows:

- .NET 8
- WPF
- MVVM
- System.Text.Json
- System.Diagnostics.Process

macOS:

- Swift
- SwiftUI
- xcodebuild

Core tools:

- yt-dlp
- ffmpeg
- Deno / Node.js

## 中文说明

YtDlp Downloader 是一个基于 `yt-dlp` 的桌面视频下载工具。它的目标是让普通用户通过图形界面完成视频解析、清晰度选择、下载进度查看，并通过 `ffmpeg` 自动合并音视频。

当前平台：

- Windows：.NET 8 + WPF
- macOS：Swift + SwiftUI

> 请只下载你有权下载的内容，并遵守相关网站服务条款和当地版权法律。

## 快速开始

### Windows

1. 从 GitHub Releases 下载 `YtDlpDownloader-v0.1.2-win-x64.zip`。
2. 解压 zip。
3. 双击 `YtDlpDownloader.exe`。
4. 如果组件状态显示缺失，点击 `Repair Missing / 修复缺失`。
5. 粘贴视频链接，点击 `Analyze / 解析`。
6. 选择清晰度，点击 `Start Download / 开始下载`。

### macOS

1. 从 GitHub Releases 下载 `YtDlpDownloader-macOS-universal.dmg`。
2. 打开 dmg。
3. 把 `YtDlp Downloader.app` 拖到 `Applications / 应用程序`。
4. 如果第一次打开时提示无法验证开发者，请在 `系统设置 -> 隐私与安全性` 中允许打开。
5. 如果组件状态显示缺失，点击 `Repair Missing / 修复缺失`。
6. 粘贴视频链接，点击 `Analyze / 解析`。
7. 选择清晰度，点击 `Start Download / 开始下载`。

## 重要：cookies

有些网站会要求登录、身份验证或确认不是机器人。浏览器里能播放，不代表 `yt-dlp` 一定能直接解析或下载。这时需要把浏览器登录状态提供给 `yt-dlp`，也就是 cookies。

典型需要 cookies 的日志：

```text
Sign in to confirm you're not a bot
No video formats found
Requested format is not available
cookies are no longer valid
HTTP Error 412: Precondition Failed
```

推荐处理顺序：

1. 先确认视频在浏览器里可以正常播放。
2. 在 `Settings / 下载设置` 里把 `Cookies Source / cookies 来源` 改为浏览器：
   - Windows：`Chrome` 或 `Edge`
   - macOS：`Chrome` 或 `Safari`
3. 重新点击 `Analyze / 解析`。
4. 如果读取浏览器 cookies 失败，再导出 `cookies.txt`，并选择 `cookies.txt` 来源。
5. 如果日志提示 cookies 过期，请重新导出 cookies。

### 导出 cookies.txt

Chrome 用户比较方便的方式是使用扩展 `Get cookies.txt LOCALLY`。

操作步骤：

1. 打开 Chrome，并登录目标网站，例如 YouTube。
2. 在 Chrome 网上应用店安装 `Get cookies.txt LOCALLY`。
3. 打开目标网站页面。
4. 使用扩展导出当前网站 cookies，保存为 `cookies.txt`。
5. 打开 YtDlp Downloader 的 `Settings / 下载设置`。
6. 将 `Cookies Source / cookies 来源` 设置为 `cookies.txt`。
7. 选择刚才导出的 `cookies.txt` 文件。
8. 重新解析链接。

cookies 很敏感。不要把 `cookies.txt` 上传到 GitHub、公共网盘或聊天群。拿到 cookies 的人可能在一段时间内模拟你的浏览器登录状态。

yt-dlp 官方说明：

- [How do I pass cookies to yt-dlp?](https://github.com/yt-dlp/yt-dlp/wiki/FAQ#how-do-i-pass-cookies-to-yt-dlp)
- [Exporting YouTube cookies](https://github.com/yt-dlp/yt-dlp/wiki/Extractors#exporting-youtube-cookies)

## 必备组件

应用可以使用本地工具，也可以使用系统 `PATH` 中已经安装的工具。

必备或推荐组件：

- `yt-dlp`：下载核心，用于解析和下载视频
- `ffmpeg`：用于合并分离的视频流和音频流，高清下载通常需要它
- `Deno` / `Node.js`：兼容运行时，用于帮助 yt-dlp 处理部分 YouTube 签名或 challenge 逻辑

应用内提供：

- `Repair Missing / 修复缺失`：自动下载缺失组件
- `Update Core / 更新核心`：更新 `yt-dlp`

普通用户通常不需要手动下载这些工具。组件状态变红时，点击 `Repair Missing / 修复缺失` 即可。

## 功能特性

- 输入视频链接并解析媒体信息
- 展示标题、作者/频道、时长、缩略图和来源链接
- 简单下载选项：最佳画质、1080p、720p、单文件 MP4、仅音频
- 高级格式列表：`format_id`、编码、清晰度、FPS、文件大小、表达式
- 下载进度、速度、ETA 和当前阶段显示
- 下载完成后打开文件或所在目录
- 下载设置：cookies、代理、字幕、封面、限速、重试、并发分片、文件冲突策略
- 组件检查、缺失组件修复、yt-dlp 下载核心更新
- 英文和简体中文界面

## YouTube 说明

YouTube 有时会要求确认不是机器人。这个问题 Windows 和 macOS 都可能遇到，取决于网络、代理、浏览器登录状态、cookies 和 YouTube 风控结果。

如果同一个链接在一台电脑能解析，另一台电脑不能解析，通常是这些因素不同：

- 公网 IP、代理、DNS 或 IPv6 路径不同
- 浏览器是否已经登录 YouTube
- cookies 是否过期
- YouTube 是否触发反机器人验证
- macOS 读取 Chrome cookies 时是否允许 Keychain 权限
- 老款 Intel Mac 读取 cookies 或运行兼容逻辑可能更慢

建议优先使用浏览器 cookies。macOS 如果弹出 Keychain 权限提示，选择 `Allow / 允许` 或 `Always Allow / 始终允许`。

## B 站说明

B 站如果出现：

```text
HTTP Error 412: Precondition Failed
```

通常是 B 站拒绝了当前请求，不一定是链接错误。建议：

1. 点击 `Update Core / 更新核心`。
2. 在浏览器里确认视频可以正常播放。
3. 使用浏览器 cookies：
   - Windows：`Chrome` 或 `Edge`
   - macOS：`Chrome` 或 `Safari`
4. 如果浏览器 cookies 失败，再使用 `cookies.txt`。

## 构建

Windows：

```powershell
dotnet build
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=false
```

macOS：

```bash
cd YtDlpDownloaderMac
./package-macos.sh
```

macOS 输出：

```text
YtDlpDownloaderMac/dist/YtDlpDownloader-macOS-universal.dmg
YtDlpDownloaderMac/dist/YtDlpDownloader-macOS-universal.zip
```

发布包建议上传到 GitHub Releases，不要提交到源码仓库。仓库中的 `releases/` 文件夹已被 Git 忽略。

## 技术栈

Windows：

- .NET 8
- WPF
- MVVM
- System.Text.Json
- System.Diagnostics.Process

macOS：

- Swift
- SwiftUI
- xcodebuild

通用核心：

- yt-dlp
- ffmpeg
- Deno / Node.js

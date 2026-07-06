# YtDlp Downloader

基于 `yt-dlp` 的桌面视频下载工具，当前提供 Windows 版和 macOS 版。

YtDlp Downloader 是一个使用 .NET 8 + WPF 开发的桌面应用，目标是让普通用户可以通过图形界面解析视频链接、选择下载格式、查看下载进度，并通过 `ffmpeg` 自动合并音视频。

English: A desktop video downloader powered by yt-dlp, currently available for Windows and macOS.

## 功能特性

- 输入视频 URL 并解析媒体信息
- 展示标题、作者/频道、时长、缩略图和来源链接
- 简单下载选项：最佳画质、1080p、720p、单文件 MP4、仅音频
- 高级格式列表：`format_id`、编码、清晰度、FPS、文件大小等
- 下载进度、速度、ETA 和当前阶段显示
- 下载完成后打开文件或所在目录
- 下载设置：cookies、代理、字幕、封面、文件冲突策略、限速、重试次数、并发分片数
- 组件检查、缺失组件修复、yt-dlp 下载核心更新

## 技术栈

- .NET 8
- WPF
- MVVM
- yt-dlp
- ffmpeg

## 必备组件

应用可以使用本地 `tools` 目录中的组件，也可以使用系统 `PATH` 中已经安装的组件。

推荐本地结构：

```text
tools/
  yt-dlp.exe
  ffmpeg.exe
  deno.exe
```

说明：

- `yt-dlp.exe`：下载核心，用于解析和下载视频
- `ffmpeg.exe`：视频合并组件，高清音视频分离格式通常需要它
- `deno.exe` / `node.exe`：兼容组件，可帮助 yt-dlp 处理部分 YouTube 提取逻辑

应用内提供：

- `修复缺失`：自动下载缺失组件到 `tools` 目录
- `更新核心`：更新 `yt-dlp.exe`

## YouTube cookies 说明

YouTube 有时会要求确认“不是机器人”，这时即使视频在浏览器里可以播放，`yt-dlp` 也可能无法直接解析或下载。这个问题不是 macOS 独有，Windows 和 macOS 都可能遇到；只是两台电脑的网络出口、代理、浏览器登录状态、cookies、YouTube 风控结果不同，所以可能出现“Windows 能下，macOS 需要 cookies”或反过来的情况。

典型日志包括：

```text
Sign in to confirm you’re not a bot
No video formats found
Requested format is not available
cookies are no longer valid
```

这通常需要给 `yt-dlp` 提供浏览器登录状态，也就是 cookies。

### cookies 是什么

cookies 可以简单理解为“浏览器登录状态”。你在 Chrome 里登录了 YouTube，浏览器会保存一份登录信息。把 cookies 提供给 YtDlp Downloader 后，`yt-dlp` 才更像是在“用你自己的浏览器身份”访问 YouTube。

注意：cookies 很敏感，拿到 cookies 的人可能在一段时间内模拟你的登录状态。不要把 `cookies.txt` 发给别人，不要上传到 GitHub，也不要放到公共网盘。

### 推荐方式 1：直接读取 Chrome / Safari

1. 先在 Chrome 或 Safari 中登录 YouTube。
2. 打开 YtDlp Downloader。
3. 进入 `下载设置`。
4. 将 `cookies 来源` 选择为 `Chrome` 或 `Safari`。
5. 回到链接输入框，重新点击 `解析`。
6. 如果 macOS 弹出钥匙串 / Keychain 权限提示，选择 `允许` 或 `始终允许`。只点一次 `允许` 也可以；点 `始终允许` 后，后续通常不用重复授权。

macOS 版推荐优先选择 `Chrome`。如果 Chrome 正在运行且读取失败，可以完全退出 Chrome 后再解析一次。Windows 版如果选择浏览器 cookies，也同样建议先登录 Chrome 后再解析。

这种方式最省事，不需要自己找 cookies 文件。它对应 yt-dlp 的 `--cookies-from-browser chrome` / `--cookies-from-browser safari`。

### 推荐方式 2：用 Chrome 扩展导出 cookies.txt

如果自动读取浏览器失败，或者你不想让程序直接读取浏览器，可以用 `cookies.txt` 文件。

Chrome 操作步骤：

1. 打开 Chrome，登录 YouTube。
2. 打开 Chrome 网上应用店。
3. 搜索并安装 `Get cookies.txt LOCALLY`。
4. 打开 YouTube 页面，例如 `https://www.youtube.com/`。
5. 点击 Chrome 右上角扩展按钮，打开 `Get cookies.txt LOCALLY`。
6. 导出当前网站 cookies，保存为 `cookies.txt`。
7. 打开 YtDlp Downloader。
8. 进入 `下载设置`。
9. 将 `cookies 来源` 选择为 `cookies.txt`。
10. 点击 `cookies 文件` 的选择按钮，选择刚才导出的 `cookies.txt`。
11. 回到链接输入框，重新点击 `解析`。

建议只在 YouTube 页面导出 cookies，不要导出所有网站 cookies。导出后把 `cookies.txt` 放在自己电脑的安全位置，不要分享给别人。

注意：请确认扩展名称是 `Get cookies.txt LOCALLY`。不要安装来源不明、名字很像的扩展。yt-dlp 官方文档也提醒过，旧的 `Get cookies.txt` 扩展曾被报告为恶意扩展并从 Chrome Web Store 移除。

相关官方说明：

- [yt-dlp FAQ: How do I pass cookies to yt-dlp?](https://github.com/yt-dlp/yt-dlp/wiki/FAQ#how-do-i-pass-cookies-to-yt-dlp)
- [yt-dlp Wiki: Exporting YouTube cookies](https://github.com/yt-dlp/yt-dlp/wiki/Extractors#exporting-youtube-cookies)

### cookies.txt 什么时候用

`cookies 来源 = cookies.txt` 时，下面的 `cookies 文件` 才会生效。

适合这些情况：

- 不想让程序直接读取浏览器 cookies
- Chrome / Safari 自动读取失败
- cookies 来自另一台电脑
- 需要使用浏览器插件导出的固定 cookies 文件

注意：cookies.txt 可能会过期。如果日志提示 `cookies are no longer valid`，请重新从浏览器导出，或改用 `Chrome` / `Safari` 来源。

### Windows 和 macOS 为什么表现不同

同一个 YouTube 链接，在 Windows 上能解析，macOS 上却提示需要 cookies，通常不是程序逻辑完全不同，而是这些因素不同：

- 两台电脑的公网 IP、代理、DNS 或 IPv6 路径不同
- Chrome 是否已经登录 YouTube
- cookies 是否过期
- YouTube 对当前网络是否触发了“不是机器人”验证
- macOS 读取 Chrome cookies 时需要 Keychain 授权
- 旧 Intel Mac 读取 cookies、运行兼容组件可能更慢

所以第一版推荐的处理顺序是：

1. 先在浏览器里确认视频可以正常播放。
2. 在应用里选择 `Chrome` cookies 来源。
3. 如果仍失败，再用 `Get cookies.txt LOCALLY` 导出 `cookies.txt`。
4. 如果提示 cookies 过期，重新导出。
5. 如果突然大量 YouTube 链接失败，先点击应用里的 `更新核心`。

### 不需要 cookies 的情况

公开视频有时可以直接解析，这时 `cookies 来源` 保持 `不使用` 即可。

如果同一个链接在一台电脑能下载，另一台电脑不能下载，通常是网络出口、代理、浏览器登录状态或 cookies 有差异。

## 构建

```powershell
dotnet build
```

## 发布打包

推荐先使用便携文件夹发布方式：

```powershell
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=false
```

发布输出目录：

```text
bin/Release/net8.0-windows/win-x64/publish/
```

把整个 `publish` 文件夹压缩成 zip，例如：

```text
YtDlpDownloader-v0.1.0-win-x64.zip
```

macOS 版在 `YtDlpDownloaderMac/` 下打包：

```bash
cd YtDlpDownloaderMac
./package-macos.sh
```

输出文件：

```text
YtDlpDownloaderMac/dist/YtDlpDownloader-macOS-universal.dmg
YtDlpDownloaderMac/dist/YtDlpDownloader-macOS-universal.zip
```

## 发布包放在哪里

发布压缩包不建议提交到源码仓库。

推荐流程：

1. 本地生成 zip 包
2. 到 GitHub 仓库页面打开 `Releases`
3. 点击 `Draft a new release`
4. 新建版本号，例如 `v0.1.0`
5. 把 zip 包作为 Release Asset 上传

本地可以临时放在：

```text
releases/YtDlpDownloader-v0.1.0-win-x64.zip
```

`releases/` 已在 `.gitignore` 中忽略，不会被提交到 GitHub 源码仓库。

## 注意事项

本项目是 `yt-dlp` 和 `ffmpeg` 的图形界面封装。请遵守相关网站的服务条款和当地版权法律。

`yt-dlp`、`ffmpeg`、`Deno` 是第三方项目，分别遵循各自的许可证。

## English Summary

YtDlp Downloader is a Windows WPF desktop app powered by yt-dlp. It supports video metadata parsing, simple and advanced format selection, download progress display, ffmpeg merging, and component repair/update.

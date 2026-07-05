# YtDlp Downloader

基于 `yt-dlp` 的 Windows 桌面视频下载工具。

YtDlp Downloader 是一个使用 .NET 8 + WPF 开发的桌面应用，目标是让普通用户可以通过图形界面解析视频链接、选择下载格式、查看下载进度，并通过 `ffmpeg` 自动合并音视频。

English: A Windows WPF desktop video downloader powered by yt-dlp.

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

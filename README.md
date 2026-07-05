# YtDlp Downloader

A Windows WPF desktop video downloader powered by yt-dlp.

YtDlp Downloader is a simple Windows desktop tool for parsing video links, choosing download formats, downloading media, and merging audio/video streams through ffmpeg.

## Features

- Parse video URL metadata with yt-dlp
- Show title, author/channel, duration, thumbnail, and source URL
- Simple download options: best quality, 1080p, 720p, single-file MP4, audio only
- Advanced format list with `format_id`, codecs, resolution, FPS, and size
- Download progress, speed, ETA, and current stage display
- Open downloaded file or containing folder after completion
- Download settings for cookies, proxy, subtitles, thumbnail, file conflict policy, rate limit, retries, and concurrent fragments
- Component check, missing component repair, and yt-dlp core update

## Tech Stack

- .NET 8
- WPF
- MVVM
- yt-dlp
- ffmpeg

## Required Components

The app can use tools from its local `tools` folder or from the system `PATH`.

Recommended local layout:

```text
tools/
  yt-dlp.exe
  ffmpeg.exe
  deno.exe
```

`ffmpeg.exe` is required for merging separated audio/video streams. `deno.exe` or `node.exe` can help yt-dlp handle some YouTube extraction cases.

The app provides:

- `修复缺失`: download missing components into `tools`
- `更新核心`: update `yt-dlp.exe`

## Build

```powershell
dotnet build
```

## Publish

Portable folder publish:

```powershell
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=false
```

Output folder:

```text
bin/Release/net8.0-windows/win-x64/publish/
```

For a first release, distribute the whole publish folder as a zip package.

## Notes

This project is a graphical wrapper around yt-dlp and ffmpeg. Please respect copyright laws and the terms of service of supported websites.

yt-dlp, ffmpeg, and Deno are third-party projects with their own licenses.

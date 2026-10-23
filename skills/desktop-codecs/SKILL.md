---
name: desktop-codecs
description: Check and complete multimedia codec support on an Ubuntu desktop — GStreamer plugin sets, FFmpeg codecs, DVD playback, and hardware video decode/encode (VA-API, VDPAU, NVDEC) per GPU vendor — and install what is missing (ubuntu-restricted-extras and friends). Use when asked "what codecs do I have", "video won't play", "install codecs", "H.265 / HEVC / AAC support", "play DVDs", "is hardware video acceleration working", or "browser video uses too much CPU". Local desktop; package checks also work over SSH.
---

# Media codecs

## Target

Local desktop. Package checks and installs work remotely too (`ssh -t <host> 'sudo apt install …'`); `vainfo` needs access to the GPU (`/dev/dri/renderD*`).

## 1. What is installed

```bash
dpkg -l | awk '/^ii/{print $2}' | grep -E '^(gstreamer1\.0-(plugins-(base|good|bad|ugly)|libav|vaapi)|ubuntu-restricted-(extras|addons)|libdvd-pkg|libdvdcss2|ffmpeg)$'
gst-inspect-1.0 2>/dev/null | grep -ciE 'h264|h265|x265|vp9|av1|aac|mp3|opus'
gst-inspect-1.0 avdec_h264 >/dev/null 2>&1 && echo "GStreamer libav: OK"
ffmpeg -hide_banner -decoders 2>/dev/null | grep -E ' (h264|hevc|vp9|av1|aac|mp3|opus) '
ffmpeg -hide_banner -hwaccels 2>/dev/null
```

## 2. Install the usual set

```bash
sudo apt install -y ubuntu-restricted-extras        # MP3, AAC, H.264 via gstreamer, MS fonts (EULA prompt)
sudo apt install -y gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly gstreamer1.0-libav ffmpeg
```

`ubuntu-restricted-extras` pulls `ttf-mscorefonts-installer`, which asks the user to accept a EULA. Kubuntu uses `kubuntu-restricted-extras`, Xubuntu `xubuntu-restricted-extras`.

### DVD playback

```bash
sudo apt install -y libdvd-pkg && sudo dpkg-reconfigure libdvd-pkg    # builds libdvdcss
```

Legality of libdvdcss varies by country; mention it, don't lecture.

## 3. Hardware video acceleration

```bash
sudo apt install -y vainfo vdpauinfo
vainfo 2>&1 | grep -E 'Driver version|VAProfile(H264|HEVC|VP9|AV1)' | head -20
```

| GPU | Packages | Notes |
| --- | --- | --- |
| Intel Broadwell+ | `intel-media-va-driver-non-free` (or `intel-media-va-driver`) | older: `i965-va-driver` |
| AMD | `mesa-va-drivers`, `mesa-vdpau-drivers` | usually preinstalled |
| NVIDIA proprietary | `nvidia-vaapi-driver` (VA-API shim over NVDEC) | `vdpauinfo` works natively; set `LIBVA_DRIVER_NAME=nvidia` |

Check a real decode: `ffmpeg -hwaccel vaapi -i <file> -f null - 2>&1 | tail -3`, or watch `intel_gpu_top` / `nvtop` / `radeontop` while playing.

Browsers: Firefox (snap on Ubuntu) uses VA-API when `about:support` shows "HARDWARE_VIDEO_DECODING: available"; Chrome needs it enabled per release. Snap/Flatpak apps ship their own codec stack — a missing codec there is fixed inside the app's runtime (e.g. `flatpak install org.freedesktop.Platform.ffmpeg-full`), not by apt.

## Desktop vs server

- **Desktop**: the whole skill.
- **Server**: only `ffmpeg` and, for transcoding servers (Jellyfin/Plex), the VA-API/NVENC part; add the service user to the `render` group.

## Confirm before

- Installing packages, especially those with EULAs or building libdvdcss.
- Setting environment variables system-wide (`/etc/environment`).

## Report

Installed vs missing codec sets, hardware acceleration status per codec (decode/encode), what was installed, and any app-specific (snap/Flatpak) caveats.

## Related

- `hardware-gpu` — GPU drivers.
- `desktop-fonts` — the MS core fonts pulled by restricted-extras.
- `packages-snap-flatpak` — sandboxed app runtimes.

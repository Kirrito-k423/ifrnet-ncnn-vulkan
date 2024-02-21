

# Windows

git bash set `.bashrc`

```bash
export PATH=/e/commonSoftware/ifrnet-ncnn-vulkan-20220720-windows:/e/commonSoftware/ffmpeg-master-latest-win64-gpl/bin:$PATH
```

# 解析

```bash
ffmpeg.exe -i "../$input_video" -map 0:v:0 input_frames/frame_%08d.png
# 处理器	Intel(R) Core(TM) i7-10700 CPU @ 2.90GHz，2904 Mhz，8 个内核，16 个逻辑处理器
frame=1192388 fps=93 q=-0.0 size=N/A time=00:00:01.83 bitrate=N/A dup=1197228 drop=0 speed=0.000143x
# Intel(R) Xeon(R) Platinum 8358 CPU @ 2.60GHz （32 cores）
frame=175897 fps=2319 q=-0.0 size=N/A time=00:00:00.27 bitrate=N/A dup=175864 drop=0 speed=0.00357x
```

输出的其他信息是关于当前处理状态的详情：

- `frame=119238`：表示已经处理了 119238 帧。
- `fps=93`：表示处理的速度是每秒 93 帧。
- `q=-0.0`：表示输出文件的质量，通常用于指定压缩率，`-1` 表示最好的质量。
- `size=N/A`：表示当前处理的帧的大小，N/A 通常意味着这个信息不适用，可能是因为正在处理的是单个帧，而不是连续的视频流。
- `time=00:01:01.83`：表示已经处理的视频长度，这里是 1 分 1.83 秒。
- `bitrate=N/A`：表示视频的比特率，N/A 表示不适用或不可用。
- `dup=1197228`：表示有多少帧被复制，可能是因为在提取帧时遇到了重复的帧。
- `drop=0`：表示有多少帧被丢弃。
- `speed=0.000143x`：表示处理的速度是正常播放速度的多少倍，这里大约是 1/7000 倍，意味着处理速度非常慢，这可能是因为命令在执行时已经接近完成。


# Other

## IFRNet ncnn Vulkan

:exclamation: :exclamation: :exclamation: This software is in the early development stage, it may bite your cat

![CI](https://github.com/nihui/ifrnet-ncnn-vulkan/workflows/CI/badge.svg)
![download](https://img.shields.io/github/downloads/nihui/ifrnet-ncnn-vulkan/total.svg)

ncnn implementation of IFRNet: Intermediate Feature Refine Network for Efficient Frame Interpolation.

ifrnet-ncnn-vulkan uses [ncnn project](https://github.com/Tencent/ncnn) as the universal neural network inference framework.

## [Download](https://github.com/nihui/ifrnet-ncnn-vulkan/releases)

Download Windows/Linux/MacOS Executable for Intel/AMD/Nvidia GPU

**https://github.com/nihui/ifrnet-ncnn-vulkan/releases**

This package includes all the binaries and models required. It is portable, so no CUDA or PyTorch runtime environment is needed :)

## About IFRNet

IFRNet: Intermediate Feature Refine Network for Efficient Frame Interpolation

https://github.com/ltkong218/IFRNet

Lingtong Kong, Boyuan Jiang, Donghao Luo, Wenqing Chu, Xiaoming Huang, Ying Tai, Chengjie Wang, Jie Yang

https://arxiv.org/abs/2205.14620

## Usages

Input two frame images, output one interpolated frame image.

### Example Commands

```shell
./ifrnet-ncnn-vulkan -0 0.jpg -1 1.jpg -o 01.jpg
./ifrnet-ncnn-vulkan -i input_frames/ -o output_frames/
```

Example below runs on CPU, Discrete GPU, and Integrated GPU all at the same time. Uses 2 threads for image decoding, 4 threads for one CPU worker, 4 threads for another CPU worker, 2 threads for discrete GPU, 1 thread for integrated GPU, and 4 threads for image encoding.
```shell
./ifrnet-ncnn-vulkan -i input_frames/ -o output_frames/ -g -1,-1,0,1 -j 2:4,4,2,1:4
```

### Video Interpolation with FFmpeg

```shell
mkdir input_frames
mkdir output_frames

# find the source fps and format with ffprobe, for example 24fps, AAC
ffprobe input.mp4

# extract audio
ffmpeg -i input.mp4 -vn -acodec copy audio.m4a

# decode all frames
ffmpeg -i input.mp4 input_frames/frame_%08d.png

# interpolate 2x frame count
./ifrnet-ncnn-vulkan -i input_frames -o output_frames

# encode interpolated frames in 48fps with audio
ffmpeg -framerate 48 -i output_frames/%08d.png -i audio.m4a -c:a copy -crf 20 -c:v libx264 -pix_fmt yuv420p output.mp4
```

### Full Usages

```console
Usage: ifrnet-ncnn-vulkan -0 infile -1 infile1 -o outfile [options]...
       ifrnet-ncnn-vulkan -i indir -o outdir [options]...

  -h                   show this help
  -v                   verbose output
  -0 input0-path       input image0 path (jpg/png/webp)
  -1 input1-path       input image1 path (jpg/png/webp)
  -i input-path        input image directory (jpg/png/webp)
  -o output-path       output image path (jpg/png/webp) or directory
  -n num-frame         target frame count (default=N*2)
  -s time-step         time step (0~1, default=0.5)
  -m model-path        ifrnet model path (default=IFRNet_Vimeo90K)
  -g gpu-id            gpu device to use (-1=cpu, default=auto) can be 0,1,2 for multi-gpu
  -j load:proc:save    thread count for load/proc/save (default=1:2:2) can be 1:2,2,2:2 for multi-gpu
  -x                   enable tta mode
  -u                   enable UHD mode
  -f pattern-format    output image filename pattern format (%08d.jpg/png/webp, default=ext/%08d.png)
```

- `input0-path`, `input1-path` and `output-path` accept file path
- `input-path` and `output-path` accept file directory
- `num-frame` = target frame count
- `time-step` = interpolation time
- `load:proc:save` = thread count for the three stages (image decoding + ifrnet interpolation + image encoding), using larger values may increase GPU usage and consume more GPU memory. You can tune this configuration with "4:4:4" for many small-size images, and "2:2:2" for large-size images. The default setting usually works fine for most situations. If you find that your GPU is hungry, try increasing thread count to achieve faster processing.
- `pattern-format` = the filename pattern and format of the image to be output, png is better supported, however webp generally yields smaller file sizes, both are losslessly encoded

If you encounter a crash or error, try upgrading your GPU driver:

- Intel: https://downloadcenter.intel.com/product/80939/Graphics-Drivers
- AMD: https://www.amd.com/en/support
- NVIDIA: https://www.nvidia.com/Download/index.aspx

## Build from Source

1. Download and setup the Vulkan SDK from https://vulkan.lunarg.com/
  - For Linux distributions, you can either get the essential build requirements from package manager
```shell
dnf install vulkan-headers vulkan-loader-devel
```
```shell
apt-get install libvulkan-dev
```
```shell
pacman -S vulkan-headers vulkan-icd-loader
```

2. Clone this project with all submodules

```shell
git clone https://github.com/nihui/ifrnet-ncnn-vulkan.git
cd ifrnet-ncnn-vulkan
git submodule update --init --recursive
```

3. Build with CMake
  - You can pass -DUSE_STATIC_MOLTENVK=ON option to avoid linking the vulkan loader library on MacOS

```shell
mkdir build
cd build
cmake ../src
cmake --build . -j 4
```

### TODO

* UHD mode
* adaptive image mean
* test-time temporal augmentation aka TTA-t

## Sample Images

### Original Image

![origin0](images/0.png)
![origin1](images/1.png)

### Interpolate with ifrnet IFRNet_Vimeo90K model

```shell
ifrnet-ncnn-vulkan.exe -m models/IFRNet_Vimeo90K -0 0.png -1 1.png -o out.png
```

![ifrnet](images/out.png)

## Original IFRNet Project

- https://github.com/ltkong218/IFRNet

## Other Open-Source Code Used

- https://github.com/Tencent/ncnn for fast neural network inference on ALL PLATFORMS
- https://github.com/webmproject/libwebp for encoding and decoding Webp images on ALL PLATFORMS
- https://github.com/nothings/stb for decoding and encoding image on Linux / MacOS
- https://github.com/tronkko/dirent for listing files in directory on Windows

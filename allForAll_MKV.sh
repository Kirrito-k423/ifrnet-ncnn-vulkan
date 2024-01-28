#!/bin/bash

log_and_print() {
    # 使用绿色打印文本
    echo -e "\033[0;32m$1\033[0m"
    echo -e "$1" >> times.log
}

create_dir_if_not_exists() {
    local dir_name="$1"  # 将第一个参数（传入的目录名）赋值给局部变量 dir_name

    if [ ! -d "$dir_name" ]; then
        mkdir "$dir_name"
        log_and_print "Directory '$dir_name' created."
    else
        log_and_print "Directory '$dir_name' already exists."
    fi
}


# Input MKV file
input_mk="$1"

# Extract filename without extension for the directory name
filename=$(basename "$input_mk" .mkv)

# Create a timestamped directory including the filename
timestamp="${filename}"
mkdir -p "$timestamp"
cd "$timestamp"

# Record start time
start_time=$(date +%s)

log_and_print "\nNew task $(date -d @$start_time '+%Y-%m-%d %H:%M:%S')"

# Check if audio.m4a already exists
if [ ! -f "audio.m4a" ]; then
    log_and_print "Extracting audio..."
    ffmpeg -i "../$input_mk" -map 0:a:0 -vn -acodec copy audio.m4a
else
    log_and_print "Audio file already exists, skipping extraction."
fi

# Log time taken
end_time=$(date +%s)
log_and_print "Extract audio: $((end_time - start_time)) seconds"

# Decode all frames from the first video stream
log_and_print "\nDecoding frames..."
start_time=$(date +%s)
create_dir_if_not_exists input_frames

# total_frames is too slow, about 1/3  of decode time
# total_frames=$(ffprobe -v error -select_streams v:0 -count_frames -show_entries stream=nb_read_frames -of default=nokey=1:noprint_wrappers=1 "../$input_mk")

# 获取帧率
fps=$(ffprobe -v error -select_streams v:0 -of default=noprint_wrappers=1:nokey=1 -show_entries stream=r_frame_rate "../$input_mk" | bc -l)
log_and_print "FPS: $fps"

# 获取总时长（秒）
duration=$(ffprobe -v error -select_streams v:0 -of default=noprint_wrappers=1:nokey=1 -show_entries format=duration "../$input_mk" | bc -l)
log_and_print "Duration: $duration seconds"

# 计算估算的总帧数
estimated_total_frames=$(echo "$fps * $duration" | bc | awk '{printf("%d\n", $1)}')
log_and_print "Estimated total frames: $estimated_total_frames"

# 计算75%的目标帧数
target_frame_count=$(echo "$estimated_total_frames * 0.75" | bc | awk '{printf("%d\n", $1)}')
log_and_print "Target frame count (75%): $target_frame_count"

frame_files_count=$(ls input_frames | wc -l)
log_and_print "Current frame files count: $frame_files_count"

if [ "$frame_files_count" -ge "$target_frame_count" ]; then
    log_and_print "All frames have been generated."
else
    log_and_print "Frame generation might be incomplete."
    ffmpeg -i "../$input_mk" -map 0:v:0 input_frames/frame_%08d.png
fi

# Log time taken
end_time=$(date +%s)
log_and_print "Decode frames: $((end_time - start_time)) seconds"


# Count the number of decoded frames
frame_count=$(ls input_frames | wc -l)

# Calculate the number of frames needed for 120fps based on the original frame rate
fps_rounded=$(printf "%.0f" "$fps")
log_and_print "FPS: $fps_rounded"
num_frames_needed=$((frame_count * 120 / fps_rounded))
log_and_print "num_frames_needed: $num_frames_needed"
time_step=$(echo "scale=2; $fps_rounded / 120" | bc)
log_and_print "time_step: $time_step"


# 检查 output_frames 目录中的图片数量
output_frame_count=$(ls output_frames | wc -l)

# 只有当 output_frames 中的图片数量少于 num_frames_needed 时才运行 ifrnet-ncnn-vulkan
if [ "$output_frame_count" -lt "$num_frames_needed" ]; then
    log_and_print "\nRunning ifrnet-ncnn-vulkan..."
    start_time=$(date +%s)
    create_dir_if_not_exists output_frames
    ../ifrnet-ncnn-vulkan -m ../IFRNet_GoPro -i input_frames -o output_frames -g -1,-1,0,1 -j 8:4,4,2,2:8 -n "$num_frames_needed" -s $time_step

    # 记录 ifrnet-ncnn-vulkan 运行时间
    end_time=$(date +%s)
    log_and_print "ifrnet-ncnn-vulkan run time: $((end_time - start_time)) seconds"
else
    log_and_print "\nSkipping ifrnet-ncnn-vulkan: output_frames contains $output_frame_count files, which meets or exceeds the required $num_frames_needed frames."
fi

# Encode interpolated frames
log_and_print "\nEncoding video..."
start_time=$(date +%s)
ffmpeg -framerate 120 -i output_frames/%08d.png -i audio.m4a -c:a copy -crf 18 -c:v libx264 -pix_fmt yuv420p output.mp4

# Log time taken
end_time=$(date +%s)
log_and_print "Encode video: $((end_time - start_time)) seconds"

# Return to the original directory
cd ..

log_and_print "All operations completed. Time log is in the $timestamp/times.log file."


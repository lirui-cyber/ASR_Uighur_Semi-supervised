"""
Author: Li Rui
Description: This script merges short audios into long audios.
"""

import os
from pydub import AudioSegment
import argparse
from collections import defaultdict

def concatenate_audio(input_folder, output_folder, required_duration, silence_duration):
    # 获取文件夹中的所有wav文件
    wav_files = [file for file in os.listdir(input_folder) if file.endswith('.wav')]
    # 按照起始时间排序
    wav_files.sort(key=lambda x: float(x.split('_')[-2]))
    # 以起始时间作为键，存储需要拼接的音频片段
    segments = defaultdict(list)
    current_duration = 0
    flag = True
    last_segment_short = False
    start_key = float
    for wav_file in wav_files:
        # 解析文件名获取音频信息
        audio_name = wav_file[:-4]  # 去除文件扩展名
        audio_parts = audio_name.split('_')  # 通过下划线分割音频信息
        audio_name1 = audio_parts[0]
        audio_name2 = audio_parts[1]
        start_time = float(audio_parts[2])
        end_time = float(audio_parts[3])
        if flag:
            start_key = start_time
        # 计算音频时长
        audio_path = os.path.join(input_folder, wav_file)
        audio = AudioSegment.from_wav(audio_path)
        duration = len(audio) / 1000  # 转换为秒
        last_second = int(duration) % required_duration
        ###
        if duration > required_duration:
            num_segments = int(duration / required_duration)
            for i in range(num_segments):

                end_time = start_time + (i + 1) * required_duration
                segment = audio[i * required_duration * 1000: (i + 1) * required_duration * 1000]
                if not last_segment_short:
                    start_key = round(start_time + i * required_duration, 3)
                else:
                    last_segment_short = False
                segments[start_key].append(segment)
            if last_second == 0:
                flag = True
                last_segment_short = False
                current_duration = 0
                continue
            start_key = round(start_time + num_segments * required_duration, 3)
            segment = audio[num_segments * required_duration * 1000: (num_segments * required_duration + last_second) * 1000]
            audio = segment
            duration = last_second
        current_duration += duration
        # 如果音频时长小于10秒，则添加到对应的起始时间键下
        segments[start_key].append(audio)
        if current_duration < required_duration - 1:
            last_segment_short = True
            flag = False
        else:
            flag = True
            current_duration = 0
    # 依次处理每个起始时间的音频片段
    for start_time, audio_list in segments.items():
        output_segments = []
        for audio in audio_list:
            # 添加当前音频片段和0.5秒的停顿
            output_segments.append(audio)
            output_segments.append(AudioSegment.silent(duration=silence_duration*1000))  # 0.5秒的停顿
        # 拼接音频片段
        output = sum(output_segments)
        # 生成文件名
        output_filename = f'{audio_name1}_{audio_name2}_{int(start_time)}_{int(start_time+output.duration_seconds)}.wav'
        output_path = os.path.join(output_folder, output_filename)
        # 保存拼接后的音频文件
        output.export(output_path, format='wav')

        print(f'生成音频文件: {output_filename}')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Process audio")
    parser.add_argument('--input_folder', help='Audio folder processed by VAD')
    parser.add_argument('--output_folder', help='Audio output path')
    parser.add_argument('--required_duration', default=10, type=int, help='Merging duration')
    parser.add_argument('--silence_duration', default=0.5, type=float, help='Silence duration')
    args = parser.parse_args()
    concatenate_audio(args.input_folder, args.output_folder, args.required_duration, args.silence_duration)

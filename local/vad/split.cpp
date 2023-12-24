#include "split.h"
#include <iostream>
#include <string>
#include <vector>
 #include <sstream>
extern "C" {
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavutil/opt.h>

}

#include <filesystem>

void split_audio(const std::string& input_file, const std::string& output_file, double start_time, double end_time) {
    av_register_all();  //??

    AVFormatContext* input_format_context = nullptr;
    if (avformat_open_input(&input_format_context, input_file.c_str(), nullptr, nullptr) < 0) {
        std::cerr << "Cannot open input file: " << input_file << std::endl;
        return;
    }

    if (avformat_find_stream_info(input_format_context, nullptr) < 0) {
        std::cerr << "Cannot find input stream information" << std::endl;
        return;
    }

    int audio_stream_index = -1;
    for (unsigned int i = 0; i < input_format_context->nb_streams; ++i) {
        if (input_format_context->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_AUDIO) {
            audio_stream_index = i;
            break;
        }
    }

    if (audio_stream_index == -1) {
        std::cerr << "No audio stream found" << std::endl;
        return;
    }

    AVStream* input_stream = input_format_context->streams[audio_stream_index];
    AVCodecParameters* input_codecpar = input_stream->codecpar;
    AVCodec* codec = avcodec_find_decoder(input_codecpar->codec_id);
    AVCodecContext* input_codec_context = avcodec_alloc_context3(codec);
    avcodec_parameters_to_context(input_codec_context, input_codecpar);
    avcodec_open2(input_codec_context, codec, nullptr);

    AVFormatContext* output_format_context = nullptr;
    avformat_alloc_output_context2(&output_format_context, nullptr, nullptr, output_file.c_str());
    if (!output_format_context) {
        std::cerr << "Cannot create output format context" << std::endl;
        return;
    }

    AVStream* output_stream = avformat_new_stream(output_format_context, codec);
    if (!output_stream) {
        std::cerr << "Cannot create output stream" << std::endl;
        return;
    }

    AVCodecParameters* output_codecpar = output_stream->codecpar;
    avcodec_parameters_copy(output_codecpar, input_codecpar);

    if (avio_open(&output_format_context->pb, output_file.c_str(), AVIO_FLAG_WRITE) < 0) {
        std::cerr << "Cannot open output file: " << output_file << std::endl;
        return;
    }

    avformat_write_header(output_format_context, nullptr);

    AVPacket packet;
    av_init_packet(&packet);

    bool finished = false;
    while (!finished && av_read_frame(input_format_context, &packet) >= 0) {
        if (packet.stream_index == audio_stream_index) {
            double packet_pts_time = packet.pts * av_q2d(input_stream->time_base);

            if (packet_pts_time >= start_time && packet_pts_time <= end_time) {
                packet.stream_index = output_stream->index;
                packet.pts = av_rescale_q_rnd(packet.pts, input_stream->time_base, output_stream->time_base, static_cast<AVRounding>(AV_ROUND_NEAR_INF | AV_ROUND_PASS_MINMAX));
                packet.dts = av_rescale_q_rnd(packet.dts, input_stream->time_base, output_stream->time_base, static_cast<AVRounding>(AV_ROUND_NEAR_INF | AV_ROUND_PASS_MINMAX));
                packet.duration = av_rescale_q(packet.duration, input_stream->time_base, output_stream->time_base);
                packet.pos = -1;

             if (av_interleaved_write_frame(output_format_context, &packet) < 0) {
                 std::cerr << "Error writing packet to output file" << std::endl;
                 break;
             }
         } else if (packet_pts_time > end_time) {
             finished = true;
         }
     }

     av_packet_unref(&packet);
 }

    av_write_trailer(output_format_context);
    avio_closep(&output_format_context->pb);
    avformat_free_context(output_format_context);
    avformat_close_input(&input_format_context);
    avcodec_free_context(&input_codec_context);
}


int main1(std::string save_path,std::string file_name,std::vector<float> start,std::vector<float> end) {

//    std::cout << "save_path:" << save_path << std::endl;
//    std::cout << "save_path:" << file_name << std::endl;
    if(start.size()==end.size()){
        for(int i =0;i<start.size();i++){
            std::string input_file = file_name;
            std::stringstream ss;
            // 将字符串和整数拼接到字符串流中
//            ss << "E:/test-wav/split/split_temp"<<start[i]<<"__"<<end[i]<< ".wav";
            ss << save_path<<"_"<<start[i]<<"_"<<end[i]<< ".wav";
            // 从字符串流中获取结果字符串
            std::string result = ss.str();
            std::string output_file = result;
            double start_time = start[i];
            double end_time = end[i];

            split_audio(input_file, output_file, start_time, end_time);
        }
    }
    return 0;
}

void writeVectorToFile(const std::vector<float>& vec1, const std::vector<float>& vec2, const std::string& filename)
{
    std::ofstream file(filename);
    if (file.is_open())
    {
        file<<vec1.size()<<"\n";
        for (size_t i = 0; i < vec1.size(); ++i)
        {
            file << vec1[i] << " " << vec2[i] << "\n";
        }
        file<<filename<<"\n";
        file.close();

        std::cout << "success save: " << filename << std::endl;
    }
    else
    {
        std::cout << "do not open: " << filename << std::endl;
    }
}


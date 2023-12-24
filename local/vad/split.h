#ifndef SPLIT_H
#define SPLIT_H

#endif // SPLIT_H
#include <iostream>
#include <string>
#include <vector>
 #include <sstream>
#include <fstream>

int main1(std::string save_path,std::string file_name,std::vector<float> start,std::vector<float> end);
void split_audio(const std::string& input_file, const std::string& output_file, double start_time, double end_time);
//写入文件
void writeVectorToFile(const std::vector<float>& vec1, const std::vector<float>& vec2, const std::string& filename);

# ASR_Uighur_Semi-supervised
This script mainly uses wenet for semi-supervised training.  
Unsupervised data(16k) -> VAD -> Inference -> Combine supervised data -> Training -> Test
## Flow Description
1. Step 1: VAD 切分无监督数据，然后根据需要的时长合并短音频  
2. Step 2: 准备 kaldi 格式的文件[wav.scp, text, utt2spk, spk2utt]  
3. Step 3: 提取80维 Fbank 特征  
4. Step 4: 整理成 wenet 格式的文件 [format.data]  
5. Step 5: 使用预训练的维吾尔语模型推理无监督数据  
6. Step 6: 合并无监督数据和有监督数据，生成半监督训练集  
7. Step 7: 半监督训练  
8. Step 8: 测试  
## Pretrianed model
For pretrained model (asr, vad) trained on 16k data, you can download from this link:  
https://drive.google.com/drive/folders/1cNP0KFGUKRCipywwRkKjqhQM2SrkPczQ?usp=sharing

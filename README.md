# ASR_Uighur_Semi-supervised
This script mainly uses wenet for semi-supervised training.  
Unsupervised data -> VAD -> Inference -> Combine supervised data -> Training -> Test
## Flow Description
1. Step 1: VAD 切分无监督数据，然后根据需要的时长合并短音频  
2. Step 2: 准备 kaldi 格式的文件[wav.scp, text, utt2spk, spk2utt] 


#!/bin/bash
#
# Author: Li Rui
# Description: VAD -> Splicing shot audio -> Inference -> Training -> Test
# Need: VAD script, Splicing script, lading script

. ./path.sh || exit 1;
. ./cmd.sh || exit 1;

set -e
set -u
set -o pipefail

stage=8
stop_stage=8
nj=20
cmd="slurm.pl --quiet "

# Data Realated
wave_data=data
#vad_raw_wav_dir=/home/zwb521/guangdian/audio
vad_raw_wav_dir=/home/lr521/wenet/examples/uy/s2/source_data

vad_train_set=UU2

use_original_train_set=true
original_train_set=Latin_U123456_2641H # Whether required or not, it must be specified because a dictionary is required

train_set=semi_train_set # Final Training set name
asr_dev_set=test_uu1_Latin_U123456_2841H
asr_recog_set="2030_test"

# Output
dir=exp/asr_${train_set}

# Model Realated
vad_checkpoint=pretrained_model/vad_model/silero_vad.onnx
asr_inference_vad_data_checkpoint=pretrained_model/asr_model/29.pt
asr_inference_vad_data_checkpoint_global_cmvn=pretrained_model/asr_model/global_cmvn
asr_config=pretrained_model/asr_model/train.yaml
asr_train_checkpoint=
asr_inference_checkpoint=$dir/0.pt


# Config
combine_short_wav=true
combine_duration=10 # second
silence_duration=0.5 # second

train_config=conf/train_conformer_large.yaml
average_checkpoint=false
average_num=5
decode_modes="attention_rescoring"
cmvn=true
do_delta=false
nbpe=5000
bpemode=unigram
#dict=$wave_data/lang_char/${original_train_set}_${bpemode}${nbpe}_units.txt
dict=pretrained_model/asr_model/Latin_U123456_2641H_unigram5000_units.txt
#bpemodel=$wave_data/lang_char/${train_set}_${bpemode}${nbpe}
bpemodel=pretrained_model/asr_model/Latin_U123456_2641H_unigram5000
. tools/parse_options.sh || exit 1;


# Use vad model to split long wav audio
if [ ${stage} -le 1 ] && [ ${stop_stage} -ge 1 ]; then

  vad_output_original_dir=${wave_data}/${vad_train_set}/wav/original
  mkdir -p ${vad_output_original_dir}

  echo "stage 1: vad"
  # 假设vad_raw_wav_dir里面包含多个音频，每个音频是一个时长 45 分钟的电视剧
  for long_wav_file in "${vad_raw_wav_dir}"/*; do
    # check file
    if [[ ${long_wav_file} == *.wav ]]; then
      long_wav_file_name="$(basename "$long_wav_file")"
      long_wav_file_name=${long_wav_file_name%.*}
      #echo $long_wav_file_name
      #mkdir -p ${vad_output_original_dir}/${long_wav_file_name}

      vad_tool  ${vad_checkpoint} ${long_wav_file} ${vad_output_original_dir}

      if ${combine_short_wav}; then

        vad_output_combine_dir=${wave_data}/${vad_train_set}/wav/combine/${long_wav_file_name}
        mkdir -p ${vad_output_combine_dir}

        python3 local/merge_audio.py \
          --input_folder ${vad_output_original_dir}/${long_wav_file_name}_split \
          --output_folder ${vad_output_combine_dir} \
          --required_duration ${combine_duration} \
          --silence_duration ${silence_duration}
      fi
    fi
  done

fi

# 合并之后 ./data/uu1/wav/combine/{drama_1, drama_2,...}/*.wav
if ${combine_short_wav}; then
  vad_output_wav_dir=${wave_data}/${vad_train_set}/wav/combine
else
  vad_output_wav_dir=${wave_data}/${vad_train_set}/wav/original
fi

if [ ${stage} -le 2 ] && [ ${stop_stage} -ge 2 ]; then

  echo "stage 2: Prepare kaldi-format data"
  python3 local/generate_kaldi_format_file.py \
      --folder_path $vad_output_wav_dir \
      --output_path ${wave_data}/${vad_train_set}
  utils/validate_data_dir.sh --no-feats --no-spk-sort  ${wave_data}/${vad_train_set} || exit 1;
  
fi

if [ ${stage} -le 3 ] && [ ${stop_stage} -ge 3 ]; then

  echo "stage 3: Feature Generation"
  fbankdir=fbank_no_pitch
    # Generate the fbank features; by default 80-dimensional fbanks with pitch on each frame
    for x in  ${vad_train_set} ${asr_dev_set} ${asr_recog_set}; do
       steps/make_fbank.sh --cmd "${cmd}" --nj ${nj} --write_utt2num_frames true \
            ${wave_data}/${x} exp/make_fbank_no_pitch/${x} ${fbankdir}/$x
        utils/fix_data_dir.sh ${wave_data}/${x}
    done
    if ${use_original_train_set}; then
      for x in ${original_train_set}; do
        steps/make_fbank.sh --cmd "${cmd}" --nj ${nj} --write_utt2num_frames true \
            ${wave_data}/${x} exp/make_fbank_no_pitch/${x} ${fbankdir}/$x

        utils/fix_data_dir.sh ${wave_data}/${x}
      done
    fi

fi

if [ ${stage} -le 4 ] && [ ${stop_stage} -ge 4 ]; then

  echo "stage 4: Prepare wenet-format data"
  # 整理成wenet-format data
  for x in ${vad_train_set}; do
        tools/format_data.sh   --nj ${nj} --feat ${wave_data}/$x/feats.scp --bpecode ${bpemodel}.model \
            ${wave_data}/$x ${dict} > ${wave_data}/$x/format.data
  done
fi

if [ ${stage} -le 5 ] && [ ${stop_stage} -ge 5 ]; then


  echo "stage 5: Inference unsupervised vad data"
  cmvn_opts=
  $cmvn && cmvn_opts="--cmvn $asr_inference_vad_data_checkpoint_global_cmvn"

  mkdir -p $dir
  decoding_chunk_size=
  ctc_weight=0.5
  # Polling GPU id begin with index 0
  num_gpus=0
  idx=0
  split_scps=""
  mkdir -p ${wave_data}/${vad_train_set}/split${nj}

  for n in $(seq ${nj}); do
    split_scps="${split_scps} ${wave_data}/${vad_train_set}/split${nj}/format.${n}.data"
  done
  tools/data/split_scp.pl ${wave_data}/${vad_train_set}/format.data ${split_scps}

  test=$vad_train_set
  mode=${decode_modes}
  test_dir=$dir/${vad_train_set}
  mkdir -p $test_dir

  for n in $(seq ${nj}); do
  {
		ngpu=0
	$cmd  $test_dir/recognise_${n}.log \
		./script/recognize_deprecated.sh \
		--mode $mode \
		--config $asr_config \
		--dir $dir \
		--test_data ./${wave_data}/$test/split${nj}/format.${n}.data \
		--decode_checkpoint ${asr_inference_vad_data_checkpoint} \
		--dict $dict \
		--result_file $test_dir/text_${n}_bpe \
		--test_dir $test_dir || exit 1;

    tools/spm_decode --model=${bpemodel}.model --input_format=piece \
      < $test_dir/text_${n}_bpe | sed -e "s/▁/ /g" > $test_dir/text_${n}

  } &
    done
  wait

  for n in $(seq ${nj});do
    cat ${test_dir}/text_${n}
  done > ${test_dir}/text_decode
  sed -i 's#  # #' ${test_dir}/text_decode
  cp ${test_dir}/text_decode ${wave_data}/${vad_train_set}/text
fi



if [ ${stage} -le 6 ] && [ ${stop_stage} -ge 6 ]; then

  echo "stage 6: Prepare wenet-format data with inference text"
  if ${use_original_train_set}; then

    utils/combine_data.sh ${wave_data}/${train_set} ${wave_data}/${vad_train_set} ${wave_data}/${original_train_set}
    utils/fix_data_dir.sh ${wave_data}/${train_set}
  else
    train_set=${vad_train_set}
  fi

  for x in ${train_set}; do
    tools/format_data.sh   --nj ${nj} --feat data/$x/feats.scp --bpecode ${bpemodel}.model \
        ${wave_data}/$x ${dict} > ${wave_data}/$x/format.data
  done
  # compute global CMVN
   compute-cmvn-stats --binary=false scp:${wave_data}/${train_set}/feats.scp ${wave_data}/${train_set}/global_cmvn

fi

if [ ${stage} -le 7 ] && [ ${stop_stage} -ge 7 ]; then

  echo "stage 7: Training model"
  mkdir -p $dir/log
  # You have to rm `INIT_FILE` manually when you resume or restart a
  # multi-machine training.
  INIT_FILE=$dir/ddp_init
  init_method=file://$(readlink -f $INIT_FILE)
  echo "$0: init method is $init_method"
  num_gpus=1
  # Use "nccl" if it works, otherwise use "gloo"
  dist_backend="gloo"
  cmvn_opts=
  $cmvn && cp ${wave_data}/${train_set}/global_cmvn $dir
  $cmvn && cmvn_opts="--cmvn ${dir}/global_cmvn"

  $cmd   --num-threads 4  --gpu 1  JOB=1:$num_gpus $dir/log/train.JOB.log \
       ./script/train.sh \
       --train_config $train_config  \
       --dict $dict \
       --train ./${wave_data}/$train_set/format.data  \
       --dev ./${wave_data}/$asr_dev_set/format.data  \
       --ngpu $num_gpus \
       --part JOB \
       --dist_backend $dist_backend \
       --checkpoint "$asr_train_checkpoint" \
       --cmvn_dir ./${wave_data}/$train_set/global_cmvn \
        $dir $init_method || exit 1;
fi

if [ ${stage} -le 8 ] && [ ${stop_stage} -ge 8 ]; then
  echo "stage 8: Test data"
  cmvn_opts=
  $cmvn && cmvn_opts="--cmvn ${wave_data}/${train_set}/global_cmvn"

  decoding_chunk_size=
  ctc_weight=0.5
  # Polling GPU id begin with index 0
  num_gpus=0
  idx=0
  split_scps=""
  mkdir -p ${wave_data}/${asr_recog_set}/split${nj}

  for n in $(seq ${nj}); do
    split_scps="${split_scps} ${wave_data}/${asr_recog_set}/split${nj}/format.${n}.data"
  done
  tools/data/split_scp.pl ${wave_data}/${asr_recog_set}/format.data ${split_scps}

  test=$asr_recog_set
  mode=${decode_modes}
  test_dir=$dir/${asr_recog_set}
  mkdir -p $test_dir

  for n in $(seq ${nj}); do
  {
		ngpu=0
	$cmd  $test_dir/recognise_${n}.log \
		./script/recognize_deprecated.sh \
		--mode $mode \
		--dir $dir \
		--test_data ./${wave_data}/$test/split${nj}/format.${n}.data \
		--decode_checkpoint ${asr_inference_checkpoint} \
		--dict $dict \
		--result_file $test_dir/text_${n}_bpe \
		--test_dir $test_dir || exit 1;

    tools/spm_decode --model=${bpemodel}.model --input_format=piece \
      < $test_dir/text_${n}_bpe | sed -e "s/▁/ /g" > $test_dir/text_${n}

  } &
    done
  wait

  for n in $(seq ${nj});do
    cat ${test_dir}/text_${n}
  done > ${test_dir}/text_decode
  sed -i 's#  # #' ${test_dir}/text_decode

 python tools/compute-wer.py --char=1 --v=1 \
      $wave_data/$test/text $test_dir/text_decode > $test_dir/wer

 python tools/compute-cer.py --char=1 --v=1 \
      $wave_data/$test/text $test_dir/text_decode > $test_dir/cer
fi

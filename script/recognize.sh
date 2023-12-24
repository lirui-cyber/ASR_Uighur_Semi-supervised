#!/bin/bash

mode=
dir=
test_data=
checkpoint=
dict=
test_dir=
ctc_weight=0.5
decoding_chunk_size=
decode_checkpoint=

gpu_id=$CUDA_VISIBLE_DEVICES
[ -z $gpu_id ] && gpu_id=-1

. ./tools/parse_options.sh || exit 1;

python wenet/bin/recognize.py --gpu $gpu_id \
       --mode $mode \
       --config $dir/train.yaml \
       --test_data $test_data \
       --checkpoint $decode_checkpoint \
       --beam_size 10 \
       --batch_size 1 \
       --penalty 0.0 \
       --dict $dict \
       --result_file $test_dir/text_bpe \
       --ctc_weight $ctc_weight 
       ${decoding_chunk_size:+--decoding_chunk_size $decoding_chunk_size}
  

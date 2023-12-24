#!/bin/bash

train_config=conf/train_u2++_conformer.yaml 
dict=
train=
dev=
ngpu=2
part=
dist_backend="gloo"
cmvn_dir=
checkpoint=



. tools/parse_options.sh || exit 1;

dir=$1
init_method=$2
cmvn_opts="--cmvn $cmvn_dir"
gpu_id=$CUDA_VISIBLE_DEVICES

python3 wenet/bin/train_deprecated.py --gpu $gpu_id \
    --config $train_config \
    --train_data $train \
    --cv_data $dev \
    ${checkpoint:+--checkpoint $checkpoint} \
    --model_dir $dir \
    --ddp.init_method $init_method \
    --ddp.world_size $ngpu \
    --ddp.rank $[ part-1 ] \
    --ddp.dist_backend $dist_backend \
    --num_workers 1 \
    $cmvn_opts \
    --pin_memory || exit 1;


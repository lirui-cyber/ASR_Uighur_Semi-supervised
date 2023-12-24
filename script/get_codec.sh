#!/bin/bash

#. utils/parse_options.sh

if [ $# != 2 ]; then
    echo "Usage: $0 <srcdir> <dstdir>"
    echo "e.g.: "
    echo "$0 data/train data/train_out"
    exit 1;
fi

export LC_ALL=C
srcdir=$1
dstdir=$2

if [ ! -f $srcdir/wav.scp ]; then
    echo "$0: Expected $srcdir/wav.scp to exist"
    exit 1;
fi
./utils/data/copy_data_dir.sh --spk-prefix cod_ --utt_prefix cod_ $srcdir $dstdir

cmddir=`dirname $0`
python2 script/get_codec.py $srcdir/wav.scp $dstdir/wav.scp || exit 1;

sed -i "s/^/cod_/g" $dstdir/wav.scp

len1=$(cat $srcdir/wav.scp | wc -l)
len2=$(cat $dstdir/wav.scp | wc -l)

if [ "$len1" != "$len2" ]; then
    echo "$0: error detected: number of lines changed $len1 vs $len2"
    exit 1;
fi

if [ -f $dstdir/feats.scp ]; then
    echo "$0: $dstdir/feats.scp exists; moving it to $dstdir/.backup/ as it would't be valid any more."
    mkdir -p $dstdir/.backup/
    mv $dstdir/feats.scp $dstdir/.backup/
fi

echo "$0: generated speed-perturbed version of data in $srcdir, in $dstdir"
if [ ! utils/data/validate_data_dir.sh --no-feats --no-text $dstdir]; then
    echo "$0: validation failed. If it is a sorting issue, try the option '--always-includ-prefix trun'"
    exit 1;
fi


echo "$0: added codec perturbation to the data in $dstdir"

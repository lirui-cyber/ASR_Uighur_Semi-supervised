# Copyright 2019 Mobvoi Inc. All Rights Reserved.
# Author: binbinzhang@mobvoi.com (Binbin Zhang)

import logging
import os
import re

import yaml
import torch


def load_checkpoint(model: torch.nn.Module, path: str) -> dict:
    #if torch.cuda.is_available():
    #    logging.info('Checkpoint: loading from checkpoint %s for GPU' % path)
    #    checkpoint = torch.load(path)
    #else:
    #    logging.info('Checkpoint: loading from checkpoint %s for CPU' % path)
    #    checkpoint = torch.load(path, map_location='cpu')
    #model.load_state_dict(checkpoint)
    if True:
        checkpoint_giga = torch.load("pretrain/giga.pt")
        checkpoint_uy = torch.load("pretrain/uy_18.pt")
        model_dict = model.state_dict()


    



        decoder_keys=[]
        with open("pretrain/uy_decoder") as f:
            for line in f:
                line=line.strip()
                decoder_keys.append(line)
        checkpoint_decoder = {k:v for k,v in checkpoint_uy.items() if k in decoder_keys}

        encoder_keys=[]
        with open("pretrain/giga_encoder") as f:
            for line in f:
                line=line.strip()
                encoder_keys.append(line)
        checkpoint_encoder = {k:v for k,v in checkpoint_giga.items() if k in encoder_keys}

        model_dict.update(checkpoint_encoder)
        model_dict.update(checkpoint_decoder)
        model.load_state_dict(model_dict)

    
    configs = {}


    return configs


def save_checkpoint(model: torch.nn.Module, path: str, infos=None):
    '''
    Args:
        infos (dict or None): any info you want to save.
    '''
    logging.info('Checkpoint: save to checkpoint %s' % path)
    if isinstance(model, torch.nn.DataParallel):
        state_dict = model.module.state_dict()
    elif isinstance(model, torch.nn.parallel.DistributedDataParallel):
        state_dict = model.module.state_dict()
    else:
        state_dict = model.state_dict()
    torch.save(state_dict, path)
    info_path = re.sub('.pt$', '.yaml', path)
    if infos is None:
        infos = {}
    with open(info_path, 'w') as fout:
        data = yaml.dump(infos)
        fout.write(data)

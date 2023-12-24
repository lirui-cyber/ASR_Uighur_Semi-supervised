"""
Author: Li Rui
Description: This script generate kaldi format file
"""

import os
import argparse
from datetime import datetime

def generate_wav_scp(folder_path, output_path):
    
    yy = datetime.now().year
    mm = datetime.now().month
    output_file = "wav.scp"
    key_counter = 0
    current_directory = os.getcwd()
    with open(os.path.join(output_path, output_file), 'w') as f, open(os.path.join(output_path, "text"), 'w') as F, open(os.path.join(output_path, "spk2utt"), 'w') as spk2utt, open(os.path.join(output_path, "utt2spk"), 'w') as utt2spk:
        for root, dirs, files in os.walk(folder_path):
            for file in files:
                if file.endswith(".wav"):
                    key_counter += 1
                    key = f"Gd_Uyghur_{yy}_{mm}_{str(key_counter).zfill(8)}"
                    path = os.path.join(current_directory, root, file)
                    f.write(f"{key} {path}\n")
                    F.write(f"{key} A\n")
                    spk2utt.write(f"{key} {key}\n")
                    utt2spk.write(f"{key} {key}\n")

    print(f"Generated {output_file} text utt2spk spk2utt successfully.")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Generate file")
    parser.add_argument('--folder_path', help='Wav file path')
    parser.add_argument('--output_path', help='File output path')
    args = parser.parse_args()
    generate_wav_scp(args.folder_path, args.output_path)






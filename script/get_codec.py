import sys
def main():
    filenamein = sys.argv[1]
    filenameout = sys.argv[2]
    print filenamein, filenameout
    fout = open(filenameout, 'wt')

    bitconfig = [['libmp3lame', 8, 'mp3', 1], ['libmp3lame', 16, 'mp3', 1], ['libmp3lame', 24, 'mp3', 1], ['libmp3lame', 32, 'mp3', 1], \
            ['libopus', 8, 'opus', 3], ['libopus', 16, 'opus', 3], ['libopus', 24, 'opus', 3], ['libopus', 32, 'opus', 3], \
            ['libvo_amrwbenc', 6.60, 'amr', 0], ['libvo_amrwbenc', 8.85, 'amr', 0], ['libvo_amrwbenc', 12.65, 'amr', 0], ['libvo_amrwbenc', 14.25, 'amr', 0], \
            ['libvo_amrwbenc', 15.85, 'amr', 0], ['libvo_amrwbenc', 18.25, 'amr', 0], ['libvo_amrwbenc', 19.85, 'amr', 0], ['libvo_amrwbenc', 23.05, 'amr', 0], \
            ['libvo_amrwbenc', 23.85, 'amr', 0], \
            ['libspeex', 8, 'spx', 2], ['libspeex', 16, 'spx', 2], ['libspeex', 24, 'spx', 2], ['libspeex', 32, 'spx', 2], \
            ['libvorbis', 16, 'ogg', 1], ['libvorbis', 24, 'ogg', 1], ['libvorbis', 32, 'ogg', 1], \
            ['fdkaac', 8, '', 1], ['fdkaac', 16, '', 1], ['fdkaac', 24, '', 1], ['fdkaac', 32, '', 1]]
    fsconfig = ['8k', '11.025k', '16k']

    for i, line in enumerate(open(filenamein, 'rt').readlines()):
        linespt = line.strip().split()
        codec = bitconfig[i % len(bitconfig)][0]
        bitrate = bitconfig[i % len(bitconfig)][1]
        fs = fsconfig[i % len(fsconfig)]
        fmt = bitconfig[i % len(bitconfig)][2]
        if bitconfig[i % len(bitconfig)][3] == 1 and fs != '16k':
            fscmd = 'sox -t wav -r 16k - -t wav -r %s - vol 0.8 |'%fs
        elif bitconfig[i % len(bitconfig)][3] == 2 and fs != '16k':
            fs = '8k'
            fscmd = 'sox -t wav -r 16k - -t wav -r %s - vol 0.8 |'%fs
        elif bitconfig[i % len(bitconfig)][3] == 3 and fs != '16k':
            if fs == '11.025k':
                fs = '12k'
            fscmd = 'sox -t wav -r 16k - -t wav -r %s - vol 0.8 |'%fs
        else:
            fscmd = ''

        if line.strip()[-1] == '|':
            if codec == 'fdkaac':
                codecconfig = " %s fdkaac -b%d -f2 -p2 - -o - | ffmpeg -v quiet -i - -ac 1 -ar 16k -f wav - |"%(fscmd, bitrate)
            else:
                if len(fscmd):
                    codecconfig = " ffmpeg -v quiet -i - -acodec %s -ab %.2fk -ar %s -f %s - | ffmpeg -v quiet -i - -ac 1 -ar 16k -f wav - |"%(codec, bitrate, fs, fmt)
                else:
                    codecconfig = " ffmpeg -v quiet -i - -acodec %s -ab %.2fk -f %s - | ffmpeg -v quiet -i - -ac 1 -ar 16k -f wav - |"%(codec, bitrate, fmt)
            fout.write(line.strip() + codecconfig + '\n')
        elif line.strip().endswith('.wav'):
            if codec == 'fdkaac':
                codecconfig = "sox -t wav -r 16k %s -t wav -r %s - vol 0.8 | fdkaac -b%d -f2 -p2 - -o - | ffmpeg -v quiet -i - -ac 1 -ar 16k -f wav - |"%(linespt[1], fs, bitrate)
            else:
                #if len(fscmd):
                #    codecconfig = " ffmpeg -v quiet -i %s -acodec %s -ab %.2fk -ar %s -f %s - | ffmpeg -i - -ac 1 -ar 16k -f wav - |"%(linespt[1],codec,bitrate,fs,fmt)
                #else:
                codecconfig = " ffmpeg -v quiet -i %s -acodec %s -ab %.2fk -f %s - | ffmpeg -i - -ac 1 -ar 16k -f wav - |"%(linespt[1],codec, bitrate, fmt)
            fout.write('%s %s\n'%(linespt[0], codecconfig))
        else:
            print "error, %s"%line
        
        fout.flush()
    fout.close()


if __name__ == "__main__":
    main()

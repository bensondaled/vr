import os
import sys

dirr = '/Volumes/BENSON32GB/TankLab/data'
go = raw_input('Are you sure you want to clean? This will delete files from the directory \"%s\". (y/n)'%dirr)

if go == 'y':
    for f in os.listdir(dirr):
        if 'mouse' not in f or 'me' in f:
            os.system('rm %s'%os.path.join(dirr, f))
    print "Cleaned."
else:
    print "Aborted."

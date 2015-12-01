import os
import numpy as np
import sys
import json
from video_reader import VideoReader as VR

class Movie(object):
    def __init__(self, mov_path):
        self.mov_path = mov_path
        self.vr = VR(self.mov_path)
        self.frame_means = self.pull_frame_means()
    def pull_frame_means(self):
        means = []
        frame = self.vr.read()
        fi = 1
        while frame!=None:
            means.append(np.mean(frame))
            frame = self.vr.read()
            fi += 1
            print fi
            sys.stdout.flush()
            if fi>2000:
                break
        return np.array(means)
    def get_trials(self, iti_min_s=1., iti_max_s=10., darkness_thresh=60):
        #currently assumes first trial starts, without darkness, at time 0
        iti_min_fr = iti_min_s * self.vr.frame_rate
        iti_max_fr = iti_max_s * self.vr.frame_rate
        is_dark = self.frame_means < darkness_thresh
        is_flip = is_dark[:-1].astype(int)+is_dark[1:].astype(int)
        dark_edges = np.argwhere(is_flip==1) + 1
        itis = []
        added = False
        for e1,e2 in zip(dark_edges[:-1],dark_edges[1:]):
            if added:
                added = False
                continue
            if e2-e1 > iti_max_fr:
                continue
            if e2-e1 < iti_min_fr:
                continue
            itis.append([e1,e2])
            added = True
        itis = np.array(itis) 
        trials = np.array([np.append(0,itis[:,1]), np.append(itis[:,0],-1)]).T
        return trials

if __name__ == '__main__':
    task = sys.argv[1]
    if task == 'run':
        with open('movie_paths.json','r') as f:
            all_paths = json.load(f)
        pathi = int(sys.argv[2])-1
        m = Movie(all_paths[pathi])
        trials = m.get_trials()
        obj = dict(trials=trials, frame_means=m.frame_means, path=all_paths[pathi])
        np.savez('temp_results_%i'%pathi, **obj)
    elif task == 'merge':
        fs = [f for f in os.listdir('.') if 'temp_results_' in f]
        res = {}
        for f in fs:
            data = np.load(f)
            res[str(data['path'])] = [data['trials'].tolist(), data['frame_means'].tolist()]
        with open('result.json','w') as ff:
            json.dump(res,ff)
        for f in fs:
            os.remove(f)

import numpy as np
import json
import subprocess as sp
import os

class VideoReader(object):
    FFMPEG_PATH = 'ffmpeg'
    FFPROBE_PATH = 'ffprobe'
    def __init__(self, video_path):
        self.DEVNULL = open(os.devnull, 'wb')
        self.vp = video_path
        command = [ self.FFMPEG_PATH,
                    '-i', self.vp,
                    '-v', 'error',
                    '-f', 'image2pipe',
                    '-pix_fmt', 'rgb24',
                    '-vcodec', 'rawvideo', '-']
        self.get_info()
        self.pipe = sp.Popen(command, stdout=sp.PIPE, stderr=sp.PIPE, stdin=self.DEVNULL,bufsize=10**8)
    def get_info(self):
        command = [self.FFPROBE_PATH, 
                    '-v', 'error',
                    '-print_format', 'json',
                    '-show_streams',
                    self.vp]
        pipe = sp.Popen(command, stdout=sp.PIPE, stderr=sp.PIPE, stdin=self.DEVNULL)
        info = pipe.stdout.read()
        pipe.kill();pipe.terminate()
        info = json.loads(info)
        self.info = info
        self.pix_fmt = info['streams'][0]['pix_fmt']
        if self.pix_fmt == 'rgb24':
            self.depth = 3
        else: #yes i realize this is ridiculous, just not spending the time now
            self.depth = 3
        self.width = info['streams'][0]['width']
        self.height = info['streams'][0]['height']
        self.dims = (self.height,self.width,self.depth) #numpy ordering
        self.n_frames = info['streams'][0]['nb_frames']
        self.frame_rate = eval(info['streams'][0]['r_frame_rate'])
    def read(self):
        n_bytes = np.product(self.dims)
        raw_im = self.pipe.stdout.read(n_bytes)
        #self.pipe.stdout.flush()
        if len(raw_im) != n_bytes:
            return None
        im = np.fromstring(raw_im, dtype=np.uint8).reshape(self.dims)
        return im
    def release(self):
        self.pipe.kill()
        self.DEVNULL.close()

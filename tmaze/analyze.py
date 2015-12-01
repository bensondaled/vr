import numpy as np
import pylab as pl
from neo import io as neo
import pyfluo as pf
from scipy.signal import find_peaks_cwt as fpc
from scipy.stats import pearsonr
from scipy.ndimage.interpolation import zoom

def norm_cc(a,b):
    #a = (a - np.mean(a)) / (np.std(a) * float(len(a)))
    #b = (b - np.mean(b)) /  np.std(b)
    return np.corrcoef(a,b)[0,1]
def galvo_peaks(g, th=2.5, dth=2):
    idx = np.squeeze(np.argwhere(g>th))
    didx = np.diff(idx)
    idx = idx[didx>dth]
    return idx

# VIRMEN
x = np.fromfile(open('data/sesh0.dat','rb'),np.double)
n = x[0]
x = x[1:]
d = np.array(np.split(x, len(x)/float(n)))
dtype = np.dtype([('ts',float),('posx',float),('posy',float),('posz',float),('posa',float),('velx',float),('vely',float),('velz',float),('vela',float),('trial_idx',int)])
data = np.zeros(len(d), dtype=dtype)
for idx,di in enumerate(d):
    data[idx] = tuple(di)
t_virmen = (86400*data['ts'])
t_virmen -= t_virmen[0]

# CLAMPEX
r = neo.AxonIO(filename='data/sesh0.abf')
bl = r.read_block(lazy=False, cascade=True)
seg = bl.segments[0]
fs = 1000. #Hz
Ts = 1./fs
xpos,ypos,iters,cue,water,galvo,vel_f,vel_l,sesh,scan = seg.analogsignals
t = Ts*np.arange(len(xpos))
gp = galvo_peaks(galvo)
velf = pf.Trace(vel_f, time=t)

# TIFFS
frame_times = t[gp]
basename = 'data/file_00002_000{:02}.tif'

# Reload from tiffs
reload = False
if reload:
    tiffs = []
    tiffrange = range(1,26)
    for i in tiffrange:
        tdata = pf.Tiff(basename.format(i))
        tdata = tdata.data[:,200:450,90:450]
        tdata = zoom(tdata, [1.,1./3.,1./3.])
        tiffs.append(tdata)
        print(i)
    tiffs = np.concatenate(tiffs, axis=0)
    mov = pf.Movie(tiffs, time=frame_times[:1000*max(tiffrange)])
    mov = mov.motion_correct()
    pf.save('data/mov',mov=mov)

else:
    mov = pf.load('data/merged_downsamp_mov.pyfluo.npz')['mov']

# GRID method:
#mov = (mov-mov.min())/(mov.max()-mov.min())
#g = np.array(pf.segmentation.grid(mov, 12, 12))
#rois = [np.zeros(mov[0].shape) for i in g]
#for r,sl in zip(rois,g):
#    r[sl.tolist()] = 1.
#roi = pf.ROI(rois) 
#tr = mov.extract_by_roi(roi)
#tr = pf.compute_dff(tr)

# correlate...
#velf = velf[velf.t2i(tr.time[0]):velf.t2i(tr.time[-1])]
#velf = velf.resample(tr.shape[0])
#velf = np.abs(velf)
#prs = np.array([pearsonr(tr[:,ti],velf) for ti in np.arange(tr.shape[1])])
#rs = prs[:,0]
#ps = prs[:,1]
#idxs = np.argsort(rs)[-10:]

#rmap = np.zeros(mov[0].shape)
#for sl,r in zip(g[idxs],rs[idxs]):
#    rmap[sl.tolist()] = r
#mov.project(show=True, method=np.std)
##pl.imshow(rmap, alpha=0.1)
#roi[idxs].show(alpha=0.2)
#pl.figure()
#pl.subplot(2,1,1)
#tr[:,idxs].plot()
#pl.subplot(2,1,2)
#velf.plot()
##cells = pf.select_roi(ax='current')


## MANUAL method
roi = pf.ROI(np.load('data/manual_rois.npy'))
mov.project(show=True, method=np.std)
roi.show(cmap=pl.cm.jet)
pl.figure()

tr = mov.extract_by_roi(roi)
dff = pf.compute_dff(tr)

thresh = 3.5*dff.std(axis=0)
spikes = dff>thresh
spikes = spikes.astype(float)

vthresh = 8.
vspikes = (velf>vthresh).astype(float)

vspikes[vspikes==0] = np.nan
spikes[spikes==0] = np.nan

pl.plot(dff.time,0.1*vspikes, '|', color='k')
cols = pl.cm.jet(np.linspace(0,1,spikes.shape[1]))
for idx in range(spikes.shape[1]):
    pl.plot(dff.time,(idx+1)*spikes[:,idx], '|', color=cols[idx])
pl.ylim([-0.5,spikes.shape[1]+1])

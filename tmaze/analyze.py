import numpy as np

x = np.fromfile(open('20150928T231710.dat','rb'),np.double)
n = x[0]
x = x[1:]
d = np.split(x, len(x)/float(n))
pl.plot(d[:,-1])

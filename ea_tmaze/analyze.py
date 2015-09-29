import numpy as np
import sys
import pylab as pl
from datetime import datetime, timedelta
import os
import re

class TrialData(object):
    TIMESTAMP = 0
    DURATION = 1
    IDX = 2
    LR = 3 #which side was correct
    CORRECT = 4 #whether or not the mouse got it right
    LICK = 5
    LEFT = 1
    RIGHT = 2
    def __init__(self, name, path):
        self.name = name 
        self.path = path

        tomatch = re.compile("2014\\d{4}_\\d{6}_mouseb%s_trunc\.dat"%name)
        self.filenames = sorted([os.path.join(path,f) for f in os.listdir(path) if re.match(tomatch, f)])
        
        if self.filenames:
            self.data_all, self.data_by_file, self.data_by_date = self.load_files()

            self.n_trials = len(self.data_all)
            self.n_files = len(self.data_by_file)
            self.n_days = len(self.data_by_date)
    def data_from_days(self, idxs):
        return np.vstack([self.data_by_date[i] for i in idxs])
    def load_files(self):
        data = [np.fromfile(open(filename,'rb'),np.double) for filename in self.filenames]
        n_fields = data[0][0]
        assert all([i[0]==n_fields for i in data])
        data = [d[1:] for d in data]

        data_all = np.hstack(data).flatten()
        data_all = np.array(np.split(data_all, (len(data_all))/n_fields))

        data_by_file = [np.array(np.split(np.array(d), (len(d))/n_fields)) for d in data]

        data_by_date = []
        lastf = ''
        for d,f in zip(data, self.filenames):
            if os.path.split(f)[1][:9] == os.path.split(lastf)[1][:9]:
                data_by_date[-1] = np.hstack([data_by_date[-1], d])
            else:
                data_by_date.append(d)
            lastf = f
        data_by_date = [np.array(np.split(np.array(d), (len(d))/n_fields)) for d in data_by_date]

        return (data_all, data_by_file, data_by_date)
    def pie(self, day_idxs=None):
        if day_idxs == None:
            day_idxs = range(self.n_days)
        
        data = self.data_from_days(day_idxs)
        goalL = sum(data[:,self.LR] == self.LEFT)
        goalR = sum(data[:,self.LR] == self.RIGHT)
        corL = sum(data[:,self.CORRECT] * (data[:,self.LR] == self.LEFT))
        corR = sum(data[:,self.CORRECT] * (data[:,self.LR] == self.RIGHT))
        pl.pie([ goalR-corR, corL,  corR, goalL-corL ], labels=['Choice=L\nGoal=R', 'Choice=L\nGoal=L','Choice=R\nGoal=R' ,'Choice=R\nGoal=L' ], autopct="%0.2f%%", colors=['r','y','b','g'])
    def learning_curve(self, day_idxs=None):
        if day_idxs == None:
            day_idxs = range(self.n_days)
        
        stats = [100*np.mean(day[:,self.CORRECT]) for day in self.data_by_date]
            
        oldticks = pl.xticks()[0]
        pl.plot(stats, label="Mouse %s, mean # trials = %0.0f"%(self.name, np.mean([len(d) for d in self.data_by_date])))
        pl.ylabel("% correct")
        pl.xlabel("Session #")
        new_n_ticks = max([len(oldticks), len(stats)])
        pl.xticks(range(new_n_ticks),[str(i+1) for i in range(new_n_ticks)])
    def lr(self):
        d = self.data_all
        left = np.where((d[:,self.CORRECT] * (d[:,self.LR]==self.LEFT)) + ((1-d[:,self.CORRECT]) * (d[:,self.LR]==self.RIGHT)))[0]
        right = np.where((d[:,self.CORRECT] * (d[:,self.LR]==self.RIGHT)) + ((1-d[:,self.CORRECT]) * (d[:,self.LR]==self.LEFT)))[0]
        pl.scatter(left, np.ones_like(left), color='b')
        pl.scatter(right, np.ones_like(right), color='g')
        pl.title('Blue: left (%i), Green: right (%i)'%(len(left),len(right)))

    def __nonzero__(self):
        return len(self.filenames)


if __name__ == '__main__':
    dirr = '/Volumes/BENSON32GB/TankLab/data/'
    #dirr = '/Users/Benson/Desktop/'

    mice = [3, 4, 5, 6, 7, 9]

    for i,mouse in enumerate(mice):
        td = TrialData(mouse, dirr)
        if not td:
            print "Warning: no data for mouse %s."%mouse
            continue
        
        pl.figure(1)
        td.learning_curve()
        pl.figure(2)
        pl.subplot(2,3,i)
        td.pie()
    pl.figure(1)
    pl.legend(loc='lower left')











#elif mode == FULL:
#    TIMESTAMP = 0
#    DT = 1
#    X = 2
#    Y = 3
#    Z = 4
#    ROT = 5
#    VX = 6
#    VY = 7
#    VZ = 8
#    VROT = 9
#    DF = 10
#    DA = 11
#    TRIALIDX = 12
#    PHASE = 13
#    REWARDS = 14
#    LICK = 15
#    LICKS = 16
#    NCORRECT = 17
#    t = data[0][TIMESTAMP]
#    t_end = data[-1][TIMESTAMP]
#    t = datetime.fromordinal(int(t)) + timedelta(days=t%1) - timedelta(days = 366)
#    t_end = datetime.fromordinal(int(t_end)) + timedelta(days=t_end%1) - timedelta(days = 366)

#!/usr/bin/python
import sys, numpy, scipy.stats, shutil, cv2, os, skimage.measure

odir = '/tmp/broken'
if not os.path.isdir(odir): os.mkdir(odir)
indir = sys.argv[1]
thr = 100


def seq_ssimscores(infiles):
	scorelist = []
	num_comparison = len(infiles) - 1
	for i in range(num_comparison):
		fn1 = infiles[i]
		fn2 = infiles[i+1]
		fpath1 = '%s/%s' % (indir, fn1)
		fpath2 = '%s/%s' % (indir, fn2)
		opath = '%s/%s' % (odir, fn2)
		img1 = cv2.imread(fpath1)
		img2 = cv2.imread(fpath2)
		score = skimage.measure.compare_ssim(img1, img2, multichannel=True)
		print i+1, num_comparison, fn1, fn2, score
		scorelist.append(score)
	return [ i+1 for i, x in enumerate(scorelist) if x < numpy.median(scorelist) - thr * scipy.stats.iqr(scorelist) ]

infiles = sorted(os.listdir(indir))
invids = {}
for fn in infiles:
	vkey = fn.split('_')[0] + '_' + fn.split('_')[1]
	if not invids.has_key(vkey): invids[vkey] = []
	invids[vkey].append(fn)
print 'Images: %d, videos: %d' % (len(infiles), len(invids))
for vkey, vidfiles in invids.items():
	print 'Video', vkey
	badfiles = []
	while True:
		outliers = seq_ssimscores(vidfiles)
		if len(outliers) == 0: break
		badfiles.append(vidfiles[outliers[0]])
		del vidfiles[outliers[0]]
		print 'bad:', badfiles
	for fn in badfiles: shutil.move('%s/%s' % (indir, fn), '%s/%s' % (odir, fn))
	print 'Moved %d images' % len(badfiles)

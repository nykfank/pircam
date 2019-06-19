#!/usr/bin/python
import sys, numpy, shutil, cv2, os, skimage.measure
odir = '/tmp/broken'
if not os.path.isdir(odir): os.mkdir(odir)
indir = sys.argv[1]
thr = 0.1

def seq_ssimscores(infiles):
	scorelist = []
	num_comparison = len(infiles) - 1
	for i in range(num_comparison):
		fpath1 = '%s/%s' % (indir, infiles[i])
		fpath2 = '%s/%s' % (indir, infiles[i+1])
		img1 = cv2.imread(fpath1)
		img2 = cv2.imread(fpath2)
		score = skimage.measure.compare_ssim(img1, img2, multichannel=True)
		scorelist.append(score)
	return [ i + 1 for i, x in enumerate(scorelist) if x < numpy.median(scorelist) - thr ]

def detect_outliers(vidfiles):
	badfiles = []
	while True:
		outliers = seq_ssimscores(vidfiles)
		if len(outliers) == 0: return badfiles
		badfiles.append(vidfiles[outliers[0]])
		del vidfiles[outliers[0]]

infiles = sorted(os.listdir(indir))
invids = {}
for fn in infiles:
	vkey = fn.split('_')[0] + '_' + fn.split('_')[1]
	if not invids.has_key(vkey): invids[vkey] = []
	invids[vkey].append(fn)
print 'Images: %d, videos: %d' % (len(infiles), len(invids))

for vkey, vidfiles in invids.items():
	nb_vids = len(vidfiles)
	badfiles = detect_outliers(vidfiles)
	for fn in badfiles: shutil.move('%s/%s' % (indir, fn), '%s/%s' % (odir, fn))
	print '%s: moved %d of %d images' % (vkey, len(badfiles), nb_vids)

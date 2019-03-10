#!/usr/bin/python
import sys, numpy, scipy.stats, shutil, cv2, os
thr = 4
odir = '/tmp/broken'
if not os.path.isdir(odir): os.mkdir(odir)
indir = sys.argv[1]

def find_jpeg_artefacts(ifn):
	# Load image and convert to 64bit integer
	img = cv2.imread(ifn, cv2.IMREAD_GRAYSCALE)
	img = numpy.int64(img)
	# Horizontal artefacts
	img_downshifted = numpy.roll(img, 1, axis = 0) # Shift down
	diff_down = abs(numpy.subtract(img, img_downshifted))
	row_sum = numpy.sum(diff_down, axis=1) / img.shape[0]
	row_sum[0] = 0 # Top row of shifted image is bottom row
	return [ i for i, x in enumerate(row_sum) if x > numpy.median(row_sum) + thr * scipy.stats.iqr(row_sum) ]

for fn in os.listdir(indir):
	fpath = '%s/%s' % (indir, fn)
	opath = '%s/%s' % (odir, fn)
	artefact_rows = find_jpeg_artefacts(fpath)
	print fn, artefact_rows
	if len(artefact_rows) > 0: shutil.move(fpath, opath)

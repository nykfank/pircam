#!/usr/bin/python
import sys, numpy, scipy.stats, shutil, cv2, os
thr = 4
odir = '/tmp/broken/'
if not os.path.isdir(odir): os.mkdir(odir)

# Load image and convert to 64bit integer
ifn = sys.argv[1]
img = cv2.imread(ifn, cv2.IMREAD_GRAYSCALE)
img = numpy.int64(img)

# Horizontal artefacts
img_downshifted = numpy.roll(img, 1, axis = 0) # Shift down
diff_down = abs(numpy.subtract(img, img_downshifted))
row_sum = numpy.sum(diff_down, axis=1) / img.shape[0]
row_sum[0] = 0 # Top row of shifted image is bottom row
artefact_rows = [ i for i, x in enumerate(row_sum) if x > numpy.median(row_sum) + thr * scipy.stats.iqr(row_sum) ]

print ifn, artefact_rows
if len(artefact_rows) > 0: shutil.move(ifn, odir + ifn)

#!/usr/bin/python
import Image, sys, math, numpy, scipy.stats, shutil
ifn = sys.argv[1]
i = Image.open(ifn)
s = i.size
im = Image.new('RGB', s)
for x in range(s[0]):
	for y in range(s[1]):
		p = i.getpixel((x, y))
		if y > 1:
			p1 = i.getpixel((x, y-1))
			p2 = i.getpixel((x, y))
			d = int(math.sqrt((p1[0] - p2[0])**2 + (p1[1] - p2[1])**2 + (p1[2] - p2[2])**2))
			im.putpixel((x,y), (d,d,d))

im.save('foo.png')
ddl = []
for y in range(s[1]):
	dd = 0
	for x in range(s[0]): dd += im.getpixel((x, y))[0]
	ddl.append(dd/s[0])
sddl = sorted(ddl)
iqr = scipy.stats.iqr(ddl)
median = numpy.median(ddl)
#print 'Median:', median
#print 'IQR:', iqr
#print sddl
lines = filter(lambda x : x > median + 4 * iqr, sddl)
print ifn, lines
if len(lines) > 0: shutil.copy(ifn, 'line/'+ifn)

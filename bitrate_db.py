#!/usr/bin/python
# Better use number of frames from mjpeg and size of compressed ogg video?

import sqlite3, os, sys
indir = sys.argv[1]
db_fn = '%s/.bitrate.db' % os.getenv("HOME")
db = sqlite3.connect(db_fn)
dbc = db.cursor()
dbc.execute('CREATE TABLE IF NOT EXISTS files (fn TEXT, bitrate INTEGER)')
dbc.execute('CREATE INDEX IF NOT EXISTS files_idx ON files (fn)')
for f in os.listdir(indir):
	if not f.endswith('ogg'): continue
	fn = '%s/%s' % (indir, f)
	cmd = 'ffprobe %s 2>&1' % fn
	print cmd
	r = os.popen(cmd).read()
	print r
	fn2 = fn.replace('/home/', '')
	r = r.split('bitrate: ')[1].split(' ')[0]
	dbc.execute('INSERT INTO files (fn, bitrate) VALUES (?,?)',(fn2, r.strip()))
	db.commit()

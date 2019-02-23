#!/usr/bin/python
import sqlite3, os
config_file = '/opt/pircam_config.txt'
db_fn = '%s/.bitrate.db' % os.getenv("HOME")

def load_config(fn, section):
	"""Load specified section of config file into dictionary."""
	cdict, current_section = {}, ''
	for i in open(fn):
		if not i.strip(): continue
		isp = i.strip().split('=')
		if len(isp) == 1:
			title = isp[0].strip()
			if title in ['GLOBAL', 'CAMERA', 'SENSOR']: current_section = title
			else: device = title
		if current_section != section: continue
		if len(isp) == 2:
			key, value = isp[0].strip(), isp[1].strip()
			if current_section == 'GLOBAL': 
				cdict[key] = value
			else:
				if not cdict.has_key(device): cdict[device] = {}
				cdict[device][key] = value
	return cdict

# Load configuration into dictionaries
cameras = load_config(config_file, 'CAMERA')
config  = load_config(config_file, 'GLOBAL')
db = sqlite3.connect(db_fn)
dbc = db.cursor()
dbc.execute('CREATE TABLE IF NOT EXISTS files (fn TEXT, bitrate INTEGER)')
dbc.execute('CREATE INDEX IF NOT EXISTS files_idx ON files (fn)')
for CAMID in cameras.keys():
	indir = '%s/%s' % (config['data_dir'], CAMID)
	for f in os.listdir(indir):
		if not f.endswith('ogg'): continue
		fn = '%s/%s' % (indir, f)
		fn2 = fn.replace(config['data_dir'], '')
		dbc.execute('SELECT COUNT(*) FROM files WHERE fn = ?', (fn2,))
		if dbc.fetchone()[0] > 0: continue
		cmd = 'ffprobe %s 2>&1' % fn
		r = os.popen(cmd).read()
		if not 'bitrate: ' in r:
			print '%s: ERROR' % fn
			continue
		bitrate = int(r.split('bitrate: ')[1].split(' ')[0].strip())
		dbc.execute('INSERT INTO files (fn, bitrate) VALUES (?,?)',(fn2, bitrate))
		print '%s: %d' % (fn, bitrate)
	db.commit()

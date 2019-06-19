#!/usr/bin/python
import sqlite3, os
config_file = '/opt/pircam_config.txt'

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

def get_rate(mfn, ofn):
	return int(100 * float(os.stat(ofn).st_size) / float(os.stat(mfn).st_size))

def rate_to_db(fn, rate):
	db = sqlite3.connect(config['db_fn'])
	dbc = db.cursor()
	fn2 = fn.replace(config['data_dir'] + '/', '')
	dbc.execute('INSERT INTO files (fn, rate) VALUES (?,?)',(fn2, rate))
	db.commit()
	db.close()

def rate_from_db(fn):
	db = sqlite3.connect(config['db_fn'])
	dbc = db.cursor()
	fn2 = fn.replace(config['data_dir'] + '/', '')
	dbc.execute('SELECT rate FROM files WHERE fn = ?', (fn2,))
	r = dbc.fetchone()
	db.close()
	if not r: return 0
	return r[0]

def exists_in_db(fn):
	db = sqlite3.connect(config['db_fn'])
	dbc = db.cursor()
	fn2 = fn.replace(config['data_dir'] + '/', '')
	dbc.execute('SELECT COUNT(*) FROM files WHERE fn = ?', (fn2,))
	r, = dbc.fetchone()
	db.close()
	return r > 0

# Load configuration into dictionaries
cameras = load_config(config_file, 'CAMERA')
config  = load_config(config_file, 'GLOBAL')
for CAMID in cameras.keys():
	indir = '%s/%s' % (config['data_dir'], CAMID)
	indir_mjpeg = '%s/%s_mjpeg' % (config['data_dir'], CAMID)
	for f in os.listdir(indir):
		if not f.endswith('ogg'): continue
		fn = '%s/%s' % (indir, f)
		mfn = '%s/%s' % (indir_mjpeg, f.replace('ogg', 'mjpeg'))
		if exists_in_db(fn): continue
		rate = get_rate(mfn, fn)
		rate_to_db(fn, rate)
		print '%s: %d' % (fn, rate)

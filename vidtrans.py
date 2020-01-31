#!/usr/bin/python
from SocketServer import TCPServer
from SocketServer import BaseRequestHandler
import subprocess, os, time
log_fn = '/var/log/vidtrans.log'
config_file = '/opt/pircam_config.txt'

def logg(x):
	"""Writes message and formated timestamp to logfile."""
	x = '%s: %s' % (time.strftime('%Y-%m-%d %H:%M:%S'), x)
	open(log_fn, 'a').write(x + '\n')

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

def log_and_run(cmd):
	"""Run command using subprocess.call and only log in case of error."""
	if config['verbose'] == 'True': logg(' '.join(cmd))
	rcode = subprocess.call(cmd)
	if rcode > 0: logg('%s (%d)' % (' '.join(cmd), rcode))

def upload_to_webserver(fn, remote_path):
	"""Run a rsync command to upload a file to a path on the webserver."""
	cmd = 'rsync', fn, '%s:%s/' % (config['webserver'], remote_path)
	log_and_run(cmd)

def filebase(x):
	"""Returns filename without path and extension."""
	return os.path.splitext(os.path.basename(x))[0]

def timeFormat(x):
	"""Convert YYYYMMDD_HHMMSS to YYYY-MM-DD_HH:MM:SS"""
	return time.strftime('%Y-%m-%d %H:%M:%S', time.strptime(filebase(x), "%Y%m%d_%H%M%S"))

def index_element(fpath):
	"""Generates variables required for an element in photoswipe."""
	src = fpath.replace(config['data_dir'], '')
	w, h = config['size_x'], config['size_y']
	video = src.replace('jpg', 'ogg').strip('/')
	if True in [k in fpath for k, v in cameras.items() if 'pipir' in v]: video = video.replace('ogg', 'mp4')
	title = timeFormat(fpath)
	pid = filebase(fpath)
	return "{src:'%s', w:%s, h:%s, title:'%s', video:'%s', pid:'%s'}" % (src, w, h, title, video, pid)

def generate_index_page():
	"""Generates HTML page for the numLast recorded videos with photoswipe user interface.""" 
	path = lambda x : '%s/%s' % (config['data_dir'], x)
	ftup = [ (f, '%s/%s' % (path(c), f)) for c in cameras.keys() for f in os.listdir(path(c)) if f.endswith('jpg') ]
	image_paths =  [ fpath for (fn, fpath) in sorted(ftup) ]
	if config['verbose'] == 'True': logg('Total %d image files' % len(image_paths))
	elemlist = [ index_element(fpath) for fpath in reversed(image_paths) ]
	photoswipe_script = 'var items = [\n%s\n];\n' % ',\n'.join(elemlist[:int(config['numLast'])])
	scriptPath = '%s/pircam.js' % config['data_dir']
	open(scriptPath, 'w').write(photoswipe_script)
	if config['verbose'] == 'True': logg('List of %d files written to %s' % (int(config['numLast']), scriptPath))

class PiSignalHandler(BaseRequestHandler):
  def handle(self):
	ip_data = self.request.recv(50).strip()
	logg('%s from %s' % (ip_data, self.client_address[0]))
	if not ':' in ip_data: logg('Bad data'); return
	camid, fn_mp4 = ip_data.split(':')
	if not cameras.has_key(camid): logg('Bad camera'); return
	if not cameras[camid].has_key('pipir'): logg('Missing pipir path'); return
	if not cameras[camid].has_key('addr'): logg('Missing pipir addr'); return
	if cameras[camid]['addr'] != self.client_address[0]: logg('Bad client addr'); return
	local_path = '%s/%s' % (config['data_dir'], camid)
	path_mp4 = '%s/%s' % (local_path, fn_mp4)
	path_jpg = '%s/%s' % (local_path, fn_mp4.replace('mp4', 'jpg'))
	cmd1 = '/usr/bin/rsync', '%s/%s' % (cameras[camid]['pipir'], fn_mp4), path_mp4
	cmd2 = '/usr/bin/ffmpeg', '-hide_banner', '-loglevel', 'panic', '-i', path_mp4, '-vf', 'select=eq(n\,50)', path_jpg
	cmd3 = '/usr/bin/mogrify', '-scale', '1280x720', path_jpg
	for cmd in [cmd1, cmd2, cmd3]: log_and_run(cmd)
	webserver_path = '%s/%s' % (config['data_dir'], camid)
	upload_to_webserver(path_jpg, webserver_path)
	upload_to_webserver(path_mp4, webserver_path)
	generate_index_page()
	upload_to_webserver('%s/pircam.js' % config['data_dir'], config['webRoot'])
	upload_to_webserver(log_fn, config['webRoot'])

# Load configuration into dictionaries
cameras = load_config(config_file, 'CAMERA')
config  = load_config(config_file, 'GLOBAL')
# https://stackoverflow.com/questions/47903031/background-threaded-tcp-server-in-python
server = TCPServer((config['server_addr'], 22333), PiSignalHandler)
print 'Server running...'
server.serve_forever()

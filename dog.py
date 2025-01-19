#!/usr/bin/python
from tinkerforge.ip_connection import IPConnection
from tinkerforge.bricklet_motion_detector import BrickletMotionDetector
from tinkerforge.bricklet_motion_detector_v2 import BrickletMotionDetectorV2
import time, subprocess, os, signal, random
tinkerforge_uid = 'MLF'
tinkerforge_address = 'localhost'
verbose = True
event_lock = False
log_fn = '/home/pi/sensodog.log'
wavdir = '/home/pi/wav'

def logg(x):
    """Writes message and formated timestamp to logfile."""
    x = '%s: %s' % (time.strftime('%Y-%m-%d %H:%M:%S'), x)
    open(log_fn, 'a').write(x + '\n')

def log_and_run(cmd):
    """Run command using subprocess.call and only log in case of error."""
    if verbose == True: logg(' '.join(cmd))
    rcode = subprocess.call(cmd)
    if rcode > 0: logg('%s (%d)' % (' '.join(cmd), rcode))

class GracefulKiller:
    kill_now = False
    def __init__(self):
        signal.signal(signal.SIGINT, self.exit_gracefully)
        signal.signal(signal.SIGTERM, self.exit_gracefully)
    def exit_gracefully(self,signum, frame):
        self.kill_now = True

def play_sound():
    global event_lock
    if event_lock == True: return
    event_lock = True
    wavfiles = os.listdir(wavdir)
    idx = int(random.random() * len(wavfiles))
    randwav = '%s/%s' % (wavdir, wavfiles[idx])
    cmd = '/usr/bin/aplay', randwav
    log_and_run(cmd)
    event_lock = False

killer = GracefulKiller()
ipc = IPConnection()
ipc.connect(tinkerforge_address, 4223)
sensor = BrickletMotionDetectorV2(tinkerforge_uid, ipc)
sensor.register_callback(sensor.CALLBACK_MOTION_DETECTED, play_sound) # Register callback function
logg('sensodog started')
# Event loop
while True:
    time.sleep(1)
    if killer.kill_now: break # Terminate
ipc.disconnect()
logg('sensodog ended')

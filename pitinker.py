#!/usr/bin/python
#import RPi.GPIO as GPIO
from tinkerforge.ip_connection import IPConnection
from tinkerforge.bricklet_motion_detector import BrickletMotionDetector
from tinkerforge.bricklet_motion_detector_v2 import BrickletMotionDetectorV2
import time, subprocess, socket, os, signal
camid = 'ghaus' # Local identifier
local_dir1 = '/home/pi/cam' # Recorded videos
local_dir2 = '/home/pi/cam_ok' # Transfered videos
pircam_address = '192.168.1.139' # Server to fetch videos
tinkerforge_address = '192.168.1.218' # Server to fetch videos
tinkerforge_uid = 'MLF'
verbose = True
Relay_Ch1 = 26
Relay_Ch2 = 20 # IR LED
Relay_Ch3 = 21
event_lock = False
log_fn = '/home/pi/pitinker.log'

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

def record_video():
    global event_lock
    if event_lock == True: return
    event_lock = True
    t = time.strftime('%Y%m%d_%H%M%S')
    fn1 = '%s/%s.h264' % (local_dir1, t)
    fn2 = '%s/%s.mp4' % (local_dir1, t)
    cmd1 = '/usr/bin/raspivid', '-t', '5000', '--mode', '4', '--framerate', '2', '-o', fn1
    cmd2 = '/usr/bin/MP4Box', '-quiet', '-fps', '2', '-add', fn1, fn2
    #GPIO.output(Relay_Ch2, GPIO.LOW)
    log_and_run(cmd1)
    #GPIO.output(Relay_Ch2, GPIO.HIGH)
    log_and_run(cmd2)
    os.unlink(fn1)
    event_lock = False
    # ffmpeg -i dark.mp4 -vf blackdetect=d=0.1:pix_th=0.1 -f rawvideo -y /dev/null
    # [blackdetect @ 0x557e6501dd00] black_start:0 black_end:1.5 black_duration:1.5
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(600)
    try: s.connect((pircam_address, 22333))
    except:
        logg('FAILED TO CONNECT')
        s.close()
        return
    msg = '%s:%s.mp4' % (camid, t)
    s.send(msg)
    logg(msg)
    s.close()


#GPIO.setwarnings(False)
#GPIO.setmode(GPIO.BCM)
#GPIO.setup(SENSOR_PIN, GPIO.IN)
#GPIO.setup(Relay_Ch2, GPIO.OUT)

killer = GracefulKiller()
# Check output directories
if not os.path.isdir(local_dir1): os.mkdir(local_dir1)
if not os.path.isdir(local_dir2): os.mkdir(local_dir2)
ipc = IPConnection()
ipc.connect(tinkerforge_address, 4223)
sensor = BrickletMotionDetectorV2(tinkerforge_uid, ipc)
sensor.register_callback(sensor.CALLBACK_MOTION_DETECTED, record_video) # Register callback function
logg('PiTinker started')
# Event loop
while True:
    if event_lock == False and killer.kill_now: break # Terminate
    time.sleep(5)
#GPIO.cleanup()
ipc.disconnect()
logg('PiTinker ended')

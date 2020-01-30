import RPi.GPIO as GPIO
import time, subprocess, socket, os
server_address='192.168.1.139' # tell
SENSOR_PIN = 23
Relay_Ch1 = 26
Relay_Ch2 = 20
Relay_Ch3 = 21
GPIO.setwarnings(False)
GPIO.setmode(GPIO.BCM)
GPIO.setup(SENSOR_PIN, GPIO.IN)
GPIO.setup(Relay_Ch2, GPIO.OUT)
event_lock = False

def record_video(channel):
    global event_lock
    if event_lock == True: return
    event_lock = True
    t = time.strftime('%Y%m%d_%H%M%S')
    fn1 = '/home/pi/cam/%s.h264' % t
    fn2 = '/home/pi/cam/%s.mp4' % t
    cmd1 = 'raspivid', '-t', '10000', '--mode', '4', '--exposure', 'auto', '--awb', 'auto', '-o', fn1
    cmd2 = 'MP4Box', '-add', fn1, fn2
    GPIO.output(Relay_Ch2, GPIO.LOW) 
    subprocess.call(cmd1)
    GPIO.output(Relay_Ch2, GPIO.HIGH)
    subprocess.call(cmd2)
    os.unlink(fn1)
    event_lock = False
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(600)
    s.connect((server_address, 22333))
    msg = 'ghaus:%s.mp4' % t
    s.send(msg)
    s.close()

try:
    GPIO.add_event_detect(SENSOR_PIN, GPIO.RISING, callback=record_video)
    while True:
        time.sleep(100)
except KeyboardInterrupt:
    print "Beende..."
GPIO.cleanup()

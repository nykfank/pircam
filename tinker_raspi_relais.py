#!/usr/bin/python
import RPi.GPIO as GPIO
from tinkerforge.ip_connection import IPConnection
from tinkerforge.bricklet_motion_detector import BrickletMotionDetector
from tinkerforge.bricklet_motion_detector_v2 import BrickletMotionDetectorV2
import time, signal

tinkerforge_address = '192.168.1.218'
tinkerforge_uid = 'MLF' # Motion Sensor 2.0
Relay_Ch1 = 26
Relay_Ch2 = 20 # Relais with IR floodlight attached
Relay_Ch3 = 21 # Relais with Camera attached
event_lock = False
reset_period = 60*60*12
reset_timer = reset_period
log_fn = '/home/pi/tinker_raspi_relais.log'

def logg(x):
    """Writes message and formated timestamp to logfile."""
    x = '%s: %s' % (time.strftime('%Y-%m-%d %H:%M:%S'), x)
    open(log_fn, 'a').write(x + '\n')

class GracefulKiller:
    kill_now = False
    def __init__(self):
        signal.signal(signal.SIGINT, self.exit_gracefully)
        signal.signal(signal.SIGTERM, self.exit_gracefully)
    def exit_gracefully(self,signum, frame):
        self.kill_now = True

def activate_relais():
    global event_lock
    if event_lock == True: return
    event_lock = True
    GPIO.output(Relay_Ch2, GPIO.LOW)
    logg('relais2 ON')
    time.sleep(30)
    GPIO.output(Relay_Ch2, GPIO.HIGH)
    logg('relais2 OFF')
    event_lock = False

killer = GracefulKiller()
ipc = IPConnection()
ipc.connect(tinkerforge_address, 4223)
sensor = BrickletMotionDetectorV2(tinkerforge_uid, ipc)
sensor.register_callback(sensor.CALLBACK_MOTION_DETECTED, activate_relais) # Register callback function
GPIO.setwarnings(False)
GPIO.setmode(GPIO.BCM)
GPIO.setup(Relay_Ch2, GPIO.OUT)
GPIO.setup(Relay_Ch3, GPIO.OUT)
GPIO.output(Relay_Ch3, GPIO.LOW)
logg('relais3 ON')
logg('tinker_raspi_relais started')

# Event loop
while True:
    if event_lock == False and killer.kill_now: break # Terminate
    time.sleep(5)
    reset_timer = reset_timer - 5
    if event_lock == False and reset_timer < 0:
        GPIO.output(Relay_Ch3, GPIO.HIGH)
        logg('relais3 OFF')
        time.sleep(30)
        GPIO.output(Relay_Ch3, GPIO.LOW)
        logg('relais3 ON')
        reset_timer = reset_period
GPIO.cleanup()
ipc.disconnect()
logg('tinker_raspi_relais ended')

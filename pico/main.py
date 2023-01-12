import config
import network
import json
import time
import urequests as requests
from machine import I2C, SoftI2C, Pin
from scd30 import SCD30
from collections import namedtuple
import random

datum = namedtuple("datum", [
    'location',
    'ts',
    'temp_c',
    'hum_pct',
    'co2_ppm',
    'pssr',
    'pm25',
])
def namedtuple2dict(tup:datum):
    return {
        k:v
        for k,v in zip(
            dir(tup)[1:],
            tup
        )
    }
    
# i2c = I2C(k)
i2c = SoftI2C(scl=Pin(1), sda=Pin(0))
scd30 = SCD30(i2c, 0x61)


wlan=network.WLAN(network.STA_IF)
wlan.active(True)

print("Waiting for wifi..", end='')
while True:
    print(".",end='')
    wlan.connect(config.SSID,config.WIFIP)
    if wlan.isconnected() == True:
        break
    else:
        time.sleep(5)
print("connected")



def submit_measurements(measurements):
    payload = json.dumps([namedtuple2dict(m) for m in measurements])

    try:
        response = requests.post(
            f'{config.API_BASE_URL}/table/public/env_log/records/',
            data=payload,
        )
        
        status_code = response.status_code
        response.close()
    
        return (status_code == 200) and random.choice([True]*3+[False]*1)
    
    except OSError as ex:
        if ex.errno == 103: #ECONNABORTED
            print("Error: Connection Aborted")
            return False
        else:
            raise

measurements = []
while True:
    print('Connecting to SCD-30..', end='')
    # Wait for sensor data to be ready to read (by default every 2 seconds)
    while scd30.get_status_ready() != 1:
        print('.',end='')
        time.sleep_ms(200)
    print('connected')
    
    measurement = scd30.read_measurement()
    measurements.append(datum(
            location=config.LOCATION,
            ts='2022-02-02 23:00:00.3123',
            co2_ppm=measurement[0],
            temp_c=measurement[1],
            hum_pct=measurement[2],
            pssr=None,
            pm25=None,
    ))

    if submit_measurements(measurements) == True:
        print(f"Submitted {len(measurements)} measurements")
        measurements = []
        
    time.sleep_ms(15*1000)


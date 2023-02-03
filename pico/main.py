import config
import network
import json
import time
import urequests as requests
from machine import I2C, Pin
from scd30 import SCD30                  # https://github.com/agners/micropython-scd30
from bme280 import BME280                # https://github.com/SebastianRoll/mpy_bme280_esp8266
from urtc import DS3231,datetime_tuple   # https://github.com/adafruit/Adafruit-uRTC
from collections import namedtuple

datum = namedtuple("datum", [
    'location',
    'ts_utc',
    'temp_c',
    'hum_pct',
    'co2_ppm',
    'prssr_hpa',
    'pm1_0_ugmm3',
    'pm2_5_ugmm3',
    'pm10_0_ugmm3'
])
def namedtuple2dict(tup:datum):
    return {
        k:v
        for k,v in zip(
            dir(tup)[1:],
            tup
        )
    }

i2c = I2C(0, scl=Pin(1), sda=Pin(0))
scd30 = SCD30(i2c=i2c, addr=0x61)
bme280 = BME280(i2c=i2c, address=0x77)
#pmsa003i = NotImplementedYet
rtc = DS3231(i2c=i2c, address=0x68)

# Set datetime:
# rtc.datetime(
#     datetime_tuple(year=2023,month=2,day=2,hour=0, minute=16, second=0)
# )


# Connect to wifi
wlan=network.WLAN(network.STA_IF)
wlan.active(True)

print("Waiting for wifi..", end='')
wlan.connect(config.SSID,config.WIFIP)
while True:
    print(".",end='')
    if wlan.isconnected() == True:
        break
    else:
        time.sleep(5)
print("connected")

sleep_time = lambda _dt: 60*(
    config.LOGGING_INTERVAL - (_dt.minute % config.LOGGING_INTERVAL) - 1
) + (60 - _dt.second)

def submit_measurements(measurements:list[datum]):
    """
    Takes a list of datum measurements and sends them to the API
    to be written to a database
    """
    payload = json.dumps([namedtuple2dict(m) for m in measurements])

    try:
        response = requests.post(
            f"{config.API_BASE_URL}/table/public/env_log/records/",
            data=payload,
        )

        status_code = response.status_code
        response.close()

        return (status_code == 200)

    except OSError as ex:
        if ex.errno == 103: #ECONNABORTED
            print("Error: Connection Aborted")
            return False
        else:
            raise

# Start with an empty list of measurements
measurements = []

# Sleep until the next time interval
print(f"Sleeping for {sleep_time(rtc.datetime())/60} minutes")
time.sleep(sleep_time(rtc.datetime()))

# Start the logging loop
while True:
    print('Connecting to SCD-30..', end='')
    # Wait for sensor data to be ready to read (by default every 2 seconds)
    while scd30.get_status_ready() != 1:
        print('.',end='')
        time.sleep_ms(200)
    print('connected')

    # Note the current time and collect measurements from each of the sensors
    now = rtc.datetime()
    measurement_bme280 = [# degC, hPa, %
        v*d for v,d in
        zip(bme280.read_compensated_data(),[0.01,0.0000390625,0.0009765625])#[100,25600,1024]
    ] # Each of these measurements needs to be adjusted to match expected units
    measurement_scd30 = scd30.read_measurement()

    now_str = config.TS_FORMAT.format(
        yr=now.year,
        mth=now.month,
        day=now.day,
        hr=now.hour,
        min=now.minute,
        sec=now.second
    )

    # Append the current measurement to the queue of measurements to be submitted
    measurements.append(datum(
            location=config.LOCATION,
            ts_utc=now_str,
            co2_ppm=measurement_scd30[0],
            temp_c=measurement_scd30[1],
            hum_pct=measurement_scd30[2],
            prssr_hpa=measurement_bme280[1],
            pm1_0_ugmm3=None,
            pm2_5_ugmm3=None, # 1 ug / dL = 10000 ug / m^3
            pm10_0_ugmm3=None,
    ))

    print(f"[{now_str}]")
    print("  SCD-30  : {}ppm, {}C, {}%".format(*measurement_scd30))
    print("  BME280  : {}C, {}hPa, {}%".format(*measurement_bme280))
    #print("  PMSA003I: {}C, {}hPa, {}%".format(*measurement_pmsa003i))

    # Try to submit the measurements, if successful, reset the queue to empty
    if submit_measurements(measurements) == True:
        print(f"Submitted {len(measurements)} measurements")
        measurements = []

    # Sleep until the next time interval
    print(f"Sleeping for {sleep_time(rtc.datetime())/60} minutes")
    time.sleep(sleep_time(rtc.datetime()))

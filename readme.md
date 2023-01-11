# Weather Station for Raspberry Pi Pico W

This project aims to build a weather station running on a Pi Pico W.  The sensors are all I2C devices
from Adafruit.  A RESTful API runs in the background to facilitate writing to a database.

## Hardware

* [Raspberry Pico Pi W][picow]
* [I2C SCD-30][co2] (addr: `0x61`) - CO2
* [I2C DS3231][rtc] (addr: `0x68`) - Real time clock
* [I2C PMSA003I][pm25] (addr: `0x12`) - PM2.5
* [I2C BME280][wthr] (addr: `0x77`) - Temp / Humidity / Pressure

[picow]: https://www.adafruit.com/product/5526
[co2]: https://www.adafruit.com/product/4867
[rtc]: https://www.adafruit.com/product/5188
[pm25]: https://www.adafruit.com/product/4632
[wthr]: https://www.adafruit.com/product/2652

## Architecutre

This project is split into two areas of focus:
* Scripts for the Pi Pico W
* FastAPI server for connecting to a database (postgres in my case)

The Pi Pico code is designed to collect measurements on 15 minute intervals.  Once a measurement is taken,
an attempt is made to post the current buffer of measurements to the API.  If the attempt fails, the buffer
is maintained and appended to with the next measurment for the next attempt.

The API backend is just an endpoint which is set up to allow the Pi Pico to save its measurements to
a database.  The API endpoint allows the Pico to `POST` a list of several records rather than only a single 
record in order to be more fault tolerant.

## Setup

1. Install the following packages on your Pi Pico W
    * `micropython_scd30` 
2. Copy `config.py.template` and rename the copy to `config.py`.  Fill out the values to match your situation
    * `LOCATION` - Your logging location (eg '`Bedroom`', `'Crawl Space'`, etc)
    * `SSID` - Your wifi network name
    * `WIFIP` - Your wifi network's passphrase
    * `API_BASE_URL` - The base url where you're running the API server (eg `'http://192.168.1.100'`)
3. Copy the Pico scripts to your Pico
    * main.py
    * config.py
4. Install the API server requirements with `pip install -r server_requirements.txt`
5. Run the API server with the command `uvicorn postgres_api:api --host 0.0.0.0`
# Weather Station for Raspberry Pi Pico W

This project aims to build a weather station running on a Pi Pico W.  The
sensors are all I2C devices from Adafruit.  A RESTful API runs in the
background to facilitate writing to a database.

## Hardware

* [Raspberry Pico Pi W][picow]
* [I2C SCD-30][co2] (addr: `0x61`) - CO2
  * [pypi][co2_pypi]
  * [gh][co2_gh]
* [I2C DS3231][rtc] (addr: `0x68`) - Real time clock
  * [pypi][rtc_pypi]
  * [gh][rtc_gh]
  * [docs][rtc_docs]
* [I2C BME280][wthr] (addr: `0x77`) - Temp / Humidity / Pressure
  * [pypi][wthr_pypi]
  * [gh][wthr_gh]
* [I2C PMSA003I][pm25] (addr: `0x12`) - PM2.5

[picow]: https://www.adafruit.com/product/5526
[co2]: https://www.adafruit.com/product/4867
[co2_gh]: https://github.com/agners/micropython-scd30
[co2_pypi]: https://pypi.org/project/micropython-scd30/
[rtc]: https://www.adafruit.com/product/5188
[rtc_gh]: https://github.com/adafruit/Adafruit-uRTC
[rtc_pypi]: https://pypi.org/project/urtc/
[rtc_docs]: https://micropython-urtc.readthedocs.io/en/latest/
[wthr]: https://www.adafruit.com/product/2652
[wthr_gh]: https://github.com/SebastianRoll/mpy_bme280_esp8266
[wthr_pypi]: https://pypi.org/project/micropython-bme280/
[pm25]: https://www.adafruit.com/product/4632

## Architecutre

This project is split into two areas of focus:
* Scripts for the Pi Pico W
* FastAPI server for connecting to a database (postgres in my case)

The Pi Pico code is designed to collect measurements on 15 minute intervals.
Once a measurement is taken, an attempt is made to post the current buffer of
measurements to the API.  If the attempt fails, the buffer is maintained and
appended to with the next measurment for the next attempt.

The API backend is just an endpoint which is set up to allow the Pi Pico to
save its measurements to a database.  The API endpoint allows the Pico to
`POST` a list of several records rather than only a single record in order to
be more fault tolerant.

## Setup

### Raspberry Pi Pico W

1. Install the following packages on your Pi Pico W (outlined in hw section)
    * `micropython_bme280`
    * `micropython_scd30`
    * `urtc`
2. Copy `config.py.template` and rename the copy to `config.py`.  Fill out the
   values to match your situation
    * `LOCATION` - Your logging location (eg '`Bedroom`', `'Crawl Space'`, etc)
    * `SSID` - Your wifi network name
    * `WIFIP` - Your wifi network's passphrase
    * `API_BASE_URL` - The base url where you're running the API server
      (eg `'http://192.168.1.100'`)
3. Copy the Pico scripts to your Pico
    * main.py
    * config.py
4. Connect an I2C sensor device to the GPIO pins:
    * SDA -> GP0
    * SLC -> GP1
    * GND -> GND
    * V   -> 3.3v
5. Use additional STEMMA QT plugs to daisy-chain the rest of the I2C sensors

### API Server

1. Install the API server requirements with
   `pip install -r server_requirements.txt`
2. Run the API server with the command `uvicorn postgres_api:api --host 0.0.0.0`

### Database Table Structure

Create the tables and function as described in [create.sql][create].
* `env_log` - Stores measurement records
* `aqi_categories` - Lookup table for descriptions and colors of AQI ranges
* `aqi_breakpoints` - Lookup table for AQI range breakpoints
* `calcualte_aqi` - Function to calcualte AQI from concentration measurement
  and reference values

[create]: ./database/create.sql
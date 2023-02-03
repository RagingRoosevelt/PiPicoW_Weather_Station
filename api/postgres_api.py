from fastapi import (
    FastAPI,
    Request,
    status,
)
from fastapi.responses import (
    RedirectResponse,
    JSONResponse,
)
from fastapi.exceptions import (
    RequestValidationError,
)
from pydantic import (
    BaseModel,
)
from typing import (
    Optional,
)
from datetime import datetime
import psycopg2
import configparser

config = configparser.ConfigParser()
config.read('config.ini')


conn = psycopg2.connect(
    host=config['POSTGRES']['host'],
    port=config['POSTGRES']['port'],
    dbname=config['POSTGRES']['dbname'],
    user=config['POSTGRES']['user'],
    password=config['POSTGRES']['password']
)


class DatabaseRecord(BaseModel):
    pass

class WeatherDatum(DatabaseRecord):
    location: str
    ts_utc: datetime
    temp_c: Optional[float] = None
    hum_pct: Optional[float] = None
    co2_ppm: Optional[float] = None
    prssr_hpa: Optional[float] = None
    pm1_0_ugmm3: Optional[float] = None
    pm2_5_ugmm3: Optional[float] = None
    pm10_0_ugmm3: Optional[float] = None
    ozone_ppm: Optional[float] = None
    co_ppm: Optional[float] = None
    so2_ppm: Optional[float] = None
    no2_ppb: Optional[float] = None


supported_tables = [
    'public.env_log',
]

api = FastAPI()


@api.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    exc_str = f'{exc}'.replace('\n', ' ').replace('   ', ' ')
    print(f"{request}: {exc_str}")
    content = {'status_code': 10422, 'message': exc_str, 'data': None}
    return JSONResponse(content=content, status_code=status.HTTP_422_UNPROCESSABLE_ENTITY)

@api.get('/')
def redirect_docs():
    response = RedirectResponse(url='/docs')
    return response

@api.get('/table/list/')
def get_table_list():
    return supported_tables

@api.post('/table/{schema}/{table_name}/records/')
def post_records_to_table(schema:str,table_name:str,records:list[WeatherDatum]):
    print([{k:v for k,v in r if v is not None} for r in records])

    cur = conn.cursor()
    for record in records:
        ts_load_utc, location = record.ts_utc, record.location
        for key,value in record.dict().items():
            if key in ['ts_utc', 'location'] or value is None:
                continue

            print((location,key,ts_load_utc,value))

            cur.execute(
                """
                    insert into environmental_log (location, fk_measurement_type_id, ts_load_utc, measurement_value)
                    select v.location, mt.id, v.ts_load_utc, v.measurement_value
                    from (
                        values (
                            %s::text,
                            %s::text,
                            %s::timestamp without time zone,
                            %s::float8
                        )
                    ) v(location, measurement_key, ts_load_utc, measurement_value)
                    inner join measurement_types mt
                    on v.measurement_key = mt.key
                """,
                (location,key,ts_load_utc,value)
            )
    conn.commit()
    cur.close()

    return {}

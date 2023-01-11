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
from datetime import datetime


class DatabaseRecord(BaseModel):
    pass

class WeatherDatum(DatabaseRecord):
    location: str
    ts: datetime
    temp_c: float|None = None
    hum_pct: float|None = None
    co2_ppm: float|None = None
    pm25: float|None = None
    pssr: float|None = None


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
    print(records)
    return {}
    

create table env_log (
    location                       VARCHAR(150)        NOT NULL  ,
    ts_load_utc                    timestamp without time zone NOT NULL DEFAULT (current_timestamp AT TIME ZONE 'UTC')  ,
    temp_c                         NUMERIC(5,2)                  , -- expected range [-999,999]
    humd_pct                       NUMERIC(5,2)                  , -- expected range [0,100]
    co2_ppm                        NUMERIC(8,2)                  , -- expected range [0,10000]
    prssr_hpa                      NUMERIC(7,2)                  , -- expected range [0,10000]
    pm1_0_umm3                     NUMERIC(6,2)                  , -- truncate to ? decimal place - expected range [?,?] µg/m^3
    pm2_5_umm3                     NUMERIC(5,1)                  , -- truncate to 1 decimal place - realistic expected range [0,500] µg/m^3
    pm10_0_umm3                    NUMERIC(4,0)                  , -- truncate to integer         - realistic expected range [0,605] µg/m^3
    primary key (location, ts_load_utc)
);
comment on table env_log is
    'Stores measurement records';
comment on column public.env_log.location is
    'Location of record collection';
comment on column public.env_log.ts_load_utc is
    'Timestamp (UTC) of record collection';
comment on column public.env_log.humd_pct is
    'Relative humidity in percents - %';
comment on column public.env_log.temp_c is
    'Temperature in degrees celsius - C';
comment on column public.env_log.co2_ppm is
    'CO2 concentration in parts per million - ppm';
comment on column public.env_log.prssr_hpa is
    'Barometric pressure in hectopascal or milibar - hPa or mbar';
comment on column public.env_log.pm1_0_umdl is
    'PM 1.0 concentration in micrograms per cubic meter - ug / m^3';
comment on column public.env_log.pm2_5_umdl is
    'PM 2.5 concentration in micrograms per cubic meter - ug / m^3';
comment on column public.env_log.pm10_0_umdl is
    'PM 10 concentration in micrograms per cubic meter - ug / m^3';


create table aqi_categories (
    id         int primary key,
    descriptor varchar(30),
    color_hex  char(6),
    color_hsv  int[],
    color_rgb  int[],
    color_cmyk int[]
);
comment on table aqi_categories is
    'Lookup table for descriptions and colors of AQI ranges';
insert into public.aqi_categories (
    id,
    descriptor,
    color_hex,
    color_hsv,
    color_rgb,
    color_cmyk
) values
    (0,'Good',                          '00E400',
        '{120,100,89}','{0,228,0}',   '{40,0,100,0}'),
    (1,'Moderate',                      'FFFF00',
        '{60,100,100}','{255,255,0}', '{0,0,100,0}'),
    (2,'Unhealthy for Sensitive Groups','FF7E00',
        '{30,100,100}','{255,126,0}', '{0,52,100,0}'),
    (3,'Unhealthy',                     'FF0000',
        '{0,100,100}', '{255,0,0}',   '{0,100,100,0}'),
    (4,'Very Unhealthy',                '8F3F97',
        '{295,58,59}', '{143,63,151}','{51,89,0,0}'),
    (5,'Hazardous',                     '7E0023',
        '{343,100,49}','{126,0,35}',  '{30,100,100,30}')
;


create table public.aqi_breakpoints (
    pollutant        varchar(10)    ,
    break_point_low  numeric(10,5)  ,
    break_point_high numeric(10,5)  ,
    aqi_low          int            ,
    aqi_high         int            ,
    fk_aqi_rating    int            ,
    primary key (pollutant, break_point_low),
    foreign key(fk_aqi_rating) references public.aqi_categories(id)
);
comment on table public.aqi_breakpoints is
    'Lookup table for AQI range breakpoints';
insert into public.aqi_breakpoints (
    pollutant,
    break_point_low,
    break_point_high,
    aqi_low,
    aqi_high,
    fk_aqi_rating
) values
    ('PM2.5',0,12,0,50,0),
    ('PM2.5',12,35.5,50,100,1),
    ('PM2.5',35.5,55.5,100,150,2),
    ('PM2.5',55.5,150.5,150,200,3),
    ('PM2.5',150.5,250.5,200,300,4),
    ('PM2.5',250.5,350.5,300,400,5),
    ('PM2.5',350.5,500.5,400,500,5),
    ('PM10',0,55,0,50,0),
    ('PM10',55,155,50,100,1),
    ('PM10',155,255,100,150,2),
    ('PM10',255,355,150,200,3),
    ('PM10',355,425,200,300,4),
    ('PM10',425,505,300,400,5),
    ('PM10',505,605,400,500,5)
;


create or replace function calcualte_aqi(
	concentration real,
	breakpoint_low real,
	breakpoint_high real,
	index_low integer,
	index_high integer
) returns integer
language sql
immutable
return round(
    ((index_high-index_low)/(breakpoint_high-breakpoint_low))
    *(concentration-breakpoint_low)+index_low
)
;
comment on function calcualte_aqi is
'Calculates the AQI given a concentration and reference breakpoints and corresponding index values';
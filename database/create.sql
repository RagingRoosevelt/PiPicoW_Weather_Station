create table measurement_types (
	id 		                int         primary key,
	key         varchar(15) not null,
	name        varchar(15) not null,
	name_long   varchar(30) not null,
	units       varchar(12) not null,
    unreasonable_min_value  int         not null,
    unreasonable_max_value  int         not null,
    measurement_notes       text
);
insert into measurement_types (
	id,
	key,
	name,
	name_long,
	units,
    unreasonable_min_value,
    unreasonable_max_value,
    measurement_notes
)
values
	(0,'temp_c',        'Temperature',  'Temperature',          'C',-100,100,null),
	(1,'humd_pct',      'Humidity',     'Humidity',             '%',0,100,null),
	(2,'co2_ppm',       'CO₂',          'CO₂ Concentration',    'ppm',0,6000,null),
	(3,'prssr_hpa',     'Pressure',     'Atmospheric Pressure', 'hPa',500,1500,null),
	(4,'pm1_0_ugmm3',    'PM1.0',        'PM1.0 Concentration',  'µg / mm³',0,1000,'24-hour'),
	(5,'pm2_5_ugmm3',    'PM2.5',        'PM2.5 Concentration',  'µg / mm³',0,1000,'24-hour'),
	(6,'pm10_0_ugmm3',   'PM10',         'PM10 Concentration',   'µg / mm³',0,1000,'24-hour'),
    (7,'ozone_ppm',     'Ozone',        'Ozone Concentration',  'ppm',0,2,'8-hour'),
    (8,'co_ppm',        'CO',           'Carbon Monoxide Concentration','ppm',0,100,'8-hour'),
    (9,'so2_ppm',       'SO₂',          'Sulfur Dioxide Concentration', 'ppm',0,2000,'1-hour'),
    (10,'no2_ppb',      'NO₂',          'Nitrogen Dioxide Concentration', 'ppb',0,4000,'1-hour')
	;

create table environmental_log (
	location 				varchar(150) not null,
	fk_measurement_type_id int not null,
	ts_load_utc timestamp without time zone NOT NULL DEFAULT (current_timestamp AT TIME ZONE 'UTC'),
	measurement_value float8,
	primary key (location, fk_measurement_type_id, ts_load_utc),
	foreign key (fk_measurement_type_id) references measurement_types(id)
);
comment on table environmental_log is
    'Stores measurement records, organized by location, type, and date';
comment on column environmental_log.location is
    'Location of record collection';
comment on column environmental_log.fk_measurement_type_id is
    'Type of measurement, see `measurement_types` table';
comment on column environmental_log.ts_load_utc is
    'Timestamp (UTC) of record collection';
comment on column environmental_log.measurement_value is
    'Measurement value, units outlined in `measurement_types` table';



create table aqi_ratings (
    id              int primary key,
    aqi_value_min   int not null,
    aqi_value_max   int not null,
    descriptor      varchar(30) not null,
    color_hex       char(6) not null,
    color_hsv       int[] not null,
    color_rgb       int[] not null,
    color_cmyk      int[] not null
);
comment on table aqi_ratings is
    'Lookup table for descriptions and colors of AQI ranges';
insert into aqi_ratings (
    id,
    aqi_value_min,
    aqi_value_max,
    descriptor,
    color_hex,
    color_hsv,
    color_rgb,
    color_cmyk
) values
    (0,0,50,    'Good',                          '00E400',
        '{120,100,89}','{0,228,0}',   '{40,0,100,0}'),
    (1,50,100,  'Moderate',                      'FFFF00',
        '{60,100,100}','{255,255,0}', '{0,0,100,0}'),
    (2,100,150, 'Unhealthy for Sensitive Groups','FF7E00',
        '{30,100,100}','{255,126,0}', '{0,52,100,0}'),
    (3,150,200, 'Unhealthy',                     'FF0000',
        '{0,100,100}', '{255,0,0}',   '{0,100,100,0}'),
    (4,200,300, 'Very Unhealthy',                '8F3F97',
        '{295,58,59}', '{143,63,151}','{51,89,0,0}'),
    (5,300,500, 'Hazardous',                     '7E0023',
        '{343,100,49}','{126,0,35}',  '{30,100,100,30}')
;


create table aqi_breakpoints (
    fk_measurement_type_id  int            ,
    fk_aqi_rating_id        int            ,
    break_point_low         float8  ,
    break_point_high        float8  ,
    primary key (fk_measurement_type_id, fk_aqi_rating_id),
    foreign key(fk_measurement_type_id) references measurement_types(id),
    foreign key(fk_aqi_rating_id) references aqi_ratings(id)
);
comment on table aqi_breakpoints is
    'Lookup table for AQI range breakpoints';
insert into aqi_breakpoints (
    fk_measurement_type_id,
    fk_aqi_rating_id,
    break_point_low,
    break_point_high
) values
    -- PM2.5
    (5, 0, 0,       12),
    (5, 1, 12,      35.5),
    (5, 2, 35.5,    55.5),
    (5, 3, 55.5,    150.5),
    (5, 4, 150.5,   250.5),
    (5, 5, 250.5,   500.5),
    -- PM10
    (6, 0, 0,       55),
    (6, 1, 55,      155),
    (6, 2, 155,     255),
    (6, 3, 255,     355),
    (6, 4, 355,     425),
    (6, 5, 425,     605),
    -- CO
    (8, 0, 0,       4.5),
    (8, 1, 4.5,     9.5),
    (8, 2, 9.5,     12.5),
    (8, 3, 12.5,    15.5),
    (8, 4, 15.5,    30.5),
    (8, 5, 30.5,    50.5)
    ;

create or replace function calcualte_aqi(
	concentration float8,
	breakpoint_low float8,
	breakpoint_high float8,
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

create view aqi_lookup as
    select
        mt.name,
        mt.units,
        bp.*,
        aqi.aqi_value_min,
        aqi_value_max,
        aqi.descriptor,
        aqi.color_hex
    from aqi_breakpoints bp
    inner join aqi_ratings aqi
    on bp.fk_aqi_rating_id = aqi.id
    inner join measurement_types mt
    on bp.fk_measurement_type_id = mt.id
    ;

create view environmental_log_localized_pacific as
    select
		m.location,
		mt.name,
		m.ts_load_utc,
		((m.ts_load_utc AT TIME ZONE 'utc'::text) AT TIME ZONE 'america/los_angeles'::text) AS ts_load_pst,
		m.measurement_value,
		mt.units,
        mt.name_long,
        mt.measurement_notes,
        calcualte_aqi(m.measurement_value, break_point_low, break_point_high, aqi_value_min, aqi_value_max) as AQI,
        aqi.descriptor,
        aqi.color_hex
    from environmental_log m
	inner join measurement_types mt
	on m.fk_measurement_type_id = mt.id
    left outer join aqi_lookup aqi
    on m.fk_measurement_type_id = aqi.fk_measurement_type_id
    and aqi.break_point_low <= m.measurement_value and m.measurement_value < aqi.break_point_high
    ;

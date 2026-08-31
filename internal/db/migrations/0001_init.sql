CREATE TABLE IF NOT EXISTS catches (
    id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    species                 text NOT NULL,
    weight_grams            integer,
    length_cm               real,
    bait_lure               text,
    technique               text,
    water_type              text,
    latitude                double precision NOT NULL,
    longitude               double precision NOT NULL,
    caught_at               timestamptz NOT NULL,
    notes                   text,
    weather_temp_c          real,
    weather_wind_speed_ms   real,
    weather_wind_direction  text,
    weather_pressure_hpa    real,
    weather_cloud_cover     text,
    water_temp_c            real,
    created_at              timestamptz NOT NULL DEFAULT now(),
    updated_at              timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS catch_images (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    catch_id    uuid NOT NULL REFERENCES catches(id) ON DELETE CASCADE,
    file_path   text NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS catch_images_catch_id_idx ON catch_images(catch_id);

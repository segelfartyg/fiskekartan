CREATE TABLE IF NOT EXISTS profiles (
    sub               text PRIMARY KEY,
    username          text NOT NULL UNIQUE,
    location          text,
    description       text,
    avatar_file_path  text,
    pin_color         text,
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now()
);

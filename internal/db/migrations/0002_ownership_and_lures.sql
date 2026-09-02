ALTER TABLE catches ADD COLUMN IF NOT EXISTS owner_sub text;
ALTER TABLE catches ADD COLUMN IF NOT EXISTS owner_display_name text;
CREATE INDEX IF NOT EXISTS catches_owner_sub_idx ON catches(owner_sub);

CREATE TABLE IF NOT EXISTS lures (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_sub         text NOT NULL,
    title             text NOT NULL,
    description       text,
    image_file_path   text,
    created_at        timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS lures_owner_sub_idx ON lures(owner_sub);

ALTER TABLE catches ADD COLUMN IF NOT EXISTS lure_id uuid REFERENCES lures(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS catches_lure_id_idx ON catches(lure_id);

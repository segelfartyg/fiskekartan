-- Who besides the owner may see a catch. 'friends' is reserved for the
-- upcoming friend feature; until then it's treated like 'private'.
ALTER TABLE catches ADD COLUMN IF NOT EXISTS visibility text NOT NULL DEFAULT 'private'
    CHECK (visibility IN ('private', 'friends', 'public'));
CREATE INDEX IF NOT EXISTS catches_public_idx ON catches(caught_at) WHERE visibility = 'public';

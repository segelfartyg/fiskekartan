package profile

import (
	"context"
	"errors"
	"fmt"
	"slices"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Repository struct {
	pool *pgxpool.Pool
}

func NewRepository(pool *pgxpool.Pool) *Repository {
	return &Repository{pool: pool}
}

const selectProfile = `
	SELECT p.sub, p.username, p.location, p.description, p.avatar_file_path, p.pin_color, p.created_at,
	       (SELECT count(*) FROM catches c WHERE c.owner_sub = p.sub)
	FROM profiles p
`

func scanProfile(row pgx.Row) (*Profile, error) {
	var p Profile
	err := row.Scan(&p.Sub, &p.Username, &p.Location, &p.Description, &p.AvatarFilePath, &p.PinColor, &p.CreatedAt, &p.CatchCount)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	if p.AvatarFilePath != nil {
		url := "/images/" + *p.AvatarFilePath
		p.Avatar = &url
	}
	return &p, nil
}

// GetByUsername returns nil, nil if no such profile exists.
func (r *Repository) GetByUsername(ctx context.Context, username string) (*Profile, error) {
	return scanProfile(r.pool.QueryRow(ctx, selectProfile+`WHERE p.username = $1`, username))
}

// GetBySub returns nil, nil if no such profile exists.
func (r *Repository) GetBySub(ctx context.Context, sub string) (*Profile, error) {
	return scanProfile(r.pool.QueryRow(ctx, selectProfile+`WHERE p.sub = $1`, sub))
}

// Ensure returns sub's profile, creating it first if needed. The username
// is tried in order from candidates (derived from the login token), skipping
// any already taken — the last candidate should be one that can't
// realistically collide. For an existing profile whose username no longer
// matches any candidate (the user was renamed in Keycloak), the username is
// re-synced to the first available candidate.
func (r *Repository) Ensure(ctx context.Context, sub string, candidates []string) (*Profile, error) {
	p, err := r.GetBySub(ctx, sub)
	if err != nil {
		return nil, err
	}
	if p != nil {
		if slices.Contains(candidates, p.Username) {
			return p, nil
		}
		return r.resync(ctx, p, candidates)
	}
	for _, username := range candidates {
		// ON CONFLICT DO NOTHING (with no target) swallows both a racing
		// insert for the same sub and a username collision; re-reading by
		// sub afterwards tells the two apart.
		_, err := r.pool.Exec(ctx, `
			INSERT INTO profiles (sub, username) VALUES ($1, $2)
			ON CONFLICT DO NOTHING
		`, sub, username)
		if err != nil {
			return nil, fmt.Errorf("insert profile: %w", err)
		}
		if p, err := r.GetBySub(ctx, sub); err != nil || p != nil {
			return p, err
		}
	}
	return nil, errors.New("no available username")
}

func (r *Repository) resync(ctx context.Context, p *Profile, candidates []string) (*Profile, error) {
	for _, username := range candidates {
		tag, err := r.pool.Exec(ctx, `
			UPDATE profiles SET username = $2, updated_at = now()
			WHERE sub = $1 AND NOT EXISTS (SELECT 1 FROM profiles WHERE username = $2)
		`, p.Sub, username)
		if err != nil {
			var pgErr *pgconn.PgError
			if errors.As(err, &pgErr) && pgErr.Code == "23505" {
				continue // lost a race for this username
			}
			return nil, fmt.Errorf("resync username: %w", err)
		}
		if tag.RowsAffected() == 1 {
			return r.GetBySub(ctx, p.Sub)
		}
	}
	// Keep the old username rather than failing the request.
	return p, nil
}

// Update overwrites sub's editable profile fields, returning the avatar
// file path that was replaced or removed (if any) so the caller can clean
// it up from object storage.
func (r *Repository) Update(ctx context.Context, sub string, in UpdateInput) (oldAvatar *string, err error) {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)

	if err := tx.QueryRow(ctx, `SELECT avatar_file_path FROM profiles WHERE sub = $1 FOR UPDATE`, sub).Scan(&oldAvatar); err != nil {
		return nil, fmt.Errorf("load profile: %w", err)
	}

	newAvatar := oldAvatar
	if in.AvatarFilePath != nil {
		newAvatar = in.AvatarFilePath
	} else if in.RemoveAvatar {
		newAvatar = nil
	}

	_, err = tx.Exec(ctx, `
		UPDATE profiles
		SET location = $2, description = $3, pin_color = $4,
		    avatar_file_path = $5, updated_at = now()
		WHERE sub = $1
	`, sub, in.Location, in.Description, in.PinColor, newAvatar)
	if err != nil {
		return nil, fmt.Errorf("update profile: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	if oldAvatar != nil && (newAvatar == nil || *newAvatar != *oldAvatar) {
		return oldAvatar, nil
	}
	return nil, nil
}

package lure

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Repository struct {
	pool *pgxpool.Pool
}

func NewRepository(pool *pgxpool.Pool) *Repository {
	return &Repository{pool: pool}
}

func (r *Repository) List(ctx context.Context, ownerSub string) ([]Lure, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT id, title, description, image_file_path, created_at
		FROM lures
		WHERE owner_sub = $1
		ORDER BY created_at DESC
	`, ownerSub)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	result := []Lure{}
	for rows.Next() {
		var l Lure
		var imagePath *string
		if err := rows.Scan(&l.ID, &l.Title, &l.Description, &imagePath, &l.CreatedAt); err != nil {
			return nil, err
		}
		if imagePath != nil {
			url := "/images/" + *imagePath
			l.Image = &url
		}
		result = append(result, l)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return result, nil
}

func (r *Repository) Create(ctx context.Context, in CreateInput) (string, error) {
	var id string
	err := r.pool.QueryRow(ctx, `
		INSERT INTO lures (owner_sub, title, description, image_file_path)
		VALUES ($1, $2, $3, $4)
		RETURNING id
	`, in.OwnerSub, in.Title, in.Description, in.ImageFilePath).Scan(&id)
	if err != nil {
		return "", fmt.Errorf("insert lure: %w", err)
	}
	return id, nil
}

// Delete removes a lure owned by ownerSub, returning its image file path (if
// any) so the caller can clean it up from object storage, and whether a row
// was actually deleted. Scoping the DELETE itself by owner_sub — rather than
// loading the row and checking ownership separately — makes the check
// atomic, with no gap between verifying ownership and acting on it.
func (r *Repository) Delete(ctx context.Context, id, ownerSub string) (imageFilePath *string, deleted bool, err error) {
	err = r.pool.QueryRow(ctx, `
		DELETE FROM lures WHERE id = $1 AND owner_sub = $2
		RETURNING image_file_path
	`, id, ownerSub).Scan(&imageFilePath)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, false, nil
		}
		return nil, false, err
	}
	return imageFilePath, true, nil
}

// OwnedBy reports whether a lure with the given id exists and belongs to
// ownerSub. Used by internal/catch to verify a lure_id before linking it to
// a catch, without giving catch any other access to lure data.
func (r *Repository) OwnedBy(ctx context.Context, id, ownerSub string) (bool, error) {
	var owned bool
	err := r.pool.QueryRow(ctx, `
		SELECT EXISTS(SELECT 1 FROM lures WHERE id = $1 AND owner_sub = $2)
	`, id, ownerSub).Scan(&owned)
	return owned, err
}

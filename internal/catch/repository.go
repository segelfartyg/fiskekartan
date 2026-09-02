package catch

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

// List returns catch summaries, optionally restricted to ownerSub's own
// catches (nil means everyone's).
func (r *Repository) List(ctx context.Context, ownerSub *string) ([]CatchSummary, error) {
	var rows pgx.Rows
	var err error
	if ownerSub == nil {
		rows, err = r.pool.Query(ctx, `
			SELECT c.id, c.species, c.latitude, c.longitude, c.caught_at,
			       (SELECT ci.file_path FROM catch_images ci
			        WHERE ci.catch_id = c.id ORDER BY ci.created_at ASC LIMIT 1)
			FROM catches c
			ORDER BY c.caught_at DESC
		`)
	} else {
		rows, err = r.pool.Query(ctx, `
			SELECT c.id, c.species, c.latitude, c.longitude, c.caught_at,
			       (SELECT ci.file_path FROM catch_images ci
			        WHERE ci.catch_id = c.id ORDER BY ci.created_at ASC LIMIT 1)
			FROM catches c
			WHERE c.owner_sub = $1
			ORDER BY c.caught_at DESC
		`, *ownerSub)
	}
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	result := []CatchSummary{}
	for rows.Next() {
		var s CatchSummary
		var thumb *string
		if err := rows.Scan(&s.ID, &s.Species, &s.Latitude, &s.Longitude, &s.CaughtAt, &thumb); err != nil {
			return nil, err
		}
		if thumb != nil {
			url := "/images/" + *thumb
			s.Thumbnail = &url
		}
		result = append(result, s)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return result, nil
}

// Get returns nil, nil if no catch with the given id exists.
func (r *Repository) Get(ctx context.Context, id string) (*Catch, error) {
	var c Catch
	err := r.pool.QueryRow(ctx, `
		SELECT id, species, weight_grams, length_cm, bait_lure, technique, water_type,
		       latitude, longitude, caught_at, notes,
		       weather_temp_c, weather_wind_speed_ms, weather_wind_direction,
		       weather_pressure_hpa, weather_cloud_cover, water_temp_c,
		       created_at, updated_at, owner_sub, owner_display_name, lure_id
		FROM catches WHERE id = $1
	`, id).Scan(
		&c.ID, &c.Species, &c.WeightGrams, &c.LengthCM, &c.BaitLure, &c.Technique, &c.WaterType,
		&c.Latitude, &c.Longitude, &c.CaughtAt, &c.Notes,
		&c.WeatherTempC, &c.WeatherWindSpeedMS, &c.WeatherWindDirection,
		&c.WeatherPressureHPa, &c.WeatherCloudCover, &c.WaterTempC,
		&c.CreatedAt, &c.UpdatedAt, &c.OwnerSub, &c.OwnerDisplayName, &c.LureID,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}

	rows, err := r.pool.Query(ctx, `SELECT file_path FROM catch_images WHERE catch_id = $1 ORDER BY created_at ASC`, id)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var path string
		if err := rows.Scan(&path); err != nil {
			return nil, err
		}
		c.Images = append(c.Images, "/images/"+path)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	return &c, nil
}

// Delete removes a catch (and its catch_images rows, via ON DELETE CASCADE).
func (r *Repository) Delete(ctx context.Context, id string) error {
	_, err := r.pool.Exec(ctx, `DELETE FROM catches WHERE id = $1`, id)
	return err
}

func (r *Repository) Create(ctx context.Context, in CreateInput) (string, error) {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return "", err
	}
	defer tx.Rollback(ctx)

	var id string
	err = tx.QueryRow(ctx, `
		INSERT INTO catches (
			species, weight_grams, length_cm, bait_lure, technique, water_type,
			latitude, longitude, caught_at, notes,
			weather_temp_c, weather_wind_speed_ms, weather_wind_direction,
			weather_pressure_hpa, weather_cloud_cover, water_temp_c,
			owner_sub, owner_display_name, lure_id
		) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19)
		RETURNING id
	`,
		in.Species, in.WeightGrams, in.LengthCM, in.BaitLure, in.Technique, in.WaterType,
		in.Latitude, in.Longitude, in.CaughtAt, in.Notes,
		in.WeatherTempC, in.WeatherWindSpeedMS, in.WeatherWindDirection,
		in.WeatherPressureHPa, in.WeatherCloudCover, in.WaterTempC,
		in.OwnerSub, in.OwnerDisplayName, in.LureID,
	).Scan(&id)
	if err != nil {
		return "", fmt.Errorf("insert catch: %w", err)
	}

	for _, path := range in.ImageFilePaths {
		if _, err := tx.Exec(ctx, `INSERT INTO catch_images (catch_id, file_path) VALUES ($1, $2)`, id, path); err != nil {
			return "", fmt.Errorf("insert catch image: %w", err)
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return "", err
	}
	return id, nil
}

package catch

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"mime/multipart"
	"net/http"
	"strconv"
	"strings"
	"time"

	"swaren.se/fiskekartan/internal/authmw"
	"swaren.se/fiskekartan/internal/imagestore"
)

// ImageStore is satisfied by *imagestore.Store.
type ImageStore interface {
	Save(fh *multipart.FileHeader) (string, error)
	Delete(filename string) error
	Open(name string) (content imagestore.ReadSeekCloser, contentType string, modTime time.Time, err error)
}

// LureVerifier is satisfied by *lure.Repository — checking ownership here
// rather than importing internal/lure keeps catch and lure independent
// siblings with no dependency between them.
type LureVerifier interface {
	OwnedBy(ctx context.Context, lureID, ownerSub string) (bool, error)
}

type Handlers struct {
	repo   *Repository
	images ImageStore
	lures  LureVerifier
}

func NewHandlers(repo *Repository, images ImageStore, lures LureVerifier) *Handlers {
	return &Handlers{repo: repo, images: images, lures: lures}
}

func (h *Handlers) List(w http.ResponseWriter, r *http.Request) {
	var ownerSub *string
	if r.URL.Query().Get("mine") == "true" {
		sub, ok := authmw.SubFromContext(r.Context())
		if !ok {
			http.Error(w, "must be logged in to filter by mine", http.StatusUnauthorized)
			return
		}
		ownerSub = &sub
	}

	list, err := h.repo.List(r.Context(), ownerSub)
	if err != nil {
		http.Error(w, "failed to list catches", http.StatusInternalServerError)
		return
	}
	writeJSON(w, http.StatusOK, list)
}

func (h *Handlers) Get(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	c, err := h.repo.Get(r.Context(), id)
	if err != nil {
		http.Error(w, "failed to get catch", http.StatusInternalServerError)
		return
	}
	if c == nil {
		http.NotFound(w, r)
		return
	}

	sub, _ := authmw.SubFromContext(r.Context())
	resp := CatchResponse{
		Catch:     *c,
		OwnedByMe: c.OwnerSub != nil && sub == *c.OwnerSub,
		HasOwner:  c.OwnerSub != nil,
		LoggedBy:  c.OwnerDisplayName,
	}
	writeJSON(w, http.StatusOK, resp)
}

func (h *Handlers) Delete(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")

	c, err := h.repo.Get(r.Context(), id)
	if err != nil {
		http.Error(w, "failed to load catch", http.StatusInternalServerError)
		return
	}
	if c == nil {
		http.NotFound(w, r)
		return
	}

	sub, _ := authmw.SubFromContext(r.Context())
	if c.OwnerSub == nil || *c.OwnerSub != sub {
		http.Error(w, "you can only delete your own catches", http.StatusForbidden)
		return
	}

	if err := h.repo.Delete(r.Context(), id); err != nil {
		http.Error(w, "failed to delete catch", http.StatusInternalServerError)
		return
	}

	for _, imageURL := range c.Images {
		filename := strings.TrimPrefix(imageURL, "/images/")
		if err := h.images.Delete(filename); err != nil {
			log.Printf("failed to delete image file %q for catch %s: %v", filename, id, err)
		}
	}

	w.WriteHeader(http.StatusNoContent)
}

func (h *Handlers) ServeImage(w http.ResponseWriter, r *http.Request) {
	name := r.PathValue("name")

	content, contentType, modTime, err := h.images.Open(name)
	if err != nil {
		if errors.Is(err, imagestore.ErrNotFound) {
			http.NotFound(w, r)
			return
		}
		http.Error(w, "failed to load image", http.StatusInternalServerError)
		return
	}
	defer content.Close()

	if contentType != "" {
		w.Header().Set("Content-Type", contentType)
	}
	http.ServeContent(w, r, name, modTime, content)
}

func (h *Handlers) Create(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseMultipartForm(32 << 20); err != nil {
		http.Error(w, "invalid multipart form", http.StatusBadRequest)
		return
	}

	species := r.FormValue("species")
	if species == "" {
		http.Error(w, "species is required", http.StatusBadRequest)
		return
	}

	lat, err := strconv.ParseFloat(r.FormValue("latitude"), 64)
	if err != nil {
		http.Error(w, "latitude is required and must be a number", http.StatusBadRequest)
		return
	}
	lng, err := strconv.ParseFloat(r.FormValue("longitude"), 64)
	if err != nil {
		http.Error(w, "longitude is required and must be a number", http.StatusBadRequest)
		return
	}

	caughtAt := time.Now()
	if v := r.FormValue("caught_at"); v != "" {
		parsed, err := time.Parse(time.RFC3339, v)
		if err != nil {
			http.Error(w, "caught_at must be RFC3339", http.StatusBadRequest)
			return
		}
		caughtAt = parsed
	}

	// Guaranteed present — this route stays behind requireAuth. The owner
	// always comes from the verified token, never a client-supplied field.
	claims, _ := authmw.ClaimsFromContext(r.Context())

	var lureID *string
	if v := r.FormValue("lure_id"); v != "" {
		owned, err := h.lures.OwnedBy(r.Context(), v, claims.Sub)
		if err != nil {
			http.Error(w, "failed to verify lure", http.StatusInternalServerError)
			return
		}
		if !owned {
			http.Error(w, "lure_id does not belong to you", http.StatusBadRequest)
			return
		}
		lureID = &v
	}

	in := CreateInput{
		Species:              species,
		WeightGrams:          parseOptionalInt(r.FormValue("weight_grams")),
		LengthCM:             parseOptionalFloat(r.FormValue("length_cm")),
		BaitLure:             parseOptionalString(r.FormValue("bait_lure")),
		Technique:            parseOptionalString(r.FormValue("technique")),
		WaterType:            parseOptionalString(r.FormValue("water_type")),
		Latitude:             lat,
		Longitude:            lng,
		CaughtAt:             caughtAt,
		Notes:                parseOptionalString(r.FormValue("notes")),
		WeatherTempC:         parseOptionalFloat(r.FormValue("weather_temp_c")),
		WeatherWindSpeedMS:   parseOptionalFloat(r.FormValue("weather_wind_speed_ms")),
		WeatherWindDirection: parseOptionalString(r.FormValue("weather_wind_direction")),
		WeatherPressureHPa:   parseOptionalFloat(r.FormValue("weather_pressure_hpa")),
		WeatherCloudCover:    parseOptionalString(r.FormValue("weather_cloud_cover")),
		WaterTempC:           parseOptionalFloat(r.FormValue("water_temp_c")),
		OwnerSub:             claims.Sub,
		OwnerDisplayName:     firstNonEmpty(claims.PreferredUsername, claims.Name),
		LureID:               lureID,
	}

	var files []*multipart.FileHeader
	if r.MultipartForm != nil {
		files = r.MultipartForm.File["images"]
	}
	for _, fh := range files {
		name, err := h.images.Save(fh)
		if err != nil {
			http.Error(w, fmt.Sprintf("failed to save image: %v", err), http.StatusBadRequest)
			return
		}
		in.ImageFilePaths = append(in.ImageFilePaths, name)
	}

	id, err := h.repo.Create(r.Context(), in)
	if err != nil {
		http.Error(w, "failed to create catch", http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusCreated, map[string]string{"id": id})
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func parseOptionalString(v string) *string {
	if v == "" {
		return nil
	}
	return &v
}

// firstNonEmpty returns a pointer to a, or b if a is empty, or nil if both are.
func firstNonEmpty(a, b string) *string {
	if a != "" {
		return &a
	}
	if b != "" {
		return &b
	}
	return nil
}

func parseOptionalInt(v string) *int {
	if v == "" {
		return nil
	}
	n, err := strconv.Atoi(v)
	if err != nil {
		return nil
	}
	return &n
}

func parseOptionalFloat(v string) *float64 {
	if v == "" {
		return nil
	}
	f, err := strconv.ParseFloat(v, 64)
	if err != nil {
		return nil
	}
	return &f
}

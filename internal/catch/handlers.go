package catch

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"mime/multipart"
	"net/http"
	"strconv"
	"strings"
	"time"

	"swaren.se/fiskekartan/internal/authmw"
)

// ImageStore is satisfied by *imagestore.Store — the one for PhotoPrefix,
// which the public /images route can't reach.
type ImageStore interface {
	Save(fh *multipart.FileHeader) (string, error)
	Delete(filename string) error
	Serve(w http.ResponseWriter, r *http.Request, name string)
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
	photos *PhotoSigner
}

func NewHandlers(repo *Repository, images ImageStore, lures LureVerifier, photos *PhotoSigner) *Handlers {
	return &Handlers{repo: repo, images: images, lures: lures, photos: photos}
}

// List returns the catches the caller may see. Behind requireAuth, like
// every catch route — even public catches are only for logged-in users.
func (h *Handlers) List(w http.ResponseWriter, r *http.Request) {
	sub, _ := authmw.SubFromContext(r.Context())
	var filter ListFilter
	if r.URL.Query().Get("mine") == "true" {
		filter.OwnerSub = &sub
	}
	if v := r.URL.Query().Get("user"); v != "" {
		username := strings.ToLower(v)
		filter.Username = &username
	}

	list, err := h.repo.List(r.Context(), sub, filter)
	if err != nil {
		http.Error(w, "failed to list catches", http.StatusInternalServerError)
		return
	}
	for i := range list {
		if f := list[i].ThumbnailFile; f != nil {
			u := h.photos.URL(*f)
			list[i].Thumbnail = &u
		}
	}
	writeJSON(w, http.StatusOK, list)
}

// Get answers 404 both for a missing catch and one the caller may not see.
func (h *Handlers) Get(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	sub, _ := authmw.SubFromContext(r.Context())
	c, err := h.repo.Get(r.Context(), sub, id)
	if err != nil {
		http.Error(w, "failed to get catch", http.StatusInternalServerError)
		return
	}
	if c == nil {
		http.NotFound(w, r)
		return
	}

	for _, f := range c.ImageFiles {
		c.Images = append(c.Images, h.photos.URL(f))
	}
	resp := CatchResponse{
		Catch:     *c,
		OwnedByMe: c.OwnerSub != nil && sub == *c.OwnerSub,
		HasOwner:  c.OwnerSub != nil,
		LoggedBy:  c.OwnerDisplayName,

		LoggedByUsername: c.OwnerUsername,
	}
	writeJSON(w, http.StatusOK, resp)
}

// SetVisibility handles PUT /api/catches/{id}/visibility, with a JSON body
// like {"visibility": "public"}. Only the owner may change it.
func (h *Handlers) SetVisibility(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	var body struct {
		Visibility string `json:"visibility"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		http.Error(w, "invalid JSON body", http.StatusBadRequest)
		return
	}
	v, ok := ParseVisibility(body.Visibility)
	if !ok {
		http.Error(w, "visibility must be private or public", http.StatusBadRequest)
		return
	}

	claims, _ := authmw.ClaimsFromContext(r.Context())
	c, ok := h.loadOwned(w, r, claims, id, "change visibility of")
	if !ok {
		return
	}
	if err := h.repo.SetVisibility(r.Context(), id, v); err != nil {
		log.Printf("catch: visibility change of catch %s failed for %s: %v", id, claims, err)
		http.Error(w, "failed to change visibility", http.StatusInternalServerError)
		return
	}
	log.Printf("catch: %s changed visibility of catch %s from %s to %s", claims, id, c.Visibility, v)
	w.WriteHeader(http.StatusNoContent)
}

// loadOwned loads a catch the caller is about to change, answering 404 if
// they can't see it and 403 if they can but don't own it. ok is false when
// it has already responded.
func (h *Handlers) loadOwned(w http.ResponseWriter, r *http.Request, claims authmw.Claims, id, action string) (c *Catch, ok bool) {
	c, err := h.repo.Get(r.Context(), claims.Sub, id)
	if err != nil {
		http.Error(w, "failed to load catch", http.StatusInternalServerError)
		return nil, false
	}
	if c == nil {
		http.NotFound(w, r)
		return nil, false
	}
	if c.OwnerSub == nil || *c.OwnerSub != claims.Sub {
		log.Printf("catch: %s denied %s catch %s (not owner)", claims, action, id)
		http.Error(w, fmt.Sprintf("you can only %s your own catches", action), http.StatusForbidden)
		return nil, false
	}
	return c, true
}

func (h *Handlers) Delete(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")

	claims, _ := authmw.ClaimsFromContext(r.Context())
	c, ok := h.loadOwned(w, r, claims, id, "delete")
	if !ok {
		return
	}
	if err := h.repo.Delete(r.Context(), id); err != nil {
		log.Printf("catch: delete of catch %s failed for %s: %v", id, claims, err)
		http.Error(w, "failed to delete catch", http.StatusInternalServerError)
		return
	}
	log.Printf("catch: %s deleted catch %s (species=%q, %d images)", claims, id, c.Species, len(c.ImageFiles))

	for _, filename := range c.ImageFiles {
		if err := h.images.Delete(filename); err != nil {
			log.Printf("failed to delete image file %q for catch %s: %v", filename, id, err)
		}
	}

	w.WriteHeader(http.StatusNoContent)
}

// ServePhoto handles GET /catch-images/{name}, for the signed URLs that
// List and Get hand out (see PhotoSigner). No login needed: the signature
// is the proof the caller may see the catch.
func (h *Handlers) ServePhoto(w http.ResponseWriter, r *http.Request) {
	name := r.PathValue("name")
	q := r.URL.Query()
	if !h.photos.Valid(name, q.Get("exp"), q.Get("sig")) {
		http.Error(w, "invalid or expired photo link", http.StatusForbidden)
		return
	}
	// Private: shared caches mustn't hand it to someone else.
	w.Header().Set("Cache-Control", "private, max-age=86400")
	h.images.Serve(w, r, name)
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

	visibility := VisibilityPrivate
	if v := r.FormValue("visibility"); v != "" {
		parsed, ok := ParseVisibility(v)
		if !ok {
			http.Error(w, "visibility must be private or public", http.StatusBadRequest)
			return
		}
		visibility = parsed
	}

	// Guaranteed present — this route stays behind requireAuth. The owner
	// always comes from the verified token, never a client-supplied field.
	claims, _ := authmw.ClaimsFromContext(r.Context())

	var lureID *string
	if v := r.FormValue("lure_id"); v != "" {
		owned, err := h.lures.OwnedBy(r.Context(), v, claims.Sub)
		if err != nil {
			log.Printf("catch: lure %s ownership check failed for %s: %v", v, claims, err)
			http.Error(w, "failed to verify lure", http.StatusInternalServerError)
			return
		}
		if !owned {
			log.Printf("catch: %s tried to attach lure %s they don't own", claims, v)
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
		Visibility:           visibility,
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
			log.Printf("catch: failed to save image for %s: %v", claims, err)
			http.Error(w, fmt.Sprintf("failed to save image: %v", err), http.StatusBadRequest)
			return
		}
		in.ImageFilePaths = append(in.ImageFilePaths, name)
	}

	id, err := h.repo.Create(r.Context(), in)
	if err != nil {
		log.Printf("catch: create failed for %s: %v", claims, err)
		http.Error(w, "failed to create catch", http.StatusInternalServerError)
		return
	}
	log.Printf("catch: %s created catch %s (species=%q, visibility=%s, %d images)", claims, id, species, visibility, len(in.ImageFilePaths))

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

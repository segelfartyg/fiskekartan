package profile

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log"
	"mime/multipart"
	"net/http"
	"strings"
	"unicode/utf8"

	"swaren.se/fiskekartan/internal/authmw"
)

// ImageStore is satisfied by *imagestore.Store — avatars live in the same
// bucket as catch and lure photos.
type ImageStore interface {
	Save(fh *multipart.FileHeader) (string, error)
	Delete(filename string) error
}

type Handlers struct {
	repo   *Repository
	images ImageStore
}

func NewHandlers(repo *Repository, images ImageStore) *Handlers {
	return &Handlers{repo: repo, images: images}
}

// Get is the public profile lookup behind /{username}.
func (h *Handlers) Get(w http.ResponseWriter, r *http.Request) {
	p, err := h.repo.GetByUsername(r.Context(), strings.ToLower(r.PathValue("username")))
	if err != nil {
		http.Error(w, "failed to get profile", http.StatusInternalServerError)
		return
	}
	if p == nil {
		http.NotFound(w, r)
		return
	}
	writeJSON(w, http.StatusOK, p)
}

// GetMine returns the caller's own profile, creating it on first call (and
// keeping its username in sync) from the token's preferred_username. Always
// behind requireAuth.
func (h *Handlers) GetMine(w http.ResponseWriter, r *http.Request) {
	claims, _ := authmw.ClaimsFromContext(r.Context())
	p, err := h.repo.Ensure(r.Context(), claims.Sub, usernameCandidates(claims))
	if err != nil {
		log.Printf("ensure profile for %s: %v", claims.Sub, err)
		http.Error(w, "failed to load profile", http.StatusInternalServerError)
		return
	}
	writeJSON(w, http.StatusOK, p)
}

func (h *Handlers) UpdateMine(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseMultipartForm(32 << 20); err != nil {
		http.Error(w, "invalid multipart form", http.StatusBadRequest)
		return
	}

	claims, _ := authmw.ClaimsFromContext(r.Context())
	// Makes sure a row exists to update, for a client that skipped GetMine.
	if _, err := h.repo.Ensure(r.Context(), claims.Sub, usernameCandidates(claims)); err != nil {
		http.Error(w, "failed to load profile", http.StatusInternalServerError)
		return
	}

	in := UpdateInput{
		Location:     optionalTrimmed(r.FormValue("location")),
		Description:  optionalTrimmed(r.FormValue("description")),
		PinColor:     optionalTrimmed(strings.ToLower(r.FormValue("pin_color"))),
		RemoveAvatar: r.FormValue("remove_avatar") == "true",
	}
	if in.Location != nil && utf8.RuneCountInString(*in.Location) > maxLocationLen {
		http.Error(w, fmt.Sprintf("location must be at most %d characters", maxLocationLen), http.StatusBadRequest)
		return
	}
	if in.Description != nil && utf8.RuneCountInString(*in.Description) > maxDescriptionLen {
		http.Error(w, fmt.Sprintf("description must be at most %d characters", maxDescriptionLen), http.StatusBadRequest)
		return
	}
	if in.PinColor != nil && !pinColorPattern.MatchString(*in.PinColor) {
		http.Error(w, "pin_color must be a hex color like #10a15a", http.StatusBadRequest)
		return
	}

	if r.MultipartForm != nil {
		if files := r.MultipartForm.File["avatar"]; len(files) > 0 {
			name, err := h.images.Save(files[0])
			if err != nil {
				http.Error(w, fmt.Sprintf("failed to save avatar: %v", err), http.StatusBadRequest)
				return
			}
			in.AvatarFilePath = &name
		}
	}

	oldAvatar, err := h.repo.Update(r.Context(), claims.Sub, in)
	if err != nil {
		if in.AvatarFilePath != nil {
			h.deleteImage(*in.AvatarFilePath)
		}
		log.Printf("update profile for %s: %v", claims.Sub, err)
		http.Error(w, "failed to update profile", http.StatusInternalServerError)
		return
	}
	if oldAvatar != nil {
		h.deleteImage(*oldAvatar)
	}

	p, err := h.repo.GetBySub(r.Context(), claims.Sub)
	if err != nil || p == nil {
		http.Error(w, "failed to load profile", http.StatusInternalServerError)
		return
	}
	writeJSON(w, http.StatusOK, p)
}

func (h *Handlers) deleteImage(name string) {
	if err := h.images.Delete(name); err != nil {
		log.Printf("failed to delete avatar file %q: %v", name, err)
	}
}

// usernameCandidates derives initial usernames to try for a new profile:
// the token's preferred_username (or name) squeezed into the allowed
// charset, then that plus a sub-derived suffix, then a purely sub-derived
// fallback that's effectively guaranteed unique.
func usernameCandidates(claims authmw.Claims) []string {
	sum := sha256.Sum256([]byte(claims.Sub))
	suffix := hex.EncodeToString(sum[:])

	var candidates []string
	base := claims.PreferredUsername
	if base == "" {
		base = claims.Name
	}
	if base, ok := sanitizeUsername(base); ok {
		candidates = append(candidates, base)
		candidates = append(candidates, truncate(base, 25)+"-"+suffix[:4])
	}
	return append(candidates, "angler-"+suffix[:10])
}

// sanitizeUsername maps free-form input (possibly an email address) onto
// the username charset, reporting whether anything usable is left.
func sanitizeUsername(s string) (string, bool) {
	if at := strings.IndexByte(s, '@'); at >= 0 {
		s = s[:at]
	}
	var b strings.Builder
	for _, r := range strings.ToLower(s) {
		switch {
		case r >= 'a' && r <= 'z', r >= '0' && r <= '9', r == '_', r == '-':
			b.WriteRune(r)
		case r == ' ' || r == '.':
			b.WriteByte('-')
		case r == 'å' || r == 'ä':
			b.WriteByte('a')
		case r == 'ö':
			b.WriteByte('o')
		case r == 'é':
			b.WriteByte('e')
		}
	}
	u := truncate(strings.Trim(b.String(), "-_"), 30)
	return u, validUsername(u)
}

func truncate(s string, n int) string {
	if len(s) > n {
		return s[:n]
	}
	return s
}

func optionalTrimmed(v string) *string {
	v = strings.TrimSpace(v)
	if v == "" {
		return nil
	}
	return &v
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

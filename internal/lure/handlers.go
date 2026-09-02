package lure

import (
	"encoding/json"
	"fmt"
	"log"
	"mime/multipart"
	"net/http"

	"swaren.se/fiskekartan/internal/authmw"
)

// ImageStore is satisfied by *imagestore.Store — the same generic
// MinIO-backed store catch photos and the pmtiles basemap already use.
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

// List returns the caller's own lures. Always behind requireAuth, so a sub
// is guaranteed present.
func (h *Handlers) List(w http.ResponseWriter, r *http.Request) {
	sub, _ := authmw.SubFromContext(r.Context())
	list, err := h.repo.List(r.Context(), sub)
	if err != nil {
		http.Error(w, "failed to list lures", http.StatusInternalServerError)
		return
	}
	writeJSON(w, http.StatusOK, list)
}

func (h *Handlers) Create(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseMultipartForm(32 << 20); err != nil {
		http.Error(w, "invalid multipart form", http.StatusBadRequest)
		return
	}

	title := r.FormValue("title")
	if title == "" {
		http.Error(w, "title is required", http.StatusBadRequest)
		return
	}

	var description *string
	if v := r.FormValue("description"); v != "" {
		description = &v
	}

	var imageFilePath *string
	if r.MultipartForm != nil {
		if files := r.MultipartForm.File["image"]; len(files) > 0 {
			name, err := h.images.Save(files[0])
			if err != nil {
				http.Error(w, fmt.Sprintf("failed to save image: %v", err), http.StatusBadRequest)
				return
			}
			imageFilePath = &name
		}
	}

	sub, _ := authmw.SubFromContext(r.Context())
	id, err := h.repo.Create(r.Context(), CreateInput{
		OwnerSub:      sub,
		Title:         title,
		Description:   description,
		ImageFilePath: imageFilePath,
	})
	if err != nil {
		http.Error(w, "failed to create lure", http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusCreated, map[string]string{"id": id})
}

func (h *Handlers) Delete(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	sub, _ := authmw.SubFromContext(r.Context())

	imagePath, deleted, err := h.repo.Delete(r.Context(), id, sub)
	if err != nil {
		http.Error(w, "failed to delete lure", http.StatusInternalServerError)
		return
	}
	if !deleted {
		// Never distinguishes "doesn't exist" from "belongs to someone
		// else" — both look like a 404 to the caller.
		http.NotFound(w, r)
		return
	}

	if imagePath != nil {
		if err := h.images.Delete(*imagePath); err != nil {
			log.Printf("failed to delete lure image file %q for lure %s: %v", *imagePath, id, err)
		}
	}

	w.WriteHeader(http.StatusNoContent)
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

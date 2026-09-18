// Package weather exposes SMHI's best-effort current conditions over HTTP,
// for pre-filling a catch's weather/water fields from its location.
package weather

import (
	"context"
	"encoding/json"
	"net/http"
	"strconv"

	"swaren.se/fiskekartan/internal/smhi"
)

// Client is satisfied by *smhi.Client.
type Client interface {
	Get(ctx context.Context, lat, lon float64) smhi.Weather
}

type Handlers struct {
	client Client
}

func NewHandlers(client Client) *Handlers {
	return &Handlers{client: client}
}

// Get handles GET /api/weather?lat=&lon=, returning whatever SMHI has for
// that point. No auth required — it's a passthrough for public data with no
// user-specific content.
func (h *Handlers) Get(w http.ResponseWriter, r *http.Request) {
	lat, err := strconv.ParseFloat(r.URL.Query().Get("lat"), 64)
	if err != nil {
		http.Error(w, "lat is required and must be a number", http.StatusBadRequest)
		return
	}
	lon, err := strconv.ParseFloat(r.URL.Query().Get("lon"), 64)
	if err != nil {
		http.Error(w, "lon is required and must be a number", http.StatusBadRequest)
		return
	}

	data := h.client.Get(r.Context(), lat, lon)
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(data)
}

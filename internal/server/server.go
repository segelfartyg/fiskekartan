package server

import (
	"errors"
	"io/fs"
	"net/http"
	"strings"

	"github.com/coreos/go-oidc/v3/oidc"
	"github.com/jackc/pgx/v5/pgxpool"
	"swaren.se/fiskekartan/internal/authmw"
	"swaren.se/fiskekartan/internal/catch"
	"swaren.se/fiskekartan/internal/imagestore"
	"swaren.se/fiskekartan/internal/lure"
	"swaren.se/fiskekartan/internal/profile"
	"swaren.se/fiskekartan/internal/smhi"
	"swaren.se/fiskekartan/internal/weather"
)

// New builds the full HTTP handler: the JSON API, image/tile serving, and
// the embedded Svelte frontend.
func New(pool *pgxpool.Pool, imgStore *imagestore.Store, photoSigner *catch.PhotoSigner, verifier *oidc.IDTokenVerifier, webDist fs.FS) (http.Handler, error) {
	lureRepo := lure.NewRepository(pool)
	lureHandlers := lure.NewHandlers(lureRepo, imgStore)

	repo := catch.NewRepository(pool)
	handlers := catch.NewHandlers(repo, imgStore.WithPrefix(catch.PhotoPrefix), lureRepo, photoSigner)

	profileHandlers := profile.NewHandlers(profile.NewRepository(pool), imgStore)

	weatherHandlers := weather.NewHandlers(smhi.NewClient())

	requireAuth := authmw.RequireAuth(verifier)

	mux := http.NewServeMux()

	// Catches are only ever shown to logged-in users, filtered by their
	// visibility (see catch.visibleTo).
	mux.HandleFunc("GET /api/catches", withMiddleware(requireAuth(handlers.List)))
	mux.HandleFunc("GET /api/catches/{id}", withMiddleware(requireAuth(handlers.Get)))
	mux.HandleFunc("POST /api/catches", withMiddleware(requireAuth(handlers.Create)))
	mux.HandleFunc("PUT /api/catches/{id}/visibility", withMiddleware(requireAuth(handlers.SetVisibility)))
	mux.HandleFunc("DELETE /api/catches/{id}", withMiddleware(requireAuth(handlers.Delete)))

	mux.HandleFunc("GET /api/lures", withMiddleware(requireAuth(lureHandlers.List)))
	mux.HandleFunc("POST /api/lures", withMiddleware(requireAuth(lureHandlers.Create)))
	mux.HandleFunc("DELETE /api/lures/{id}", withMiddleware(requireAuth(lureHandlers.Delete)))

	mux.HandleFunc("GET /api/profiles/{username}", withMiddleware(profileHandlers.Get))
	mux.HandleFunc("GET /api/me/profile", withMiddleware(requireAuth(profileHandlers.GetMine)))
	mux.HandleFunc("PUT /api/me/profile", withMiddleware(requireAuth(profileHandlers.UpdateMine)))

	mux.HandleFunc("GET /api/weather", withMiddleware(weatherHandlers.Get))

	// Proxied through the backend (rather than presigned MinIO URLs) so the
	// object store never needs to be reachable from the browser. Avatars,
	// lure photos and the map tile file sit at the bucket root and are
	// public; catch photos sit under catch.PhotoPrefix and need a signed URL.
	serveRoot := func(w http.ResponseWriter, r *http.Request) {
		imgStore.Serve(w, r, r.PathValue("name"))
	}
	mux.HandleFunc("GET /images/{name}", withMiddleware(serveRoot))
	mux.HandleFunc("GET /tiles/{name}", withMiddleware(serveRoot))
	mux.HandleFunc("GET /catch-images/{name}", withMiddleware(handlers.ServePhoto))

	mux.Handle("GET /", spaHandler(webDist))

	return mux, nil
}

// spaHandler serves the built frontend, falling back to index.html for any
// path that isn't a real file — that's how client-side routes like the
// public profile page at /{username} load the app on a direct visit.
func spaHandler(webDist fs.FS) http.Handler {
	files := http.FileServer(http.FS(webDist))
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		name := strings.TrimPrefix(r.URL.Path, "/")
		if name != "" {
			if _, err := fs.Stat(webDist, name); errors.Is(err, fs.ErrNotExist) && !strings.HasPrefix(name, "assets/") {
				// Missing hashed assets still 404, rather than handing a
				// stale-bundle browser HTML where it expects JS.
				http.ServeFileFS(w, r, webDist, "index.html")
				return
			}
		}
		files.ServeHTTP(w, r)
	})
}

// withMiddleware is a no-op passthrough applied to every route (auth-gated
// or not) — a seam for cross-cutting concerns like logging, added later.
func withMiddleware(h http.HandlerFunc) http.HandlerFunc {
	return h
}

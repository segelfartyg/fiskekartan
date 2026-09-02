package server

import (
	"io/fs"
	"net/http"

	"github.com/coreos/go-oidc/v3/oidc"
	"github.com/jackc/pgx/v5/pgxpool"
	"swaren.se/fiskekartan/internal/authmw"
	"swaren.se/fiskekartan/internal/catch"
	"swaren.se/fiskekartan/internal/imagestore"
	"swaren.se/fiskekartan/internal/lure"
)

// New builds the full HTTP handler: the JSON API, image/tile serving, and
// the embedded Svelte frontend.
func New(pool *pgxpool.Pool, imgStore *imagestore.Store, verifier *oidc.IDTokenVerifier, webDist fs.FS) (http.Handler, error) {
	lureRepo := lure.NewRepository(pool)
	lureHandlers := lure.NewHandlers(lureRepo, imgStore)

	repo := catch.NewRepository(pool)
	handlers := catch.NewHandlers(repo, imgStore, lureRepo)

	requireAuth := authmw.RequireAuth(verifier)
	optionalAuth := authmw.OptionalAuth(verifier)

	mux := http.NewServeMux()

	mux.HandleFunc("GET /api/catches", withMiddleware(optionalAuth(handlers.List)))
	mux.HandleFunc("GET /api/catches/{id}", withMiddleware(optionalAuth(handlers.Get)))
	mux.HandleFunc("POST /api/catches", withMiddleware(requireAuth(handlers.Create)))
	mux.HandleFunc("DELETE /api/catches/{id}", withMiddleware(requireAuth(handlers.Delete)))

	mux.HandleFunc("GET /api/lures", withMiddleware(requireAuth(lureHandlers.List)))
	mux.HandleFunc("POST /api/lures", withMiddleware(requireAuth(lureHandlers.Create)))
	mux.HandleFunc("DELETE /api/lures/{id}", withMiddleware(requireAuth(lureHandlers.Delete)))

	// Proxied through the backend (rather than presigned MinIO URLs) so the
	// object store never needs to be reachable from the browser. The same
	// handler serves both — it's just generic bucket-object streaming, and
	// the map tile file lives in the same bucket as photos.
	mux.HandleFunc("GET /images/{name}", withMiddleware(handlers.ServeImage))
	mux.HandleFunc("GET /tiles/{name}", withMiddleware(handlers.ServeImage))

	mux.Handle("GET /", http.FileServer(http.FS(webDist)))

	return mux, nil
}

// withMiddleware is a no-op passthrough applied to every route (auth-gated
// or not) — a seam for cross-cutting concerns like logging, added later.
func withMiddleware(h http.HandlerFunc) http.HandlerFunc {
	return h
}

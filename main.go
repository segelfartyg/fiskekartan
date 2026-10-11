package main

import (
	"context"
	"crypto/rand"
	"embed"
	"io/fs"
	"log"
	"net/http"
	"os"

	"github.com/coreos/go-oidc/v3/oidc"
	"github.com/joho/godotenv"
	"swaren.se/fiskekartan/internal/catch"
	"swaren.se/fiskekartan/internal/db"
	"swaren.se/fiskekartan/internal/imagestore"
	"swaren.se/fiskekartan/internal/server"
)

//go:embed web/dist
var webDistFS embed.FS

func main() {
	// Loads .env into the process environment for local `go run .`; a
	// missing file is expected (and fine) under Docker, where compose
	// injects the environment directly.
	_ = godotenv.Load()

	ctx := context.Background()

	pool, err := db.Connect(ctx, mustEnv("DATABASE_URL"))
	if err != nil {
		log.Fatalf("connect to database: %v", err)
	}
	defer pool.Close()

	if err := db.Migrate(ctx, pool); err != nil {
		log.Fatalf("run migrations: %v", err)
	}

	imgStore, err := imagestore.New(
		mustEnv("MINIO_ENDPOINT"),
		mustEnv("MINIO_ACCESS_KEY"),
		mustEnv("MINIO_SECRET_KEY"),
		envOrDefault("MINIO_BUCKET", "fiskekartan-images"),
		envOrDefault("MINIO_USE_SSL", "false") == "true",
	)
	if err != nil {
		log.Fatalf("connect to image store: %v", err)
	}

	if err := catch.MovePhotos(ctx, catch.NewRepository(pool), imgStore, imgStore.WithPrefix(catch.PhotoPrefix)); err != nil {
		log.Fatalf("move catch photos: %v", err)
	}

	oidcProvider, err := oidc.NewProvider(ctx, mustEnv("OIDC_ISSUER_URL"))
	if err != nil {
		log.Fatalf("connect to OIDC issuer: %v", err)
	}
	verifier := oidcProvider.Verifier(&oidc.Config{ClientID: mustEnv("OIDC_AUDIENCE")})

	webDist, err := fs.Sub(webDistFS, "web/dist")
	if err != nil {
		log.Fatalf("load embedded frontend: %v", err)
	}

	srv, err := server.New(
		pool,
		imgStore,
		catch.NewPhotoSigner(photoSigningKey()),
		verifier,
		webDist,
	)
	if err != nil {
		log.Fatalf("build server: %v", err)
	}

	addr := envOrDefault("ADDR", ":8080")
	log.Printf("fiskekartan listening on %s", addr)
	if err := http.ListenAndServe(addr, srv); err != nil {
		log.Fatal(err)
	}
}

// photoSigningKey is the key catch photo URLs are signed with. Without
// CATCH_PHOTO_SIGNING_KEY a random one is used, which works for a single
// replica but breaks the photo links clients already hold on every restart.
func photoSigningKey() []byte {
	if v := os.Getenv("CATCH_PHOTO_SIGNING_KEY"); v != "" {
		return []byte(v)
	}
	log.Printf("CATCH_PHOTO_SIGNING_KEY not set, using a random key: photo links break on restart")
	return []byte(rand.Text())
}

func envOrDefault(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func mustEnv(key string) string {
	v := os.Getenv(key)
	if v == "" {
		log.Fatalf("%s is required", key)
	}
	return v
}

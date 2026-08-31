// Package authmw gates write endpoints behind a valid Keycloak-issued bearer
// token, while leaving read endpoints untouched.
package authmw

import (
	"log"
	"net/http"
	"strings"

	"github.com/coreos/go-oidc/v3/oidc"
)

// RequireAuth wraps h so it only runs when the request carries a valid
// "Authorization: Bearer <token>" header, verified against verifier (issuer,
// audience, signature, and expiry are all checked by verifier.Verify).
func RequireAuth(verifier *oidc.IDTokenVerifier) func(http.HandlerFunc) http.HandlerFunc {
	return func(h http.HandlerFunc) http.HandlerFunc {
		return func(w http.ResponseWriter, r *http.Request) {
			token, ok := bearerToken(r)
			if !ok {
				http.Error(w, "authentication required", http.StatusUnauthorized)
				return
			}

			if _, err := verifier.Verify(r.Context(), token); err != nil {
				log.Printf("auth: token verification failed: %v", err)
				http.Error(w, "invalid or expired token", http.StatusUnauthorized)
				return
			}

			h(w, r)
		}
	}
}

func bearerToken(r *http.Request) (string, bool) {
	header := r.Header.Get("Authorization")
	const prefix = "Bearer "
	if !strings.HasPrefix(header, prefix) {
		return "", false
	}
	token := strings.TrimSpace(strings.TrimPrefix(header, prefix))
	if token == "" {
		return "", false
	}
	return token, true
}

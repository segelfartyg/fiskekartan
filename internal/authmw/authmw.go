// Package authmw gates write endpoints behind a valid Keycloak-issued bearer
// token, while leaving read endpoints untouched.
package authmw

import (
	"context"
	"log"
	"net/http"
	"strings"

	"github.com/coreos/go-oidc/v3/oidc"
)

// Claims are the token claims handlers care about. PreferredUsername and
// Name are best-effort — this realm isn't guaranteed to map them (unlike
// Sub, a standard OIDC claim always present).
type Claims struct {
	Sub               string `json:"sub"`
	PreferredUsername string `json:"preferred_username"`
	Name              string `json:"name"`
}

type contextKey int

const claimsContextKey contextKey = iota

// ClaimsFromContext returns the verified claims injected by RequireAuth or
// OptionalAuth, if any were (ok is false for an anonymous request).
func ClaimsFromContext(ctx context.Context) (Claims, bool) {
	claims, ok := ctx.Value(claimsContextKey).(Claims)
	return claims, ok
}

// SubFromContext is a convenience wrapper around ClaimsFromContext for the
// common case of only needing the subject.
func SubFromContext(ctx context.Context) (string, bool) {
	claims, ok := ClaimsFromContext(ctx)
	if !ok {
		return "", false
	}
	return claims.Sub, true
}

// RequireAuth wraps h so it only runs when the request carries a valid
// "Authorization: Bearer <token>" header, verified against verifier (issuer,
// audience, signature, and expiry are all checked by verifier.Verify). The
// verified claims are injected into the request context for h to read via
// ClaimsFromContext/SubFromContext.
func RequireAuth(verifier *oidc.IDTokenVerifier) func(http.HandlerFunc) http.HandlerFunc {
	return func(h http.HandlerFunc) http.HandlerFunc {
		return func(w http.ResponseWriter, r *http.Request) {
			token, ok := bearerToken(r)
			if !ok {
				http.Error(w, "authentication required", http.StatusUnauthorized)
				return
			}

			idToken, err := verifier.Verify(r.Context(), token)
			if err != nil {
				log.Printf("auth: token verification failed: %v", err)
				http.Error(w, "invalid or expired token", http.StatusUnauthorized)
				return
			}

			var claims Claims
			if err := idToken.Claims(&claims); err != nil {
				log.Printf("auth: failed to parse claims: %v", err)
				http.Error(w, "invalid token claims", http.StatusUnauthorized)
				return
			}

			h(w, r.WithContext(context.WithValue(r.Context(), claimsContextKey, claims)))
		}
	}
}

// OptionalAuth wraps h so that a valid bearer token's claims are made
// available via ClaimsFromContext/SubFromContext, without ever requiring
// one — h always runs. A missing token runs h anonymously; an invalid or
// expired one fails open (logged, then treated as anonymous) rather than
// rejecting the request, so a stale token sitting in the browser can never
// break a read that would otherwise work fine. Intended for read endpoints
// that adjust their response based on who's asking, but must stay reachable
// by anyone.
func OptionalAuth(verifier *oidc.IDTokenVerifier) func(http.HandlerFunc) http.HandlerFunc {
	return func(h http.HandlerFunc) http.HandlerFunc {
		return func(w http.ResponseWriter, r *http.Request) {
			token, ok := bearerToken(r)
			if !ok {
				h(w, r)
				return
			}

			idToken, err := verifier.Verify(r.Context(), token)
			if err != nil {
				log.Printf("auth: optional token verification failed, continuing anonymously: %v", err)
				h(w, r)
				return
			}

			var claims Claims
			if err := idToken.Claims(&claims); err != nil {
				log.Printf("auth: optional token claims parse failed, continuing anonymously: %v", err)
				h(w, r)
				return
			}

			h(w, r.WithContext(context.WithValue(r.Context(), claimsContextKey, claims)))
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

package catch

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"log"
	"net/url"
	"strconv"
	"time"

	"swaren.se/fiskekartan/internal/imagestore"
)

// PhotoPrefix is where catch photos live in the bucket, apart from the
// avatars, lure photos and map tiles that GET /images serves to anyone.
const PhotoPrefix = "catches/"

// PhotoSigner hands out URLs for catch photos that only work with a valid,
// unexpired signature. A plain <img src> can't send a bearer token, so
// instead the API signs each photo URL in the responses of whoever may see
// the catch, and GET /catch-images checks the signature.
type PhotoSigner struct {
	key []byte
	now func() time.Time
}

func NewPhotoSigner(key []byte) *PhotoSigner {
	return &PhotoSigner{key: key, now: time.Now}
}

// URL returns the signed URL for a photo's object name. The expiry is
// rounded to the day, so a photo's URL stays the same for a day and
// browsers can cache it, while it always has at least a day left.
func (s *PhotoSigner) URL(name string) string {
	exp := strconv.FormatInt(s.now().UTC().Truncate(24*time.Hour).Add(48*time.Hour).Unix(), 10)
	q := url.Values{"exp": {exp}, "sig": {s.sign(name, exp)}}
	return "/catch-images/" + url.PathEscape(name) + "?" + q.Encode()
}

// Valid reports whether sig is a signature URL issued for name and exp,
// and exp hasn't passed.
func (s *PhotoSigner) Valid(name, exp, sig string) bool {
	expUnix, err := strconv.ParseInt(exp, 10, 64)
	if err != nil || s.now().Unix() > expUnix {
		return false
	}
	return hmac.Equal([]byte(sig), []byte(s.sign(name, exp)))
}

func (s *PhotoSigner) sign(name, exp string) string {
	mac := hmac.New(sha256.New, s.key)
	mac.Write([]byte(name + "\n" + exp))
	return base64.RawURLEncoding.EncodeToString(mac.Sum(nil))
}

// MovePhotos moves catch photos saved before PhotoPrefix existed from the
// bucket root into photos. Already-moved photos are skipped, so it's safe
// to run on every start; it can be removed once it has run in production.
func MovePhotos(ctx context.Context, repo *Repository, root, photos *imagestore.Store) error {
	names, err := repo.AllImageFiles(ctx)
	if err != nil {
		return err
	}
	for _, name := range names {
		if err := photos.MoveIn(ctx, root, name); err != nil {
			log.Printf("catch: failed to move photo %q into %s: %v", name, PhotoPrefix, err)
		}
	}
	return nil
}

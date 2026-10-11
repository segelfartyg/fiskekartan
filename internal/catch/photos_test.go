package catch

import (
	"net/url"
	"strings"
	"testing"
	"time"
)

func TestPhotoSigner(t *testing.T) {
	now := time.Date(2026, 10, 11, 15, 0, 0, 0, time.UTC)
	s := NewPhotoSigner([]byte("test-key"))
	s.now = func() time.Time { return now }

	u, err := url.Parse(s.URL("abc.jpg"))
	if err != nil {
		t.Fatal(err)
	}
	if u.Path != "/catch-images/abc.jpg" {
		t.Fatalf("path = %q", u.Path)
	}
	exp, sig := u.Query().Get("exp"), u.Query().Get("sig")

	if !s.Valid("abc.jpg", exp, sig) {
		t.Error("own signature rejected")
	}
	if s.Valid("other.jpg", exp, sig) {
		t.Error("signature accepted for another photo")
	}
	if s.Valid("abc.jpg", exp+"0", sig) {
		t.Error("signature accepted with a changed expiry")
	}
	if NewPhotoSigner([]byte("other-key")).Valid("abc.jpg", exp, sig) {
		t.Error("signature accepted under another key")
	}

	// Stable for the rest of the day, so browsers can cache it.
	s.now = func() time.Time { return now.Add(8 * time.Hour) }
	if again := s.URL("abc.jpg"); !strings.HasSuffix(again, u.RawQuery) {
		t.Errorf("URL changed within the day: %q vs %q", again, u.RawQuery)
	}

	s.now = func() time.Time { return now.Add(34 * time.Hour) }
	if s.Valid("abc.jpg", exp, sig) {
		t.Error("expired signature accepted")
	}
}

package profile

import (
	"regexp"
	"strings"
	"time"
)

// Profile is the public view of a user — everything here is visible to
// anyone at /{username}. The owning sub is never serialized.
type Profile struct {
	Username    string    `json:"username"`
	Location    *string   `json:"location,omitempty"`
	Description *string   `json:"description,omitempty"`
	Avatar      *string   `json:"avatar,omitempty"`
	PinColor    *string   `json:"pin_color,omitempty"`
	CatchCount  int       `json:"catch_count"`
	CreatedAt   time.Time `json:"created_at"`

	Sub            string  `json:"-"`
	AvatarFilePath *string `json:"-"`
}

// UpdateInput holds the user-editable fields. The username isn't one of
// them — it always mirrors the OAuth login's preferred_username (see
// Repository.Ensure).
type UpdateInput struct {
	Location       *string
	Description    *string
	PinColor       *string
	AvatarFilePath *string
	// RemoveAvatar clears the avatar when AvatarFilePath is nil; otherwise
	// a nil AvatarFilePath leaves the existing avatar untouched.
	RemoveAvatar bool
}

// describe summarizes an update for logging — which fields are set, never
// their (user-written) contents.
func (in UpdateInput) describe() string {
	var fields []string
	if in.Location != nil {
		fields = append(fields, "location")
	}
	if in.Description != nil {
		fields = append(fields, "description")
	}
	if in.PinColor != nil {
		fields = append(fields, "pin_color="+*in.PinColor)
	}
	switch {
	case in.AvatarFilePath != nil:
		fields = append(fields, "avatar=new")
	case in.RemoveAvatar:
		fields = append(fields, "avatar=removed")
	}
	if len(fields) == 0 {
		return "[none]"
	}
	return "[" + strings.Join(fields, ",") + "]"
}

const (
	maxLocationLen    = 100
	maxDescriptionLen = 1000
)

var (
	usernamePattern = regexp.MustCompile(`^[a-z0-9_-]{3,30}$`)
	pinColorPattern = regexp.MustCompile(`^#[0-9a-f]{6}$`)
)

// reservedUsernames can't be claimed, since /{username} shares the URL
// space with the backend's own top-level routes and static assets. Anything
// containing a dot (index.html, favicon.svg, ...) is already excluded by
// usernamePattern.
var reservedUsernames = map[string]bool{
	"api":     true,
	"images":  true,
	"tiles":   true,
	"assets":  true,
	"me":      true,
	"profile": true,
	"login":   true,
	"logout":  true,
	"admin":   true,
}

func validUsername(u string) bool {
	return usernamePattern.MatchString(u) && !reservedUsernames[u]
}

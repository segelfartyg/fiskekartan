package lure

import "time"

type Lure struct {
	ID          string    `json:"id"`
	Title       string    `json:"title"`
	Description *string   `json:"description,omitempty"`
	Image       *string   `json:"image,omitempty"`
	CreatedAt   time.Time `json:"created_at"`
}

type CreateInput struct {
	OwnerSub      string
	Title         string
	Description   *string
	ImageFilePath *string
}

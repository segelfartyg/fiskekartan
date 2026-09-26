package catch

import "time"

type Catch struct {
	ID                   string    `json:"id"`
	Species              string    `json:"species"`
	WeightGrams          *int      `json:"weight_grams,omitempty"`
	LengthCM             *float64  `json:"length_cm,omitempty"`
	BaitLure             *string   `json:"bait_lure,omitempty"`
	Technique            *string   `json:"technique,omitempty"`
	WaterType            *string   `json:"water_type,omitempty"`
	Latitude             float64   `json:"latitude"`
	Longitude            float64   `json:"longitude"`
	CaughtAt             time.Time `json:"caught_at"`
	Notes                *string   `json:"notes,omitempty"`
	WeatherTempC         *float64  `json:"weather_temp_c,omitempty"`
	WeatherWindSpeedMS   *float64  `json:"weather_wind_speed_ms,omitempty"`
	WeatherWindDirection *string   `json:"weather_wind_direction,omitempty"`
	WeatherPressureHPa   *float64  `json:"weather_pressure_hpa,omitempty"`
	WeatherCloudCover    *string   `json:"weather_cloud_cover,omitempty"`
	WaterTempC           *float64  `json:"water_temp_c,omitempty"`
	CreatedAt            time.Time `json:"created_at"`
	UpdatedAt            time.Time `json:"updated_at"`
	Images               []string  `json:"images,omitempty"`

	// Raw ownership fields — never serialized directly. Get responds with
	// CatchResponse instead, which derives what the viewer is actually
	// allowed to see from these.
	OwnerSub         *string `json:"-"`
	OwnerDisplayName *string `json:"-"`
	OwnerUsername    *string `json:"-"`
	LureID           *string `json:"-"`
}

// CatchResponse is what GET /api/catches/{id} actually returns: the raw
// Catch plus fields derived relative to the requesting viewer, so a raw
// owner_sub is never exposed over HTTP.
type CatchResponse struct {
	Catch
	OwnedByMe bool    `json:"owned_by_me"`
	HasOwner  bool    `json:"has_owner"`
	LoggedBy  *string `json:"logged_by,omitempty"`
	// LoggedByUsername links to the owner's public profile, when they have
	// one.
	LoggedByUsername *string `json:"logged_by_username,omitempty"`
}

// CatchSummary is the lightweight shape used for map pins.
type CatchSummary struct {
	ID        string    `json:"id"`
	Species   string    `json:"species"`
	Latitude  float64   `json:"latitude"`
	Longitude float64   `json:"longitude"`
	CaughtAt  time.Time `json:"caught_at"`
	Thumbnail *string   `json:"thumbnail,omitempty"`
	// PinColor is the owner's chosen map pin color, if they've set one.
	PinColor *string `json:"pin_color,omitempty"`
}

// ListFilter restricts List to one owner, by sub or by profile username.
// Both nil means everyone's catches.
type ListFilter struct {
	OwnerSub *string
	Username *string
}

type CreateInput struct {
	Species              string
	WeightGrams          *int
	LengthCM             *float64
	BaitLure             *string
	Technique            *string
	WaterType            *string
	Latitude             float64
	Longitude            float64
	CaughtAt             time.Time
	Notes                *string
	WeatherTempC         *float64
	WeatherWindSpeedMS   *float64
	WeatherWindDirection *string
	WeatherPressureHPa   *float64
	WeatherCloudCover    *string
	WaterTempC           *float64
	ImageFilePaths       []string
	OwnerSub             string
	OwnerDisplayName     *string
	LureID               *string
}

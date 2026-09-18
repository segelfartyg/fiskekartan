// Package smhi looks up current weather and sea temperature from SMHI's
// public open data APIs, for pre-filling a catch's conditions from its
// location. Every lookup is best-effort: SMHI's forecast grid and its ~44
// coastal observation stations don't cover every point in (and around)
// Sweden, so a miss is reported as a nil field, never an error — the catch
// form stays fillable by hand either way.
package smhi

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"math"
	"net/http"
	"time"
)

// Weather mirrors the catch package's weather/water fields so handlers can
// pass it straight through to the frontend.
type Weather struct {
	AirTempC      *float64 `json:"weather_temp_c,omitempty"`
	WindSpeedMS   *float64 `json:"weather_wind_speed_ms,omitempty"`
	WindDirection *string  `json:"weather_wind_direction,omitempty"`
	PressureHPa   *float64 `json:"weather_pressure_hpa,omitempty"`
	CloudCover    *string  `json:"weather_cloud_cover,omitempty"`
	WaterTempC    *float64 `json:"water_temp_c,omitempty"`
}

const (
	// snow1g replaced pmp3g (retired 2026-03-31) as SMHI's high-resolution
	// point forecast; same host and URL shape, renamed category.
	forecastURLFormat = "https://opendata-download-metfcst.smhi.se/api/category/snow1g/version/1/geotype/point/lon/%.6f/lat/%.6f/data.json"

	// Parameter 5 is "Havstemperatur" (sea temperature, °C). latest-day
	// gives ~40 reporting coastal stations at once; latest-hour often has
	// under 10.
	seaTempURL = "https://opendata-download-ocobs.smhi.se/api/version/1.0/parameter/5/station-set/all/period/latest-day/data.json"

	// Stations are coastal only; beyond this a "nearest" match is more
	// likely to mislead than help (an inland lake catch, say).
	maxSeaStationDistanceKM = 50.0
)

type Client struct {
	http *http.Client
}

func NewClient() *Client {
	return &Client{http: &http.Client{Timeout: 10 * time.Second}}
}

// Get returns whatever SMHI has for the given coordinates right now.
// Lookup failures are logged and leave the corresponding fields nil rather
// than failing the request.
func (c *Client) Get(ctx context.Context, lat, lon float64) Weather {
	w := Weather{}

	if fc, err := c.forecast(ctx, lat, lon); err != nil {
		log.Printf("smhi: forecast lookup for (%.4f, %.4f) failed: %v", lat, lon, err)
	} else {
		w = *fc
	}

	if wt, err := c.seaTemp(ctx, lat, lon); err != nil {
		log.Printf("smhi: sea temperature lookup for (%.4f, %.4f) failed: %v", lat, lon, err)
	} else {
		w.WaterTempC = wt
	}

	return w
}

type forecastResponse struct {
	TimeSeries []struct {
		Data map[string]float64 `json:"data"`
	} `json:"timeSeries"`
}

// forecast fetches the nearest forecast grid point and reads off its first
// (i.e. current-hour) time step.
func (c *Client) forecast(ctx context.Context, lat, lon float64) (*Weather, error) {
	url := fmt.Sprintf(forecastURLFormat, lon, lat)
	var body forecastResponse
	if err := c.getJSON(ctx, url, &body); err != nil {
		return nil, err
	}
	if len(body.TimeSeries) == 0 {
		return nil, fmt.Errorf("smhi forecast: no timeSeries entries")
	}

	data := body.TimeSeries[0].Data
	w := &Weather{}
	if v, ok := data["air_temperature"]; ok {
		w.AirTempC = ptr(round1(v))
	}
	if v, ok := data["wind_speed"]; ok {
		w.WindSpeedMS = ptr(round1(v))
	}
	if v, ok := data["wind_from_direction"]; ok {
		dir := compassDirection(v)
		w.WindDirection = &dir
	}
	if v, ok := data["air_pressure_at_mean_sea_level"]; ok {
		w.PressureHPa = ptr(round1(v))
	}
	if v, ok := data["cloud_area_fraction"]; ok {
		cover := cloudCoverLabel(v)
		w.CloudCover = &cover
	}
	return w, nil
}

type seaTempResponse struct {
	Station []struct {
		Latitude  float64 `json:"latitude"`
		Longitude float64 `json:"longitude"`
		Value     []struct {
			Value float64 `json:"value"`
		} `json:"value"`
	} `json:"station"`
}

// seaTemp returns the latest reading from whichever reporting coastal
// station sits nearest (lat, lon), or nil if none is within range.
func (c *Client) seaTemp(ctx context.Context, lat, lon float64) (*float64, error) {
	var body seaTempResponse
	if err := c.getJSON(ctx, seaTempURL, &body); err != nil {
		return nil, err
	}

	var best *float64
	bestDistKM := math.Inf(1)
	for _, s := range body.Station {
		if len(s.Value) == 0 {
			continue
		}
		if d := haversineKM(lat, lon, s.Latitude, s.Longitude); d < bestDistKM {
			bestDistKM = d
			v := s.Value[len(s.Value)-1].Value
			best = &v
		}
	}
	if best == nil || bestDistKM > maxSeaStationDistanceKM {
		return nil, nil
	}
	return best, nil
}

func (c *Client) getJSON(ctx context.Context, url string, out any) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return err
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("unexpected status %d from %s", resp.StatusCode, url)
	}
	return json.NewDecoder(resp.Body).Decode(out)
}

// compassDirection converts a "wind from" bearing in degrees to an 8-point
// compass label, matching the style of the form's manual-entry placeholder.
func compassDirection(deg float64) string {
	dirs := [8]string{"N", "NE", "E", "SE", "S", "SW", "W", "NW"}
	idx := int(math.Round(deg/45.0)) % 8
	if idx < 0 {
		idx += 8
	}
	return dirs[idx]
}

// cloudCoverLabel maps SMHI's okta (eighths-of-sky-covered, 0-8) cloud cover
// to the free-text style already used for manual entry.
func cloudCoverLabel(oktas float64) string {
	switch {
	case oktas <= 0:
		return "clear"
	case oktas <= 2:
		return "mostly clear"
	case oktas <= 5:
		return "partly cloudy"
	case oktas <= 7:
		return "mostly cloudy"
	default:
		return "overcast"
	}
}

func haversineKM(lat1, lon1, lat2, lon2 float64) float64 {
	const earthRadiusKM = 6371.0
	toRad := func(d float64) float64 { return d * math.Pi / 180 }

	dLat := toRad(lat2 - lat1)
	dLon := toRad(lon2 - lon1)
	a := math.Sin(dLat/2)*math.Sin(dLat/2) +
		math.Cos(toRad(lat1))*math.Cos(toRad(lat2))*math.Sin(dLon/2)*math.Sin(dLon/2)
	return earthRadiusKM * 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))
}

func round1(v float64) float64 { return math.Round(v*10) / 10 }

func ptr[T any](v T) *T { return &v }

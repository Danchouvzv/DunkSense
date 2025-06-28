package metrics

import (
	"time"
)

// JumpMetric represents a single jump measurement
type JumpMetric struct {
	ID               string    `json:"id" bson:"_id"`
	AthleteID        string    `json:"athlete_id" bson:"athlete_id"`
	SessionID        string    `json:"session_id" bson:"session_id"`
	Timestamp        time.Time `json:"timestamp" bson:"timestamp"`
	
	// Core jump metrics
	HeightCm         float64   `json:"height_cm" bson:"height_cm"`
	ContactTimeMs    int       `json:"contact_time_ms" bson:"contact_time_ms"`
	FlightTimeMs     int       `json:"flight_time_ms" bson:"flight_time_ms"`
	
	// Biomechanical analysis
	ValgusAngleDeg   float64   `json:"valgus_angle_deg" bson:"valgus_angle_deg"`
	KneeFlexionDeg   float64   `json:"knee_flexion_deg" bson:"knee_flexion_deg"`
	HipFlexionDeg    float64   `json:"hip_flexion_deg" bson:"hip_flexion_deg"`
	
	// Technique scores (0-100)
	TakeoffScore     int       `json:"takeoff_score" bson:"takeoff_score"`
	LandingScore     int       `json:"landing_score" bson:"landing_score"`
	OverallScore     int       `json:"overall_score" bson:"overall_score"`
	
	// Device and processing info
	DeviceType       string    `json:"device_type" bson:"device_type"`
	AppVersion       string    `json:"app_version" bson:"app_version"`
	ProcessingTimeMs int       `json:"processing_time_ms" bson:"processing_time_ms"`
	Confidence       float64   `json:"confidence" bson:"confidence"`
	
	// Additional metadata
	Location         *Location `json:"location,omitempty" bson:"location,omitempty"`
	Weather          *Weather  `json:"weather,omitempty" bson:"weather,omitempty"`
	Notes            string    `json:"notes,omitempty" bson:"notes,omitempty"`
}

// Location represents GPS coordinates
type Location struct {
	Latitude  float64 `json:"latitude" bson:"latitude"`
	Longitude float64 `json:"longitude" bson:"longitude"`
	Altitude  float64 `json:"altitude" bson:"altitude"`
}

// Weather represents environmental conditions
type Weather struct {
	Temperature float64 `json:"temperature" bson:"temperature"`
	Humidity    float64 `json:"humidity" bson:"humidity"`
	Pressure    float64 `json:"pressure" bson:"pressure"`
}

// JumpSession represents a training session
type JumpSession struct {
	ID          string       `json:"id" bson:"_id"`
	AthleteID   string       `json:"athlete_id" bson:"athlete_id"`
	StartTime   time.Time    `json:"start_time" bson:"start_time"`
	EndTime     time.Time    `json:"end_time" bson:"end_time"`
	Duration    int          `json:"duration_seconds" bson:"duration_seconds"`
	JumpCount   int          `json:"jump_count" bson:"jump_count"`
	MaxHeight   float64      `json:"max_height_cm" bson:"max_height_cm"`
	AvgHeight   float64      `json:"avg_height_cm" bson:"avg_height_cm"`
	LoadScore   int          `json:"load_score" bson:"load_score"`
	RPE         int          `json:"rpe" bson:"rpe"` // Rate of Perceived Exertion (1-10)
	Jumps       []JumpMetric `json:"jumps" bson:"jumps"`
}

// AthleteProfile represents athlete information
type AthleteProfile struct {
	ID           string    `json:"id" bson:"_id"`
	UserID       string    `json:"user_id" bson:"user_id"`
	Name         string    `json:"name" bson:"name"`
	Age          int       `json:"age" bson:"age"`
	Height       int       `json:"height_cm" bson:"height_cm"`
	Weight       float64   `json:"weight_kg" bson:"weight_kg"`
	SportLevel   string    `json:"sport_level" bson:"sport_level"` // beginner, intermediate, advanced, pro
	CreatedAt    time.Time `json:"created_at" bson:"created_at"`
	UpdatedAt    time.Time `json:"updated_at" bson:"updated_at"`
	
	// Performance baselines
	MaxJumpHeight     float64 `json:"max_jump_height_cm" bson:"max_jump_height_cm"`
	AvgJumpHeight     float64 `json:"avg_jump_height_cm" bson:"avg_jump_height_cm"`
	BestContactTime   int     `json:"best_contact_time_ms" bson:"best_contact_time_ms"`
	RSI               float64 `json:"rsi" bson:"rsi"` // Reactive Strength Index
	
	// Training preferences
	Goals             []string `json:"goals" bson:"goals"`
	TrainingDays      []string `json:"training_days" bson:"training_days"`
	PreferredDuration int      `json:"preferred_duration_min" bson:"preferred_duration_min"`
}

// MetricsSummary represents aggregated metrics for an athlete
type MetricsSummary struct {
	AthleteID        string    `json:"athlete_id"`
	Period           string    `json:"period"` // daily, weekly, monthly
	StartDate        time.Time `json:"start_date"`
	EndDate          time.Time `json:"end_date"`
	
	// Jump statistics
	TotalJumps       int     `json:"total_jumps"`
	TotalSessions    int     `json:"total_sessions"`
	MaxHeight        float64 `json:"max_height_cm"`
	AvgHeight        float64 `json:"avg_height_cm"`
	HeightImprovement float64 `json:"height_improvement_cm"`
	
	// Technique analysis
	AvgTakeoffScore  int     `json:"avg_takeoff_score"`
	AvgLandingScore  int     `json:"avg_landing_score"`
	AvgOverallScore  int     `json:"avg_overall_score"`
	
	// Injury risk indicators
	AvgValgusAngle   float64 `json:"avg_valgus_angle_deg"`
	MaxValgusAngle   float64 `json:"max_valgus_angle_deg"`
	RiskScore        int     `json:"risk_score"` // 0-100, higher = more risk
	
	// Training load
	TotalLoadScore   int     `json:"total_load_score"`
	AvgRPE          float64 `json:"avg_rpe"`
	
	// Trends
	HeightTrend      string  `json:"height_trend"` // improving, stable, declining
	TechniqueTrend   string  `json:"technique_trend"`
	LoadTrend        string  `json:"load_trend"`
}

// SubmitRequest represents a request to submit metrics
type SubmitRequest struct {
	AthleteID string       `json:"athlete_id"`
	Session   JumpSession  `json:"session"`
	Metrics   []JumpMetric `json:"metrics"`
}

// GetMetricsRequest represents a request to get metrics
type GetMetricsRequest struct {
	AthleteID string    `json:"athlete_id"`
	StartDate time.Time `json:"start_date"`
	EndDate   time.Time `json:"end_date"`
	Limit     int       `json:"limit"`
	Offset    int       `json:"offset"`
}

// GetMetricsResponse represents a response with metrics
type GetMetricsResponse struct {
	Metrics    []JumpMetric    `json:"metrics"`
	Summary    MetricsSummary  `json:"summary"`
	TotalCount int             `json:"total_count"`
	HasMore    bool            `json:"has_more"`
}

// ValidationError represents validation errors
type ValidationError struct {
	Field   string `json:"field"`
	Message string `json:"message"`
}

// ErrorResponse represents an error response
type ErrorResponse struct {
	Error       string            `json:"error"`
	Code        string            `json:"code"`
	Validations []ValidationError `json:"validations,omitempty"`
} 
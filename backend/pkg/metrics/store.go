package metrics

import (
	"context"
	"fmt"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

const (
	DatabaseName           = "dunksense"
	MetricsCollection      = "jump_metrics"
	SessionsCollection     = "jump_sessions"
	AthleteProfilesCollection = "athlete_profiles"
)

// Store handles all metrics-related database operations
type Store struct {
	client   *mongo.Client
	database *mongo.Database
}

// NewStore creates a new metrics store
func NewStore() (*Store, error) {
	// In production, get connection string from environment
	connectionString := "mongodb://localhost:27017"
	
	client, err := mongo.Connect(context.Background(), options.Client().ApplyURI(connectionString))
	if err != nil {
		return nil, fmt.Errorf("failed to connect to MongoDB: %w", err)
	}

	// Test the connection
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	
	if err := client.Ping(ctx, nil); err != nil {
		return nil, fmt.Errorf("failed to ping MongoDB: %w", err)
	}

	database := client.Database(DatabaseName)
	
	store := &Store{
		client:   client,
		database: database,
	}

	// Create indexes
	if err := store.createIndexes(); err != nil {
		return nil, fmt.Errorf("failed to create indexes: %w", err)
	}

	return store, nil
}

// createIndexes creates necessary database indexes
func (s *Store) createIndexes() error {
	ctx := context.Background()

	// Metrics collection indexes
	metricsCollection := s.database.Collection(MetricsCollection)
	
	metricsIndexes := []mongo.IndexModel{
		{
			Keys: bson.D{
				{Key: "athlete_id", Value: 1},
				{Key: "timestamp", Value: -1},
			},
		},
		{
			Keys: bson.D{
				{Key: "session_id", Value: 1},
			},
		},
		{
			Keys: bson.D{
				{Key: "athlete_id", Value: 1},
				{Key: "height_cm", Value: -1},
			},
		},
	}

	_, err := metricsCollection.Indexes().CreateMany(ctx, metricsIndexes)
	if err != nil {
		return fmt.Errorf("failed to create metrics indexes: %w", err)
	}

	// Sessions collection indexes
	sessionsCollection := s.database.Collection(SessionsCollection)
	
	sessionsIndexes := []mongo.IndexModel{
		{
			Keys: bson.D{
				{Key: "athlete_id", Value: 1},
				{Key: "start_time", Value: -1},
			},
		},
	}

	_, err = sessionsCollection.Indexes().CreateMany(ctx, sessionsIndexes)
	if err != nil {
		return fmt.Errorf("failed to create sessions indexes: %w", err)
	}

	return nil
}

// Submit stores new metrics and session data
func (s *Store) Submit(ctx context.Context, req *SubmitRequest) error {
	if err := s.validateSubmitRequest(req); err != nil {
		return fmt.Errorf("validation failed: %w", err)
	}

	// Start a transaction
	session, err := s.client.StartSession()
	if err != nil {
		return fmt.Errorf("failed to start session: %w", err)
	}
	defer session.EndSession(ctx)

	_, err = session.WithTransaction(ctx, func(sc mongo.SessionContext) (interface{}, error) {
		// Insert session
		sessionsCollection := s.database.Collection(SessionsCollection)
		
		// Generate session ID if not provided
		if req.Session.ID == "" {
			req.Session.ID = primitive.NewObjectID().Hex()
		}

		_, err := sessionsCollection.InsertOne(sc, req.Session)
		if err != nil {
			return nil, fmt.Errorf("failed to insert session: %w", err)
		}

		// Insert metrics
		if len(req.Metrics) > 0 {
			metricsCollection := s.database.Collection(MetricsCollection)
			
			// Convert to interface slice for bulk insert
			docs := make([]interface{}, len(req.Metrics))
			for i, metric := range req.Metrics {
				// Generate metric ID if not provided
				if metric.ID == "" {
					metric.ID = primitive.NewObjectID().Hex()
				}
				// Set session ID
				metric.SessionID = req.Session.ID
				docs[i] = metric
			}

			_, err := metricsCollection.InsertMany(sc, docs)
			if err != nil {
				return nil, fmt.Errorf("failed to insert metrics: %w", err)
			}
		}

		// Update athlete profile with latest metrics
		if err := s.updateAthleteProfile(sc, req.AthleteID, req.Metrics); err != nil {
			return nil, fmt.Errorf("failed to update athlete profile: %w", err)
		}

		return nil, nil
	})

	return err
}

// GetByAthleteID retrieves metrics for a specific athlete
func (s *Store) GetByAthleteID(ctx context.Context, athleteID string) (*GetMetricsResponse, error) {
	collection := s.database.Collection(MetricsCollection)

	// Default to last 30 days
	endDate := time.Now()
	startDate := endDate.AddDate(0, 0, -30)

	filter := bson.M{
		"athlete_id": athleteID,
		"timestamp": bson.M{
			"$gte": startDate,
			"$lte": endDate,
		},
	}

	// Get total count
	totalCount, err := collection.CountDocuments(ctx, filter)
	if err != nil {
		return nil, fmt.Errorf("failed to count documents: %w", err)
	}

	// Get metrics with pagination
	opts := options.Find().
		SetSort(bson.D{{Key: "timestamp", Value: -1}}).
		SetLimit(100)

	cursor, err := collection.Find(ctx, filter, opts)
	if err != nil {
		return nil, fmt.Errorf("failed to find metrics: %w", err)
	}
	defer cursor.Close(ctx)

	var metrics []JumpMetric
	if err := cursor.All(ctx, &metrics); err != nil {
		return nil, fmt.Errorf("failed to decode metrics: %w", err)
	}

	// Generate summary
	summary, err := s.generateSummary(ctx, athleteID, startDate, endDate)
	if err != nil {
		return nil, fmt.Errorf("failed to generate summary: %w", err)
	}

	return &GetMetricsResponse{
		Metrics:    metrics,
		Summary:    *summary,
		TotalCount: int(totalCount),
		HasMore:    int(totalCount) > len(metrics),
	}, nil
}

// GetSummary retrieves aggregated metrics summary for an athlete
func (s *Store) GetSummary(ctx context.Context, athleteID string) (*MetricsSummary, error) {
	// Default to last 7 days
	endDate := time.Now()
	startDate := endDate.AddDate(0, 0, -7)

	return s.generateSummary(ctx, athleteID, startDate, endDate)
}

// generateSummary creates a metrics summary for the given period
func (s *Store) generateSummary(ctx context.Context, athleteID string, startDate, endDate time.Time) (*MetricsSummary, error) {
	collection := s.database.Collection(MetricsCollection)

	pipeline := []bson.M{
		{
			"$match": bson.M{
				"athlete_id": athleteID,
				"timestamp": bson.M{
					"$gte": startDate,
					"$lte": endDate,
				},
			},
		},
		{
			"$group": bson.M{
				"_id": nil,
				"total_jumps": bson.M{"$sum": 1},
				"max_height": bson.M{"$max": "$height_cm"},
				"avg_height": bson.M{"$avg": "$height_cm"},
				"avg_takeoff_score": bson.M{"$avg": "$takeoff_score"},
				"avg_landing_score": bson.M{"$avg": "$landing_score"},
				"avg_overall_score": bson.M{"$avg": "$overall_score"},
				"avg_valgus_angle": bson.M{"$avg": "$valgus_angle_deg"},
				"max_valgus_angle": bson.M{"$max": "$valgus_angle_deg"},
			},
		},
	}

	cursor, err := collection.Aggregate(ctx, pipeline)
	if err != nil {
		return nil, fmt.Errorf("failed to aggregate metrics: %w", err)
	}
	defer cursor.Close(ctx)

	var results []bson.M
	if err := cursor.All(ctx, &results); err != nil {
		return nil, fmt.Errorf("failed to decode aggregation results: %w", err)
	}

	summary := &MetricsSummary{
		AthleteID: athleteID,
		Period:    "weekly",
		StartDate: startDate,
		EndDate:   endDate,
	}

	if len(results) > 0 {
		result := results[0]
		
		if val, ok := result["total_jumps"].(int32); ok {
			summary.TotalJumps = int(val)
		}
		if val, ok := result["max_height"].(float64); ok {
			summary.MaxHeight = val
		}
		if val, ok := result["avg_height"].(float64); ok {
			summary.AvgHeight = val
		}
		if val, ok := result["avg_takeoff_score"].(float64); ok {
			summary.AvgTakeoffScore = int(val)
		}
		if val, ok := result["avg_landing_score"].(float64); ok {
			summary.AvgLandingScore = int(val)
		}
		if val, ok := result["avg_overall_score"].(float64); ok {
			summary.AvgOverallScore = int(val)
		}
		if val, ok := result["avg_valgus_angle"].(float64); ok {
			summary.AvgValgusAngle = val
		}
		if val, ok := result["max_valgus_angle"].(float64); ok {
			summary.MaxValgusAngle = val
		}
	}

	// Calculate risk score based on valgus angle
	summary.RiskScore = s.calculateRiskScore(summary.AvgValgusAngle, summary.MaxValgusAngle)

	// Determine trends (simplified for now)
	summary.HeightTrend = "stable"
	summary.TechniqueTrend = "stable"
	summary.LoadTrend = "stable"

	return summary, nil
}

// updateAthleteProfile updates athlete profile with latest metrics
func (s *Store) updateAthleteProfile(ctx context.Context, athleteID string, metrics []JumpMetric) error {
	if len(metrics) == 0 {
		return nil
	}

	collection := s.database.Collection(AthleteProfilesCollection)

	// Find max height from current metrics
	maxHeight := 0.0
	for _, metric := range metrics {
		if metric.HeightCm > maxHeight {
			maxHeight = metric.HeightCm
		}
	}

	// Update athlete profile
	filter := bson.M{"_id": athleteID}
	update := bson.M{
		"$max": bson.M{
			"max_jump_height_cm": maxHeight,
		},
		"$set": bson.M{
			"updated_at": time.Now(),
		},
	}

	_, err := collection.UpdateOne(ctx, filter, update, options.Update().SetUpsert(true))
	if err != nil {
		return fmt.Errorf("failed to update athlete profile: %w", err)
	}

	return nil
}

// calculateRiskScore calculates injury risk score based on biomechanical data
func (s *Store) calculateRiskScore(avgValgus, maxValgus float64) int {
	// Simplified risk calculation
	// In practice, this would use more sophisticated algorithms
	riskScore := 0

	// Valgus angle risk (higher angle = higher risk)
	if avgValgus > 10 {
		riskScore += 30
	} else if avgValgus > 5 {
		riskScore += 15
	}

	if maxValgus > 15 {
		riskScore += 40
	} else if maxValgus > 10 {
		riskScore += 20
	}

	// Cap at 100
	if riskScore > 100 {
		riskScore = 100
	}

	return riskScore
}

// validateSubmitRequest validates the submit request
func (s *Store) validateSubmitRequest(req *SubmitRequest) error {
	if req.AthleteID == "" {
		return fmt.Errorf("athlete_id is required")
	}

	if req.Session.AthleteID == "" {
		req.Session.AthleteID = req.AthleteID
	}

	if req.Session.AthleteID != req.AthleteID {
		return fmt.Errorf("session athlete_id must match request athlete_id")
	}

	for i, metric := range req.Metrics {
		if metric.AthleteID == "" {
			req.Metrics[i].AthleteID = req.AthleteID
		}
		
		if metric.AthleteID != req.AthleteID {
			return fmt.Errorf("metric athlete_id must match request athlete_id")
		}

		if metric.HeightCm < 0 || metric.HeightCm > 200 {
			return fmt.Errorf("invalid height_cm: %f", metric.HeightCm)
		}

		if metric.Confidence < 0 || metric.Confidence > 1 {
			return fmt.Errorf("invalid confidence: %f", metric.Confidence)
		}
	}

	return nil
}

// Close closes the database connection
func (s *Store) Close() error {
	return s.client.Disconnect(context.Background())
} 
package metrics

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/Danchouvzv/DunkSense/backend/pkg/logging"
)

// MockStore is a mock implementation of the Store interface
type MockStore struct {
	mock.Mock
}

func (m *MockStore) CreateJumpMetric(ctx context.Context, metric *JumpMetric) error {
	args := m.Called(ctx, metric)
	return args.Error(0)
}

func (m *MockStore) GetJumpMetric(ctx context.Context, id string) (*JumpMetric, error) {
	args := m.Called(ctx, id)
	return args.Get(0).(*JumpMetric), args.Error(1)
}

func (m *MockStore) GetJumpMetrics(ctx context.Context, userID string, limit, offset int) ([]*JumpMetric, error) {
	args := m.Called(ctx, userID, limit, offset)
	return args.Get(0).([]*JumpMetric), args.Error(1)
}

func (m *MockStore) UpdateJumpMetric(ctx context.Context, metric *JumpMetric) error {
	args := m.Called(ctx, metric)
	return args.Error(0)
}

func (m *MockStore) DeleteJumpMetric(ctx context.Context, id string) error {
	args := m.Called(ctx, id)
	return args.Error(0)
}

func (m *MockStore) GetUserStats(ctx context.Context, userID string, startDate, endDate time.Time) (*UserStats, error) {
	args := m.Called(ctx, userID, startDate, endDate)
	return args.Get(0).(*UserStats), args.Error(1)
}

func (m *MockStore) GetPersonalBest(ctx context.Context, userID string) (*JumpMetric, error) {
	args := m.Called(ctx, userID)
	return args.Get(0).(*JumpMetric), args.Error(1)
}

func (m *MockStore) Close() error {
	args := m.Called()
	return args.Error(0)
}

func TestService_CreateJumpMetric(t *testing.T) {
	mockStore := new(MockStore)
	logger, _ := logging.NewLogger(logging.InfoLevel, "test")
	service := NewService(mockStore, logger)

	metric := &JumpMetric{
		ID:              "test-id",
		UserID:          "user-123",
		Height:          85.5,
		FlightTime:      0.65,
		ContactTime:     0.25,
		TakeoffVelocity: 3.2,
		LandingForce:    1200.0,
		SymmetryScore:   0.85,
		TechniqueScore:  0.78,
		Timestamp:       time.Now(),
	}

	mockStore.On("CreateJumpMetric", mock.Anything, metric).Return(nil)

	err := service.CreateJumpMetric(context.Background(), metric)

	assert.NoError(t, err)
	mockStore.AssertExpectations(t)
}

func TestService_GetJumpMetric(t *testing.T) {
	mockStore := new(MockStore)
	logger, _ := logging.NewLogger(logging.InfoLevel, "test")
	service := NewService(mockStore, logger)

	expectedMetric := &JumpMetric{
		ID:              "test-id",
		UserID:          "user-123",
		Height:          85.5,
		FlightTime:      0.65,
		ContactTime:     0.25,
		TakeoffVelocity: 3.2,
		LandingForce:    1200.0,
		SymmetryScore:   0.85,
		TechniqueScore:  0.78,
		Timestamp:       time.Now(),
	}

	mockStore.On("GetJumpMetric", mock.Anything, "test-id").Return(expectedMetric, nil)

	result, err := service.GetJumpMetric(context.Background(), "test-id")

	assert.NoError(t, err)
	assert.Equal(t, expectedMetric, result)
	mockStore.AssertExpectations(t)
}

func TestService_GetUserStats(t *testing.T) {
	mockStore := new(MockStore)
	logger, _ := logging.NewLogger(logging.InfoLevel, "test")
	service := NewService(mockStore, logger)

	startDate := time.Now().AddDate(0, -1, 0) // 1 month ago
	endDate := time.Now()

	expectedStats := &UserStats{
		UserID:           "user-123",
		TotalJumps:       50,
		AverageHeight:    82.3,
		MaxHeight:        95.2,
		AverageFlightTime: 0.63,
		MaxFlightTime:    0.72,
		ImprovementRate:  0.15,
		Period:           "monthly",
	}

	mockStore.On("GetUserStats", mock.Anything, "user-123", startDate, endDate).Return(expectedStats, nil)

	result, err := service.GetUserStats(context.Background(), "user-123", startDate, endDate)

	assert.NoError(t, err)
	assert.Equal(t, expectedStats, result)
	mockStore.AssertExpectations(t)
}

func TestService_GetPersonalBest(t *testing.T) {
	mockStore := new(MockStore)
	logger, _ := logging.NewLogger(logging.InfoLevel, "test")
	service := NewService(mockStore, logger)

	expectedBest := &JumpMetric{
		ID:              "best-jump-id",
		UserID:          "user-123",
		Height:          95.2,
		FlightTime:      0.72,
		ContactTime:     0.22,
		TakeoffVelocity: 3.5,
		LandingForce:    1350.0,
		SymmetryScore:   0.92,
		TechniqueScore:  0.88,
		Timestamp:       time.Now().AddDate(0, 0, -5), // 5 days ago
	}

	mockStore.On("GetPersonalBest", mock.Anything, "user-123").Return(expectedBest, nil)

	result, err := service.GetPersonalBest(context.Background(), "user-123")

	assert.NoError(t, err)
	assert.Equal(t, expectedBest, result)
	mockStore.AssertExpectations(t)
}

func TestService_ValidateJumpMetric(t *testing.T) {
	tests := []struct {
		name        string
		metric      *JumpMetric
		expectError bool
	}{
		{
			name: "valid metric",
			metric: &JumpMetric{
				ID:              "test-id",
				UserID:          "user-123",
				Height:          85.5,
				FlightTime:      0.65,
				ContactTime:     0.25,
				TakeoffVelocity: 3.2,
				LandingForce:    1200.0,
				SymmetryScore:   0.85,
				TechniqueScore:  0.78,
				Timestamp:       time.Now(),
			},
			expectError: false,
		},
		{
			name: "missing user ID",
			metric: &JumpMetric{
				ID:              "test-id",
				Height:          85.5,
				FlightTime:      0.65,
				ContactTime:     0.25,
				TakeoffVelocity: 3.2,
				LandingForce:    1200.0,
				SymmetryScore:   0.85,
				TechniqueScore:  0.78,
				Timestamp:       time.Now(),
			},
			expectError: true,
		},
		{
			name: "negative height",
			metric: &JumpMetric{
				ID:              "test-id",
				UserID:          "user-123",
				Height:          -10.0,
				FlightTime:      0.65,
				ContactTime:     0.25,
				TakeoffVelocity: 3.2,
				LandingForce:    1200.0,
				SymmetryScore:   0.85,
				TechniqueScore:  0.78,
				Timestamp:       time.Now(),
			},
			expectError: true,
		},
		{
			name: "invalid symmetry score",
			metric: &JumpMetric{
				ID:              "test-id",
				UserID:          "user-123",
				Height:          85.5,
				FlightTime:      0.65,
				ContactTime:     0.25,
				TakeoffVelocity: 3.2,
				LandingForce:    1200.0,
				SymmetryScore:   1.5, // Should be between 0 and 1
				TechniqueScore:  0.78,
				Timestamp:       time.Now(),
			},
			expectError: true,
		},
	}

	mockStore := new(MockStore)
	logger, _ := logging.NewLogger(logging.InfoLevel, "test")
	service := NewService(mockStore, logger)

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := service.validateJumpMetric(tt.metric)
			if tt.expectError {
				assert.Error(t, err)
			} else {
				assert.NoError(t, err)
			}
		})
	}
}

func TestService_CalculateImprovementRate(t *testing.T) {
	mockStore := new(MockStore)
	logger, _ := logging.NewLogger(logging.InfoLevel, "test")
	service := NewService(mockStore, logger)

	// Test data: user improved from 80cm to 90cm over 10 jumps
	recentJumps := []*JumpMetric{
		{Height: 90.0, Timestamp: time.Now()},
		{Height: 89.5, Timestamp: time.Now().AddDate(0, 0, -1)},
		{Height: 88.0, Timestamp: time.Now().AddDate(0, 0, -2)},
		{Height: 87.5, Timestamp: time.Now().AddDate(0, 0, -3)},
		{Height: 85.0, Timestamp: time.Now().AddDate(0, 0, -4)},
	}

	oldJumps := []*JumpMetric{
		{Height: 82.0, Timestamp: time.Now().AddDate(0, 0, -8)},
		{Height: 81.5, Timestamp: time.Now().AddDate(0, 0, -9)},
		{Height: 80.0, Timestamp: time.Now().AddDate(0, 0, -10)},
		{Height: 79.5, Timestamp: time.Now().AddDate(0, 0, -11)},
		{Height: 78.0, Timestamp: time.Now().AddDate(0, 0, -12)},
	}

	improvementRate := service.calculateImprovementRate(recentJumps, oldJumps)

	// Expected improvement: (87.9 - 80.2) / 80.2 ≈ 0.096
	assert.Greater(t, improvementRate, 0.0)
	assert.Less(t, improvementRate, 0.2) // Should be reasonable improvement rate
}

func TestService_GenerateRecommendations(t *testing.T) {
	mockStore := new(MockStore)
	logger, _ := logging.NewLogger(logging.InfoLevel, "test")
	service := NewService(mockStore, logger)

	tests := []struct {
		name           string
		metric         *JumpMetric
		expectedCount  int
		expectedTopics []string
	}{
		{
			name: "low symmetry score",
			metric: &JumpMetric{
				Height:         85.0,
				SymmetryScore:  0.6, // Low symmetry
				TechniqueScore: 0.8,
			},
			expectedCount:  1,
			expectedTopics: []string{"symmetry"},
		},
		{
			name: "low technique score",
			metric: &JumpMetric{
				Height:         85.0,
				SymmetryScore:  0.8,
				TechniqueScore: 0.6, // Low technique
			},
			expectedCount:  1,
			expectedTopics: []string{"technique"},
		},
		{
			name: "good overall performance",
			metric: &JumpMetric{
				Height:         90.0, // Good height
				SymmetryScore:  0.9,  // High symmetry
				TechniqueScore: 0.85, // Good technique
			},
			expectedCount:  1,
			expectedTopics: []string{"maintain"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			recommendations := service.generateRecommendations(tt.metric)
			
			assert.Len(t, recommendations, tt.expectedCount)
			
			// Check if expected topics are covered
			for _, expectedTopic := range tt.expectedTopics {
				found := false
				for _, rec := range recommendations {
					if containsSubstring(rec, expectedTopic) {
						found = true
						break
					}
				}
				assert.True(t, found, "Expected topic '%s' not found in recommendations", expectedTopic)
			}
		})
	}
}

// Helper function to check if a string contains a substring (case-insensitive)
func containsSubstring(s, substr string) bool {
	return len(s) >= len(substr) && 
		   (s == substr || 
		    len(s) > len(substr) && 
		    (s[:len(substr)] == substr || 
		     s[len(s)-len(substr):] == substr ||
		     contains(s, substr)))
}

func contains(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}

func BenchmarkService_CreateJumpMetric(b *testing.B) {
	mockStore := new(MockStore)
	logger, _ := logging.NewLogger(logging.InfoLevel, "test")
	service := NewService(mockStore, logger)

	metric := &JumpMetric{
		ID:              "test-id",
		UserID:          "user-123",
		Height:          85.5,
		FlightTime:      0.65,
		ContactTime:     0.25,
		TakeoffVelocity: 3.2,
		LandingForce:    1200.0,
		SymmetryScore:   0.85,
		TechniqueScore:  0.78,
		Timestamp:       time.Now(),
	}

	mockStore.On("CreateJumpMetric", mock.Anything, metric).Return(nil)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = service.CreateJumpMetric(context.Background(), metric)
	}
} 
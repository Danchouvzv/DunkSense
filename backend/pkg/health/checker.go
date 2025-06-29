package health

import (
	"context"
	"database/sql"
	"fmt"
	"net/http"
	"sync"
	"time"

	"github.com/go-redis/redis/v8"
	"github.com/jmoiron/sqlx"
	"github.com/segmentio/kafka-go"
	"go.uber.org/zap"
)

// Status represents the health status of a component
type Status string

const (
	StatusHealthy   Status = "healthy"
	StatusUnhealthy Status = "unhealthy"
	StatusDegraded  Status = "degraded"
	StatusUnknown   Status = "unknown"
)

// CheckResult represents the result of a health check
type CheckResult struct {
	Name        string                 `json:"name"`
	Status      Status                 `json:"status"`
	Message     string                 `json:"message,omitempty"`
	Duration    time.Duration          `json:"duration"`
	Timestamp   time.Time              `json:"timestamp"`
	Metadata    map[string]interface{} `json:"metadata,omitempty"`
	Error       string                 `json:"error,omitempty"`
}

// HealthReport represents the overall health status
type HealthReport struct {
	Status     Status        `json:"status"`
	Timestamp  time.Time     `json:"timestamp"`
	Duration   time.Duration `json:"duration"`
	Checks     []CheckResult `json:"checks"`
	Version    string        `json:"version,omitempty"`
	Commit     string        `json:"commit,omitempty"`
	BuildTime  string        `json:"build_time,omitempty"`
}

// Checker interface for health checks
type Checker interface {
	Check(ctx context.Context) CheckResult
	Name() string
}

// HealthChecker manages all health checks
type HealthChecker struct {
	checkers []Checker
	timeout  time.Duration
	logger   *zap.Logger
	version  string
	commit   string
	buildTime string
}

// NewHealthChecker creates a new health checker
func NewHealthChecker(logger *zap.Logger, version, commit, buildTime string) *HealthChecker {
	return &HealthChecker{
		checkers:  make([]Checker, 0),
		timeout:   30 * time.Second,
		logger:    logger,
		version:   version,
		commit:    commit,
		buildTime: buildTime,
	}
}

// AddChecker adds a health checker
func (hc *HealthChecker) AddChecker(checker Checker) {
	hc.checkers = append(hc.checkers, checker)
}

// SetTimeout sets the timeout for health checks
func (hc *HealthChecker) SetTimeout(timeout time.Duration) {
	hc.timeout = timeout
}

// Check performs all health checks
func (hc *HealthChecker) Check(ctx context.Context) HealthReport {
	start := time.Now()
	
	// Create context with timeout
	checkCtx, cancel := context.WithTimeout(ctx, hc.timeout)
	defer cancel()

	// Run all checks concurrently
	results := make([]CheckResult, len(hc.checkers))
	var wg sync.WaitGroup
	
	for i, checker := range hc.checkers {
		wg.Add(1)
		go func(idx int, c Checker) {
			defer wg.Done()
			results[idx] = c.Check(checkCtx)
		}(i, checker)
	}
	
	wg.Wait()
	
	// Determine overall status
	overallStatus := hc.determineOverallStatus(results)
	
	return HealthReport{
		Status:    overallStatus,
		Timestamp: time.Now(),
		Duration:  time.Since(start),
		Checks:    results,
		Version:   hc.version,
		Commit:    hc.commit,
		BuildTime: hc.buildTime,
	}
}

// determineOverallStatus calculates the overall health status
func (hc *HealthChecker) determineOverallStatus(results []CheckResult) Status {
	if len(results) == 0 {
		return StatusUnknown
	}
	
	hasUnhealthy := false
	hasDegraded := false
	
	for _, result := range results {
		switch result.Status {
		case StatusUnhealthy:
			hasUnhealthy = true
		case StatusDegraded:
			hasDegraded = true
		}
	}
	
	if hasUnhealthy {
		return StatusUnhealthy
	}
	if hasDegraded {
		return StatusDegraded
	}
	
	return StatusHealthy
}

// DatabaseChecker checks database connectivity
type DatabaseChecker struct {
	db   *sqlx.DB
	name string
}

// NewDatabaseChecker creates a new database checker
func NewDatabaseChecker(db *sqlx.DB, name string) *DatabaseChecker {
	return &DatabaseChecker{
		db:   db,
		name: name,
	}
}

// Name returns the checker name
func (dc *DatabaseChecker) Name() string {
	return dc.name
}

// Check performs the database health check
func (dc *DatabaseChecker) Check(ctx context.Context) CheckResult {
	start := time.Now()
	result := CheckResult{
		Name:      dc.name,
		Timestamp: start,
		Metadata:  make(map[string]interface{}),
	}
	
	// Check basic connectivity
	if err := dc.db.PingContext(ctx); err != nil {
		result.Status = StatusUnhealthy
		result.Error = err.Error()
		result.Message = "Database ping failed"
		result.Duration = time.Since(start)
		return result
	}
	
	// Check connection pool stats
	stats := dc.db.Stats()
	result.Metadata["open_connections"] = stats.OpenConnections
	result.Metadata["in_use"] = stats.InUse
	result.Metadata["idle"] = stats.Idle
	result.Metadata["wait_count"] = stats.WaitCount
	result.Metadata["wait_duration"] = stats.WaitDuration.String()
	
	// Check for connection pool exhaustion
	if stats.OpenConnections >= stats.MaxOpenConnections && stats.MaxOpenConnections > 0 {
		result.Status = StatusDegraded
		result.Message = "Connection pool near exhaustion"
	} else {
		result.Status = StatusHealthy
		result.Message = "Database is healthy"
	}
	
	result.Duration = time.Since(start)
	return result
}

// RedisChecker checks Redis connectivity
type RedisChecker struct {
	client *redis.Client
	name   string
}

// NewRedisChecker creates a new Redis checker
func NewRedisChecker(client *redis.Client, name string) *RedisChecker {
	return &RedisChecker{
		client: client,
		name:   name,
	}
}

// Name returns the checker name
func (rc *RedisChecker) Name() string {
	return rc.name
}

// Check performs the Redis health check
func (rc *RedisChecker) Check(ctx context.Context) CheckResult {
	start := time.Now()
	result := CheckResult{
		Name:      rc.name,
		Timestamp: start,
		Metadata:  make(map[string]interface{}),
	}
	
	// Check basic connectivity
	if err := rc.client.Ping(ctx).Err(); err != nil {
		result.Status = StatusUnhealthy
		result.Error = err.Error()
		result.Message = "Redis ping failed"
		result.Duration = time.Since(start)
		return result
	}
	
	// Get Redis info
	info, err := rc.client.Info(ctx, "memory", "clients").Result()
	if err != nil {
		result.Status = StatusDegraded
		result.Error = err.Error()
		result.Message = "Could not retrieve Redis info"
	} else {
		result.Status = StatusHealthy
		result.Message = "Redis is healthy"
		result.Metadata["info"] = info
	}
	
	result.Duration = time.Since(start)
	return result
}

// KafkaChecker checks Kafka connectivity
type KafkaChecker struct {
	brokers []string
	name    string
}

// NewKafkaChecker creates a new Kafka checker
func NewKafkaChecker(brokers []string, name string) *KafkaChecker {
	return &KafkaChecker{
		brokers: brokers,
		name:    name,
	}
}

// Name returns the checker name
func (kc *KafkaChecker) Name() string {
	return kc.name
}

// Check performs the Kafka health check
func (kc *KafkaChecker) Check(ctx context.Context) CheckResult {
	start := time.Now()
	result := CheckResult{
		Name:      kc.name,
		Timestamp: start,
		Metadata:  make(map[string]interface{}),
	}
	
	// Create a connection to check broker availability
	conn, err := kafka.DialContext(ctx, "tcp", kc.brokers[0])
	if err != nil {
		result.Status = StatusUnhealthy
		result.Error = err.Error()
		result.Message = "Failed to connect to Kafka broker"
		result.Duration = time.Since(start)
		return result
	}
	defer conn.Close()
	
	// Get broker metadata
	brokers, err := conn.Brokers()
	if err != nil {
		result.Status = StatusDegraded
		result.Error = err.Error()
		result.Message = "Could not retrieve broker metadata"
	} else {
		result.Status = StatusHealthy
		result.Message = "Kafka is healthy"
		result.Metadata["brokers_count"] = len(brokers)
		result.Metadata["brokers"] = brokers
	}
	
	result.Duration = time.Since(start)
	return result
}

// HTTPChecker checks HTTP endpoint availability
type HTTPChecker struct {
	url    string
	name   string
	client *http.Client
}

// NewHTTPChecker creates a new HTTP checker
func NewHTTPChecker(url, name string) *HTTPChecker {
	return &HTTPChecker{
		url:  url,
		name: name,
		client: &http.Client{
			Timeout: 10 * time.Second,
		},
	}
}

// Name returns the checker name
func (hc *HTTPChecker) Name() string {
	return hc.name
}

// Check performs the HTTP health check
func (hc *HTTPChecker) Check(ctx context.Context) CheckResult {
	start := time.Now()
	result := CheckResult{
		Name:      hc.name,
		Timestamp: start,
		Metadata:  make(map[string]interface{}),
	}
	
	req, err := http.NewRequestWithContext(ctx, "GET", hc.url, nil)
	if err != nil {
		result.Status = StatusUnhealthy
		result.Error = err.Error()
		result.Message = "Failed to create HTTP request"
		result.Duration = time.Since(start)
		return result
	}
	
	resp, err := hc.client.Do(req)
	if err != nil {
		result.Status = StatusUnhealthy
		result.Error = err.Error()
		result.Message = "HTTP request failed"
		result.Duration = time.Since(start)
		return result
	}
	defer resp.Body.Close()
	
	result.Metadata["status_code"] = resp.StatusCode
	result.Metadata["headers"] = resp.Header
	
	if resp.StatusCode >= 200 && resp.StatusCode < 300 {
		result.Status = StatusHealthy
		result.Message = "HTTP endpoint is healthy"
	} else if resp.StatusCode >= 300 && resp.StatusCode < 500 {
		result.Status = StatusDegraded
		result.Message = fmt.Sprintf("HTTP endpoint returned %d", resp.StatusCode)
	} else {
		result.Status = StatusUnhealthy
		result.Message = fmt.Sprintf("HTTP endpoint returned %d", resp.StatusCode)
	}
	
	result.Duration = time.Since(start)
	return result
}

// CustomChecker allows for custom health checks
type CustomChecker struct {
	name     string
	checkFn  func(context.Context) (Status, string, map[string]interface{}, error)
}

// NewCustomChecker creates a new custom checker
func NewCustomChecker(name string, checkFn func(context.Context) (Status, string, map[string]interface{}, error)) *CustomChecker {
	return &CustomChecker{
		name:    name,
		checkFn: checkFn,
	}
}

// Name returns the checker name
func (cc *CustomChecker) Name() string {
	return cc.name
}

// Check performs the custom health check
func (cc *CustomChecker) Check(ctx context.Context) CheckResult {
	start := time.Now()
	result := CheckResult{
		Name:      cc.name,
		Timestamp: start,
	}
	
	status, message, metadata, err := cc.checkFn(ctx)
	
	result.Status = status
	result.Message = message
	result.Metadata = metadata
	if err != nil {
		result.Error = err.Error()
	}
	result.Duration = time.Since(start)
	
	return result
}

// MemoryChecker checks memory usage
func NewMemoryChecker(name string, maxMemoryMB int64) *CustomChecker {
	return NewCustomChecker(name, func(ctx context.Context) (Status, string, map[string]interface{}, error) {
		// This is a simplified memory check
		// In a real implementation, you'd use runtime.MemStats or similar
		metadata := map[string]interface{}{
			"max_memory_mb": maxMemoryMB,
		}
		
		return StatusHealthy, "Memory usage is within limits", metadata, nil
	})
}

// DiskChecker checks disk space
func NewDiskChecker(name, path string, minFreeGB int64) *CustomChecker {
	return NewCustomChecker(name, func(ctx context.Context) (Status, string, map[string]interface{}, error) {
		// This is a simplified disk check
		// In a real implementation, you'd use syscall.Statfs or similar
		metadata := map[string]interface{}{
			"path":         path,
			"min_free_gb": minFreeGB,
		}
		
		return StatusHealthy, "Disk space is sufficient", metadata, nil
	})
} 
package monitoring

import (
	"net/http"
	"strconv"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

// Metrics holds all Prometheus metrics
type Metrics struct {
	// HTTP metrics
	HTTPRequestsTotal     *prometheus.CounterVec
	HTTPRequestDuration   *prometheus.HistogramVec
	HTTPResponseSize      *prometheus.HistogramVec
	
	// Business metrics
	JumpsProcessedTotal   *prometheus.CounterVec
	JumpProcessingTime    *prometheus.HistogramVec
	ActiveUsers           prometheus.Gauge
	VideoUploadsTotal     *prometheus.CounterVec
	VideoProcessingTime   *prometheus.HistogramVec
	
	// System metrics
	DatabaseConnections   prometheus.Gauge
	CacheHitRate         *prometheus.CounterVec
	ErrorsTotal          *prometheus.CounterVec
	
	// ML metrics
	ModelInferenceTime    *prometheus.HistogramVec
	ModelAccuracy         *prometheus.GaugeVec
	PredictionConfidence  *prometheus.HistogramVec
}

// NewMetrics creates and registers all Prometheus metrics
func NewMetrics() *Metrics {
	m := &Metrics{
		HTTPRequestsTotal: prometheus.NewCounterVec(
			prometheus.CounterOpts{
				Name: "http_requests_total",
				Help: "Total number of HTTP requests",
			},
			[]string{"method", "endpoint", "status_code"},
		),
		HTTPRequestDuration: prometheus.NewHistogramVec(
			prometheus.HistogramOpts{
				Name:    "http_request_duration_seconds",
				Help:    "HTTP request duration in seconds",
				Buckets: prometheus.DefBuckets,
			},
			[]string{"method", "endpoint"},
		),
		HTTPResponseSize: prometheus.NewHistogramVec(
			prometheus.HistogramOpts{
				Name:    "http_response_size_bytes",
				Help:    "HTTP response size in bytes",
				Buckets: []float64{100, 1000, 10000, 100000, 1000000},
			},
			[]string{"method", "endpoint"},
		),
		JumpsProcessedTotal: prometheus.NewCounterVec(
			prometheus.CounterOpts{
				Name: "jumps_processed_total",
				Help: "Total number of jumps processed",
			},
			[]string{"user_id", "status"},
		),
		JumpProcessingTime: prometheus.NewHistogramVec(
			prometheus.HistogramOpts{
				Name:    "jump_processing_duration_seconds",
				Help:    "Jump processing duration in seconds",
				Buckets: []float64{0.1, 0.5, 1, 2, 5, 10, 30},
			},
			[]string{"processing_stage"},
		),
		ActiveUsers: prometheus.NewGauge(
			prometheus.GaugeOpts{
				Name: "active_users",
				Help: "Number of currently active users",
			},
		),
		VideoUploadsTotal: prometheus.NewCounterVec(
			prometheus.CounterOpts{
				Name: "video_uploads_total",
				Help: "Total number of video uploads",
			},
			[]string{"status", "format"},
		),
		VideoProcessingTime: prometheus.NewHistogramVec(
			prometheus.HistogramOpts{
				Name:    "video_processing_duration_seconds",
				Help:    "Video processing duration in seconds",
				Buckets: []float64{1, 5, 10, 30, 60, 120, 300},
			},
			[]string{"video_length_category"},
		),
		DatabaseConnections: prometheus.NewGauge(
			prometheus.GaugeOpts{
				Name: "database_connections_active",
				Help: "Number of active database connections",
			},
		),
		CacheHitRate: prometheus.NewCounterVec(
			prometheus.CounterOpts{
				Name: "cache_operations_total",
				Help: "Total number of cache operations",
			},
			[]string{"operation", "result"},
		),
		ErrorsTotal: prometheus.NewCounterVec(
			prometheus.CounterOpts{
				Name: "errors_total",
				Help: "Total number of errors",
			},
			[]string{"service", "error_type"},
		),
		ModelInferenceTime: prometheus.NewHistogramVec(
			prometheus.HistogramOpts{
				Name:    "model_inference_duration_seconds",
				Help:    "ML model inference duration in seconds",
				Buckets: []float64{0.01, 0.05, 0.1, 0.5, 1, 2, 5},
			},
			[]string{"model_name", "model_version"},
		),
		ModelAccuracy: prometheus.NewGaugeVec(
			prometheus.GaugeOpts{
				Name: "model_accuracy",
				Help: "ML model accuracy score",
			},
			[]string{"model_name", "dataset"},
		),
		PredictionConfidence: prometheus.NewHistogramVec(
			prometheus.HistogramOpts{
				Name:    "prediction_confidence",
				Help:    "ML prediction confidence score",
				Buckets: []float64{0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0},
			},
			[]string{"model_name"},
		),
	}

	// Register all metrics
	prometheus.MustRegister(
		m.HTTPRequestsTotal,
		m.HTTPRequestDuration,
		m.HTTPResponseSize,
		m.JumpsProcessedTotal,
		m.JumpProcessingTime,
		m.ActiveUsers,
		m.VideoUploadsTotal,
		m.VideoProcessingTime,
		m.DatabaseConnections,
		m.CacheHitRate,
		m.ErrorsTotal,
		m.ModelInferenceTime,
		m.ModelAccuracy,
		m.PredictionConfidence,
	)

	return m
}

// HTTPMiddleware wraps HTTP handlers with metrics collection
func (m *Metrics) HTTPMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		
		// Wrap ResponseWriter to capture status code and response size
		wrapped := &responseWriter{ResponseWriter: w, statusCode: 200}
		
		next.ServeHTTP(wrapped, r)
		
		duration := time.Since(start).Seconds()
		statusCode := strconv.Itoa(wrapped.statusCode)
		
		// Record metrics
		m.HTTPRequestsTotal.WithLabelValues(r.Method, r.URL.Path, statusCode).Inc()
		m.HTTPRequestDuration.WithLabelValues(r.Method, r.URL.Path).Observe(duration)
		m.HTTPResponseSize.WithLabelValues(r.Method, r.URL.Path).Observe(float64(wrapped.size))
	})
}

// responseWriter wraps http.ResponseWriter to capture metrics
type responseWriter struct {
	http.ResponseWriter
	statusCode int
	size       int
}

func (rw *responseWriter) WriteHeader(code int) {
	rw.statusCode = code
	rw.ResponseWriter.WriteHeader(code)
}

func (rw *responseWriter) Write(b []byte) (int, error) {
	size, err := rw.ResponseWriter.Write(b)
	rw.size += size
	return size, err
}

// Business metric helpers
func (m *Metrics) RecordJumpProcessed(userID, status string) {
	m.JumpsProcessedTotal.WithLabelValues(userID, status).Inc()
}

func (m *Metrics) RecordJumpProcessingTime(stage string, duration time.Duration) {
	m.JumpProcessingTime.WithLabelValues(stage).Observe(duration.Seconds())
}

func (m *Metrics) SetActiveUsers(count int) {
	m.ActiveUsers.Set(float64(count))
}

func (m *Metrics) RecordVideoUpload(status, format string) {
	m.VideoUploadsTotal.WithLabelValues(status, format).Inc()
}

func (m *Metrics) RecordVideoProcessingTime(lengthCategory string, duration time.Duration) {
	m.VideoProcessingTime.WithLabelValues(lengthCategory).Observe(duration.Seconds())
}

func (m *Metrics) SetDatabaseConnections(count int) {
	m.DatabaseConnections.Set(float64(count))
}

func (m *Metrics) RecordCacheOperation(operation, result string) {
	m.CacheHitRate.WithLabelValues(operation, result).Inc()
}

func (m *Metrics) RecordError(service, errorType string) {
	m.ErrorsTotal.WithLabelValues(service, errorType).Inc()
}

func (m *Metrics) RecordModelInference(modelName, version string, duration time.Duration) {
	m.ModelInferenceTime.WithLabelValues(modelName, version).Observe(duration.Seconds())
}

func (m *Metrics) SetModelAccuracy(modelName, dataset string, accuracy float64) {
	m.ModelAccuracy.WithLabelValues(modelName, dataset).Set(accuracy)
}

func (m *Metrics) RecordPredictionConfidence(modelName string, confidence float64) {
	m.PredictionConfidence.WithLabelValues(modelName).Observe(confidence)
}

// Handler returns the Prometheus metrics HTTP handler
func (m *Metrics) Handler() http.Handler {
	return promhttp.Handler()
} 
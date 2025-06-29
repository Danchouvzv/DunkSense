package tracing

import (
	"context"
	"fmt"
	"os"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/jaeger"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.17.0"
	"go.opentelemetry.io/otel/trace"
)

// TracingConfig holds configuration for tracing
type TracingConfig struct {
	ServiceName     string
	ServiceVersion  string
	Environment     string
	JaegerEndpoint  string
	SamplingRate    float64
	Enabled         bool
}

// Tracer wraps OpenTelemetry tracer with additional functionality
type Tracer struct {
	tracer   trace.Tracer
	provider *sdktrace.TracerProvider
	config   TracingConfig
}

// Common attribute keys
const (
	AttrUserID     = "user.id"
	AttrSessionID  = "session.id"
	AttrRequestID  = "request.id"
	AttrJumpID     = "jump.id"
	AttrVideoID    = "video.id"
	AttrModelName  = "ml.model.name"
	AttrModelVersion = "ml.model.version"
	AttrCacheKey   = "cache.key"
	AttrDBTable    = "db.table"
	AttrDBOperation = "db.operation"
	AttrKafkaTopic = "kafka.topic"
	AttrHTTPMethod = "http.method"
	AttrHTTPURL    = "http.url"
	AttrHTTPStatus = "http.status_code"
)

// NewTracer creates a new tracer with Jaeger exporter
func NewTracer(config TracingConfig) (*Tracer, error) {
	if !config.Enabled {
		return &Tracer{
			tracer: otel.Tracer(config.ServiceName),
			config: config,
		}, nil
	}

	// Create Jaeger exporter
	exporter, err := jaeger.New(
		jaeger.WithCollectorEndpoint(
			jaeger.WithEndpoint(config.JaegerEndpoint),
		),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create Jaeger exporter: %w", err)
	}

	// Create resource
	res, err := resource.New(
		context.Background(),
		resource.WithAttributes(
			semconv.ServiceNameKey.String(config.ServiceName),
			semconv.ServiceVersionKey.String(config.ServiceVersion),
			semconv.DeploymentEnvironmentKey.String(config.Environment),
		),
		resource.WithFromEnv(),
		resource.WithProcess(),
		resource.WithOS(),
		resource.WithContainer(),
		resource.WithHost(),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create resource: %w", err)
	}

	// Create trace provider
	provider := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exporter),
		sdktrace.WithResource(res),
		sdktrace.WithSampler(sdktrace.TraceIDRatioBased(config.SamplingRate)),
	)

	// Set global provider
	otel.SetTracerProvider(provider)
	otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
		propagation.TraceContext{},
		propagation.Baggage{},
	))

	return &Tracer{
		tracer:   provider.Tracer(config.ServiceName),
		provider: provider,
		config:   config,
	}, nil
}

// StartSpan starts a new span with the given name and options
func (t *Tracer) StartSpan(ctx context.Context, name string, opts ...trace.SpanStartOption) (context.Context, trace.Span) {
	return t.tracer.Start(ctx, name, opts...)
}

// StartHTTPSpan starts a span for HTTP requests
func (t *Tracer) StartHTTPSpan(ctx context.Context, method, url string) (context.Context, trace.Span) {
	spanName := fmt.Sprintf("HTTP %s", method)
	ctx, span := t.tracer.Start(ctx, spanName,
		trace.WithSpanKind(trace.SpanKindServer),
		trace.WithAttributes(
			attribute.String(AttrHTTPMethod, method),
			attribute.String(AttrHTTPURL, url),
		),
	)
	return ctx, span
}

// StartDatabaseSpan starts a span for database operations
func (t *Tracer) StartDatabaseSpan(ctx context.Context, operation, table string) (context.Context, trace.Span) {
	spanName := fmt.Sprintf("DB %s %s", operation, table)
	ctx, span := t.tracer.Start(ctx, spanName,
		trace.WithSpanKind(trace.SpanKindClient),
		trace.WithAttributes(
			attribute.String(AttrDBOperation, operation),
			attribute.String(AttrDBTable, table),
		),
	)
	return ctx, span
}

// StartCacheSpan starts a span for cache operations
func (t *Tracer) StartCacheSpan(ctx context.Context, operation, key string) (context.Context, trace.Span) {
	spanName := fmt.Sprintf("Cache %s", operation)
	ctx, span := t.tracer.Start(ctx, spanName,
		trace.WithSpanKind(trace.SpanKindClient),
		trace.WithAttributes(
			attribute.String("cache.operation", operation),
			attribute.String(AttrCacheKey, key),
		),
	)
	return ctx, span
}

// StartMLSpan starts a span for ML operations
func (t *Tracer) StartMLSpan(ctx context.Context, modelName, version string) (context.Context, trace.Span) {
	spanName := fmt.Sprintf("ML %s", modelName)
	ctx, span := t.tracer.Start(ctx, spanName,
		trace.WithSpanKind(trace.SpanKindInternal),
		trace.WithAttributes(
			attribute.String(AttrModelName, modelName),
			attribute.String(AttrModelVersion, version),
		),
	)
	return ctx, span
}

// StartKafkaSpan starts a span for Kafka operations
func (t *Tracer) StartKafkaSpan(ctx context.Context, operation, topic string) (context.Context, trace.Span) {
	spanName := fmt.Sprintf("Kafka %s %s", operation, topic)
	ctx, span := t.tracer.Start(ctx, spanName,
		trace.WithSpanKind(trace.SpanKindProducer),
		trace.WithAttributes(
			attribute.String("kafka.operation", operation),
			attribute.String(AttrKafkaTopic, topic),
		),
	)
	return ctx, span
}

// StartJumpProcessingSpan starts a span for jump processing
func (t *Tracer) StartJumpProcessingSpan(ctx context.Context, jumpID, stage string) (context.Context, trace.Span) {
	spanName := fmt.Sprintf("Jump Processing %s", stage)
	ctx, span := t.tracer.Start(ctx, spanName,
		trace.WithSpanKind(trace.SpanKindInternal),
		trace.WithAttributes(
			attribute.String(AttrJumpID, jumpID),
			attribute.String("processing.stage", stage),
		),
	)
	return ctx, span
}

// StartVideoProcessingSpan starts a span for video processing
func (t *Tracer) StartVideoProcessingSpan(ctx context.Context, videoID, operation string) (context.Context, trace.Span) {
	spanName := fmt.Sprintf("Video %s", operation)
	ctx, span := t.tracer.Start(ctx, spanName,
		trace.WithSpanKind(trace.SpanKindInternal),
		trace.WithAttributes(
			attribute.String(AttrVideoID, videoID),
			attribute.String("video.operation", operation),
		),
	)
	return ctx, span
}

// AddUserContext adds user-related attributes to the current span
func (t *Tracer) AddUserContext(ctx context.Context, userID, sessionID string) {
	span := trace.SpanFromContext(ctx)
	if span.IsRecording() {
		span.SetAttributes(
			attribute.String(AttrUserID, userID),
			attribute.String(AttrSessionID, sessionID),
		)
	}
}

// AddRequestContext adds request-related attributes to the current span
func (t *Tracer) AddRequestContext(ctx context.Context, requestID string) {
	span := trace.SpanFromContext(ctx)
	if span.IsRecording() {
		span.SetAttributes(
			attribute.String(AttrRequestID, requestID),
		)
	}
}

// AddError adds error information to the current span
func (t *Tracer) AddError(ctx context.Context, err error) {
	span := trace.SpanFromContext(ctx)
	if span.IsRecording() {
		span.RecordError(err)
		span.SetStatus(trace.StatusError, err.Error())
	}
}

// AddEvent adds an event to the current span
func (t *Tracer) AddEvent(ctx context.Context, name string, attributes ...attribute.KeyValue) {
	span := trace.SpanFromContext(ctx)
	if span.IsRecording() {
		span.AddEvent(name, trace.WithAttributes(attributes...))
	}
}

// FinishSpan finishes the span with optional attributes
func (t *Tracer) FinishSpan(span trace.Span, attributes ...attribute.KeyValue) {
	if span.IsRecording() && len(attributes) > 0 {
		span.SetAttributes(attributes...)
	}
	span.End()
}

// FinishHTTPSpan finishes an HTTP span with status code
func (t *Tracer) FinishHTTPSpan(span trace.Span, statusCode int) {
	if span.IsRecording() {
		span.SetAttributes(attribute.Int(AttrHTTPStatus, statusCode))
		
		// Set span status based on HTTP status code
		if statusCode >= 400 {
			span.SetStatus(trace.StatusError, fmt.Sprintf("HTTP %d", statusCode))
		} else {
			span.SetStatus(trace.StatusOK, "")
		}
	}
	span.End()
}

// GetTraceID returns the trace ID from the context
func (t *Tracer) GetTraceID(ctx context.Context) string {
	span := trace.SpanFromContext(ctx)
	if span.SpanContext().IsValid() {
		return span.SpanContext().TraceID().String()
	}
	return ""
}

// GetSpanID returns the span ID from the context
func (t *Tracer) GetSpanID(ctx context.Context) string {
	span := trace.SpanFromContext(ctx)
	if span.SpanContext().IsValid() {
		return span.SpanContext().SpanID().String()
	}
	return ""
}

// InjectHeaders injects tracing headers into a map
func (t *Tracer) InjectHeaders(ctx context.Context, headers map[string]string) {
	otel.GetTextMapPropagator().Inject(ctx, &HeaderCarrier{headers: headers})
}

// ExtractHeaders extracts tracing context from headers
func (t *Tracer) ExtractHeaders(ctx context.Context, headers map[string]string) context.Context {
	return otel.GetTextMapPropagator().Extract(ctx, &HeaderCarrier{headers: headers})
}

// Shutdown shuts down the tracer provider
func (t *Tracer) Shutdown(ctx context.Context) error {
	if t.provider != nil {
		return t.provider.Shutdown(ctx)
	}
	return nil
}

// HeaderCarrier implements TextMapCarrier for HTTP headers
type HeaderCarrier struct {
	headers map[string]string
}

func (hc *HeaderCarrier) Get(key string) string {
	return hc.headers[key]
}

func (hc *HeaderCarrier) Set(key, value string) {
	hc.headers[key] = value
}

func (hc *HeaderCarrier) Keys() []string {
	keys := make([]string, 0, len(hc.headers))
	for k := range hc.headers {
		keys = append(keys, k)
	}
	return keys
}

// LoadTracingConfig loads tracing configuration from environment
func LoadTracingConfig(serviceName string) TracingConfig {
	return TracingConfig{
		ServiceName:    serviceName,
		ServiceVersion: getEnv("SERVICE_VERSION", "1.0.0"),
		Environment:    getEnv("ENVIRONMENT", "development"),
		JaegerEndpoint: getEnv("JAEGER_ENDPOINT", "http://localhost:14268/api/traces"),
		SamplingRate:   getFloatEnv("TRACING_SAMPLING_RATE", 1.0),
		Enabled:        getBoolEnv("TRACING_ENABLED", true),
	}
}

// Helper functions
func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getBoolEnv(key string, defaultValue bool) bool {
	if value := os.Getenv(key); value != "" {
		return value == "true" || value == "1"
	}
	return defaultValue
}

func getFloatEnv(key string, defaultValue float64) float64 {
	if value := os.Getenv(key); value != "" {
		if parsed, err := fmt.Sscanf(value, "%f", &defaultValue); err == nil && parsed == 1 {
			return defaultValue
		}
	}
	return defaultValue
}

// Global tracer instance
var globalTracer *Tracer

// InitGlobalTracer initializes the global tracer
func InitGlobalTracer(config TracingConfig) error {
	tracer, err := NewTracer(config)
	if err != nil {
		return err
	}
	globalTracer = tracer
	return nil
}

// GetGlobalTracer returns the global tracer instance
func GetGlobalTracer() *Tracer {
	if globalTracer == nil {
		// Fallback to no-op tracer
		config := TracingConfig{
			ServiceName: "dunksense",
			Enabled:     false,
		}
		tracer, _ := NewTracer(config)
		return tracer
	}
	return globalTracer
} 
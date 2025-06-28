package logging

import (
	"context"
	"fmt"
	"os"
	"runtime"
	"strings"
	"time"

	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

// Logger wraps zap.Logger with additional functionality
type Logger struct {
	*zap.Logger
	level zapcore.Level
}

// LogLevel represents different log levels
type LogLevel string

const (
	DebugLevel LogLevel = "debug"
	InfoLevel  LogLevel = "info"
	WarnLevel  LogLevel = "warn"
	ErrorLevel LogLevel = "error"
	FatalLevel LogLevel = "fatal"
)

// ContextKey is used for context-based logging
type ContextKey string

const (
	RequestIDKey ContextKey = "request_id"
	UserIDKey    ContextKey = "user_id"
	TraceIDKey   ContextKey = "trace_id"
	ServiceKey   ContextKey = "service"
)

// NewLogger creates a new structured logger
func NewLogger(level LogLevel, environment string) (*Logger, error) {
	var zapLevel zapcore.Level
	switch level {
	case DebugLevel:
		zapLevel = zapcore.DebugLevel
	case InfoLevel:
		zapLevel = zapcore.InfoLevel
	case WarnLevel:
		zapLevel = zapcore.WarnLevel
	case ErrorLevel:
		zapLevel = zapcore.ErrorLevel
	case FatalLevel:
		zapLevel = zapcore.FatalLevel
	default:
		zapLevel = zapcore.InfoLevel
	}

	var config zap.Config
	if environment == "production" {
		config = zap.NewProductionConfig()
		config.EncoderConfig.TimeKey = "timestamp"
		config.EncoderConfig.EncodeTime = zapcore.ISO8601TimeEncoder
	} else {
		config = zap.NewDevelopmentConfig()
		config.EncoderConfig.EncodeLevel = zapcore.CapitalColorLevelEncoder
	}

	config.Level = zap.NewAtomicLevelAt(zapLevel)
	config.OutputPaths = []string{"stdout"}
	config.ErrorOutputPaths = []string{"stderr"}

	// Add caller information
	config.EncoderConfig.CallerKey = "caller"
	config.EncoderConfig.EncodeCaller = zapcore.ShortCallerEncoder

	// Add stack trace for errors
	config.EncoderConfig.StacktraceKey = "stacktrace"

	zapLogger, err := config.Build(
		zap.AddCallerSkip(1), // Skip wrapper functions
		zap.AddStacktrace(zapcore.ErrorLevel),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create logger: %w", err)
	}

	return &Logger{
		Logger: zapLogger,
		level:  zapLevel,
	}, nil
}

// WithContext returns a logger with context values
func (l *Logger) WithContext(ctx context.Context) *Logger {
	fields := []zap.Field{}

	if requestID := ctx.Value(RequestIDKey); requestID != nil {
		fields = append(fields, zap.String("request_id", requestID.(string)))
	}

	if userID := ctx.Value(UserIDKey); userID != nil {
		fields = append(fields, zap.String("user_id", userID.(string)))
	}

	if traceID := ctx.Value(TraceIDKey); traceID != nil {
		fields = append(fields, zap.String("trace_id", traceID.(string)))
	}

	if service := ctx.Value(ServiceKey); service != nil {
		fields = append(fields, zap.String("service", service.(string)))
	}

	return &Logger{
		Logger: l.Logger.With(fields...),
		level:  l.level,
	}
}

// WithFields returns a logger with additional fields
func (l *Logger) WithFields(fields map[string]interface{}) *Logger {
	zapFields := make([]zap.Field, 0, len(fields))
	for k, v := range fields {
		zapFields = append(zapFields, zap.Any(k, v))
	}

	return &Logger{
		Logger: l.Logger.With(zapFields...),
		level:  l.level,
	}
}

// WithError returns a logger with error field
func (l *Logger) WithError(err error) *Logger {
	return &Logger{
		Logger: l.Logger.With(zap.Error(err)),
		level:  l.level,
	}
}

// LogRequest logs HTTP request details
func (l *Logger) LogRequest(ctx context.Context, method, path string, statusCode int, duration time.Duration, size int64) {
	fields := []zap.Field{
		zap.String("method", method),
		zap.String("path", path),
		zap.Int("status_code", statusCode),
		zap.Duration("duration", duration),
		zap.Int64("response_size", size),
	}

	if requestID := ctx.Value(RequestIDKey); requestID != nil {
		fields = append(fields, zap.String("request_id", requestID.(string)))
	}

	if userID := ctx.Value(UserIDKey); userID != nil {
		fields = append(fields, zap.String("user_id", userID.(string)))
	}

	level := zapcore.InfoLevel
	if statusCode >= 400 {
		level = zapcore.WarnLevel
	}
	if statusCode >= 500 {
		level = zapcore.ErrorLevel
	}

	l.Logger.Log(level, "HTTP request", fields...)
}

// LogJumpProcessing logs jump processing events
func (l *Logger) LogJumpProcessing(ctx context.Context, jumpID, userID, stage string, duration time.Duration, metadata map[string]interface{}) {
	fields := []zap.Field{
		zap.String("jump_id", jumpID),
		zap.String("user_id", userID),
		zap.String("processing_stage", stage),
		zap.Duration("duration", duration),
	}

	for k, v := range metadata {
		fields = append(fields, zap.Any(k, v))
	}

	if requestID := ctx.Value(RequestIDKey); requestID != nil {
		fields = append(fields, zap.String("request_id", requestID.(string)))
	}

	l.Logger.Info("Jump processing", fields...)
}

// LogVideoUpload logs video upload events
func (l *Logger) LogVideoUpload(ctx context.Context, userID, videoID string, size int64, format string, success bool) {
	fields := []zap.Field{
		zap.String("user_id", userID),
		zap.String("video_id", videoID),
		zap.Int64("size", size),
		zap.String("format", format),
		zap.Bool("success", success),
	}

	if requestID := ctx.Value(RequestIDKey); requestID != nil {
		fields = append(fields, zap.String("request_id", requestID.(string)))
	}

	if success {
		l.Logger.Info("Video upload completed", fields...)
	} else {
		l.Logger.Warn("Video upload failed", fields...)
	}
}

// LogDatabaseOperation logs database operations
func (l *Logger) LogDatabaseOperation(ctx context.Context, operation, table string, duration time.Duration, rowsAffected int64, err error) {
	fields := []zap.Field{
		zap.String("operation", operation),
		zap.String("table", table),
		zap.Duration("duration", duration),
		zap.Int64("rows_affected", rowsAffected),
	}

	if requestID := ctx.Value(RequestIDKey); requestID != nil {
		fields = append(fields, zap.String("request_id", requestID.(string)))
	}

	if err != nil {
		fields = append(fields, zap.Error(err))
		l.Logger.Error("Database operation failed", fields...)
	} else {
		l.Logger.Debug("Database operation completed", fields...)
	}
}

// LogModelInference logs ML model inference events
func (l *Logger) LogModelInference(ctx context.Context, modelName, version string, duration time.Duration, confidence float64, success bool) {
	fields := []zap.Field{
		zap.String("model_name", modelName),
		zap.String("model_version", version),
		zap.Duration("duration", duration),
		zap.Float64("confidence", confidence),
		zap.Bool("success", success),
	}

	if requestID := ctx.Value(RequestIDKey); requestID != nil {
		fields = append(fields, zap.String("request_id", requestID.(string)))
	}

	if success {
		l.Logger.Info("Model inference completed", fields...)
	} else {
		l.Logger.Warn("Model inference failed", fields...)
	}
}

// LogCacheOperation logs cache operations
func (l *Logger) LogCacheOperation(ctx context.Context, operation, key string, hit bool, duration time.Duration) {
	fields := []zap.Field{
		zap.String("operation", operation),
		zap.String("key", key),
		zap.Bool("hit", hit),
		zap.Duration("duration", duration),
	}

	if requestID := ctx.Value(RequestIDKey); requestID != nil {
		fields = append(fields, zap.String("request_id", requestID.(string)))
	}

	l.Logger.Debug("Cache operation", fields...)
}

// LogError logs errors with context and stack trace
func (l *Logger) LogError(ctx context.Context, err error, message string, fields map[string]interface{}) {
	zapFields := []zap.Field{
		zap.Error(err),
		zap.String("error_type", getErrorType(err)),
	}

	// Add context fields
	if requestID := ctx.Value(RequestIDKey); requestID != nil {
		zapFields = append(zapFields, zap.String("request_id", requestID.(string)))
	}

	if userID := ctx.Value(UserIDKey); userID != nil {
		zapFields = append(zapFields, zap.String("user_id", userID.(string)))
	}

	// Add additional fields
	for k, v := range fields {
		zapFields = append(zapFields, zap.Any(k, v))
	}

	// Add caller information
	if pc, file, line, ok := runtime.Caller(1); ok {
		zapFields = append(zapFields, zap.String("caller", fmt.Sprintf("%s:%d %s", file, line, runtime.FuncForPC(pc).Name())))
	}

	l.Logger.Error(message, zapFields...)
}

// LogPanic logs panic recovery
func (l *Logger) LogPanic(ctx context.Context, recovered interface{}, stack []byte) {
	fields := []zap.Field{
		zap.Any("panic", recovered),
		zap.ByteString("stack", stack),
	}

	if requestID := ctx.Value(RequestIDKey); requestID != nil {
		fields = append(fields, zap.String("request_id", requestID.(string)))
	}

	l.Logger.Error("Panic recovered", fields...)
}

// LogSecurityEvent logs security-related events
func (l *Logger) LogSecurityEvent(ctx context.Context, event, userID, ipAddress string, metadata map[string]interface{}) {
	fields := []zap.Field{
		zap.String("security_event", event),
		zap.String("user_id", userID),
		zap.String("ip_address", ipAddress),
		zap.Time("timestamp", time.Now()),
	}

	for k, v := range metadata {
		fields = append(fields, zap.Any(k, v))
	}

	if requestID := ctx.Value(RequestIDKey); requestID != nil {
		fields = append(fields, zap.String("request_id", requestID.(string)))
	}

	l.Logger.Warn("Security event", fields...)
}

// LogPerformanceMetric logs performance metrics
func (l *Logger) LogPerformanceMetric(ctx context.Context, metric string, value float64, unit string, tags map[string]string) {
	fields := []zap.Field{
		zap.String("metric", metric),
		zap.Float64("value", value),
		zap.String("unit", unit),
	}

	for k, v := range tags {
		fields = append(fields, zap.String(k, v))
	}

	if requestID := ctx.Value(RequestIDKey); requestID != nil {
		fields = append(fields, zap.String("request_id", requestID.(string)))
	}

	l.Logger.Info("Performance metric", fields...)
}

// Sync flushes any buffered log entries
func (l *Logger) Sync() error {
	return l.Logger.Sync()
}

// SetLevel changes the log level dynamically
func (l *Logger) SetLevel(level LogLevel) {
	var zapLevel zapcore.Level
	switch level {
	case DebugLevel:
		zapLevel = zapcore.DebugLevel
	case InfoLevel:
		zapLevel = zapcore.InfoLevel
	case WarnLevel:
		zapLevel = zapcore.WarnLevel
	case ErrorLevel:
		zapLevel = zapcore.ErrorLevel
	case FatalLevel:
		zapLevel = zapcore.FatalLevel
	default:
		zapLevel = zapcore.InfoLevel
	}
	l.level = zapLevel
}

// IsLevelEnabled checks if a log level is enabled
func (l *Logger) IsLevelEnabled(level LogLevel) bool {
	var zapLevel zapcore.Level
	switch level {
	case DebugLevel:
		zapLevel = zapcore.DebugLevel
	case InfoLevel:
		zapLevel = zapcore.InfoLevel
	case WarnLevel:
		zapLevel = zapcore.WarnLevel
	case ErrorLevel:
		zapLevel = zapcore.ErrorLevel
	case FatalLevel:
		zapLevel = zapcore.FatalLevel
	default:
		zapLevel = zapcore.InfoLevel
	}
	return l.level <= zapLevel
}

// Helper functions
func getErrorType(err error) string {
	if err == nil {
		return "unknown"
	}
	
	errorType := fmt.Sprintf("%T", err)
	if strings.Contains(errorType, ".") {
		parts := strings.Split(errorType, ".")
		return parts[len(parts)-1]
	}
	return errorType
}

// Global logger instance
var globalLogger *Logger

// InitGlobalLogger initializes the global logger
func InitGlobalLogger(level LogLevel, environment string) error {
	logger, err := NewLogger(level, environment)
	if err != nil {
		return err
	}
	globalLogger = logger
	return nil
}

// GetGlobalLogger returns the global logger instance
func GetGlobalLogger() *Logger {
	if globalLogger == nil {
		// Fallback to default logger
		logger, _ := NewLogger(InfoLevel, "development")
		return logger
	}
	return globalLogger
}

// Context helper functions
func WithRequestID(ctx context.Context, requestID string) context.Context {
	return context.WithValue(ctx, RequestIDKey, requestID)
}

func WithUserID(ctx context.Context, userID string) context.Context {
	return context.WithValue(ctx, UserIDKey, userID)
}

func WithTraceID(ctx context.Context, traceID string) context.Context {
	return context.WithValue(ctx, TraceIDKey, traceID)
}

func WithService(ctx context.Context, service string) context.Context {
	return context.WithValue(ctx, ServiceKey, service)
} 
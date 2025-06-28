package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/Danchouvzv/DunkSense/backend/pkg/config"
	"github.com/Danchouvzv/DunkSense/backend/pkg/logging"
	"github.com/Danchouvzv/DunkSense/backend/pkg/metrics"
	"github.com/Danchouvzv/DunkSense/backend/pkg/monitoring"
)

func main() {
	// Load configuration
	cfg, err := config.LoadConfig()
	if err != nil {
		fmt.Printf("Failed to load configuration: %v\n", err)
		os.Exit(1)
	}

	// Initialize logger
	logger, err := logging.NewLogger(
		logging.LogLevel(cfg.Monitoring.LogLevel),
		cfg.Server.Environment,
	)
	if err != nil {
		fmt.Printf("Failed to initialize logger: %v\n", err)
		os.Exit(1)
	}
	defer logger.Sync()

	// Initialize global logger
	if err := logging.InitGlobalLogger(
		logging.LogLevel(cfg.Monitoring.LogLevel),
		cfg.Server.Environment,
	); err != nil {
		logger.Error("Failed to initialize global logger", err)
		os.Exit(1)
	}

	// Initialize metrics
	metricsCollector := monitoring.NewMetrics()

	// Initialize database store
	store, err := metrics.NewStore(cfg.Database.PostgresURI)
	if err != nil {
		logger.WithError(err).Error("Failed to initialize database store")
		os.Exit(1)
	}
	defer store.Close()

	// Initialize metrics service
	metricsService := metrics.NewService(store, logger)

	// Set up Gin router
	if cfg.Server.Environment == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	router := gin.New()

	// Add middleware
	router.Use(gin.Recovery())
	router.Use(metricsCollector.HTTPMiddleware)
	router.Use(requestIDMiddleware())
	router.Use(loggingMiddleware(logger))
	router.Use(corsMiddleware())

	// Health check endpoint
	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":    "healthy",
			"timestamp": time.Now().UTC(),
			"version":   "1.0.0",
		})
	})

	// Metrics endpoint for Prometheus
	router.GET("/metrics", gin.WrapH(metricsCollector.Handler()))

	// API routes
	v1 := router.Group("/api/v1")
	{
		// Jump metrics endpoints
		v1.POST("/jumps", metricsService.CreateJumpMetric)
		v1.GET("/jumps", metricsService.GetJumpMetrics)
		v1.GET("/jumps/:id", metricsService.GetJumpMetric)
		v1.PUT("/jumps/:id", metricsService.UpdateJumpMetric)
		v1.DELETE("/jumps/:id", metricsService.DeleteJumpMetric)

		// User metrics endpoints
		v1.GET("/users/:user_id/jumps", metricsService.GetUserJumpMetrics)
		v1.GET("/users/:user_id/stats", metricsService.GetUserStats)
		v1.GET("/users/:user_id/personal-best", metricsService.GetPersonalBest)

		// Analytics endpoints
		v1.GET("/analytics/daily", metricsService.GetDailyAnalytics)
		v1.GET("/analytics/weekly", metricsService.GetWeeklyAnalytics)
		v1.GET("/analytics/monthly", metricsService.GetMonthlyAnalytics)
	}

	// Create HTTP server
	server := &http.Server{
		Addr:         cfg.Server.HTTPPort,
		Handler:      router,
		ReadTimeout:  cfg.Server.ReadTimeout,
		WriteTimeout: cfg.Server.WriteTimeout,
	}

	// Start server in a goroutine
	go func() {
		logger.Info("Starting HTTP server", map[string]interface{}{
			"port":        cfg.Server.HTTPPort,
			"environment": cfg.Server.Environment,
		})

		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.WithError(err).Error("Failed to start HTTP server")
			os.Exit(1)
		}
	}()

	// Wait for interrupt signal to gracefully shutdown the server
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	logger.Info("Shutting down server...")

	// Create a deadline for shutdown
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Shutdown server gracefully
	if err := server.Shutdown(ctx); err != nil {
		logger.WithError(err).Error("Server forced to shutdown")
		os.Exit(1)
	}

	logger.Info("Server exited")
}

// requestIDMiddleware adds a unique request ID to each request
func requestIDMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		requestID := c.GetHeader("X-Request-ID")
		if requestID == "" {
			requestID = generateRequestID()
		}

		c.Header("X-Request-ID", requestID)
		
		// Add request ID to context
		ctx := logging.WithRequestID(c.Request.Context(), requestID)
		c.Request = c.Request.WithContext(ctx)

		c.Next()
	}
}

// loggingMiddleware logs HTTP requests
func loggingMiddleware(logger *logging.Logger) gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		path := c.Request.URL.Path
		method := c.Request.Method

		c.Next()

		duration := time.Since(start)
		statusCode := c.Writer.Status()
		responseSize := int64(c.Writer.Size())

		logger.LogRequest(
			c.Request.Context(),
			method,
			path,
			statusCode,
			duration,
			responseSize,
		)
	}
}

// corsMiddleware handles CORS headers
func corsMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Origin, Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, Authorization, X-Request-ID")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}

		c.Next()
	}
}

// generateRequestID generates a unique request ID
func generateRequestID() string {
	return fmt.Sprintf("%d", time.Now().UnixNano())
} 
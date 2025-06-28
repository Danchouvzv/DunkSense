package main

import (
	"context"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/Danchouvzv/DunkSense/backend/pkg/metrics"
	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
	"go.uber.org/zap"
	"google.golang.org/grpc"
)

const (
	defaultGRPCPort = ":50051"
	defaultHTTPPort = ":8080"
)

type Server struct {
	grpcServer   *grpc.Server
	httpServer   *http.Server
	metricsStore *metrics.Store
	logger       *zap.Logger
	upgrader     websocket.Upgrader
}

func main() {
	// Initialize logger
	logger, err := zap.NewProduction()
	if err != nil {
		log.Fatal("Failed to initialize logger:", err)
	}
	defer logger.Sync()

	// Initialize metrics store
	store, err := metrics.NewStore()
	if err != nil {
		logger.Fatal("Failed to initialize metrics store", zap.Error(err))
	}

	// Create server
	server := &Server{
		metricsStore: store,
		logger:       logger,
		upgrader: websocket.Upgrader{
			CheckOrigin: func(r *http.Request) bool {
				// In production, implement proper origin checking
				return true
			},
		},
	}

	// Start servers
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Start gRPC server
	go server.startGRPCServer(ctx)

	// Start HTTP/WebSocket server
	go server.startHTTPServer(ctx)

	// Wait for interrupt signal
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	<-sigChan

	logger.Info("Shutting down servers...")
	cancel()

	// Graceful shutdown
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer shutdownCancel()

	if server.httpServer != nil {
		server.httpServer.Shutdown(shutdownCtx)
	}
	if server.grpcServer != nil {
		server.grpcServer.GracefulStop()
	}

	logger.Info("Servers shut down successfully")
}

func (s *Server) startGRPCServer(ctx context.Context) {
	grpcPort := os.Getenv("GRPC_PORT")
	if grpcPort == "" {
		grpcPort = defaultGRPCPort
	}

	lis, err := net.Listen("tcp", grpcPort)
	if err != nil {
		s.logger.Fatal("Failed to listen on gRPC port", zap.String("port", grpcPort), zap.Error(err))
	}

	s.grpcServer = grpc.NewServer()
	
	// Register services here
	// metrics.RegisterMetricsServiceServer(s.grpcServer, s)

	s.logger.Info("Starting gRPC server", zap.String("port", grpcPort))
	
	if err := s.grpcServer.Serve(lis); err != nil {
		s.logger.Error("gRPC server failed", zap.Error(err))
	}
}

func (s *Server) startHTTPServer(ctx context.Context) {
	httpPort := os.Getenv("HTTP_PORT")
	if httpPort == "" {
		httpPort = defaultHTTPPort
	}

	gin.SetMode(gin.ReleaseMode)
	router := gin.New()
	router.Use(gin.Logger(), gin.Recovery())

	// Health check endpoint
	router.GET("/health", s.healthCheck)
	
	// WebSocket endpoint for real-time metrics
	router.GET("/ws/metrics", s.handleWebSocket)
	
	// REST API endpoints
	api := router.Group("/api/v1")
	{
		api.POST("/metrics", s.submitMetrics)
		api.GET("/metrics/:athleteId", s.getMetrics)
		api.GET("/metrics/:athleteId/summary", s.getMetricsSummary)
	}

	s.httpServer = &http.Server{
		Addr:    httpPort,
		Handler: router,
	}

	s.logger.Info("Starting HTTP server", zap.String("port", httpPort))
	
	if err := s.httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		s.logger.Error("HTTP server failed", zap.Error(err))
	}
}

func (s *Server) healthCheck(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"status":    "healthy",
		"service":   "metrics-svc",
		"timestamp": time.Now().Unix(),
	})
}

func (s *Server) handleWebSocket(c *gin.Context) {
	conn, err := s.upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		s.logger.Error("WebSocket upgrade failed", zap.Error(err))
		return
	}
	defer conn.Close()

	athleteID := c.Query("athleteId")
	if athleteID == "" {
		conn.WriteMessage(websocket.TextMessage, []byte(`{"error": "athleteId required"}`))
		return
	}

	s.logger.Info("WebSocket connection established", zap.String("athleteId", athleteID))

	// Handle WebSocket messages
	for {
		messageType, message, err := conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				s.logger.Error("WebSocket error", zap.Error(err))
			}
			break
		}

		// Echo message back for now (implement real-time metrics processing)
		if err := conn.WriteMessage(messageType, message); err != nil {
			s.logger.Error("WebSocket write error", zap.Error(err))
			break
		}
	}
}

func (s *Server) submitMetrics(c *gin.Context) {
	var req metrics.SubmitRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Process metrics submission
	if err := s.metricsStore.Submit(c.Request.Context(), &req); err != nil {
		s.logger.Error("Failed to submit metrics", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to submit metrics"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"status": "success"})
}

func (s *Server) getMetrics(c *gin.Context) {
	athleteID := c.Param("athleteId")
	if athleteID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "athleteId required"})
		return
	}

	metrics, err := s.metricsStore.GetByAthleteID(c.Request.Context(), athleteID)
	if err != nil {
		s.logger.Error("Failed to get metrics", zap.String("athleteId", athleteID), zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get metrics"})
		return
	}

	c.JSON(http.StatusOK, metrics)
}

func (s *Server) getMetricsSummary(c *gin.Context) {
	athleteID := c.Param("athleteId")
	if athleteID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "athleteId required"})
		return
	}

	summary, err := s.metricsStore.GetSummary(c.Request.Context(), athleteID)
	if err != nil {
		s.logger.Error("Failed to get metrics summary", zap.String("athleteId", athleteID), zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get metrics summary"})
		return
	}

	c.JSON(http.StatusOK, summary)
} 
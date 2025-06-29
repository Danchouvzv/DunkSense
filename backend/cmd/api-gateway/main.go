package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
)

func main() {
	// Check for health check flag
	if len(os.Args) > 1 && os.Args[1] == "-health-check" {
		fmt.Println("API Gateway service is healthy")
		os.Exit(0)
	}

	// Set up Gin router
	r := gin.Default()

	// Health endpoints
	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":    "healthy",
			"service":   "api-gateway",
			"timestamp": time.Now().Unix(),
		})
	})

	r.GET("/ready", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status": "ready",
			"service": "api-gateway",
		})
	})

	// API Gateway endpoints
	r.GET("/api/v1/status", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"message": "DunkSense API Gateway",
			"version": "1.0.0",
			"status":  "running",
		})
	})

	// Proxy endpoints (placeholder)
	r.Any("/api/v1/metrics/*path", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"message": "Metrics service proxy",
			"path":    c.Param("path"),
		})
	})

	r.Any("/api/v1/ml/*path", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"message": "ML Pipeline proxy",
			"path":    c.Param("path"),
		})
	})

	// Metrics endpoint
	r.GET("/metrics", func(c *gin.Context) {
		c.String(http.StatusOK, "# API Gateway Metrics\ngateway_requests_total 0\n")
	})

	// Start server
	port := os.Getenv("PORT")
	if port == "" {
		port = "8082"
	}

	srv := &http.Server{
		Addr:    ":" + port,
		Handler: r,
	}

	// Graceful shutdown
	go func() {
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("listen: %s\n", err)
		}
	}()

	log.Printf("API Gateway service started on port %s", port)

	// Wait for interrupt signal to gracefully shutdown the server
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("Shutting down API Gateway service...")

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Fatal("API Gateway service forced to shutdown:", err)
	}

	log.Println("API Gateway service exited")
} 
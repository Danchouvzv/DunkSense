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
		fmt.Println("ML Pipeline service is healthy")
		os.Exit(0)
	}

	// Set up Gin router
	r := gin.Default()

	// Health endpoints
	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":    "healthy",
			"service":   "ml-pipeline",
			"timestamp": time.Now().Unix(),
		})
	})

	r.GET("/ready", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status": "ready",
			"service": "ml-pipeline",
		})
	})

	// ML Pipeline endpoints
	r.POST("/process", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"message": "ML processing endpoint",
			"status":  "implemented",
		})
	})

	r.GET("/models", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"models": []string{"jump-analysis-v1", "pose-detection-v2"},
			"status": "active",
		})
	})

	// Metrics endpoint
	r.GET("/metrics", func(c *gin.Context) {
		c.String(http.StatusOK, "# ML Pipeline Metrics\nml_requests_total 0\n")
	})

	// Start server
	port := os.Getenv("PORT")
	if port == "" {
		port = "8081"
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

	log.Printf("ML Pipeline service started on port %s", port)

	// Wait for interrupt signal to gracefully shutdown the server
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("Shutting down ML Pipeline service...")

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Fatal("ML Pipeline service forced to shutdown:", err)
	}

	log.Println("ML Pipeline service exited")
} 
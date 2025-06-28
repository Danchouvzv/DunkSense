# DunkSense Backend Makefile

.PHONY: help dev-setup build run-local test clean docker-build docker-run proto-gen

# Default target
help:
	@echo "Available commands:"
	@echo "  dev-setup    - Setup development environment"
	@echo "  build        - Build all services"
	@echo "  run-local    - Run services locally"
	@echo "  test         - Run tests"
	@echo "  clean        - Clean build artifacts"
	@echo "  docker-build - Build Docker images"
	@echo "  docker-run   - Run services in Docker"
	@echo "  proto-gen    - Generate gRPC code from proto files"

# Variables
GO_VERSION := 1.23
DOCKER_REGISTRY := ghcr.io/danchouvzv
SERVICES := auth-svc metrics-svc plan-svc media-svc

# Development setup
dev-setup:
	@echo "Setting up development environment..."
	go mod download
	go mod tidy
	@echo "Installing development tools..."
	go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
	go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
	go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest

# Build all services
build:
	@echo "Building all services..."
	@for service in $(SERVICES); do \
		echo "Building $$service..."; \
		cd cmd/$$service && go build -o ../../bin/$$service . && cd ../..; \
	done

# Run services locally
run-local:
	@echo "Starting local development environment..."
	docker-compose -f docker-compose.dev.yml up -d
	@echo "Services started. Check logs with: docker-compose -f docker-compose.dev.yml logs -f"

# Run tests
test:
	@echo "Running tests..."
	go test -v -race -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -rf bin/
	rm -f coverage.out coverage.html
	go clean -cache

# Docker build
docker-build:
	@echo "Building Docker images..."
	@for service in $(SERVICES); do \
		echo "Building Docker image for $$service..."; \
		docker build -f cmd/$$service/Dockerfile -t $(DOCKER_REGISTRY)/$$service:latest .; \
	done

# Docker run
docker-run:
	@echo "Running services in Docker..."
	docker-compose up -d

# Generate gRPC code
proto-gen:
	@echo "Generating gRPC code from proto files..."
	@if [ ! -d "proto" ]; then mkdir proto; fi
	protoc --go_out=. --go_opt=paths=source_relative \
		--go-grpc_out=. --go-grpc_opt=paths=source_relative \
		proto/*.proto

# Lint code
lint:
	@echo "Running linter..."
	golangci-lint run

# Format code
fmt:
	@echo "Formatting code..."
	go fmt ./...

# Security scan
security:
	@echo "Running security scan..."
	go install github.com/securecodewarrior/gosec/v2/cmd/gosec@latest
	gosec ./...

# Database migrations
migrate-up:
	@echo "Running database migrations..."
	go run cmd/migrate/main.go up

migrate-down:
	@echo "Rolling back database migrations..."
	go run cmd/migrate/main.go down

# Generate mocks for testing
mocks:
	@echo "Generating mocks..."
	go install github.com/golang/mock/mockgen@latest
	mockgen -source=pkg/auth/service.go -destination=pkg/auth/mocks/service_mock.go
	mockgen -source=pkg/metrics/service.go -destination=pkg/metrics/mocks/service_mock.go

# Performance benchmarks
bench:
	@echo "Running benchmarks..."
	go test -bench=. -benchmem ./...

# Install dependencies
deps:
	@echo "Installing dependencies..."
	go mod download
	go mod verify

# Update dependencies
deps-update:
	@echo "Updating dependencies..."
	go get -u ./...
	go mod tidy

# Create new service template
new-service:
	@read -p "Enter service name: " service; \
	mkdir -p cmd/$$service; \
	echo "package main\n\nimport \"fmt\"\n\nfunc main() {\n\tfmt.Println(\"$$service service started\")\n}" > cmd/$$service/main.go

# Check for outdated dependencies
deps-check:
	@echo "Checking for outdated dependencies..."
	go list -u -m all 
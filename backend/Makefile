# DunkSense Backend Makefile

.PHONY: help dev-setup build run-local test clean docker-build docker-run proto-gen migrate-up migrate-down lint fmt vet deps dev prod benchmark integration-test e2e-test

# Variables
APP_NAME := dunksense-backend
VERSION := $(shell git describe --tags --always --dirty)
BUILD_TIME := $(shell date -u '+%Y-%m-%d_%H:%M:%S')
DOCKER_IMAGE := $(APP_NAME):$(VERSION)
DOCKER_REGISTRY := ghcr.io/danchouvzv
SERVICES := auth-svc metrics-svc plan-svc media-svc
GO_VERSION := 1.21

# Build flags
LDFLAGS := -X main.Version=$(VERSION) -X main.BuildTime=$(BUILD_TIME)
BUILD_FLAGS := -ldflags "$(LDFLAGS)"

# Go commands
GO_BUILD := go build $(BUILD_FLAGS)
GO_TEST := go test -v -race -timeout=5m
GO_CLEAN := go clean
GO_DEPS := go mod download
GO_LINT := golangci-lint run
GO_FMT := go fmt
GO_VET := go vet

# Directories
CMD_DIR := ./cmd
PKG_DIR := ./pkg
BUILD_DIR := ./build
MIGRATION_DIR := ./migrations

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
	@echo "  migrate-up   - Run database migrations"
	@echo "  migrate-down - Rollback database migrations"
	@echo "  lint         - Lint code"
	@echo "  fmt          - Format code"
	@echo "  vet          - Vet code"
	@echo "  deps         - Install dependencies"
	@echo "  dev          - Run in development mode"
	@echo "  prod         - Build for production"
	@echo "  benchmark    - Run benchmark tests"
	@echo "  integration-test - Run integration tests"
	@echo "  e2e-test     - Run end-to-end tests"
	@echo "  dev-env-up   - Start development environment"
	@echo "  dev-env-down - Stop development environment"
	@echo "  health-check - Perform health check"
	@echo "  security-scan - Run security scan"
	@echo "  install-tools - Install development tools"
	@echo "  pre-commit   - Run pre-commit checks"
	@echo "  ci           - Run CI pipeline"
	@echo "  prod         - Build for production"
	@echo "  run          - Run the application"

# Development setup
dev-setup:
	@echo "Setting up development environment..."
	$(GO_DEPS)
	@echo "Installing development tools..."
	$(GO_DEPS)
	$(GO_LINT)
	$(GO_FMT) ./...
	$(GO_VET) ./...

# Build all services
build:
	@echo "Building all services..."
	@for service in $(SERVICES); do \
		echo "Building $$service..."; \
		cd cmd/$$service && $(GO_BUILD) -o ../../bin/$$service . && cd ../..; \
	done

# Run services locally
run-local:
	@echo "Starting local development environment..."
	docker-compose -f docker-compose.dev.yml up -d
	@echo "Services started. Check logs with: docker-compose -f docker-compose.dev.yml logs -f"

# Run tests
test:
	@echo "Running tests..."
	$(GO_TEST) ./...

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	$(GO_CLEAN)
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
	$(GO_LINT)

# Format code
fmt:
	@echo "Formatting code..."
	$(GO_FMT) ./...

# Vet code
vet:
	@echo "Vetting code..."
	$(GO_VET) ./...

# Security scan
security:
	@echo "Running security scan..."
	go install github.com/securecodewarrior/gosec/v2/cmd/gosec@latest
	gosec ./...

# Database migrations
migrate-up:
	@echo "Running database migrations up..."
	migrate -path $(MIGRATION_DIR) -database "$(DATABASE_URL)" up

migrate-down:
	@echo "Running database migrations down..."
	migrate -path $(MIGRATION_DIR) -database "$(DATABASE_URL)" down

# Generate mocks for testing
mocks:
	@echo "Generating mocks..."
	go install github.com/golang/mock/mockgen@latest
	mockgen -source=pkg/auth/service.go -destination=pkg/auth/mocks/service_mock.go
	mockgen -source=pkg/metrics/service.go -destination=pkg/metrics/mocks/service_mock.go

# Performance benchmarks
bench:
	@echo "Running benchmarks..."
	$(GO_TEST) -bench=. -benchmem ./...

# Install dependencies
deps:
	@echo "Installing dependencies..."
	$(GO_DEPS)

# Update dependencies
deps-update:
	@echo "Updating dependencies..."
	$(GO_DEPS)
	$(GO_LINT)
	$(GO_FMT) ./...
	$(GO_VET) ./...

# Create new service template
new-service:
	@read -p "Enter service name: " service; \
	mkdir -p cmd/$$service; \
	echo "package main\n\nimport \"fmt\"\n\nfunc main() {\n\tfmt.Println(\"$$service service started\")\n}" > cmd/$$service/main.go

# Check for outdated dependencies
deps-check:
	@echo "Checking for outdated dependencies..."
	$(GO_DEPS)

# Run in development mode
dev:
	@echo "Running in development mode..."
	$(GO_BUILD) -o $(BUILD_DIR)/$(APP_NAME) $(CMD_DIR)/metrics-svc/main.go
	$(BUILD_DIR)/$(APP_NAME)

# Build for production
build-prod:
	@echo "Building for production..."
	mkdir -p $(BUILD_DIR)
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 $(GO_BUILD) -a -installsuffix cgo -o $(BUILD_DIR)/$(APP_NAME)-linux-amd64 $(CMD_DIR)/metrics-svc/main.go
	@echo "Production build completed: $(BUILD_DIR)/$(APP_NAME)-linux-amd64"

# Run the application
run: build
	@echo "Running application..."
	$(BUILD_DIR)/$(APP_NAME)

# Run tests with coverage
test-coverage:
	@echo "Running tests with coverage..."
	$(GO_TEST) -coverprofile=coverage.out -covermode=atomic ./...
	$(GO_TEST) -bench=. -benchmem ./...
	go tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report generated: coverage.html"

# Run benchmark tests
benchmark:
	@echo "Running benchmark tests..."
	$(GO_TEST) -bench=. -benchmem ./...
	@echo "Benchmark tests completed"

# Run integration tests
integration-test:
	@echo "Running integration tests..."
	$(GO_TEST) -tags=integration ./...
	@echo "Integration tests completed"

# Run end-to-end tests
e2e-test:
	@echo "Running end-to-end tests..."
	$(GO_TEST) -tags=e2e ./...
	@echo "End-to-end tests completed"

# Development environment
dev-env-up:
	@echo "Starting development environment..."
	docker-compose -f docker-compose.dev.yml up -d
	@echo "Development environment started"

dev-env-down:
	@echo "Stopping development environment..."
	docker-compose -f docker-compose.dev.yml down
	@echo "Development environment stopped"

dev-env-logs:
	@echo "Showing development environment logs..."
	docker-compose -f docker-compose.dev.yml logs -f

# Production environment
prod-env-up:
	@echo "Starting production environment..."
	docker-compose -f docker-compose.prod.yml up -d
	@echo "Production environment started"

prod-env-down:
	@echo "Stopping production environment..."
	docker-compose -f docker-compose.prod.yml down
	@echo "Production environment stopped"

# Monitoring and health checks
health-check:
	@echo "Performing health check..."
	curl -f http://localhost:8080/health || exit 1
	@echo "Health check passed"

metrics-check:
	@echo "Checking metrics endpoint..."
	curl -f http://localhost:8080/metrics || exit 1
	@echo "Metrics endpoint is healthy"

# Load testing
load-test:
	@echo "Running load tests..."
	k6 run tests/load/basic.js
	@echo "Load tests completed"

# Security scanning
security-scan:
	@echo "Running security scan..."
	$(GO_LINT)
	$(GO_VET) ./...
	$(GO_FMT) ./...
	gosec ./...
	@echo "Security scan completed"

# Dependency vulnerability check
vuln-check:
	@echo "Checking for vulnerabilities..."
	$(GO_DEPS)
	go list -json -deps ./... | nancy sleuth
	@echo "Vulnerability check completed"

# Generate documentation
docs:
	@echo "Generating documentation..."
	godoc -http=:6060 &
	@echo "Documentation server started at http://localhost:6060"

# Generate API documentation
api-docs:
	@echo "Generating API documentation..."
	swag init -g $(CMD_DIR)/metrics-svc/main.go
	@echo "API documentation generated"

# Install development tools
install-tools:
	@echo "Installing development tools..."
	$(GO_DEPS)
	$(GO_LINT)
	$(GO_FMT) ./...
	$(GO_VET) ./...
	go install github.com/golang-migrate/migrate/v4/cmd/migrate@latest
	go install github.com/swaggo/swag/cmd/swag@latest
	go install github.com/securecodewarrior/gosec/v2/cmd/gosec@latest
	@echo "Development tools installed"

# Pre-commit checks
pre-commit: clean deps fmt vet lint test
	@echo "Pre-commit checks passed"

# CI/CD pipeline simulation
ci: clean deps fmt vet lint test-coverage benchmark security-scan build-prod
	@echo "CI pipeline completed successfully"

# Release preparation
release: clean deps test-coverage build-prod docker-build
	@echo "Release preparation completed"
	@echo "Version: $(VERSION)"
	@echo "Build time: $(BUILD_TIME)"

# Docker push
docker-push:
	@echo "Pushing Docker image to registry..."
	docker tag $(DOCKER_IMAGE) $(DOCKER_REGISTRY)/$(DOCKER_IMAGE)
	docker push $(DOCKER_REGISTRY)/$(DOCKER_IMAGE)
	@echo "Docker image pushed successfully"

# Create new migration
migrate-create:
	@echo "Creating new migration: $(name)"
	migrate create -ext sql -dir $(MIGRATION_DIR) $(name)
	@echo "Migration created successfully" 
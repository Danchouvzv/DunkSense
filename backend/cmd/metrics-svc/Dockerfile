# Build stage
FROM golang:1.21-alpine AS builder

# Install build dependencies
RUN apk add --no-cache \
    git \
    ca-certificates \
    tzdata \
    gcc \
    musl-dev

# Set working directory
WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download && go mod verify

# Copy source code
COPY . .

# Build the application
RUN CGO_ENABLED=1 GOOS=linux go build \
    -a -installsuffix cgo \
    -ldflags='-w -s -extldflags "-static"' \
    -o metrics-svc \
    ./cmd/metrics-svc

# Development stage
FROM builder AS development

# Install development tools
RUN go install github.com/cosmtrek/air@latest && \
    go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest

# Set environment
ENV ENVIRONMENT=development
ENV GIN_MODE=debug

# Expose ports
EXPOSE 8080 50051

# Use air for hot reloading
CMD ["air", "-c", ".air.toml"]

# Production stage
FROM alpine:3.18 AS production

# Install runtime dependencies
RUN apk --no-cache add \
    ca-certificates \
    tzdata \
    curl \
    && update-ca-certificates

# Create non-root user
RUN addgroup -g 1001 -S dunksense && \
    adduser -u 1001 -S dunksense -G dunksense

# Set timezone
ENV TZ=UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Create directories
RUN mkdir -p /app/logs /app/certs && \
    chown -R dunksense:dunksense /app

# Set working directory
WORKDIR /app

# Copy binary from builder stage
COPY --from=builder --chown=dunksense:dunksense /app/metrics-svc .

# Copy configuration files
COPY --chown=dunksense:dunksense ./configs/ ./configs/

# Switch to non-root user
USER dunksense

# Set environment
ENV ENVIRONMENT=production
ENV GIN_MODE=release

# Expose ports
EXPOSE 8080 50051

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Run the application
CMD ["./metrics-svc"] 
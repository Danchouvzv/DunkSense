# DunkSense Backend

## 🏀 Overview

DunkSense Backend is a high-performance microservices architecture built with Go, designed to process basketball jump metrics with AI-powered analysis. The system provides real-time analytics, progress tracking, and personalized recommendations for basketball players.

## 🚀 Features

- **Real-time Jump Analysis**: Process video data and extract jump metrics
- **AI-Powered Insights**: Machine learning models for performance analysis
- **Scalable Architecture**: Microservices with horizontal scaling
- **Comprehensive Monitoring**: Prometheus, Grafana, and Jaeger integration
- **Security First**: JWT authentication, rate limiting, and TLS encryption
- **High Performance**: Optimized for low latency and high throughput

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   iOS Client    │    │   Web Client    │    │  Admin Panel    │
└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘
          │                      │                      │
          └──────────────────────┼──────────────────────┘
                                 │
                    ┌─────────────┴─────────────┐
                    │       Nginx (LB)          │
                    └─────────────┬─────────────┘
                                 │
                    ┌─────────────┴─────────────┐
                    │    Metrics Service        │
                    │   (Go + Gin + gRPC)      │
                    └─────────────┬─────────────┘
                                 │
        ┌────────────────────────┼────────────────────────┐
        │                       │                        │
┌───────┴───────┐    ┌─────────┴─────────┐    ┌─────────┴─────────┐
│   PostgreSQL   │    │     MongoDB       │    │      Redis        │
│  (Metrics DB)  │    │  (Analytics DB)   │    │     (Cache)       │
└───────────────┘    └───────────────────┘    └───────────────────┘
        │                       │                        │
        └────────────────────────┼────────────────────────┘
                                 │
                    ┌─────────────┴─────────────┐
                    │       Kafka Queue         │
                    └───────────────────────────┘
```

## 📋 Prerequisites

- **Go 1.21+**
- **Docker & Docker Compose**
- **PostgreSQL 15+**
- **Redis 7+**
- **MongoDB 7+**
- **Make** (for build automation)

## 🛠️ Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/Danchouvzv/DunkSense.git
cd DunkSense/backend
```

### 2. Environment Setup

```bash
# Copy environment template
cp .env.example .env

# Edit environment variables
nano .env
```

### 3. Development Setup

```bash
# Install dependencies
make deps

# Run development environment
make dev
```

### 4. Production Setup

```bash
# Build production image
make build-prod

# Deploy with Docker Compose
make deploy-prod
```

## 🔧 Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `ENVIRONMENT` | Runtime environment | `development` |
| `HTTP_PORT` | HTTP server port | `:8080` |
| `GRPC_PORT` | gRPC server port | `:50051` |
| `POSTGRES_URI` | PostgreSQL connection string | Required |
| `MONGODB_URI` | MongoDB connection string | Required |
| `REDIS_URL` | Redis connection string | Required |
| `JWT_SECRET` | JWT signing secret | Required |
| `LOG_LEVEL` | Logging level | `info` |

### Database Configuration

```yaml
# PostgreSQL (Primary metrics storage)
POSTGRES_URI: postgres://user:pass@localhost:5432/dunksense?sslmode=require

# MongoDB (Analytics and ML data)
MONGODB_URI: mongodb://user:pass@localhost:27017/dunksense?authSource=admin

# Redis (Caching and sessions)
REDIS_URL: redis://localhost:6379/0
```

## 🚀 Deployment

### Development

```bash
# Start all services
make dev

# Run tests
make test

# Run with hot reload
make watch
```

### Production

```bash
# Build production image
docker build -t dunksense-backend -f cmd/metrics-svc/Dockerfile .

# Deploy with Docker Compose
docker-compose -f docker-compose.prod.yml up -d

# Check health
curl http://localhost:8080/health
```

### Kubernetes

```bash
# Apply manifests
kubectl apply -f k8s/

# Check status
kubectl get pods -n dunksense
```

## 📊 Monitoring

### Metrics

- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000
- **Jaeger**: http://localhost:16686

### Health Checks

```bash
# Application health
curl http://localhost:8080/health

# Metrics endpoint
curl http://localhost:8080/metrics

# Database status
make health-check
```

## 🧪 Testing

### Unit Tests

```bash
# Run all tests
make test

# Run with coverage
make test-coverage

# Run specific package
go test ./pkg/metrics/...
```

### Integration Tests

```bash
# Start test environment
make test-env

# Run integration tests
make integration-test

# Load testing
make load-test
```

### Benchmarks

```bash
# Run benchmarks
make benchmark

# Profile CPU usage
make profile-cpu
```

## 📡 API Documentation

### REST API

Base URL: `https://api.dunksense.ai/api/v1`

#### Authentication

```bash
# Login
POST /auth/login
{
  "email": "user@example.com",
  "password": "password"
}

# Response
{
  "token": "jwt_token_here",
  "user": {...}
}
```

#### Jump Metrics

```bash
# Create jump metric
POST /metrics/jumps
Authorization: Bearer <token>
{
  "height": 75.5,
  "hang_time": 0.85,
  "video_url": "https://...",
  "timestamp": "2024-01-15T10:30:00Z"
}

# Get user metrics
GET /metrics/users/{user_id}/stats?from=2024-01-01&to=2024-01-31
Authorization: Bearer <token>
```

### gRPC API

```protobuf
service MetricsService {
  rpc CreateJumpMetric(CreateJumpMetricRequest) returns (JumpMetric);
  rpc GetUserStats(GetUserStatsRequest) returns (UserStats);
  rpc GetPersonalBest(GetPersonalBestRequest) returns (JumpMetric);
}
```

## 🔐 Security

### Authentication

- **JWT Tokens**: Stateless authentication
- **Refresh Tokens**: Secure token renewal
- **Rate Limiting**: API abuse prevention

### Authorization

```go
// Role-based access control
type Role string

const (
    RoleUser    Role = "user"
    RoleCoach   Role = "coach"
    RoleAdmin   Role = "admin"
)
```

### Data Protection

- **TLS Encryption**: All communications encrypted
- **Data Anonymization**: Personal data protection
- **Audit Logging**: Security event tracking

## 🔧 Development

### Code Style

```bash
# Format code
make fmt

# Lint code
make lint

# Run static analysis
make vet
```

### Database Migrations

```bash
# Create migration
make migrate-create name=add_jump_metrics

# Run migrations
make migrate-up

# Rollback migrations
make migrate-down
```

### Adding New Features

1. **Create Feature Branch**
   ```bash
   git checkout -b feature/new-feature
   ```

2. **Write Tests First**
   ```bash
   # Create test file
   touch pkg/feature/feature_test.go
   ```

3. **Implement Feature**
   ```bash
   # Create implementation
   touch pkg/feature/feature.go
   ```

4. **Update Documentation**
   ```bash
   # Update API docs
   nano docs/api.md
   ```

## 📈 Performance

### Optimization Tips

- **Database Indexing**: Ensure proper indexes
- **Connection Pooling**: Optimize database connections
- **Caching Strategy**: Redis for frequently accessed data
- **Async Processing**: Use Kafka for heavy operations

### Monitoring Metrics

- **Response Time**: < 100ms for API calls
- **Throughput**: 1000+ requests/second
- **Error Rate**: < 0.1%
- **CPU Usage**: < 70%
- **Memory Usage**: < 80%

## 🐛 Troubleshooting

### Common Issues

1. **Database Connection Failed**
   ```bash
   # Check database status
   make db-status
   
   # Reset database
   make db-reset
   ```

2. **High Memory Usage**
   ```bash
   # Check memory usage
   make profile-memory
   
   # Analyze heap dump
   go tool pprof heap.prof
   ```

3. **Slow API Responses**
   ```bash
   # Enable query logging
   export LOG_LEVEL=debug
   
   # Profile API calls
   make profile-api
   ```

### Debugging

```bash
# Enable debug mode
export GIN_MODE=debug
export LOG_LEVEL=debug

# Run with debugger
dlv debug ./cmd/metrics-svc
```

## 🤝 Contributing

1. **Fork the repository**
2. **Create feature branch**: `git checkout -b feature/new-feature`
3. **Write tests**: Ensure 80%+ coverage
4. **Commit changes**: Use conventional commits
5. **Push to branch**: `git push origin feature/new-feature`
6. **Create Pull Request**: Include description and tests

### Commit Convention

```
feat: add new jump analysis algorithm
fix: resolve database connection timeout
docs: update API documentation
test: add integration tests for metrics
refactor: optimize database queries
```

## 📞 Support

- **Documentation**: [docs.dunksense.ai](https://docs.dunksense.ai)
- **Issues**: [GitHub Issues](https://github.com/Danchouvzv/DunkSense/issues)
- **Slack**: #dunksense-support
- **Email**: support@dunksense.ai

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🎯 Roadmap

### Q1 2024
- [ ] Real-time video processing
- [ ] Advanced ML models
- [ ] Mobile app optimization

### Q2 2024
- [ ] Multi-sport support
- [ ] Team management features
- [ ] Advanced analytics dashboard

### Q3 2024
- [ ] AI coaching recommendations
- [ ] Social features
- [ ] Competition platform

---

**Built with ❤️ by the DunkSense Team**
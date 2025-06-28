package config

import (
	"fmt"
	"os"
	"strconv"
	"time"
)

// Config holds all configuration for the application
type Config struct {
	// Server configuration
	Server ServerConfig `mapstructure:"server"`
	
	// Database configuration
	Database DatabaseConfig `mapstructure:"database"`
	
	// Authentication configuration
	Auth AuthConfig `mapstructure:"auth"`
	
	// Kafka configuration
	Kafka KafkaConfig `mapstructure:"kafka"`
	
	// External services
	External ExternalConfig `mapstructure:"external"`
	
	// Monitoring configuration
	Monitoring MonitoringConfig `mapstructure:"monitoring"`
	
	// TLS configuration
	TLS TLSConfig `mapstructure:"tls"`
}

type ServerConfig struct {
	HTTPPort     string        `mapstructure:"http_port"`
	GRPCPort     string        `mapstructure:"grpc_port"`
	ReadTimeout  time.Duration `mapstructure:"read_timeout"`
	WriteTimeout time.Duration `mapstructure:"write_timeout"`
	Environment  string        `mapstructure:"environment"`
	Debug        bool          `mapstructure:"debug"`
}

type DatabaseConfig struct {
	MongoURI    string `mapstructure:"mongo_uri"`
	PostgresURI string `mapstructure:"postgres_uri"`
	RedisURL    string `mapstructure:"redis_url"`
}

type AuthConfig struct {
	JWTSecret           string        `mapstructure:"jwt_secret"`
	JWTExpiry           time.Duration `mapstructure:"jwt_expiry"`
	RefreshTokenExpiry  time.Duration `mapstructure:"refresh_token_expiry"`
	AppleTeamID         string        `mapstructure:"apple_team_id"`
	AppleKeyID          string        `mapstructure:"apple_key_id"`
	ApplePrivateKeyPath string        `mapstructure:"apple_private_key_path"`
}

type KafkaConfig struct {
	Brokers       []string `mapstructure:"brokers"`
	TopicJumpRaw  string   `mapstructure:"topic_jump_raw"`
	TopicJumpDaily string  `mapstructure:"topic_jump_daily"`
	ConsumerGroup string   `mapstructure:"consumer_group"`
}

type ExternalConfig struct {
	OpenAIAPIKey      string `mapstructure:"openai_api_key"`
	FirebaseProjectID string `mapstructure:"firebase_project_id"`
	FCMServerKey      string `mapstructure:"fcm_server_key"`
	S3Endpoint        string `mapstructure:"s3_endpoint"`
	S3AccessKey       string `mapstructure:"s3_access_key"`
	S3SecretKey       string `mapstructure:"s3_secret_key"`
	S3BucketPlans     string `mapstructure:"s3_bucket_plans"`
	S3BucketVideos    string `mapstructure:"s3_bucket_videos"`
}

type MonitoringConfig struct {
	PrometheusEndpoint string `mapstructure:"prometheus_endpoint"`
	JaegerEndpoint     string `mapstructure:"jaeger_endpoint"`
	LogLevel           string `mapstructure:"log_level"`
}

type TLSConfig struct {
	CertPath string `mapstructure:"cert_path"`
	KeyPath  string `mapstructure:"key_path"`
	CAPath   string `mapstructure:"ca_path"`
	Enabled  bool   `mapstructure:"enabled"`
}

// LoadConfig loads configuration from environment variables
func LoadConfig() (*Config, error) {
	config := &Config{
		Server: ServerConfig{
			HTTPPort:     getEnv("HTTP_PORT", ":8080"),
			GRPCPort:     getEnv("GRPC_PORT", ":50051"),
			ReadTimeout:  getDurationEnv("READ_TIMEOUT", 30*time.Second),
			WriteTimeout: getDurationEnv("WRITE_TIMEOUT", 30*time.Second),
			Environment:  getEnv("ENVIRONMENT", "development"),
			Debug:        getBoolEnv("DEBUG", false),
		},
		Database: DatabaseConfig{
			MongoURI:    getEnv("MONGODB_URI", "mongodb://localhost:27017/dunksense"),
			PostgresURI: getEnv("POSTGRES_URI", "postgres://postgres:password@localhost:5432/dunksense?sslmode=disable"),
			RedisURL:    getEnv("REDIS_URL", "redis://localhost:6379"),
		},
		Auth: AuthConfig{
			JWTSecret:           getEnv("JWT_SECRET", "development-secret-change-in-production"),
			JWTExpiry:           getDurationEnv("JWT_EXPIRY", 24*time.Hour),
			RefreshTokenExpiry:  getDurationEnv("REFRESH_TOKEN_EXPIRY", 30*24*time.Hour),
			AppleTeamID:         getEnv("APPLE_TEAM_ID", ""),
			AppleKeyID:          getEnv("APPLE_KEY_ID", ""),
			ApplePrivateKeyPath: getEnv("APPLE_PRIVATE_KEY_PATH", ""),
		},
		Kafka: KafkaConfig{
			Brokers:       getSliceEnv("KAFKA_BROKERS", []string{"localhost:9092"}),
			TopicJumpRaw:  getEnv("KAFKA_TOPIC_JUMP_RAW", "jump.raw"),
			TopicJumpDaily: getEnv("KAFKA_TOPIC_JUMP_DAILY", "jump.daily"),
			ConsumerGroup: getEnv("KAFKA_CONSUMER_GROUP", "dunksense-processors"),
		},
		External: ExternalConfig{
			OpenAIAPIKey:      getEnv("OPENAI_API_KEY", ""),
			FirebaseProjectID: getEnv("FIREBASE_PROJECT_ID", ""),
			FCMServerKey:      getEnv("FCM_SERVER_KEY", ""),
			S3Endpoint:        getEnv("S3_ENDPOINT", "localhost:9000"),
			S3AccessKey:       getEnv("S3_ACCESS_KEY", "minioadmin"),
			S3SecretKey:       getEnv("S3_SECRET_KEY", "minioadmin"),
			S3BucketPlans:     getEnv("S3_BUCKET_PLANS", "dunksense-plans"),
			S3BucketVideos:    getEnv("S3_BUCKET_VIDEOS", "dunksense-videos"),
		},
		Monitoring: MonitoringConfig{
			PrometheusEndpoint: getEnv("PROMETHEUS_ENDPOINT", "http://localhost:9090"),
			JaegerEndpoint:     getEnv("JAEGER_ENDPOINT", "http://localhost:14268"),
			LogLevel:           getEnv("LOG_LEVEL", "info"),
		},
		TLS: TLSConfig{
			CertPath: getEnv("TLS_CERT_PATH", ""),
			KeyPath:  getEnv("TLS_KEY_PATH", ""),
			CAPath:   getEnv("TLS_CA_PATH", ""),
			Enabled:  getBoolEnv("TLS_ENABLED", false),
		},
	}

	// Validate required fields
	if err := validateConfig(config); err != nil {
		return nil, fmt.Errorf("config validation failed: %w", err)
	}

	return config, nil
}

// validateConfig validates required configuration fields
func validateConfig(config *Config) error {
	if config.Auth.JWTSecret == "" || config.Auth.JWTSecret == "development-secret-change-in-production" {
		if config.Server.Environment == "production" {
			return fmt.Errorf("JWT_SECRET must be set in production")
		}
	}

	if config.Server.Environment == "production" {
		if config.External.OpenAIAPIKey == "" {
			return fmt.Errorf("OPENAI_API_KEY is required in production")
		}
		if config.External.FirebaseProjectID == "" {
			return fmt.Errorf("FIREBASE_PROJECT_ID is required in production")
		}
	}

	return nil
}

// Helper functions for environment variable parsing
func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getBoolEnv(key string, defaultValue bool) bool {
	if value := os.Getenv(key); value != "" {
		if parsed, err := strconv.ParseBool(value); err == nil {
			return parsed
		}
	}
	return defaultValue
}

func getDurationEnv(key string, defaultValue time.Duration) time.Duration {
	if value := os.Getenv(key); value != "" {
		if parsed, err := time.ParseDuration(value); err == nil {
			return parsed
		}
	}
	return defaultValue
}

func getSliceEnv(key string, defaultValue []string) []string {
	if value := os.Getenv(key); value != "" {
		// Simple split by comma - could be enhanced
		return []string{value}
	}
	return defaultValue
} 
package security

import (
	"context"
	"crypto/subtle"
	"fmt"
	"net"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/go-redis/redis/v8"
	"github.com/golang-jwt/jwt/v5"
	"go.uber.org/zap"
	"golang.org/x/time/rate"
)

// SecurityConfig holds security configuration
type SecurityConfig struct {
	// CORS settings
	AllowedOrigins     []string `json:"allowed_origins"`
	AllowedMethods     []string `json:"allowed_methods"`
	AllowedHeaders     []string `json:"allowed_headers"`
	AllowCredentials   bool     `json:"allow_credentials"`
	MaxAge             int      `json:"max_age"`

	// Rate limiting
	RateLimit          int           `json:"rate_limit"`          // requests per minute
	RateLimitBurst     int           `json:"rate_limit_burst"`    // burst capacity
	RateLimitWindow    time.Duration `json:"rate_limit_window"`   // time window

	// JWT settings
	JWTSecret          string        `json:"jwt_secret"`
	JWTExpiration      time.Duration `json:"jwt_expiration"`
	JWTIssuer          string        `json:"jwt_issuer"`

	// Security headers
	EnableHSTS         bool          `json:"enable_hsts"`
	HSTSMaxAge         int           `json:"hsts_max_age"`
	EnableCSP          bool          `json:"enable_csp"`
	CSPPolicy          string        `json:"csp_policy"`
	EnableXFrameOptions bool         `json:"enable_x_frame_options"`
	XFrameOptions      string        `json:"x_frame_options"`

	// IP filtering
	AllowedIPs         []string      `json:"allowed_ips"`
	BlockedIPs         []string      `json:"blocked_ips"`
	TrustedProxies     []string      `json:"trusted_proxies"`

	// API Key settings
	RequireAPIKey      bool          `json:"require_api_key"`
	ValidAPIKeys       []string      `json:"valid_api_keys"`
}

// SecurityMiddleware provides security middleware
type SecurityMiddleware struct {
	config    *SecurityConfig
	logger    *zap.Logger
	redis     *redis.Client
	limiters  map[string]*rate.Limiter
	limiterMu sync.RWMutex
}

// NewSecurityMiddleware creates a new security middleware
func NewSecurityMiddleware(config *SecurityConfig, logger *zap.Logger, redis *redis.Client) *SecurityMiddleware {
	return &SecurityMiddleware{
		config:   config,
		logger:   logger,
		redis:    redis,
		limiters: make(map[string]*rate.Limiter),
	}
}

// CORS middleware
func (sm *SecurityMiddleware) CORS() gin.HandlerFunc {
	return func(c *gin.Context) {
		origin := c.Request.Header.Get("Origin")
		
		// Check if origin is allowed
		allowed := false
		for _, allowedOrigin := range sm.config.AllowedOrigins {
			if allowedOrigin == "*" || allowedOrigin == origin {
				allowed = true
				break
			}
		}
		
		if allowed {
			c.Header("Access-Control-Allow-Origin", origin)
		}
		
		c.Header("Access-Control-Allow-Methods", strings.Join(sm.config.AllowedMethods, ", "))
		c.Header("Access-Control-Allow-Headers", strings.Join(sm.config.AllowedHeaders, ", "))
		c.Header("Access-Control-Max-Age", strconv.Itoa(sm.config.MaxAge))
		
		if sm.config.AllowCredentials {
			c.Header("Access-Control-Allow-Credentials", "true")
		}
		
		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}
		
		c.Next()
	}
}

// SecurityHeaders middleware adds security headers
func (sm *SecurityMiddleware) SecurityHeaders() gin.HandlerFunc {
	return func(c *gin.Context) {
		// HSTS
		if sm.config.EnableHSTS && c.Request.TLS != nil {
			c.Header("Strict-Transport-Security", fmt.Sprintf("max-age=%d; includeSubDomains", sm.config.HSTSMaxAge))
		}
		
		// Content Security Policy
		if sm.config.EnableCSP && sm.config.CSPPolicy != "" {
			c.Header("Content-Security-Policy", sm.config.CSPPolicy)
		}
		
		// X-Frame-Options
		if sm.config.EnableXFrameOptions {
			c.Header("X-Frame-Options", sm.config.XFrameOptions)
		}
		
		// Other security headers
		c.Header("X-Content-Type-Options", "nosniff")
		c.Header("X-XSS-Protection", "1; mode=block")
		c.Header("Referrer-Policy", "strict-origin-when-cross-origin")
		c.Header("Permissions-Policy", "geolocation=(), microphone=(), camera=()")
		
		c.Next()
	}
}

// RateLimit middleware implements rate limiting
func (sm *SecurityMiddleware) RateLimit() gin.HandlerFunc {
	return func(c *gin.Context) {
		clientIP := c.ClientIP()
		
		// Use Redis-based rate limiting if available
		if sm.redis != nil {
			if !sm.checkRedisRateLimit(c, clientIP) {
				sm.logger.Warn("Rate limit exceeded", 
					zap.String("client_ip", clientIP),
					zap.String("path", c.Request.URL.Path),
				)
				c.JSON(http.StatusTooManyRequests, gin.H{
					"error": "Rate limit exceeded",
					"retry_after": sm.config.RateLimitWindow.Seconds(),
				})
				c.Abort()
				return
			}
		} else {
			// Fallback to in-memory rate limiting
			if !sm.checkInMemoryRateLimit(clientIP) {
				sm.logger.Warn("Rate limit exceeded", 
					zap.String("client_ip", clientIP),
					zap.String("path", c.Request.URL.Path),
				)
				c.JSON(http.StatusTooManyRequests, gin.H{
					"error": "Rate limit exceeded",
					"retry_after": sm.config.RateLimitWindow.Seconds(),
				})
				c.Abort()
				return
			}
		}
		
		c.Next()
	}
}

// checkRedisRateLimit checks rate limit using Redis
func (sm *SecurityMiddleware) checkRedisRateLimit(c *gin.Context, clientIP string) bool {
	ctx := c.Request.Context()
	key := fmt.Sprintf("rate_limit:%s", clientIP)
	
	// Use Redis sliding window rate limiting
	pipe := sm.redis.Pipeline()
	now := time.Now().Unix()
	window := int64(sm.config.RateLimitWindow.Seconds())
	
	// Remove old entries
	pipe.ZRemRangeByScore(ctx, key, "0", fmt.Sprintf("%d", now-window))
	
	// Count current requests
	pipe.ZCard(ctx, key)
	
	// Add current request
	pipe.ZAdd(ctx, key, &redis.Z{Score: float64(now), Member: now})
	
	// Set expiration
	pipe.Expire(ctx, key, sm.config.RateLimitWindow)
	
	results, err := pipe.Exec(ctx)
	if err != nil {
		sm.logger.Error("Redis rate limit error", zap.Error(err))
		return true // Allow request on Redis error
	}
	
	// Get count result
	countCmd := results[1].(*redis.IntCmd)
	count, err := countCmd.Result()
	if err != nil {
		sm.logger.Error("Redis rate limit count error", zap.Error(err))
		return true
	}
	
	return count < int64(sm.config.RateLimit)
}

// checkInMemoryRateLimit checks rate limit using in-memory limiters
func (sm *SecurityMiddleware) checkInMemoryRateLimit(clientIP string) bool {
	sm.limiterMu.RLock()
	limiter, exists := sm.limiters[clientIP]
	sm.limiterMu.RUnlock()
	
	if !exists {
		sm.limiterMu.Lock()
		// Double-check after acquiring write lock
		if limiter, exists = sm.limiters[clientIP]; !exists {
			limiter = rate.NewLimiter(rate.Every(sm.config.RateLimitWindow/time.Duration(sm.config.RateLimit)), sm.config.RateLimitBurst)
			sm.limiters[clientIP] = limiter
		}
		sm.limiterMu.Unlock()
	}
	
	return limiter.Allow()
}

// IPFilter middleware filters requests based on IP addresses
func (sm *SecurityMiddleware) IPFilter() gin.HandlerFunc {
	return func(c *gin.Context) {
		clientIP := c.ClientIP()
		
		// Check blocked IPs
		for _, blockedIP := range sm.config.BlockedIPs {
			if sm.matchIP(clientIP, blockedIP) {
				sm.logger.Warn("Blocked IP attempted access", 
					zap.String("client_ip", clientIP),
					zap.String("blocked_pattern", blockedIP),
				)
				c.JSON(http.StatusForbidden, gin.H{"error": "Access denied"})
				c.Abort()
				return
			}
		}
		
		// Check allowed IPs (if configured)
		if len(sm.config.AllowedIPs) > 0 {
			allowed := false
			for _, allowedIP := range sm.config.AllowedIPs {
				if sm.matchIP(clientIP, allowedIP) {
					allowed = true
					break
				}
			}
			
			if !allowed {
				sm.logger.Warn("Non-whitelisted IP attempted access", 
					zap.String("client_ip", clientIP),
				)
				c.JSON(http.StatusForbidden, gin.H{"error": "Access denied"})
				c.Abort()
				return
			}
		}
		
		c.Next()
	}
}

// matchIP checks if an IP matches a pattern (supports CIDR)
func (sm *SecurityMiddleware) matchIP(clientIP, pattern string) bool {
	// Try exact match first
	if clientIP == pattern {
		return true
	}
	
	// Try CIDR match
	_, ipNet, err := net.ParseCIDR(pattern)
	if err != nil {
		return false
	}
	
	ip := net.ParseIP(clientIP)
	if ip == nil {
		return false
	}
	
	return ipNet.Contains(ip)
}

// APIKeyAuth middleware validates API keys
func (sm *SecurityMiddleware) APIKeyAuth() gin.HandlerFunc {
	return func(c *gin.Context) {
		if !sm.config.RequireAPIKey {
			c.Next()
			return
		}
		
		apiKey := c.GetHeader("X-API-Key")
		if apiKey == "" {
			apiKey = c.Query("api_key")
		}
		
		if apiKey == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "API key required"})
			c.Abort()
			return
		}
		
		// Validate API key using constant-time comparison
		valid := false
		for _, validKey := range sm.config.ValidAPIKeys {
			if subtle.ConstantTimeCompare([]byte(apiKey), []byte(validKey)) == 1 {
				valid = true
				break
			}
		}
		
		if !valid {
			sm.logger.Warn("Invalid API key attempted", 
				zap.String("client_ip", c.ClientIP()),
				zap.String("api_key_prefix", apiKey[:min(len(apiKey), 8)]),
			)
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid API key"})
			c.Abort()
			return
		}
		
		c.Next()
	}
}

// JWTAuth middleware validates JWT tokens
func (sm *SecurityMiddleware) JWTAuth() gin.HandlerFunc {
	return func(c *gin.Context) {
		tokenString := c.GetHeader("Authorization")
		if tokenString == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization header required"})
			c.Abort()
			return
		}
		
		// Remove "Bearer " prefix
		if strings.HasPrefix(tokenString, "Bearer ") {
			tokenString = tokenString[7:]
		}
		
		// Parse and validate token
		token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
			// Validate signing method
			if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
			}
			return []byte(sm.config.JWTSecret), nil
		})
		
		if err != nil {
			sm.logger.Warn("Invalid JWT token", 
				zap.String("client_ip", c.ClientIP()),
				zap.Error(err),
			)
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token"})
			c.Abort()
			return
		}
		
		if claims, ok := token.Claims.(jwt.MapClaims); ok && token.Valid {
			// Validate issuer
			if iss, ok := claims["iss"].(string); ok && iss != sm.config.JWTIssuer {
				c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token issuer"})
				c.Abort()
				return
			}
			
			// Store claims in context
			c.Set("jwt_claims", claims)
			c.Set("user_id", claims["sub"])
		} else {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token claims"})
			c.Abort()
			return
		}
		
		c.Next()
	}
}

// RequestLogger middleware logs security-relevant requests
func (sm *SecurityMiddleware) RequestLogger() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		
		// Process request
		c.Next()
		
		// Log request details
		duration := time.Since(start)
		status := c.Writer.Status()
		
		fields := []zap.Field{
			zap.String("method", c.Request.Method),
			zap.String("path", c.Request.URL.Path),
			zap.String("client_ip", c.ClientIP()),
			zap.String("user_agent", c.Request.UserAgent()),
			zap.Int("status", status),
			zap.Duration("duration", duration),
			zap.String("request_id", c.GetString("request_id")),
		}
		
		// Add user ID if authenticated
		if userID := c.GetString("user_id"); userID != "" {
			fields = append(fields, zap.String("user_id", userID))
		}
		
		// Log with appropriate level based on status
		if status >= 400 {
			if status >= 500 {
				sm.logger.Error("Request failed", fields...)
			} else {
				sm.logger.Warn("Request error", fields...)
			}
		} else {
			sm.logger.Info("Request completed", fields...)
		}
	}
}

// TrustedProxies configures trusted proxy settings
func (sm *SecurityMiddleware) TrustedProxies() gin.HandlerFunc {
	return func(c *gin.Context) {
		// This would typically be handled at the Gin engine level
		// but we can add additional validation here
		c.Next()
	}
}

// Helper function for min
func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

// SecurityMetrics tracks security-related metrics
type SecurityMetrics struct {
	RateLimitHits    int64 `json:"rate_limit_hits"`
	BlockedIPs       int64 `json:"blocked_ips"`
	InvalidAPIKeys   int64 `json:"invalid_api_keys"`
	InvalidJWTTokens int64 `json:"invalid_jwt_tokens"`
	TotalRequests    int64 `json:"total_requests"`
}

// GetMetrics returns security metrics
func (sm *SecurityMiddleware) GetMetrics() SecurityMetrics {
	// This would typically be implemented with atomic counters
	// or metrics collection system like Prometheus
	return SecurityMetrics{}
}

// CleanupLimiters removes old rate limiters to prevent memory leaks
func (sm *SecurityMiddleware) CleanupLimiters() {
	sm.limiterMu.Lock()
	defer sm.limiterMu.Unlock()
	
	// In a production system, you'd implement proper cleanup logic
	// based on last access time or use a TTL cache
	if len(sm.limiters) > 10000 {
		sm.limiters = make(map[string]*rate.Limiter)
	}
} 
package auth

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/hwview/hwview/config"
)

type Middleware struct {
	enabled  bool
	adminKey string
}

func NewMiddleware(cfg *config.AuthConfig) *Middleware {
	return &Middleware{enabled: cfg.Enabled, adminKey: cfg.AdminKey}
}

func (m *Middleware) RequireAdmin() gin.HandlerFunc {
	return func(c *gin.Context) {
		if !m.enabled {
			c.Next()
			return
		}
		key := c.GetHeader("X-Admin-Key")
		if key == "" {
			key = strings.TrimPrefix(c.GetHeader("Authorization"), "Bearer ")
		}
		if key != m.adminKey {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
			return
		}
		c.Set("actor", "admin")
		c.Next()
	}
}

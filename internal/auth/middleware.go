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
			c.Set("actor", "admin")
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

func (m *Middleware) Login() gin.HandlerFunc {
	return func(c *gin.Context) {
		var req struct {
			Key string `json:"key" binding:"required"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "key is required"})
			return
		}
		if !m.enabled {
			c.JSON(http.StatusOK, gin.H{"status": "ok", "auth_enabled": false})
			return
		}
		if req.Key != m.adminKey {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid admin key"})
			return
		}
		c.JSON(http.StatusOK, gin.H{"status": "ok", "token": req.Key})
	}
}

func (m *Middleware) Check() gin.HandlerFunc {
	return func(c *gin.Context) {
		if !m.enabled {
			c.JSON(http.StatusOK, gin.H{"status": "ok", "auth_enabled": false})
			return
		}
		key := c.GetHeader("X-Admin-Key")
		if key == "" {
			key = strings.TrimPrefix(c.GetHeader("Authorization"), "Bearer ")
		}
		if key != m.adminKey {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
			return
		}
		c.JSON(http.StatusOK, gin.H{"status": "ok", "auth_enabled": true})
	}
}

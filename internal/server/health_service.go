package server

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/hwview/hwview/pkg/model"
	"gorm.io/gorm"
)

type HealthService struct {
	db *gorm.DB
}

func NewHealthService(db *gorm.DB) *HealthService {
	return &HealthService{db: db}
}

func (s *HealthService) RegisterRoutes(rg *gin.RouterGroup) {
	health := rg.Group("/health")
	health.GET("/sources", s.listSourcesHealth)
	health.GET("/lines/:lineCode", s.lineHealthHandler)
}

func (s *HealthService) listSourcesHealth(c *gin.Context) {
	var healths []model.DataSourceHealth
	if err := s.db.Find(&healths).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"healths": healths})
}

func (s *HealthService) lineHealthHandler(c *gin.Context) {
	lineCode := c.Param("lineCode")
	var line model.ProductionLine
	if err := s.db.Where("line_code = ?", lineCode).First(&line).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "line not found"})
		return
	}
	var sources []model.DataSource
	s.db.Where("line_id = ?", line.ID).Find(&sources)

	var healths []model.DataSourceHealth
	for _, src := range sources {
		var h model.DataSourceHealth
		if err := s.db.Where("source_id = ?", src.ID).First(&h).Error; err == nil {
			healths = append(healths, h)
		}
	}
	c.JSON(http.StatusOK, gin.H{"line": lineCode, "healths": healths})
}

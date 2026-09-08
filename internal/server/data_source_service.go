package server

import (
	"context"
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/hwview/hwview/internal/audit"
	"github.com/hwview/hwview/internal/store"
	"github.com/hwview/hwview/pkg/model"
)

type DataSourceService struct {
	repo  *store.DataSourceRepo
	audit *audit.Service
}

func NewDataSourceService(repo *store.DataSourceRepo, auditSvc *audit.Service) *DataSourceService {
	return &DataSourceService{repo: repo, audit: auditSvc}
}

type CreateSourceRequest struct {
	LineID    int64  `json:"line_id" binding:"required"`
	AgentID   string `json:"agent_id"`
	Hostname  string `json:"hostname"`
	CurrentIP string `json:"current_ip" binding:"required"`
	Port      int    `json:"port" binding:"required"`
	BasePath  string `json:"base_path" binding:"required"`
	Enabled   *bool  `json:"enabled"`
}

type UpdateIPRequest struct {
	CurrentIP string `json:"current_ip" binding:"required"`
}

func (s *DataSourceService) Create(ctx context.Context, req *CreateSourceRequest, actor string) (*model.DataSource, error) {
	src := &model.DataSource{
		LineID:    req.LineID,
		AgentID:   req.AgentID,
		Hostname:  req.Hostname,
		CurrentIP: req.CurrentIP,
		Port:      req.Port,
		BasePath:  req.BasePath,
		Enabled:   true,
		Status:    model.SourceStatusOffline,
	}
	if req.Enabled != nil {
		src.Enabled = *req.Enabled
	}
	if err := s.repo.Create(ctx, src); err != nil {
		if errors.Is(err, store.ErrSourceLineConflict) {
			return nil, ErrSourceLineConflict
		}
		if errors.Is(err, store.ErrRequiredFieldEmpty) {
			return nil, ErrRequiredFieldEmpty
		}
		return nil, err
	}
	_ = s.audit.Record(ctx, actor, "CREATE", "DataSource", "", req, false)
	return src, nil
}

func (s *DataSourceService) ListByLine(ctx context.Context, lineID int64) ([]model.DataSource, error) {
	return s.repo.ListByLine(ctx, lineID)
}

func (s *DataSourceService) UpdateIP(ctx context.Context, id int64, newIP string, actor string) error {
	if err := s.repo.UpdateCurrentIP(ctx, id, newIP); err != nil {
		return err
	}
	_ = s.audit.Record(ctx, actor, "IP_CHANGED", "DataSource", "", map[string]string{"new_ip": newIP}, false)
	return nil
}

var ErrSourceLineConflict = errors.New("data source conflict")

func (s *DataSourceService) RegisterRoutes(rg *gin.RouterGroup, authMW gin.HandlerFunc) {
	sources := rg.Group("/sources", authMW)
	sources.POST("", s.createHandler)
	sources.GET("", s.listHandler)
	sources.GET("/line/:lineID", s.listByLineHandler)
	sources.PUT("/:id/ip", s.updateIPHandler)
}

func (s *DataSourceService) createHandler(c *gin.Context) {
	var req CreateSourceRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
		return
	}
	actor, _ := c.Get("actor")
	actorStr, _ := actor.(string)
	src, err := s.Create(c.Request.Context(), &req, actorStr)
	if err != nil {
		s.mapError(c, err)
		return
	}
	c.JSON(http.StatusCreated, src)
}

func (s *DataSourceService) listHandler(c *gin.Context) {
	sources, err := s.repo.List(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"sources": sources})
}

func (s *DataSourceService) listByLineHandler(c *gin.Context) {
	lineID := strToInt64(c.Param("lineID"))
	sources, err := s.ListByLine(c.Request.Context(), lineID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"sources": sources})
}

func (s *DataSourceService) updateIPHandler(c *gin.Context) {
	var req UpdateIPRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
		return
	}
	id := strToInt64(c.Param("id"))
	actor, _ := c.Get("actor")
	actorStr, _ := actor.(string)
	if err := s.UpdateIP(c.Request.Context(), id, req.CurrentIP, actorStr); err != nil {
		if errors.Is(err, store.ErrSourceNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"error": "source not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"status": "ok"})
}

func (s *DataSourceService) mapError(c *gin.Context, err error) {
	switch {
	case errors.Is(err, ErrSourceLineConflict):
		c.JSON(http.StatusConflict, gin.H{"error": "data source conflict"})
	case errors.Is(err, ErrRequiredFieldEmpty):
		c.JSON(http.StatusBadRequest, gin.H{"error": "required field empty"})
	default:
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
	}
}

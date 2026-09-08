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

type ProductionLineService struct {
	repo  *store.ProductionLineRepo
	audit *audit.Service
}

func NewProductionLineService(repo *store.ProductionLineRepo, auditSvc *audit.Service) *ProductionLineService {
	return &ProductionLineService{repo: repo, audit: auditSvc}
}

type CreateLineRequest struct {
	LineCode    string `json:"line_code" binding:"required"`
	LineName    string `json:"line_name" binding:"required"`
	Customer    string `json:"customer" binding:"required"`
	Product     string `json:"product" binding:"required"`
	AdapterType string `json:"adapter_type" binding:"required"`
	Enabled     *bool  `json:"enabled"`
}

type UpdateLineRequest struct {
	LineName    *string `json:"line_name"`
	Customer    *string `json:"customer"`
	Product     *string `json:"product"`
	AdapterType *string `json:"adapter_type"`
	Enabled     *bool   `json:"enabled"`
	Status      *string `json:"status"`
}

func (s *ProductionLineService) Create(ctx context.Context, req *CreateLineRequest, actor string) (*model.ProductionLine, error) {
	line := &model.ProductionLine{
		LineCode:    req.LineCode,
		LineName:    req.LineName,
		Customer:    req.Customer,
		Product:     req.Product,
		AdapterType: req.AdapterType,
		Enabled:     true,
		Status:      model.LineStatusConfigured,
	}
	if req.Enabled != nil {
		line.Enabled = *req.Enabled
	}

	if err := s.repo.Create(ctx, line); err != nil {
		if errors.Is(err, store.ErrLineCodeConflict) {
			return nil, ErrLineCodeConflict
		}
		if errors.Is(err, store.ErrRequiredFieldEmpty) {
			return nil, ErrRequiredFieldEmpty
		}
		return nil, err
	}

	_ = s.audit.Record(ctx, actor, "CREATE", "ProductionLine", line.LineCode, req, false)
	return line, nil
}

func (s *ProductionLineService) GetByCode(ctx context.Context, code string) (*model.ProductionLine, error) {
	return s.repo.GetByCode(ctx, code)
}

func (s *ProductionLineService) List(ctx context.Context) ([]model.ProductionLine, error) {
	return s.repo.List(ctx)
}

func (s *ProductionLineService) Update(ctx context.Context, id int64, req *UpdateLineRequest, actor string) (*model.ProductionLine, error) {
	line, err := s.repo.GetByID(ctx, id)
	if err != nil {
		return nil, err
	}
	if req.LineName != nil {
		line.LineName = *req.LineName
	}
	if req.Customer != nil {
		line.Customer = *req.Customer
	}
	if req.Product != nil {
		line.Product = *req.Product
	}
	if req.AdapterType != nil {
		line.AdapterType = *req.AdapterType
	}
	if req.Enabled != nil {
		line.Enabled = *req.Enabled
	}
	if req.Status != nil {
		line.Status = *req.Status
	}

	if err := s.repo.Update(ctx, line); err != nil {
		if errors.Is(err, store.ErrLineCodeConflict) {
			return nil, ErrLineCodeConflict
		}
		return nil, err
	}
	_ = s.audit.Record(ctx, actor, "UPDATE", "ProductionLine", line.LineCode, req, false)
	return line, nil
}

func (s *ProductionLineService) Delete(ctx context.Context, id int64, actor string) error {
	line, err := s.repo.GetByID(ctx, id)
	if err != nil {
		return err
	}
	if err := s.repo.Delete(ctx, id); err != nil {
		return err
	}
	_ = s.audit.Record(ctx, actor, "DELETE", "ProductionLine", line.LineCode, nil, false)
	return nil
}

var (
	ErrLineCodeConflict   = errors.New("line_code conflict")
	ErrRequiredFieldEmpty = errors.New("required field empty")
)

func (s *ProductionLineService) RegisterRoutes(rg *gin.RouterGroup, authMW gin.HandlerFunc) {
	lines := rg.Group("/lines", authMW)
	lines.POST("", s.createHandler)
	lines.GET("", s.listHandler)
	lines.GET("/:lineCode", s.getByCodeHandler)
	lines.PUT("/:id", s.updateHandler)
	lines.DELETE("/:id", s.deleteHandler)
}

func (s *ProductionLineService) createHandler(c *gin.Context) {
	var req CreateLineRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request", "detail": err.Error()})
		return
	}
	actor, _ := c.Get("actor")
	actorStr, _ := actor.(string)
	line, err := s.Create(c.Request.Context(), &req, actorStr)
	if err != nil {
		s.mapError(c, err)
		return
	}
	c.JSON(http.StatusCreated, line)
}

func (s *ProductionLineService) listHandler(c *gin.Context) {
	lines, err := s.List(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"lines": lines})
}

func (s *ProductionLineService) getByCodeHandler(c *gin.Context) {
	code := c.Param("lineCode")
	line, err := s.GetByCode(c.Request.Context(), code)
	if err != nil {
		if errors.Is(err, store.ErrLineNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"error": "line not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, line)
}

func (s *ProductionLineService) updateHandler(c *gin.Context) {
	var req UpdateLineRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
		return
	}
	id := strToInt64(c.Param("id"))
	actor, _ := c.Get("actor")
	actorStr, _ := actor.(string)
	line, err := s.Update(c.Request.Context(), id, &req, actorStr)
	if err != nil {
		s.mapError(c, err)
		return
	}
	c.JSON(http.StatusOK, line)
}

func (s *ProductionLineService) deleteHandler(c *gin.Context) {
	id := strToInt64(c.Param("id"))
	actor, _ := c.Get("actor")
	actorStr, _ := actor.(string)
	if err := s.Delete(c.Request.Context(), id, actorStr); err != nil {
		if errors.Is(err, store.ErrLineNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"error": "line not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusNoContent, nil)
}

func (s *ProductionLineService) mapError(c *gin.Context, err error) {
	switch {
	case errors.Is(err, ErrLineCodeConflict):
		c.JSON(http.StatusConflict, gin.H{"error": "line_code already exists"})
	case errors.Is(err, ErrRequiredFieldEmpty):
		c.JSON(http.StatusBadRequest, gin.H{"error": "required field empty"})
	case errors.Is(err, store.ErrLineNotFound):
		c.JSON(http.StatusNotFound, gin.H{"error": "line not found"})
	default:
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
	}
}

func strToInt64(s string) int64 {
	var n int64
	for _, c := range s {
		if c >= '0' && c <= '9' {
			n = n*10 + int64(c-'0')
		}
	}
	return n
}

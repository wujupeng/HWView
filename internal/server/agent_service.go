package server

import (
	"context"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/hwview/hwview/internal/audit"
	"github.com/hwview/hwview/pkg/model"
	"gorm.io/gorm"
)

type AgentService struct {
	db    *gorm.DB
	audit *audit.Service
}

func NewAgentService(db *gorm.DB, auditSvc *audit.Service) *AgentService {
	return &AgentService{db: db, audit: auditSvc}
}

type HeartbeatRequest struct {
	AgentID   string `json:"agent_id" binding:"required"`
	Hostname  string `json:"hostname" binding:"required"`
	MachineID string `json:"machine_id" binding:"required"`
	MAC       string `json:"mac" binding:"required"`
	IPv4      string `json:"ipv4" binding:"required"`
}

type IPChangedRequest struct {
	AgentID string `json:"agent_id" binding:"required"`
	OldIP   string `json:"old_ip" binding:"required"`
	NewIP   string `json:"new_ip" binding:"required"`
}

func (s *AgentService) Heartbeat(ctx context.Context, req *HeartbeatRequest) error {
	agent := &model.Agent{
		AgentID:         req.AgentID,
		Hostname:        req.Hostname,
		MachineID:       req.MachineID,
		MAC:             req.MAC,
		IPv4:            req.IPv4,
		LastHeartbeatAt: time.Now(),
		Status:          model.AgentStatusPendingBind,
	}

	var existing model.Agent
	err := s.db.WithContext(ctx).Where("agent_id = ?", req.AgentID).First(&existing).Error
	if err == gorm.ErrRecordNotFound {
		if err := s.db.WithContext(ctx).Create(agent).Error; err != nil {
			return err
		}
	} else if err == nil {
		agent.BoundLineID = existing.BoundLineID
		if existing.Status == model.AgentStatusBound {
			agent.Status = model.AgentStatusBound
		}
		if err := s.db.WithContext(ctx).Save(agent).Error; err != nil {
			return err
		}
	} else {
		return err
	}

	var sources []model.DataSource
	s.db.WithContext(ctx).Where("agent_id = ?", req.AgentID).Find(&sources)
	now := time.Now()
	for _, src := range sources {
		s.db.WithContext(ctx).Model(&model.DataSource{}).Where("id = ?", src.ID).
			Update("last_heartbeat_at", now)
	}

	return nil
}

func (s *AgentService) IPChanged(ctx context.Context, req *IPChangedRequest, actor string) error {
	var sources []model.DataSource
	s.db.WithContext(ctx).Where("agent_id = ?", req.AgentID).Find(&sources)

	for _, src := range sources {
		if src.CurrentIP == req.OldIP {
			s.db.WithContext(ctx).Model(&model.DataSource{}).Where("id = ?", src.ID).
				Updates(map[string]interface{}{
					"current_ip": req.NewIP,
					"status":     model.SourceStatusSwitching,
				})
		}
	}

	_ = s.audit.Record(ctx, actor, "IP_CHANGED", "Agent", req.AgentID, req, false)
	return nil
}

func (s *AgentService) RegisterRoutes(rg *gin.RouterGroup) {
	agents := rg.Group("/agent")
	agents.POST("/heartbeat", s.heartbeatHandler)
	agents.POST("/ip_changed", s.ipChangedHandler)
}

func (s *AgentService) heartbeatHandler(c *gin.Context) {
	var req HeartbeatRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
		return
	}
	if err := s.Heartbeat(c.Request.Context(), &req); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"status": "ok"})
}

func (s *AgentService) ipChangedHandler(c *gin.Context) {
	var req IPChangedRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
		return
	}
	if err := s.IPChanged(c.Request.Context(), &req, req.AgentID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"status": "ok"})
}
